import sys, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from shadow_patches import select
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
if __name__=='__main__':unittest.main()
