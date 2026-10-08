# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import sys, tempfile, unittest
from pathlib import Path
import numpy as np
from PIL import ImageCms
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from lcms_float import LittleCMS
from photo_gradients import metrics, run

class PhotoGradientTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.profile=Path(self.temp.name)/'sRGB.icc'
        self.profile.write_bytes(ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes());self.cmm=LittleCMS()
    def tearDown(self): self.temp.cleanup()
    def test_actual_rgb_chain_identity_and_integer_buffers(self):
        rgb=np.array([[.13,.57,.83],[.2,.3,.4],[.8,.7,.6]])
        np.testing.assert_allclose(self.cmm.photo_transform(self.profile,rgb),rgb,atol=2e-4)
        for bits in (8,16):
            out=self.cmm.photo_transform(self.profile,rgb,bits=bits);scale=2**bits-1
            np.testing.assert_allclose(out*scale,np.round(out*scale),atol=1e-10)
            np.testing.assert_allclose(out,np.round(rgb*scale)/scale,atol=max(1/scale,2e-4))
        self.assertGreater(np.max(abs(self.cmm.photo_transform(self.profile,rgb,'Adobe RGB (1998)')-rgb)),.02)
    def test_clipping_mask_and_quantization_are_explicit(self):
        rgb=np.zeros((40,3));lab=np.column_stack([np.arange(40),np.zeros((40,2))]);m=metrics(rgb,lab)
        self.assertEqual(m['interiorTriples'],0);self.assertIsNone(m['interiorCurvatureP95']);self.assertEqual(m['unchangedSteps'],39)
    def test_all_modes_and_report_identity(self):
        r=run(self.profile,Path(self.temp.name)/'report',samples=65)
        self.assertEqual(len(r['paths']),216)
        self.assertEqual({p['precision'] for p in r['paths']},{'float','16-bit','8-bit'})
        self.assertEqual({p['bpc'] for p in r['paths']},{False,True})
        self.assertTrue(r['comparisonMetrics']);self.assertTrue(all(np.isfinite(p['curvatureP95']) for p in r['comparisonMetrics']))
        with self.assertRaises(ValueError): self.cmm.photo_transform(self.profile,np.array([[np.nan,0,0]]))
if __name__=='__main__':unittest.main()
