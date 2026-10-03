# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from row_direction_check import compare_rows

class RowDirectionTests(unittest.TestCase):
 def test_reversal_and_shuffled_storage(self):
  ref=np.array([[20,30,20],[40,-40,30],[60,20,-40],[80,-10,0.]])
  order=[2,0,3,1];loc=np.array(['22A','22B','22C','22D'])[order]
  measured=ref[::-1].copy();before=measured.copy()
  result=compare_rows(loc,measured[order],ref[order])[0]
  self.assertTrue(result['suspectedReverse']);self.assertAlmostEqual(result['reverseMeanDeltaE00'],0)
  np.testing.assert_array_equal(measured,before)
 def test_correct_and_symmetric_not_flagged(self):
  ref=np.array([[20,30,20],[40,-40,30],[60,20,-40],[80,-10,0.]])
  loc=['1A','1B','1C','1D']
  self.assertFalse(compare_rows(loc,ref,ref)[0]['suspectedReverse'])
  same=np.tile([50.,0,0],(4,1));self.assertFalse(compare_rows(loc,same,same)[0]['suspectedReverse'])
 def test_incomplete_columns_skipped(self):
  self.assertEqual(compare_rows(['1A','1C','1D','1E'],np.zeros((4,3)),np.zeros((4,3))),[])
if __name__=='__main__':unittest.main()
