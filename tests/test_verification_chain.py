# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
import tifffile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_chain import analyse

class ChainTests(unittest.TestCase):
 def check(self,pixel,layout=True):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);folder=root/'print';folder.mkdir()
   r={'patches':[{'id':'1','role':'colour','referenceLabD50Absolute':[0,0,0],'deviceRGB16':[0,0,0],'placement':{'sampleId':'1'}}], 'printPackage':{'folder':'print'}}
   m=[{'sampleId':'1','measuredLab':[0,0,0]}]
   if layout:
    (folder/'layout.json').write_text(json.dumps({'patches':[{'sampleId':'1','tiff':'target.tif','rectMm':[1,1,2,2]}]}))
    tifffile.imwrite(folder/'target.tif',np.full((10,10,3),pixel,dtype=np.uint16),resolution=(25.4,25.4),resolutionunit='INCH')
   with patch('verification_chain.lookup',side_effect=lambda exe,profile,x,*args:np.asarray(x)), patch('verification_chain.lookup_evidence',return_value={'engine':'test'}):
    return analyse(r,root,'unused','unused',m)
 def test_exact_pixels(self):
  d=self.check(0);self.assertEqual(d['tiff']['mismatchCount'],0);self.assertEqual(d['print']['summary']['max'],0)
 def test_changed_pixels_are_not_hidden(self):
  d=self.check(1);self.assertEqual(d['tiff']['mismatchCount'],1);self.assertEqual(d['tiff']['maxChannelCodeError'],1)
 def test_missing_layout_is_unavailable(self):
  d=self.check(0,False);self.assertEqual(d['tiff']['status'],'unavailable');self.assertEqual(d['print']['status'],'unavailable')
if __name__=='__main__':unittest.main()
