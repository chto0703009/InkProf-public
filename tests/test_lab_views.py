# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import sys,json,hashlib,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from gamut_surface import slice_segments,pdf_drawing,interactive
from lab_views import point_drawing,measured_data

class LabViewsTests(unittest.TestCase):
 def test_exact_surface_intersection_not_vertex_band(self):
  data=dict(vertices=[[0,0,0],[100,20,0],[100,0,20]],triangles=[[0,1,2]],rgb=[[0,0,0],[1,0,0],[0,1,0]])
  segments=slice_segments(data,50)
  self.assertEqual(len(segments),1)
  self.assertEqual(segments[0][:2],([10.,0.],[0.,10.]))
  self.assertEqual(slice_segments(data,101),[])
  labels=[getattr(x,'text','') for x in pdf_drawing(data).contents]
  self.assertIn('ICC gamut | exact L* = 50 slice',labels);self.assertIn('a*',labels);self.assertIn('b*',labels)
 def test_measured_band_and_controls(self):
  drawing=point_drawing([[44,0,0],[45,1,2],[55,3,4],[56,0,0]])
  labels=[getattr(x,'text','') for x in drawing.contents]
  self.assertIn('2 of 4 points in the L* band; not a gamut boundary.',labels)
  page=interactive(dict(vertices=[[50,0,0]],triangles=[[0,0,0]],rgb=[[.5,.5,.5]]))
  self.assertIn('value="2d"',page);self.assertIn('value="3d"',page);self.assertIn('value="50"',page)
 def test_single_matlab_row_is_preserved(self):
  data=measured_data(dict(measuredColours=dict(lab=[50,1,2],rgb=[.5,.5,.5])),'.')
  self.assertEqual(data['vertices'],[[50,1,2]])
 def test_predictions_are_not_used_as_measurements(self):
  self.assertIsNone(measured_data(dict(visualization=dict(lab=[[50,1,2]])),'.'))
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'c3.json';p.write_text(json.dumps(dict(patches=[dict(measuredLab=[50,0,0],role='colour'),dict(measuredLab=[99,0,0],role='repeat')])))
   report=dict(sources=dict(c3_report=dict(file=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest())))
   self.assertEqual(measured_data(report,folder)['vertices'],[[50,0,0]])
   p.write_text('{}')
   with self.assertRaisesRegex(ValueError,'integrity'):measured_data(report,folder)
if __name__=='__main__':unittest.main()
