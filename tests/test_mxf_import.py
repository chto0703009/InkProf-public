import sys, unittest, tempfile, copy, random
from pathlib import Path
import xml.etree.ElementTree as E
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'exchange'))
from import_mxf import convert, N
C='{'+N['c']+'}';P='{http://www.xrite.com/products/prism}'
def fixture():
 root=E.Element(C+'CxF');E.SubElement(root,C+'FileInformation');res=E.SubElement(root,C+'Resources');objs=E.SubElement(res,C+'ObjectCollection')
 specs=E.SubElement(res,C+'ColorSpecificationCollection');s=E.SubElement(specs,C+'ColorSpecification',Id='M0spec');ms=E.SubElement(s,C+'MeasurementSpec')
 E.SubElement(ms,C+'MeasurementType').text='Spectrum_Reflectance';E.SubElement(ms,C+'WavelengthRange',StartWL='380',Increment='10');E.SubElement(ms,C+'CalibrationStandard').text='XRGA';dev=E.SubElement(ms,C+'Device');E.SubElement(dev,C+'DeviceIllumination').text='M0_Incandescent'
 for i,(page,row,col) in enumerate([(1,0,0),(1,0,1),(1,1,0),(1,1,1),(2,0,0),(2,0,1),(2,1,0)],1):
  for kind in ['Target','M0_Measurement']:
   o=E.SubElement(objs,C+'Object',ObjectType=kind,Id=kind+str(i),Name=kind+str(i))
   if kind=='Target':
    color=E.SubElement(E.SubElement(o,C+'DeviceColorValues'),C+'ColorRGB')
    for ch in 'RGB':E.SubElement(color,C+ch).text='128' # deliberate duplicate RGB
   else:E.SubElement(E.SubElement(o,C+'ColorValues'),C+'ReflectanceSpectrum',StartWL='380',ColorSpecification='M0spec').text=' '.join(str(.1*i+.001*j) for j in range(36))
   tags=E.SubElement(o,C+'TagCollection',Name='Location')
   for k,v in [('Page',page),('Row',row),('Column',col),('SampleID',-1)]:E.SubElement(tags,C+'Tag',Name=k,Value=str(v))
 custom=E.SubElement(root,C+'CustomResources');E.SubElement(custom,P+'CustomAttributes',ColorSpace='RGB',NumberPatchColumns='2',NumberPatchRows='2',NumberPatchPages='2',MeasurementDevice='i1Pro 2',MeasurementDeviceSerialNumber='TEST',Paper='Matte')
 return root
class ImportTests(unittest.TestCase):
 def run_import(self,root,condition=''):
  with tempfile.TemporaryDirectory() as temp:
   p=Path(temp)/'input.mxf';E.ElementTree(root).write(p,encoding='utf-8',xml_declaration=True);raw=p.read_bytes()
   result=convert(p,Path(temp)/'out',condition)
   self.assertEqual(raw,p.read_bytes());return result
 def test_shuffled_measurements_duplicate_rgb_and_pages(self):
  root=fixture();objs=root.find('c:Resources/c:ObjectCollection',N);items=list(objs);random.Random(42).shuffle(items);objs[:]=items
  r=self.run_import(root);self.assertEqual(r['patchCount'],7);self.assertEqual(r['customAttributes']['Paper'],'Matte')
  for m in r['mapping']:
   i=int(m['targetName'].removeprefix('Target'));self.assertEqual(m['measurementObjectId'],'M0_Measurement'+str(i));self.assertAlmostEqual(m['spectra'][0],i*10)
  self.assertIn('4A',[m['sampleLoc'] for m in r['mapping']])
 def test_ambiguous_location_rejected(self):
  root=fixture();objs=root.find('c:Resources/c:ObjectCollection',N);m=[o for o in objs if o.get('ObjectType')=='M0_Measurement'];m[1].find('c:TagCollection/c:Tag[@Name="Column"]',N).set('Value','0')
  with self.assertRaisesRegex(ValueError,'Ambiguous'):self.run_import(root)
 def test_cmyk_rejected(self):
  r=fixture();r.find('.//'+P+'CustomAttributes').set('ColorSpace','CMYK')
  with self.assertRaisesRegex(ValueError,'RGB'):self.run_import(r)
 def test_bad_grid_and_nonfinite_rejected(self):
  for attr,value in [('StartWL','390'),('text','nan')]:
   r=fixture();sp=r.find('.//c:ReflectanceSpectrum',N)
   if attr=='text':sp.text=value
   else:sp.set(attr,value)
   with self.assertRaises(ValueError):self.run_import(r)
 def test_multiple_conditions_require_selection(self):
  r=fixture();objs=r.find('c:Resources/c:ObjectCollection',N)
  for o in list(objs):
   if o.get('ObjectType')=='M0_Measurement':
    new=copy.deepcopy(o);new.set('Id','second'+o.get('Id'));new.set('ObjectType','M1_Measurement');objs.append(new)
  with self.assertRaisesRegex(ValueError,'specify Condition'):self.run_import(r)
  self.assertEqual(self.run_import(r,'M0')['availableConditions'],['M0','M1'])
if __name__=='__main__':unittest.main()
