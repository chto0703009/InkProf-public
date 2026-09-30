import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from profile_fit import parse_log,stats

class FitTests(unittest.TestCase):
 def setUp(self):
  self.expected={'ids':['1'],'locations':['1A'],'rgb':[[0,0,0]]}
  self.line='[0.000000] 1 @ 1A: 0 0 0 -> 10 0 0 should be 10 0 0'
 def test_exact(self):
  p=parse_log(self.line,self.expected);self.assertEqual(p[0]['coordinate'],'A1');self.assertTrue(p[0]['gray']);self.assertEqual(stats(p)['mean'],0)
 def test_identity(self):
  with self.assertRaises(ValueError):parse_log(self.line.replace('1 @','2 @'),self.expected)
 def test_duplicate(self):
  with self.assertRaises(ValueError):parse_log(self.line+'\n'+self.line,self.expected)
 def test_missing(self):
  with self.assertRaises(ValueError):parse_log('No data',self.expected)
 def test_rgb(self):
  with self.assertRaises(ValueError):parse_log(self.line.replace(': 0 0 0',': 1 0 0'),self.expected)
 def test_delta(self):
  with self.assertRaises(ValueError):parse_log(self.line.replace('[0.000000]','[5.000000]'),self.expected)

if __name__=='__main__':unittest.main()
