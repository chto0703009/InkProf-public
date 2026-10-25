# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import sys
import tempfile
import json
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
import gamut_refinement as r
import gamut_surface as g


class GamutRefinementTests(unittest.TestCase):
    def test_neighbourhood_boundary_quantisation_and_exclusions(self):
        rows, sources = r.candidates([[0, 50, 100]], [[0, 50, 100]], radius=3, spacing=1, maximum=100)
        rgb = np.asarray(rows)
        self.assertEqual(len(rgb), 11)  # 2 x 3 x 2, less the already-measured anchor
        self.assertTrue(np.all((rgb >= 0) & (rgb <= 100)))
        np.testing.assert_allclose(rgb / 100 * 65535, np.round(rgb / 100 * 65535), atol=1e-8)
        self.assertEqual(len(set(map(tuple, rows))), len(rows))
        self.assertTrue(np.all(np.max(np.abs(rgb - [0, 50, 100]), axis=1) >= 1))
        self.assertEqual(set(sources), {1})

    def test_budget_gives_each_area_a_turn_and_spacing_is_enforced(self):
        rows, sources = r.candidates([[20, 30, 40], [70, 80, 90]], [], maximum=2)
        self.assertEqual(sources, [1, 2])
        rows, _ = r.candidates([[50, 50, 50], [50, 50, 50]], [], radius=3, spacing=2)
        rgb = np.asarray(rows)
        d = np.max(np.abs(rgb[:, None] - rgb[None, :]), axis=2)
        np.fill_diagonal(d, np.inf)
        self.assertTrue(np.all(d >= 2))

    def test_invalid_settings_and_no_new_points(self):
        for anchor, radius, spacing, budget in [([[float('nan'), 0, 0]], 3, 1, 100),
                                               ([[101, 0, 0]], 3, 1, 100),
                                               ([[50, 50, 50]], 0, 1, 100),
                                               ([[50, 50, 50]], 3, 0, 100),
                                               ([[50, 50, 50]], 3, 1, 1.5)]:
            with self.assertRaises(ValueError):
                r.candidates(anchor, [], radius, spacing, budget)
        self.assertEqual(r.candidates([[50, 50, 50]], [[50, 50, 50]], radius=1, spacing=2)[0], [])

    def test_extend_target_preserves_parent_rgb_excludes_training_and_new_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            profile=Path(tmp)/'profile.icc';profile.write_bytes(b'fixture')
            inherited=[[20,30,40],[20,30,40],[0,0,0],[60,70,80]]
            request=dict(profile=str(profile),profileSHA256=g.digest(profile),xicclu='fake',
                         anchors=[],anchorRGBPercent=[[20,30,40],[90,80,70]],existingRGBPercent=[[0,0,0]],
                         inheritedRGBPercent=inherited,radiusPercent=3,minSpacingPercent=1,maxPatches=4)
            original=profile.read_bytes()
            with patch.object(r,'forward_lookup',side_effect=lambda exe,p,rgb:rgb*100):
                proposal=r.run(request,Path(tmp)/'new')
            old=proposal['inheritedCandidates'];new=proposal['candidates']
            self.assertEqual([p['rgbPercent'] for p in old],[[20,30,40],[60,70,80]])
            self.assertEqual(proposal['extensionCounts'],dict(parentCount=4,retainedCount=2,excludedMeasuredOrDuplicate=2))
            self.assertEqual(len(new),4)
            for p in new:
                self.assertTrue(all(np.max(np.abs(np.asarray(p['rgbPercent'])-q))>=1 for q in [[0,0,0],[20,30,40],[60,70,80]]))
            self.assertEqual(set(old[0]),set(new[0]))
            self.assertEqual(profile.read_bytes(),original)
            self.assertTrue((Path(tmp)/'new'/'proposal.json').is_file())

    def test_extend_shell_retains_signed_positions_and_invalid_rgb_is_rejected(self):
        from test_gamut_shell import prism
        v,t=prism([(0,0),(100,0),(100,100),(0,100)],[[0,1,2],[0,2,3]],100)
        with tempfile.TemporaryDirectory() as tmp:
            profile=Path(tmp)/'profile.icc';profile.write_bytes(b'fixture');sha=g.digest(profile)
            request=dict(profile=str(profile),profileSHA256=sha,xicclu='fake',anchors=[],anchorRGBPercent=[],
                         existingRGBPercent=[[0,0,0]],inheritedRGBPercent=[[1,50,50]],radiusPercent=3,
                         minSpacingPercent=1,maxPatches=4,samplingMode='boundary',shellThicknessDeltaE76=3,
                         surface=dict(profileSHA256=sha,vertices=v,triangles=t))
            with patch.object(r,'forward_lookup',side_effect=lambda exe,p,rgb:rgb*100), patch('gamut_shell.forward_lookup',side_effect=lambda exe,p,rgb:rgb*100):
                proposal=r.run(request,Path(tmp)/'new')
            old=proposal['inheritedCandidates'][0];new=proposal['candidates'][0]
            self.assertEqual(set(old),set(new));self.assertAlmostEqual(old['surfaceDistanceDeltaE76'],1)
            self.assertFalse(old['predictedOutsideMesh'])
            request['inheritedRGBPercent']=[[101,0,0]]
            with self.assertRaises(ValueError):r.run(request,Path(tmp)/'invalid')

    def test_mapping_retains_known_forward_rgb_and_approximation_distance(self):
        def linear(exe, profile, rgb):
            return rgb * 100
        with patch.object(g, 'forward_lookup', side_effect=linear):
            m = g.device_mapping('profile', 'xicclu', [[0, 50, 100], [101, 50, 100]])
        self.assertTrue(m['approximate'])
        np.testing.assert_allclose(m['rgb'][0], [0, .5, 1])
        np.testing.assert_allclose(m['lab'][0], [0, 50, 100])
        self.assertEqual(m['distanceDeltaE76'], [0., 1.])


if __name__ == '__main__':
    unittest.main()
