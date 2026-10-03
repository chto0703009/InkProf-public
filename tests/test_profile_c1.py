# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from lcms_float import LittleCMS
from profile_c1 import numerical_alerts,require_profile
from test_icc_reader import fixture

class C1Tests(unittest.TestCase):
    def test_lab_double_identity(self):
        c=LittleCMS();v=np.array([[0,0,0],[50,-10,20],[100,0,0],[33.12345,6.789,-22.333]])
        np.testing.assert_allclose(c.transform(None,v,'lab-identity'),v,atol=3e-5)
    def test_invalid_input(self):
        c=LittleCMS()
        with self.assertRaises(ValueError): c.transform(None,[[float('nan'),0,0]],'lab-identity')
        with self.assertRaises(ValueError): c.transform(None,[[0,0]],'lab-identity')
    def test_missing_library(self):
        with self.assertRaises(RuntimeError): LittleCMS('/not/an/installed/library')
    def test_invalid_profile(self):
        with self.assertRaises(ValueError): require_profile(b'bad')
    def test_wrong_class(self):
        v=fixture();v[12:16]=b'mntr'
        with self.assertRaises(ValueError): require_profile(v)
    def test_missing_relative_luts(self):
        with self.assertRaises(ValueError): require_profile(fixture())
    def test_gross_failure_detection(self):
        self.assertEqual(numerical_alerts(np.array([1]),np.array([[0,.5,1]])),[])
        self.assertIn('roundtrip-over-10-dE00',numerical_alerts(np.array([40]),np.zeros((1,3))))
        self.assertIn('rgb-out-of-range',numerical_alerts(np.array([1]),np.array([[0,0,1.1]])))
        self.assertIn('nonfinite',numerical_alerts(np.array([np.nan]),np.zeros((1,3))))
if __name__=='__main__': unittest.main()
