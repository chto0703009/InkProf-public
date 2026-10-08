# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, tempfile, unittest, json, hashlib
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from compare_profiles import run, srgb_preview
class ComparisonTests(unittest.TestCase):
 def test_srgb_previews_use_lab_not_printer_rgb(self):
  self.assertEqual(srgb_preview([0,0,0]),'#000000')
  self.assertEqual(srgb_preview([100,0,0]),'#ffffff')
  self.assertEqual(srgb_preview([50,0,0]),'#777777')
 def test_identical_profiles_and_portable_reports(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'a.icc';b=bytearray(128);b[36:40]=b'acsp';b[12:20]=b'prtrRGB ';p.write_bytes(b)
   def lookup(exe,profile,v,direction,intent):return np.asarray(v)*(100 if direction=='f' else .01)
   def gamut(profile,folder,exe):
    folder.mkdir();digest=hashlib.sha256(profile.read_bytes()).hexdigest()
    value=dict(profileSHA256=digest,vertices=[[0,0,0],[50,10,0],[100,0,0]],triangles=[[0,1,2]],rgb=[[0,0,0],[.5,.5,.5],[1,1,1]])
    file=folder/'gamut-surface.json';file.write_text(json.dumps(value))
    return dict(status='available',file=file.name,sha256=hashlib.sha256(file.read_bytes()).hexdigest(),profileSHA256=digest)
   with patch('compare_profiles.lookup',lookup),patch('gamut_surface.generate',gamut):r=run(p,p,'fake',Path(d)/'out',2,3)
   self.assertEqual(r['sameRGBDeltaE00']['max'],0)
   self.assertEqual(r['sameLabRGBChangePercentagePoints']['max'],0)
   self.assertEqual(r['measuredImprovement'],'not-assessed')
   html=(Path(d)/'out/comparison.html').read_text()
   self.assertIn('id="lightness"',html)
   self.assertIn('Iteration 1 - previous profile gamut',html)
   self.assertIn('Iteration 2 - current profile gamut',html)
   self.assertEqual(html.count('<div class="gamut-view">'),2)
   self.assertIn('id="slice"',html)
   self.assertIn('Previous sRGB',html)
   self.assertEqual(html.count('aria-label="Previous:'),len(r['worst']))
   self.assertEqual(html.count('aria-label="Current:'),len(r['worst']))
   for f in ['comparison.json','comparison.html','comparison.pdf','previous.icc','current.icc']:self.assertTrue((Path(d)/'out'/f).is_file())
if __name__=='__main__':unittest.main()
