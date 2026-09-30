import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from paired_check import compare_pairs
class Tests(unittest.TestCase):
 def test_row_warning_and_threshold(self):
  r={'data':{'locations':['1A','2A']},'pairedReadings':{'pairRows':[[1,2],[3,4]],'rawMeasurement':{'data':{'xyz':[[20,20,20],[20,20,20],[50,50,50],[10,10,10]]}}}}
  c=compare_pairs(r,1);self.assertEqual([v['row'] for v in c['flaggedRows']],['2'])
  self.assertEqual(compare_pairs(r,100)['flaggedRows'],[])
  with self.assertRaises(ValueError):compare_pairs(r,0)
if __name__=='__main__':unittest.main()
