# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import sys
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
