# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Colour-managed image proposals; fixtures never use customer measurements."""
import ctypes as C
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from image_refinement import source_profile, representatives, choose_candidates, attach_fit_estimates, run, sha
from lcms_float import LittleCMS

class ImageRefinementTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        # Argyll build accepts v2; make a real v2 matrix profile with LittleCMS.
        lib=LittleCMS().lib
        lib.cmsCreate_sRGBProfile.restype=C.c_void_p
        lib.cmsSetProfileVersion.argtypes=[C.c_void_p,C.c_double]
        handle=lib.cmsCreate_sRGBProfile();lib.cmsSetProfileVersion(handle,2.1)
        path=self.root/'srgb-v2.icc'
        lib.cmsSaveProfileToFile(handle,str(path).encode());lib.cmsCloseProfile(handle)
        self.icc=path.read_bytes()
        self.image=self.root/'image.png'
        self.rgb=np.array([[1,0,0],[0,1,0],[0,0,1],[.6,.2,.7],[.2,.6,.7]])
        Image.fromarray(np.uint8(self.rgb[None]*255)).save(self.image,icc_profile=self.icc)
    def test_profile_preserved_and_missing_requires_explicit_choice(self):
        dst=self.root/'source.icc';r=source_profile(self.image,'embedded',dst)
        self.assertEqual(dst.read_bytes(),self.icc);self.assertTrue(r['embeddedAvailable'])
        Image.new('RGB',(1,1)).save(self.image)
        with self.assertRaisesRegex(ValueError,'no embedded'):source_profile(self.image,'embedded',dst)
        r=source_profile(self.image,'sRGB',dst)
        self.assertEqual(r['choice'],'sRGB');self.assertFalse(r['embeddedAvailable'])
    def test_diversity_and_device_spacing(self):
        labs=np.array([[50,60,30],[60,-50,20],[30,30,-60],[50,60,30]])
        idx,counts=representatives(labs,3)
        self.assertEqual(set(idx),{0,1,2});self.assertEqual(counts.sum(),4)
        device=np.array([[10.,20,30],[10.01,20,30],[70,80,90]])
        c,_=choose_candidates(device,labs[:3],labs[:3],np.ones(3),np.array([[10,20,30]]),10,1,0)
        self.assertEqual(len(c),1);np.testing.assert_allclose(c[0]['rgbPercent'],device[2],atol=.001)
    def test_local_estimates_and_wrong_profile(self):
        report=self.root/'fit.json';(self.root/'sources').mkdir()
        fit=dict(documentType='inkprof.profile-fit',profileSHA256='profile',sourceTI3SHA256='training',
          patches=[dict(rgbPercent=[20,20,20],deltaE00=2),dict(rgbPercent=[24,20,20],deltaE00=4)])
        report.write_text(json.dumps(fit))
        candidates=[dict(rgbPercent=[22,20,20]),dict(rgbPercent=[90,90,90])]
        r=attach_fit_estimates(candidates,report,'profile','training',self.root)
        self.assertEqual(candidates[0]['estimatedLocalFitDeltaE00'],3)
        self.assertEqual(candidates[0]['localFitSupportCount'],2)
        self.assertIsNone(candidates[1]['estimatedLocalFitDeltaE00'])
        self.assertEqual(r['summary']['mean'],3)
        with self.assertRaisesRegex(ValueError,'current profile'):
            attach_fit_estimates(candidates,report,'other','training',self.root)
    @unittest.skipUnless(shutil.which('xicclu'),'ArgyllCMS required')
    def test_end_to_end_and_changed_image(self):
        profile=self.root/'printer.icc';profile.write_bytes(self.icc)
        request=dict(image=str(self.image),imageSHA256=sha(self.image),sourceProfile='embedded',profile=str(profile),
          xicclu=shutil.which('xicclu'),samples=self.rgb.tolist(),existingRGBPercent=[],selection={},maxPatches=5,minSpacingPercent=.1,neighborRadiusPercent=0)
        req=self.root/'request.json';req.write_text(json.dumps(request))
        r=run(req,self.root/'out')
        self.assertEqual(len(r['candidates']),5);self.assertFalse(r['profileApplied'])
        self.assertEqual(r['imageProfile']['sha256'],sha(profile))
        expected=LittleCMS().transform(profile,self.rgb)
        np.testing.assert_allclose(sorted(x['desiredLab'][0] for x in r['candidates']),sorted(expected[:,0]),atol=1e-8)
        self.assertLess(max(x['sourceMappingDeltaE00'] for x in r['candidates']),.1)
        Image.new('RGB',(1,1)).save(self.image)
        with self.assertRaisesRegex(ValueError,'changed'):run(req,self.root/'changed')

if __name__=='__main__':unittest.main()
