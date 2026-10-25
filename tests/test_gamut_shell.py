# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'analysis'))
import gamut_shell as s


def prism(polygon, caps, height):
    n = len(polygon)
    vertices = [[x,y,z] for z in (0,height) for x,y in polygon]
    triangles = list(caps) + [[a+n,b+n,c+n] for a,b,c in caps]
    for i in range(n):
        j=(i+1)%n
        triangles.extend([[i,j,j+n],[i,j+n,i+n]])
    return vertices, triangles


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.v, self.t = prism([(0,0),(100,0),(100,100),(0,100)], [[0,1,2],[0,2,3]],100)

    def test_distance_inside_outside_and_boundary(self):
        depth, inside=s.shell_depth([[50,50,50],[1,50,50],[-1,50,50],[0,40,50],[101,101,50]],self.v,self.t)
        np.testing.assert_allclose(depth,[50,1,1,0,np.sqrt(2)])
        np.testing.assert_array_equal(inside,[True,True,False,True,False])

    def test_concavity_and_winding_independence(self):
        v,t=prism([(0,0),(2,0),(2,1),(1,1),(1,2),(0,2)],[[0,1,3],[1,2,3],[0,3,5],[3,4,5]],2)
        depth,inside=s.shell_depth([[1.5,1.5,1],[.9,1.5,1],[.5,.5,1]],v,t)
        np.testing.assert_array_equal(inside,[False,True,True])
        np.testing.assert_allclose(depth,[.5,.1,.5])
        reversed_depth,reversed_inside=s.shell_depth([[1.5,1.5,1],[.9,1.5,1],[.5,.5,1]],v,[row[::-1] for row in t])
        np.testing.assert_allclose(depth,reversed_depth)
        np.testing.assert_array_equal(inside,reversed_inside)

    def test_open_mesh_rejected(self):
        with self.assertRaises(ValueError):
            s.shell_depth([[1,2,3]],self.v,self.t[:-1])

    def request(self):
        return dict(profileSHA256='fixture',surface=dict(profileSHA256='fixture',vertices=self.v,triangles=self.t),
                    xicclu='fake',shellThicknessDeltaE76=3,minSpacingPercent=1,maxPatches=25,
                    existingRGBPercent=[[0,0,0],[100,100,100]],samplingMode='shell')

    def test_printable_shell_budget_spacing_and_determinism(self):
        request=self.request()
        with patch.object(s,'forward_lookup',side_effect=lambda exe, profile, rgb: rgb*100):
            rows,lab,depth=s.candidates(request,'fake')
            again=s.candidates(request,'fake')[0]
        self.assertEqual(rows,again)
        self.assertEqual(len(rows),25)
        self.assertTrue(np.all(depth <= 3))
        rgb=np.asarray(rows)
        np.testing.assert_allclose(rgb,lab)
        np.testing.assert_allclose(rgb/100*65535,np.round(rgb/100*65535),atol=1e-8)
        occupied=np.vstack([request['existingRGBPercent'],rgb])
        distances=np.max(np.abs(occupied[:,None]-occupied[None,:]),axis=2)
        np.fill_diagonal(distances,np.inf)
        self.assertTrue(np.all(distances >= 1))

    def test_boundary_keeps_printable_outside_predictions_but_inner_shell_excludes_them(self):
        request=self.request()
        request['surface']['vertices']=(np.asarray(self.v)*.8+10).tolist()
        request.update(samplingMode='boundary',maxPatches=150,shellThicknessDeltaE76=5)
        with patch.object(s,'forward_lookup',side_effect=lambda exe, profile, rgb: rgb*100):
            rows,lab,depth=s.candidates(request,'fake')
            request['samplingMode']='shell'
            inner_rows,inner_lab,inner_depth=s.candidates(request,'fake')
        self.assertTrue(np.any(depth<0))
        self.assertTrue(np.any(depth>0))
        self.assertTrue(np.all(np.abs(depth)<=5))
        self.assertTrue(np.all((np.asarray(rows)>=0)&(np.asarray(rows)<=100)))
        distances,inside=s.shell_depth(lab,request['surface']['vertices'],self.t)
        np.testing.assert_array_equal(depth<0,~inside)
        np.testing.assert_allclose(np.abs(depth),distances)
        self.assertTrue(np.all(inner_depth>=0))
        self.assertTrue(np.all(s.shell_depth(inner_lab,request['surface']['vertices'],self.t)[1]))

    def test_local_shell_and_invalid_parameters(self):
        request=self.request(); request.update(samplingMode='shell-region',anchors=[dict(lab=[0,50,50])],regionRadiusDeltaE76=10)
        with patch.object(s,'forward_lookup',side_effect=lambda exe, profile, rgb: rgb*100):
            rows,lab,depth=s.candidates(request,'fake')
        self.assertTrue(np.all(np.linalg.norm(lab-[0,50,50],axis=1)<=10))
        self.assertTrue(np.all(depth<=3))
        for thickness in (0,float('nan'),51):
            request['shellThicknessDeltaE76']=thickness
            with self.assertRaises(ValueError):s.candidates(request,'fake')
        request=self.request();request['surface']['profileSHA256']='other'
        with self.assertRaises(ValueError):s.candidates(request,'fake')


if __name__ == '__main__':
    unittest.main()
