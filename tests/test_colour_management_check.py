# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, tempfile, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
import colour
import colour_management_check as cmc
from lcms_float import LittleCMS


class DoubleColourManagementTests(unittest.TestCase):
    def setUp(self):
        from PIL import ImageCms
        self.dir = tempfile.TemporaryDirectory(); d = Path(self.dir.name)
        # A matrix profile stands in for the printer ICC; only the chain logic is tested.
        self.icc = d / 'printer.icc'
        self.icc.write_bytes(ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
        rng = np.random.default_rng(3); self.rgb = rng.uniform(0.05, 0.95, (60, 3))
        self.cmm = LittleCMS(); self.predicted = self.cmm.transform(self.icc, self.rgb, 'f')
        self.reference = dict(patches=[dict(id=str(i + 1), deviceRGB=list(c), predictedLabD50Absolute=list(p))
                                       for i, (c, p) in enumerate(zip(self.rgb, self.predicted))])

    def tearDown(self): self.dir.cleanup()

    def patches(self, measured):
        return [dict(sampleId=str(i + 1), role='colour', measuredLab=list(m),
                     deltaE00=float(colour.delta_E(p, m, method='CIE 2000')))
                for i, (p, m) in enumerate(zip(self.predicted, measured))]

    def test_detects_adobe_rgb_assigned_and_converted(self):
        source = cmc._lab_from_space(self.rgb, 'Adobe RGB (1998)')
        device = np.clip(self.cmm.transform(self.icc, source, 'b'), 0, 1)
        measured = self.cmm.transform(self.icc, device, 'f')
        r = cmc.check(self.icc, self.reference, self.patches(measured))
        self.assertTrue(r['suspectedDoubleColourManagement']); self.assertEqual(r['bestMatch'], 'Adobe RGB (1998)')
        self.assertIn('double colour management', r['message'])

    def test_correct_print_is_not_flagged(self):
        rng = np.random.default_rng(4)
        r = cmc.check(self.icc, self.reference, self.patches(self.predicted + rng.normal(0, 0.5, self.predicted.shape)))
        self.assertFalse(r['suspectedDoubleColourManagement'])


if __name__ == '__main__':
    unittest.main()
