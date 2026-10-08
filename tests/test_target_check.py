# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from target_check import check_target
class TargetTests(unittest.TestCase):
 def setUp(self):
  self.chart={'exchangeTables':{'signature':'CTI2','fields':['SAMPLE_ID','SAMPLE_LOC','RGB_R','RGB_G','RGB_B','XYZ_X','XYZ_Y','XYZ_Z'],'metadata':[{'tokens':['APPROX_WHITE_POINT','95.047 100 108.883']}],'rows':[{'values':['1','1A','100','100','100','95.047','100','108.883']}]}}
  self.data={'ids':['1'],'locations':['1A'],'rgbPercent':[[100,100,100]]}
 def test_adaptation_and_threshold(self):
  r=check_target(self.chart,self.data,[[96.42956764295677,100,82.510460251046]],20)
  self.assertLess(r['patchDeltaE00'][0],.001);self.assertEqual(r['flaggedCount'],0)
  r=check_target(self.chart,self.data,[[0,0,0]],20);self.assertEqual(r['flaggedCount'],1)
 def test_unknown_white_not_guessed(self):
  self.chart['exchangeTables']['metadata']=[]
  self.assertFalse(check_target(self.chart,self.data,[[0,0,0]])['available'])
 def test_identity_and_invalid_threshold(self):
  with self.assertRaises(ValueError):check_target(self.chart,self.data,[[0,0,0]],float('nan'))
  self.data['rgbPercent']=[[0,0,0]]
  with self.assertRaises(ValueError):check_target(self.chart,self.data,[[0,0,0]])
if __name__=='__main__':unittest.main()
