# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'exchange'))
from export_i1profiler_cgats import export


class CGATSExportTests(unittest.TestCase):
    def test_precision_identity_and_rejections(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory)
            patch = dict(sampleId='1', sampleLoc='32A', isPadding=False, rgbPercent=[12.3456789, 0, 100])
            chart = p / 'chart.json'
            chart.write_text(json.dumps(dict(patches=[patch])))
            record = dict(documentType='inkprof.chart-measurement', complete=True, chartJSONSHA256=hashlib.sha256(chart.read_bytes()).hexdigest(), measurementCondition=dict(interpreted='M0', fwaApplied=False), metadata=[['DEVCALSTD', 'XRGA']], expectedSourcePatches=1, chartIndex=[1], data=dict(ids=['1'], locations=['32A'], rgbPercent=[patch['rgbPercent']], wavelengthNm=list(range(380,731,10)), spectra=[[115.3258]*36]))
            source = p / 'measurement.json'
            source.write_text(json.dumps(record))
            original = source.read_bytes()
            report = export(source, p / 'test.txt')
            self.assertEqual(report['patchCount'], 1)
            self.assertFalse(report['recipientImportVerified'])
            self.assertIn('1\tA32\t', (p/'test.txt').read_text())
            self.assertIn('1.153258', (p/'test.txt').read_text())
            self.assertEqual(source.read_bytes(), original)
            with self.assertRaisesRegex(ValueError, 'already exists'):
                export(source, p / 'test.txt')
            for field, value, message in [('chartJSONSHA256', 'wrong', 'hash'), ('complete', False, 'Complete')]:
                changed = dict(record, **{field:value})
                source.write_text(json.dumps(changed))
                with self.assertRaisesRegex(ValueError, message):
                    export(source, p/'bad.txt')
                self.assertFalse((p/'bad.txt').exists())
            record['data']['rgbPercent'] = [[99,0,100]]
            source.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, 'RGB differs'):
                export(source, p/'bad.txt')

if __name__ == '__main__':
    unittest.main()
