# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from shadow_patches import select, neutral_pool
class ShadowTests(unittest.TestCase):
 def test_relative_dark_threshold_and_exclusion(self):
  rgb=np.array([[0,0,0],[5,5,5],[10,8,8],[11,8,8],[80,80,80]],float)
  lab=np.array([[25,0,0],[28,0,0],[32,4,2],[35,-4,1],[80,0,0]],float)
  selected,predicted,limit=select(rgb,lab,[[0,0,0]],48,25,95)
  self.assertEqual(limit,42.5);self.assertEqual(len(selected),3)
  self.assertTrue(np.all(predicted[:,0]<=limit));self.assertFalse(np.any(np.all(selected==0,axis=1)))
  self.assertEqual(len(select(rgb,lab,[],0,25,95)[0]),0)
 def test_quantized_duplicates(self):
  selected,_,_=select(np.array([[1,1,1],[1.000001,1,1]]),np.array([[10,0,0],[10,0,0]]),[],10,0,100)
  self.assertEqual(len(selected),1)
 def test_neutral_and_weak_chroma_are_not_crowded_out(self):
  rgb=np.array([[v,v,v] for v in (2,4,6,8)]+[[v,v+1,v] for v in (3,5,7,9)]+[[v,0,20] for v in (1,3,5,7)],float)
  lab=np.array([[v,0,0] for v in (24,28,32,36)]+[[v,5,0] for v in (25,29,33,37)]+[[v,25,20] for v in (24,28,32,36)],float)
  selected,predicted,_=select(rgb,lab,[],6,22,96)
  self.assertEqual(len(selected),6)
  chroma=np.hypot(predicted[:,1],predicted[:,2])
  self.assertGreaterEqual(sum(chroma<=3),2)
  self.assertGreaterEqual(sum((chroma>3)&(chroma<=10)),2)
 def test_tinted_device_gray_and_budget_fallback(self):
  rgb=np.array([[2,2,2],[4,4,4],[8,1,2]],float)
  lab=np.array([[25,5,2],[30,5,2],[35,20,0]],float)
  selected,_,_=select(rgb,lab,[],3,22,96)
  self.assertEqual(len(selected),3)
  self.assertLess(np.ptp(selected[0]),.01)
 def test_neutral_pool_has_gray_and_both_channel_offsets(self):
  rgb=neutral_pool()
  self.assertTrue(np.all((rgb>=0)&(rgb<=100)))
  self.assertEqual(len(rgb),len(np.unique(rgb,axis=0)))
  self.assertGreaterEqual(sum(np.ptp(rgb,axis=1)<.01),129)
  self.assertTrue(np.any(rgb[:,0]>rgb[:,1]))
  self.assertTrue(np.any(rgb[:,0]<rgb[:,1]))
if __name__=='__main__':unittest.main()
