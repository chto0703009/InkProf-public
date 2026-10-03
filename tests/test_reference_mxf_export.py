# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,tempfile,unittest,json,hashlib
from pathlib import Path
import xml.etree.ElementTree as ET
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'exchange'))
from export_reference_mxf import export
from test_mxf_import import fixture
from import_mxf import N

class ReferenceExportTests(unittest.TestCase):
 def test_payload_only_and_reject_wrong_target(self):
  with tempfile.TemporaryDirectory() as w:
   w=Path(w);root=fixture();template=w/'template.mxf'
   ET.register_namespace('cc',N['c']);ET.ElementTree(root).write(template,encoding='utf-8',xml_declaration=True)
   chart=w/'chart.json';chart.write_text('{}')
   r=dict(documentType='inkprof.chart-measurement',complete=True,chartJSONSHA256=hashlib.sha256(chart.read_bytes()).hexdigest(),measurementCondition=dict(interpreted='M0',fwaApplied=False),metadata=[['DEVCALSTD','XRGA']],data=dict(ids=[str(i) for i in range(1,8)],locations=['1A','1B','2A','2B','3A','3B','4A'],rgbPercent=[[128/255*100]*3 for _ in range(7)],wavelengthNm=list(range(380,731,10)),spectra=[[20+i]*36 for i in range(7)]))
   source=w/'measurement.json';source.write_text(json.dumps(r));out=w/'out.mxf';original=template.read_bytes();report=export(source,template,out)
   self.assertEqual(template.read_bytes(),original);self.assertEqual(report['patchCount'],7)
   parsed=ET.parse(out).getroot();spectra=parsed.findall('.//c:ReflectanceSpectrum',N)
   self.assertAlmostEqual(float(spectra[0].text.split()[0]),.2)
   self.assertEqual(ET.tostring(parsed.find('c:CustomResources',N)),ET.tostring(root.find('c:CustomResources',N)))
   with self.assertRaises(ValueError):export(source,template,out)
   r['data']['rgbPercent'][0][0]=0;source.write_text(json.dumps(r))
   with self.assertRaisesRegex(ValueError,'RGB differs'):export(source,template,w/'bad.mxf')
   self.assertFalse((w/'bad.mxf').exists())
if __name__=='__main__':unittest.main()
