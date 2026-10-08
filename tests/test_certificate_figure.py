# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import hashlib
import json
import tempfile
import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from certificate_figure import load, interactive, pdf_drawing
from reportlab.graphics import renderPDF

class CertificateFigureTests(unittest.TestCase):
    def test_verified_data_and_views(self):
        with tempfile.TemporaryDirectory() as root:
            path=Path(root)/'comparison.json'
            value={'previousIteration':1,'currentIteration':2,'profileSHA256':{'current':'current-hash'},'grid':{'previousLab':[[50,10,20]],'currentLab':[[51,11,21]]}}
            path.write_text(json.dumps(value))
            report={'profile':{'sha256':'current-hash'},'sources':{'comparison':{'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}}}
            groups=load(root,report)
            for language in ['sv','en']:
                page=interactive(groups,language)
                self.assertIn('id="slice" checked',page)
                self.assertIn('value="50"',page)
                self.assertIn('onpointermove',page)
                self.assertIn('Iteration 1',page);self.assertIn('Iteration 2',page)
                self.assertTrue(renderPDF.drawToString(pdf_drawing(groups,language)).startswith(b'%PDF'))
            report['profile']['sha256']='different'
            with self.assertRaisesRegex(ValueError,'different current ICC'):load(root,report)
            report['profile']['sha256']='current-hash'
            path.write_text('{}')
            with self.assertRaisesRegex(ValueError,'checksum mismatch'):load(root,report)
    def test_no_comparison_no_invented_figure(self):
        self.assertIsNone(load('.',{'sources':{}}))
if __name__=='__main__':unittest.main()
