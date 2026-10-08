# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'profiles'))
import colour_math as c
import preregularize as p


class ColourMathTests(unittest.TestCase):
    def test_lab_xyz_roundtrip_and_de00_matches_scalar(self):
        lab = np.array([[3.9, -0.1, -0.6], [50, 20, -40], [95, 0, 2], [0, 0, 0]])
        self.assertTrue(np.allclose(c.xyz_to_lab(c.lab_to_xyz(lab)), lab, atol=1e-9))
        self.assertTrue(np.allclose(c.lab_to_xyz([[100, 0, 0]]), [c.ICC_D50]))
        other = lab + [0.5, -1, 2]
        self.assertTrue(np.allclose(c.delta_e00(lab, other), [p.delta_e00(a, b) for a, b in zip(lab, other)], atol=1e-12))

    def test_noise_estimate_recovers_sigma_and_suggests_avgdev(self):
        rng = np.random.default_rng(1)
        rgb = np.repeat(rng.random((400, 3)), 2, axis=0)
        lab = rgb * np.array([90, 60, 60]) + rng.normal(0, 0.5, rgb.shape)
        n = c.estimate_noise(rgb, lab)
        self.assertEqual(n['groups'], 400)
        self.assertAlmostEqual(n['sigmaLab'], 0.5 * np.sqrt(3), delta=0.1)
        self.assertEqual(c.estimate_noise(rgb[::2], lab[::2])['groups'], 0)
        hint = c.argyll_avgdev_suggestion(n)
        self.assertTrue(0.1 <= hint['suggestedPercent'] <= 2.0)
        self.assertIsNone(c.argyll_avgdev_suggestion(dict(groups=0, pairs=0)))


if __name__ == '__main__':
    unittest.main()
