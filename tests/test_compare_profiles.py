# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from compare_profiles import run
class ComparisonTests(unittest.TestCase):
 def test_identical_profiles_and_portable_reports(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'a.icc';b=bytearray(128);b[36:40]=b'acsp';b[12:20]=b'prtrRGB ';p.write_bytes(b)
   def lookup(exe,profile,v,direction,intent):return np.asarray(v)*(100 if direction=='f' else .01)
   with patch('compare_profiles.lookup',lookup):r=run(p,p,'fake',Path(d)/'out',2,3)
   self.assertEqual(r['sameRGBDeltaE00']['max'],0)
   self.assertEqual(r['sameLabRGBChangePercentagePoints']['max'],0)
   self.assertEqual(r['measuredImprovement'],'not-assessed')
   html=(Path(d)/'out/comparison.html').read_text()
   self.assertIn('id="lightness"',html)
   self.assertIn('id="slice"',html)
   for f in ['comparison.json','comparison.html','comparison.pdf','previous.icc','current.icc']:self.assertTrue((Path(d)/'out'/f).is_file())
if __name__=='__main__':unittest.main()
