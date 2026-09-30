import sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'exchange'))
from read_cxf import read, attach_layout
FIXTURE=Path(__file__).parent/'fixtures/cxf/rgb-spectrum.cxf'
class CxFTests(unittest.TestCase):
 def altered(self,old,new):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'test.cxf';p.write_text(FIXTURE.read_text().replace(old,new));return read(p)
 def test_spectrum_and_maxrange(self):
  r=read(FIXTURE);o=r['objects'][0];self.assertEqual(o['rgbScale'],100)
  self.assertEqual(o['values'][0]['wavelengthNm'],[390,400,410]);self.assertEqual(o['values'][0]['values'],[.1,.5,1.1]);self.assertEqual(o['values'][0]['scale'],1)
  self.assertEqual(r['originalXML'],FIXTURE.read_text());self.assertFalse(r['validation']['xsdValidated'])
 def test_default_rgb_scale(self):
  self.assertEqual(self.altered('<MaxRange>100</MaxRange>','')['objects'][0]['rgbScale'],255)
 def test_invalid_data(self):
  for old,new in [('ColorSpecification="spec"','ColorSpecification="missing"'),('<R>10</R>','<R>101</R>'),('0.1 0.5 1.1','nan 0.5 1.1'),('0.1 0.5 1.1','0.1 0.5 100'),('Increment="10"','Increment="0"'),('CxF3-core','CxF2-core'),('ColorRGB','ColorCMYK')]:
   with self.subTest(new=new),self.assertRaises(ValueError):self.altered(old,new)
 def test_missing_grid_preserved_without_guess(self):
  r=self.altered('<WavelengthRange StartWL="400" Increment="10"/>','');self.assertEqual(r['objects'][0]['values'][0]['wavelengthNm'],[]);self.assertTrue(r['warnings'])
 def test_entities(self):
  with self.assertRaises(ValueError):self.altered('<Resources>','<!DOCTYPE foo><Resources>')
 def test_layout_requires_sequence_and_unique_positions(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'layout.cxf'
   text=FIXTURE.read_text().replace('</DeviceColorValues>', '</DeviceColorValues><TagCollection Name="Location"><Tag Name="Page" Value="1"/><Tag Name="Row" Value="12"/><Tag Name="Column" Value="0"/></TagCollection>')
   p.write_text(text)
   r=attach_layout(read(FIXTURE),p)
   self.assertEqual(r['layout']['mapping'][0]['coordinate'],'A13')
   self.assertNotIn('spectra',r['layout'])
   p.write_text(text.replace('<R>10</R>','<R>11</R>'))
   with self.assertRaises(ValueError):attach_layout(read(FIXTURE),p)
if __name__=='__main__':unittest.main()
