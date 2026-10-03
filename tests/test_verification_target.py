# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,unittest,tempfile,json,hashlib
from unittest.mock import patch
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_target import select_indices,generate
class VerificationTests(unittest.TestCase):
 def test_training_and_duplicates_excluded(self):
  rgb=np.array([[0,0,0],[.5,.5,.5],[.5,.5,.5],[.7,.2,.6]])
  self.assertEqual(select_indices(rgb,np.zeros((1,3)),2,.01),[1,3])
 def test_unavailable_count(self):
  with self.assertRaises(ValueError):select_indices(np.zeros((2,3)),np.zeros((1,3)),1,.01)
 def test_existing_group_excluded(self):
  rgb=np.array([[.5,.5,.5],[.7,.7,.7]])
  self.assertEqual(select_indices(rgb,np.zeros((1,3)),1,.01,[[.5,.5,.5]]),[1])
 def test_external_target_without_training_data(self):
  with tempfile.TemporaryDirectory() as directory:
   job=Path(directory)/'imported';job.mkdir();profile=job/'profile.icc';profile.write_bytes(b'synthetic test only')
   (job/'source.json').write_text(json.dumps({'profileSHA256':hashlib.sha256(profile.read_bytes()).hexdigest()}))
   request=dict(externalProfile=True,name='Synthetic external test',printing={'printer':'fixture'},trainingRGB=[],minTrainingRGBDistance=1/255,seed=42,colourPatches=400,grayPatches=80,challengePatches=55,repeats=40)
   def lookup(exe,profile,values,direction='f',intent='a'):
    values=np.asarray(values)
    if direction in ('b','if'):
     rgb=(values+[0,100,100])/[100,200,200]
     if direction=='if':rgb[values[:,1]>50,0]=0
     return rgb
    return values*[100,200,200]-[0,100,100]
   class CMM:
    def save_lab_profile(self,path):Path(path).write_bytes(b'synthetic Lab')
   with patch('verification_target.require_profile'),patch('verification_target.lookup',lookup),patch('verification_target.LittleCMS',CMM):
    r=generate(job,'unused',request,Path(directory)/'target')
   self.assertEqual(len(r['patches']),575)
   self.assertEqual(sum(x['role']=='repeat' for x in r['patches']),40)
   self.assertIsNone(r['trainingTI3SHA256'])
   self.assertTrue(r['externalProfile'])
   self.assertIn('unknown',r['trainingIndependence'])
   self.assertTrue(all(x['minTrainingRGBDistance'] is None for x in r['patches']))
   self.assertEqual(r['profileApplications'],1)
   self.assertFalse(r['bpc'])
   self.assertEqual((Path(directory)/'target/printer.icc').read_bytes(),profile.read_bytes())
 def test_zero_count(self):
  self.assertEqual(select_indices(np.ones((2,3)),np.zeros((1,3)),0,.01),[])
if __name__=='__main__':unittest.main()
