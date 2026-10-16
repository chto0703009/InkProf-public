# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import json
import hashlib
import tempfile
import unittest
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from workflow_final_pdf import create
from pypdf import PdfReader


class AppendixTests(unittest.TestCase):
    def test_complete_records_are_separate_and_identifiable(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            records=[dict(sampleId=f'PATCH-{i:03}',deltaE00=1.,hex='#8899aa') for i in range(50)]
            report=dict(project=dict(name='Synthetic QA'),iteration=1,createdUTC='2026-10-12T00:00:00Z',
                        certificateId='TEST-CERT',profile=dict(sha256='a'*64),approval=dict(notes='Synthetic example'),
                        patchOutliers=dict(allPatches=records,patches=[],message='Synthetic',overviewText='50 synthetic colours',basis='Synthetic',colourNote='Preview colours'),results={})
            (folder/'final-report.json').write_text(json.dumps(report))
            (folder/'final-report.txt').write_text('COMPLETE HISTORY\nExample history\n')
            create(folder)
            main='\n'.join(p.extract_text() for p in PdfReader(folder/'final-report.pdf').pages)
            annex='\n'.join(p.extract_text() for p in PdfReader(folder/'measurement-appendix.pdf').pages)
            for record in records:
                self.assertNotIn(record['sampleId'],main)
                self.assertIn(record['sampleId'],''.join(annex.split()))
            self.assertIn('TEST-CERT',main);self.assertIn('TEST-CERT',annex)
            self.assertIn('Example history',annex);self.assertNotIn('Example history',main)
            metadata=json.loads((folder/'measurement-appendix.json').read_text())
            self.assertEqual(metadata['sha256'],hashlib.sha256((folder/'measurement-appendix.pdf').read_bytes()).hexdigest())


    def test_reference_swatches_stay_in_main_certificate(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            report=dict(project=dict(name='Synthetic QA'),iteration=1,createdUTC='2026-10-12',
                        profile=dict(sha256='a'*64),approval=dict(notes='Synthetic'),
                        referenceTarget=dict(name='ColorChecker synthetic'),
                        patchOutliers=dict(allPatches=[dict(sampleId='CC-01',referenceName='Dark skin',
                            deltaE00=1.25,hex='#886644',desiredHex='#996655')],
                            patches=[],message='Synthetic',overviewText='Reference colours',basis='Synthetic',colourNote='Preview'),results={})
            (folder/'final-report.json').write_text(json.dumps(report))
            (folder/'final-report.txt').write_text('Synthetic history')
            create(folder)
            main=' '.join(p.extract_text() for p in PdfReader(folder/'final-report.pdf').pages)
            self.assertIn('ColorChecker synthetic',main)
            self.assertNotIn('Dark skin',main)
            self.assertIn('1.25',main)
            self.assertIn('ΔE00',main)


    def test_numerical_certificate_has_complete_historical_appendix(self):
        from numerical_report import create as numerical_create
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            old=dict(referenceTarget=dict(name='ColorChecker synthetic'),
                patchOutliers=dict(allPatches=[dict(sampleId='ACCEPTED-01', referenceName='Dark skin',
                    deltaE00=1.25,hex='#886644',desiredHex='#996655')], patches=[]))
            previous=folder/'previous.json';previous.write_text(json.dumps(old))
            check=folder/'fit.json';check.write_text(json.dumps(dict(summary=dict(mean=1.,max=2.), patches=[dict(sourceIndex=1,sampleId='FIT-ACCEPTED-01',coordinate='1A',rgbPercent=[10.,20.,30.],measuredLab=[30.,2.,3.],predictedLab=[31.,2.,3.],deltaE00=1.)])))
            report=dict(project=dict(id='QA',name='Synthetic'),iteration=4,iterationId='QA-ITERATION',
                certificateId='QA-CERTIFICATE',scopeStatement='Numerically checked; no separate print verification.',
                profile=dict(file='profile.icc',sha256='a'*64),decision=dict(notes='Synthetic decision'),
                printing={},reportUser='QA',reportDate='2026-10-12',pageHeader='InkProf',
                sources=dict(fit=dict(file='fit.json',sha256=hashlib.sha256(check.read_bytes()).hexdigest())),
                historicalCertificate=dict(file='previous.json',sha256=hashlib.sha256(previous.read_bytes()).hexdigest(),
                    scope='Historical evidence, not verification of the current ICC.',iteration=3,profileSHA256='b'*64))
            (folder/'final-report.json').write_text(json.dumps(report))
            numerical_create(folder)
            main=' '.join(p.extract_text() for p in PdfReader(folder/'final-report.pdf').pages)
            annex=' '.join(p.extract_text() for p in PdfReader(folder/'measurement-appendix.pdf').pages)
            self.assertNotIn('Dark skin', main)
            self.assertIn('1.25',main)
            self.assertNotIn('Numerical evidence: fit', main)
            self.assertIn('Numerical evidence: fit', annex)
            self.assertIn('ACCEPTED-01',annex)
            self.assertIn('FIT-ACCEPTED-01',annex)
            self.assertNotIn('FIT-ACCEPTED-01',main)
            self.assertIn('QA-CERTIFICATE',main);self.assertIn('QA-CERTIFICATE',annex)
            self.assertIn('measurement-appendix.pdf',(folder/'final-report.html').read_text())
            metadata=json.loads((folder/'measurement-appendix.json').read_text())
            self.assertEqual(metadata['profileSHA256'],'a'*64)
            self.assertEqual(metadata['sha256'],hashlib.sha256((folder/'measurement-appendix.pdf').read_bytes()).hexdigest())


if __name__=='__main__':unittest.main()
