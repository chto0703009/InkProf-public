# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,json,hashlib,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from certificate_swatches import enrich,lab_hex,html_chips
class SwatchTests(unittest.TestCase):
 def test_lab_and_missing(self):
  self.assertEqual(lab_hex([0,0,0]),'#000000')
  self.assertEqual(lab_hex([100,0,0]),'#FFFFFF')
  self.assertIn('saknas',html_chips({'hex':'#777777'}))
 def test_legacy_recovery_and_integrity(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'c3.json'
   item=dict(sampleId='1',coordinate='A1',page=1,hex='#777777')
   p.write_text(json.dumps({'patches':[dict(item,desiredLab=[60,0,0],predictedLab=[55,0,0])]}))
   report={'sources':{'c3_report':{'file':'c3.json','sha256':hashlib.sha256(p.read_bytes()).hexdigest()}}}
   found=enrich([item],report,d)[0]
   self.assertEqual(found['desiredHex'],lab_hex([60,0,0]))
   self.assertEqual(found['predictedHex'],lab_hex([55,0,0]))
   self.assertNotIn('desiredHex',enrich([dict(item,page=2)],report,d)[0])
   p.write_text('{}')
   with self.assertRaises(ValueError):enrich([item],report,d)
