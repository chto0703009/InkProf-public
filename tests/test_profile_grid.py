import sys,unittest
from pathlib import Path
from unittest.mock import patch
import subprocess
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from profile_grid import lookup,summary,run,encode_lab8,decode_lab8

class GridTests(unittest.TestCase):
 def test_lookup(self):
  with patch('profile_grid.subprocess.run',return_value=subprocess.CompletedProcess([],0,'1 2 3\n','')) as call:
   out=lookup('xicclu','profile',[[0,0,0]],'b');self.assertEqual(out.tolist(),[[1,2,3]]);self.assertIn('-fb',call.call_args.args[0]);self.assertIn('-ir',call.call_args.args[0])
 def test_nonfinite(self):
  with patch('profile_grid.subprocess.run',return_value=subprocess.CompletedProcess([],0,'NaN 2 3\n','')):
   with self.assertRaises(ValueError):lookup('x','p',[[0,0,0]])
 def test_missing(self):
  with patch('profile_grid.subprocess.run',return_value=subprocess.CompletedProcess([],0,'','')):
   with self.assertRaises(ValueError):lookup('x','p',[[0,0,0]])
 def test_failed_tool(self):
  with patch('profile_grid.subprocess.run',return_value=subprocess.CompletedProcess([],1,'','failure')):
   with self.assertRaises(ValueError):lookup('x','p',[[0,0,0]])
 def test_bounds(self):
  with self.assertRaises(ValueError):run('job','exe','unused',2)
 def test_lab_encoding(self):
  import numpy as np
  from PIL import Image
  v=encode_lab8([[100,0,0],[50,-10,20]])
  self.assertEqual(v[0].tolist(),[255,0,0])
  image=Image.fromarray(v.reshape(1,2,3),'LAB')
  self.assertEqual(image.getpixel((0,0)),(255,128,128))
  self.assertTrue(np.allclose(decode_lab8(v)[:,1:],[[0,0],[-10,20]]))
 def test_stats(self):self.assertEqual(summary([0,2])['mean'],1)

if __name__=='__main__':unittest.main()
