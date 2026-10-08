# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
import rgb_gradients as g


class RGBGradientTests(unittest.TestCase):
    def test_local_kink_increases_second_difference(self):
        rgb = g.ramps()['Dark blue to pale blue']
        t = np.linspace(0, 1, len(rgb))
        smooth = rgb * [100, 20, 40]
        kink = smooth.copy(); kink[:, 0] += 0.5 * np.exp(-((t - 0.5) / 0.015) ** 2)
        a, b = g.metrics(rgb, smooth), g.metrics(rgb, kink)
        self.assertGreater(b['labSecondDifference']['max'], a['labSecondDifference']['max'] * 100)
        self.assertAlmostEqual(b['worstAt'], 0.5, delta=0.02)

    def test_saved_report_contains_curves_for_all_paths_and_intents(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d); profile = p / 'profile.icc'; profile.write_bytes(b'fixture')
            with patch.object(g, 'lookup', side_effect=lambda exe, profile, rgb, direction, intent: rgb * [100, 20, 40]):
                r = g.run(profile, 'fake-xicclu', p / 'out')
            saved = json.loads((p / 'out/rgb-gradients.json').read_text())
            self.assertEqual(saved['profileSHA256'], r['profileSHA256'])
            self.assertEqual(len(saved['paths']), 18)
            for row in saved['paths']:
                self.assertEqual(len(row['lab']), 1025)
                self.assertEqual(len(row['colourSteps']), 1024)
            self.assertTrue((p / 'out/rgb-gradients.md').exists())

    def test_profile_change_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d); profile = p / 'profile.icc'; profile.write_bytes(b'before')
            def lookup(exe, profile, rgb, direction, intent):
                profile.write_bytes(b'after'); return rgb * [100, 20, 40]
            with patch.object(g, 'lookup', side_effect=lookup):
                with self.assertRaisesRegex(ValueError, 'Profile changed'):
                    g.run(profile, 'fake', p / 'out')
            self.assertFalse((p / 'out').exists())


if __name__ == '__main__':
    unittest.main()
