# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_target import select_indices
class VerificationTests(unittest.TestCase):
 def test_training_and_duplicates_excluded(self):
  rgb=np.array([[0,0,0],[.5,.5,.5],[.5,.5,.5],[.7,.2,.6]])
  self.assertEqual(select_indices(rgb,np.zeros((1,3)),2,.01),[1,3])
 def test_unavailable_count(self):
  with self.assertRaises(ValueError):select_indices(np.zeros((2,3)),np.zeros((1,3)),1,.01)
 def test_existing_group_excluded(self):
  rgb=np.array([[.5,.5,.5],[.7,.7,.7]])
  self.assertEqual(select_indices(rgb,np.zeros((1,3)),1,.01,[[.5,.5,.5]]),[1])
 def test_zero_count(self):
  self.assertEqual(select_indices(np.ones((2,3)),np.zeros((1,3)),0,.01),[])
if __name__=='__main__':unittest.main()
