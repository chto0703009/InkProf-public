# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util,json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('print_controls',ROOT/'analysis/print_controls.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class Tests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.folder=Path(self.temp.name)
  self.context={'printer':'fixture','paper':'fixture'}
  self.values={'R':[40,21,2],'G':[20,40,10],'B':[10,5,50]}
  self.readings=[{'page':page,'colour':colour} for page in [1,2] for colour in ['R','G','B']]
  self.request=dict(readings=self.readings,pageCount=2,context=self.context,calibrationStandard='XRGA',instrumentSerial='TEST')
  (self.folder/'request.json').write_text(json.dumps(self.request))
  for i,r in enumerate(self.readings):
   (self.folder/f'reading-{i+1:03d}.json').write_text(json.dumps(dict(request=r,xyz=self.values[r['colour']],measurementCondition='M0',calibrationStandard='XRGA',instrumentSerial='TEST')))
  self.reference=dict(context=self.context,calibrationStandard='XRGA',xyz=self.values)
 def tearDown(self):self.temp.cleanup()
 def test_pass_and_large_wrong_print_failure(self):
  report=module.assess(self.folder,self.reference);self.assertEqual(report['status'],'passed');self.assertTrue(report['excludedFromProfiling'])
  file=self.folder/'reading-005.json';r=json.loads(file.read_text());r['xyz']=[50,70,35];file.write_text(json.dumps(r))
  report=module.assess(self.folder,self.reference);self.assertEqual(report['status'],'review-required');self.assertTrue(report['readings'][4]['flagged'])
  self.assertEqual(report['readings'][4]['label'],'G');self.assertEqual(report['readings'][4]['page'],2)
 def test_no_reference_and_missing_spot(self):
  self.assertEqual(module.assess(self.folder)['status'],'reference-needed')
  (self.folder/'reading-006.json').unlink()
  with self.assertRaises(FileNotFoundError):module.assess(self.folder,self.reference)
 def test_scalar_reference_is_rejected(self):
  self.reference['xyz']['R']=21.0
  with self.assertRaisesRegex(ValueError,'three finite XYZ'):
   module.assess(self.folder,self.reference)
 def test_wrong_paper_or_identity_cannot_pass(self):
  self.reference['context']={'paper':'other'}
  with self.assertRaises(ValueError):module.assess(self.folder,self.reference)
  r=json.loads((self.folder/'reading-001.json').read_text());r['request']['page']=2;(self.folder/'reading-001.json').write_text(json.dumps(r))
  with self.assertRaises(ValueError):module.assess(self.folder)
if __name__=='__main__':unittest.main()
