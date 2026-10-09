# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,unittest,tempfile,json,hashlib
from unittest.mock import patch
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_target import select_indices,generate,balanced_indices,external_selection
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
   with patch('verification_target.require_profile'),patch('verification_target.lookup',lookup),patch('verification_target.LittleCMS',CMM),patch('verification_target.lookup_evidence',return_value={'engine':'test'}):
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
 def test_balanced_small_and_large_targets(self):
  rng=np.random.default_rng(4)
  # Deliberately put all dark candidates first: order must not dominate selection.
  dark=np.column_stack((rng.uniform(5,17,1000),rng.uniform(-15,15,(1000,2))))
  broad=np.column_stack((rng.uniform(18,90,5000),rng.uniform(-75,75,(5000,2))))
  broad[1000:1300]=np.column_stack((rng.uniform(35,80,300),rng.uniform(5,25,300),rng.uniform(8,30,300)))
  neutral=np.column_stack((np.linspace(3,95,1000),np.zeros((1000,2))))
  lab=np.vstack((dark,broad,neutral));rgb=(lab+[0,100,100])/[100,200,200]
  reach=np.zeros(len(lab));reach[1000:2000]=4
  for counts in ([97,20,13,10],[399,81,55,40]):
   records,summary=external_selection(lab,rgb,reach,6000,counts)
   self.assertEqual(len(records),sum(counts[:3]))
   self.assertEqual(records,external_selection(lab,rgb,reach,6000,counts)[0])
   self.assertEqual(len({tuple(rgb[r['sourceIndex']]) for r in records}),len(records))
   colours=lab[[r['sourceIndex'] for r in records if r['role']=='colour']]
   self.assertLess(np.mean(colours[:,0]<18),.12)
   self.assertGreater(np.sum(colours[:,0]>65),counts[0]*.1)
   for group in ('skin-tone','shadow','broad-colour','neutral','challenge'):
    self.assertEqual(summary[group]['requested'],summary[group]['selected'])
   gray=lab[[r['sourceIndex'] for r in records if r['role']=='gray'],0]
   self.assertAlmostEqual(gray.min(),3);self.assertAlmostEqual(gray.max(),95)
   challenge=lab[[r['sourceIndex'] for r in records if r['role']=='challenge']]
   self.assertEqual(len(set(np.digitize(challenge[:,0],[25,50,75]))),4)
 def test_clipped_duplicates_and_shortfall(self):
  lab=np.array([[5,0,0],[10,0,0],[50,10,10],[90,0,0]],float)
  rgb=np.array([[0,0,0],[0,0,0],[.5,.5,.5],[1,1,1]])
  ids=balanced_indices(lab,rgb,4,gray=True)
  self.assertEqual(len(ids),3)
  self.assertEqual(len(balanced_indices(lab,rgb,4,used=[[0,0,0]])),2)
 def test_missing_reserved_colours_are_disclosed(self):
  lab=np.array([[30,-10,0],[50,-10,0],[70,-10,0],[90,-10,0],[3,0,0],[95,0,0]],float)
  rgb=(lab+[0,100,100])/[100,200,200]
  records,summary=external_selection(lab,rgb,np.zeros(6),4,[4,2,0,0])
  self.assertEqual(len(records),6)
  self.assertEqual(summary['skin-tone'],{'requested':1,'selected':0})
  self.assertEqual(summary['broad-colour']['selected'],4)
 def test_zero_count(self):
  self.assertEqual(select_indices(np.ones((2,3)),np.zeros((1,3)),0,.01),[])
if __name__=='__main__':unittest.main()
