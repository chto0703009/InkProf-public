# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys,unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from refinement import propose,local_sensitivity

def patch(i,rgb,error=5):
 return dict(sampleId=str(i),rgbPercent=rgb,measuredLab=[50+error,0,0],predictedLab=[50,0,0])
class RefinementTests(unittest.TestCase):
 def setUp(self):
  self.fit=[[0,0,0],[100,100,100],[20,50,50],[80,50,50]]
  self.p=[patch(1,[48,50,50]),patch(2,[52,50,50]),patch(3,[50,54,50])]
 def test_local_budget_and_spacing(self):
  r=propose(self.fit,self.p,budget=2,spacing=.5)
  self.assertEqual(len(r['candidates']),2)
  self.assertEqual(r['stopReason'],'iteration budget')
  existing=np.array(self.fit+[p['rgbPercent'] for p in self.p])
  for q in r['candidates']:
   self.assertGreaterEqual(np.min(np.linalg.norm(existing-q['rgbPercent'],axis=1)),.5-1e-8)
   self.assertLess(np.linalg.norm(np.array(q['rgbPercent'])-[50,50,50]),20)
 def test_norm_stops(self):
  r=propose(self.fit,self.p,norm_target=20)
  self.assertEqual(r['candidates'],[]);self.assertTrue(r['errorNorm']['reached'])
 def test_isolated_error(self):
  r=propose(self.fit,self.p[:1]);self.assertEqual(r['candidates'],[]);self.assertEqual(len(r['review']),1)
 def test_repeats_do_not_count_as_support(self):
  r=propose(self.fit,[self.p[0],self.p[0]])
  self.assertEqual(len(r['observations']),1);self.assertEqual(r['candidates'],[])
 def test_bad_repeat_excluded(self):
  r=propose(self.fit,[self.p[0],patch(4,[48,50,50],25)])
  self.assertEqual(r['errorNorm']['value'],None);self.assertEqual(r['candidates'],[])
 def test_fit_points_not_proposed_as_anchors(self):
  p=[patch(1,[20,50,50]),patch(2,[20,50,50])]
  self.assertEqual(propose(self.fit,p)['reuseObservationIndices'],[])
 def test_jacobian_direction_and_boundary(self):
  matrix=np.diag([4.,2.,0.])
  samples=np.array([[0,50,100],[50,50,50]])
  sens=local_sensitivity(lambda rgb:rgb@matrix.T,samples)
  for value in sens.values():
   np.testing.assert_allclose(value['jacobian'],matrix,atol=1e-12)
   self.assertTrue(value['nearSingular']);self.assertIsNone(value['conditionNumber'])
 def test_sensitivity_is_bounded_and_needs_error_support(self):
  sens=local_sensitivity(lambda rgb:rgb@np.diag([100.,1.,.1]),[p['rgbPercent'] for p in self.p])
  r=propose(self.fit,self.p,spacing=.5,sensitivity=sens)
  self.assertTrue(r['candidates'])
  for c in r['candidates']:self.assertTrue(1<=c['components']['sensitivityFactor']<=2)
  r=propose(self.fit,self.p[:1],sensitivity=sens)
  self.assertEqual(r['candidates'],[])
 def test_invalid(self):
  for kwargs in [dict(budget=0),dict(norm_target=-1),dict(spacing=20,radius=10)]:
   with self.assertRaises(ValueError):propose(self.fit,self.p,**kwargs)
 def test_deterministic(self):
  self.assertEqual(propose(self.fit,self.p),propose(self.fit,list(reversed(self.p))))
if __name__=='__main__':unittest.main()
