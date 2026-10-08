# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
from row_compare import compare


class RowComparisonTests(unittest.TestCase):
    def test_explicit_mapping_with_shuffled_parent(self):
        parent = dict(chartIndex=[4, 1, 5, 2], data=dict(locations=['2A', '1A', '2B', '1B'],
                      xyz=[[20, 25, 30], [10, 15, 20], [30, 35, 40], [40, 45, 50]]))
        candidate = dict(chartIndex=[2, 1], data=dict(ids=['5', '4'], xyz=[[30, 35, 40], [21, 26, 31]]))
        r = compare(parent, candidate, dict(chartIndices=[4, 5]))
        self.assertEqual([p['location'] for p in r['patches']], ['2A', '2B'])
        self.assertGreater(r['patches'][0]['deltaE00'], 0)
        self.assertEqual(r['patches'][1]['deltaE00'], 0)

    def test_duplicate_mapping_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            compare(dict(chartIndex=[1, 1]), dict(chartIndex=[1]), dict(chartIndices=[1]))


if __name__ == '__main__':
    unittest.main()
