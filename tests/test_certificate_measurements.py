# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'analysis'))
from certificate_measurements import build


class MeasurementViewTests(unittest.TestCase):
    def test_groups_portability_scope_and_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp); (p/'profile.icc').write_bytes(b'ICC'); digest=hashlib.sha256(b'ICC').hexdigest()
            patch=dict(sampleId='</script>',coordinate='A1',measuredLab=[50,10,-20],desiredLab=[51,11,-19],predictedLab=[50,10,-19],deltaE00=.2)
            fit=p/'fit.json'; fit.write_text(json.dumps(dict(profileSHA256=digest,patches=[patch]*3)))
            c3=p/'c3.json'; c3.write_text(json.dumps(dict(sources=[dict(path='printer.icc',sha256=digest)],patches=[patch])))
            (p/'final-report.json').write_text('{}'); (p/'final-report.html').write_text('<html></html>')
            req=dict(profileSHA256=digest,fit=str(fit),verification=str(c3))
            reference=p/'verification.json'
            reference.write_text(json.dumps(dict(printerProfile=dict(sha256=digest),patches=[
                dict(id=patch['sampleId'],deviceRGB=[.1,.2,.3],placement=dict(sampleId='printed-1'))])))
            reference_hash=hashlib.sha256(reference.read_bytes()).hexdigest()
            c3.write_text(json.dumps(dict(sources=[dict(path='printer.icc',sha256=digest),
                dict(path=str(reference),sha256=reference_hash)],patches=[patch])))
            req['verificationReference']=str(reference)
            result=build(req,p)
            self.assertEqual(result['groups'][1]['points'][0]['rgb'],[10,20,30])
            req['verificationReference']=''
            self.assertEqual([len(g['points']) for g in result['groups']],[3,1])
            html=(p/'all-measurements.html').read_text()
            self.assertIn('\\u003c/script>',html)
            self.assertNotIn(str(p),html)
            self.assertIn('all-measurements.html',(p/'final-report.html').read_text())
            patch['deltaE00']=1.00001
            c3.write_text(json.dumps(dict(sources=[dict(path='printer.icc',sha256=digest)],patches=[patch])))
            req['scope']='latest'
            (p/'final-report.html').write_text('<html></html>')
            result=build(req,p)
            self.assertEqual(result['defaultScope'],'latest')
            text=(p/'final-report.html').read_text()
            self.assertIn('1 selected patches above 1.000 (up to 100 largest, smallest first).',(p/'patch-comparison.html').read_text())
            self.assertNotIn('51.00, 11.00, -19.00',text)
            text=(p/'patch-comparison.html').read_text()
            self.assertIn('51.00, 11.00, -19.00',text)
            self.assertNotIn('&lt;/script&gt;',text)
            patch['deltaE00']=1
            c3.write_text(json.dumps(dict(sources=[dict(path='printer.icc',sha256=digest)],patches=[patch])))
            (p/'final-report.html').write_text('<html></html>')
            build(req,p)
            self.assertIn('0 selected patches above 1.000 (up to 100 largest, smallest first).',(p/'patch-comparison.html').read_text())
            req['verification']=''; req['fit']=''
            self.assertEqual(build(req,p)['groups'],[])
            req['verification']=str(c3); c3.write_text(json.dumps(dict(sources=[dict(path='other.icc',sha256='wrong')],patches=[patch])))
            with self.assertRaisesRegex(ValueError,'another ICC'): build(req,p)


if __name__=='__main__': unittest.main()
