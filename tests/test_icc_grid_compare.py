# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys
import struct
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'profiles'))
import icc_grid_compare as c


def lut_profile(n):
    lut=bytearray(52+2*(3*2+n**3*3+3*2))
    lut[:4]=b'mft2';lut[8:11]=bytes([3,3,n]);struct.pack_into('>HH',lut,48,2,2)
    data=bytearray(156);data[8]=2;data[12:24]=b'prtrRGB Lab ';data[36:40]=b'acsp'
    struct.pack_into('>I',data,128,2)
    for i,tag in enumerate((b'A2B0',b'B2A0')):
        struct.pack_into('>4sII',data,132+i*12,tag,156,len(lut))
    data+=lut;struct.pack_into('>I',data,0,len(data))
    return data


class GridComparisonTests(unittest.TestCase):
    def test_actual_dimensions_and_increase(self):
        with tempfile.TemporaryDirectory() as d:
            a,b=Path(d)/'a.icc',Path(d)/'b.icc'
            a.write_bytes(lut_profile(9));b.write_bytes(lut_profile(17))
            result=c.compare(a,b)
            self.assertEqual(len(result['comparison']),2)
            self.assertEqual(result['comparison'][0]['sourcePoints'],729)
            self.assertEqual(result['comparison'][0]['candidatePoints'],4913)
            self.assertTrue(result['comparison'][0]['increased'])
            self.assertFalse(c.compare(a,a)['comparison'][0]['increased'])

    def test_truncated_lut_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'a.icc';data=lut_profile(9);data[166]=33;path.write_bytes(data)
            with self.assertRaisesRegex(ValueError,'Truncated'):c.grids(path)


if __name__=='__main__':unittest.main()
