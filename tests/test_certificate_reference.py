# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Christer Törnkvist.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'analysis'))
from certificate_reference import html_section, patches


class ReferenceTests(unittest.TestCase):
    def test_named_reference_and_measurement(self):
        report = {'referenceTarget': {'name': 'ColorChecker SG'}, 'patchOutliers': {'allPatches': [
            {'referenceName': 'A1', 'sampleId': '1', 'desiredHex': '#123456', 'hex': '#234567', 'deltaE00': 1.25}]}}
        html = html_section(report)
        for text in ['ColorChecker SG', 'A1', '1.25', '#123456', '#234567']:
            self.assertIn(text, html)
        self.assertEqual(patches(report)[0]['deltaE00'], 1.25)

    def test_generic_target_has_no_reference_claim(self):
        self.assertEqual(html_section({'patchOutliers': {'allPatches': [{}]}}), '')

    def test_single_patch_and_escaping(self):
        report = {'referenceTarget': {'name': '<reference>'}, 'patchOutliers': {'allPatches':
            {'sampleId': '1', 'referenceName': '<A1>', 'hex': '#234567', 'deltaE00': 0}}}
        html = html_section(report)
        self.assertIn('&lt;reference&gt;', html)
        self.assertIn('&lt;A1&gt;', html)


if __name__ == '__main__':
    unittest.main()
