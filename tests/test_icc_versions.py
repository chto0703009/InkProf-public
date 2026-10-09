# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import datetime,hashlib,json,struct,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'profiles'),str(ROOT/'analysis')]
from icc_v2_to_v4 import Profile,Lut16,D50_HEADER,convert,ConversionError,main,mluc
from icc_lookup import lookup
from lcms_float import LittleCMS
from profile_job import run
from verification_check import v4_readings

def profile():
 h=bytearray(128);h[8:12]=bytes([2,0x20,0,0]);h[12:24]=b'prtrRGB Lab ';h[36:40]=b'acsp';h[68:80]=D50_HEADER
 struct.pack_into('>6H',h,24,2026,10,9,10,0,0)
 nodes=np.array(np.meshgrid(*[np.linspace(0,1,3)]*3,indexing='ij')).reshape(3,-1).T
 curve=np.tile([0.,1.],(3,1));matrix=struct.pack('>9i',65536,0,0,0,65536,0,0,0,65536)
 a=Lut16(3,3,3,matrix,curve,nodes,curve).to_bytes()
 tags=[(s,a) for s in [b'A2B0',b'A2B1',b'A2B2',b'B2A0',b'B2A1',b'B2A2',b'gamt']]
 text=b'Fixture\0';desc=b'desc'+bytes(4)+struct.pack('>I',len(text))+text+bytes(78)
 tags += [(b'wtpt',b'XYZ '+bytes(4)+D50_HEADER),(b'desc',desc),(b'cprt',b'text'+bytes(4)+text)]
 return Profile(h,tags).assemble()

class VersionTests(unittest.TestCase):
 def test_preserves_colorimetric_tables_and_ids(self):
  src=profile();out,r=convert(src,timestamp=datetime.datetime(2026,10,9))
  self.assertEqual(r['problems'],[]);self.assertEqual(out[8:12],bytes([4,0x40,0,0]))
  for tag in (b'A2B1',b'B2A1',b'wtpt'):self.assertEqual(Profile.parse(src).get(tag),Profile.parse(out).get(tag))
  with tempfile.TemporaryDirectory() as d:
   a=Path(d)/'v2.icc';b=Path(d)/'v4.icc';a.write_bytes(src);b.write_bytes(out)
   c=LittleCMS();rgb=np.random.default_rng(3).random((100,3))
   for intent in [1,3]:np.testing.assert_allclose(c.transform(a,rgb,intent=intent),c.transform(b,rgb,intent=intent),atol=1e-10)
   with patch('icc_lookup.argyll_lookup',side_effect=AssertionError('Argyll must not read v4')):
    np.testing.assert_allclose(lookup('unused',b,rgb,'f','a'),c.transform(b,rgb,intent=3))
 def test_invalid_lut_and_same_path_rejected(self):
  with self.assertRaises(ConversionError):Lut16.parse(b'mft2')
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'p.icc';p.write_bytes(profile());self.assertEqual(main([str(p),str(p)]),2);self.assertEqual(p.read_bytes(),profile())
 def test_worker_choices_and_atomic_failure(self):
  from test_profile_job import JobTests
  for choice in ['v2','v4','both','invalid']:
   with self.subTest(choice=choice),tempfile.TemporaryDirectory() as d:
    folder=JobTests().prepare(d);exe=folder/'fake-colprof'
    exe.write_text(f'#!{sys.executable}\nimport sys\nfrom pathlib import Path\nif "-?" in sys.argv:sys.exit(1)\nPath(sys.argv[-1]+".icc").write_bytes({profile()!r})\n');exe.chmod(0o755)
    p=folder/'recipe.json';r=json.loads(p.read_text());r['printing']['profileOutputVersions']=choice;p.write_text(json.dumps(r))
    q=folder/'request.json';request=json.loads(q.read_text());request['files']['recipe.json']=hashlib.sha256(p.read_bytes()).hexdigest();q.write_text(json.dumps(request))
    result=run(folder)
    self.assertEqual(result['status'],'failed' if choice=='invalid' else 'succeeded')
    if choice=='invalid':self.assertFalse((folder/'result').exists());continue
    self.assertEqual(len(result['deliveryProfiles']),2 if choice=='both' else 1)
    self.assertEqual((folder/'result/profile-v4.icc').exists(),choice in ('v4','both'))
 def test_native_c3_never_sends_v4_to_profcheck(self):
  from types import SimpleNamespace
  from test_verification_check import fixture
  from verification_check import run as check_print
  ref,m,_=fixture()
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory)
   for name,data in [('profile.icc',convert(profile())[0]),('target.ti2',b'target'),('source.ti2',b'target'),('chart.json',b'{}'),('measurement.ti3',b'synthetic source')]:
    (root/name).write_bytes(data)
   sha=lambda name:hashlib.sha256((root/name).read_bytes()).hexdigest()
   ref.update(printerProfile=dict(file='profile.icc',sha256=sha('profile.icc')),printPackage=dict(ti2='target.ti2',ti2SHA256=sha('target.ti2')),externalProfile=True)
   m.update(sourceTI3SHA256=sha('measurement.ti3'),chartJSONSHA256=sha('chart.json'))
   (root/'reference.json').write_text(json.dumps(ref));(root/'measurement.json').write_text(json.dumps(m))
   def subprocess_run(command,**kwargs):
    if '-?' not in command:
     self.assertTrue(str(command[0]).endswith('spec2cie'))
     self.assertNotIn(str(root/'profile.icc'),command)
     Path(command[-1]).write_text('CTI3\nBEGIN_DATA_FORMAT\nSAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nBEGIN_DATA\n2 2A 50 50 50 20 20 20\n1 1A 50 50 50 20 20 20\nEND_DATA\n')
    return SimpleNamespace(returncode=0,stdout=b'test integration',stderr=b'')
   with patch('verification_check.subprocess.run',side_effect=subprocess_run),patch('colour_management_check.check',return_value={'status':'test'}),patch('verification_chain.analyse',return_value={'sources':[]}):
    result=check_print(root/'reference.json',root/'measurement.json','/unused/profcheck',root/'output')
   self.assertEqual(result['colourEngine']['engine'],'LittleCMS')
   self.assertEqual(result['summary']['count'],1)
 def test_v4_integrated_readings_keep_identity(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'p.icc';p.write_bytes(convert(profile())[0]);t=Path(d)/'measured.ti3'
   t.write_text('CTI3\nBEGIN_DATA_FORMAT\nSAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z\nEND_DATA_FORMAT\nBEGIN_DATA\n1 1A 50 50 50 20 20 20\nEND_DATA\n')
   expected=dict(ids=['1'],locations=['1A'],rgb=[[50,50,50]])
   rows=v4_readings(t,p,expected);self.assertEqual(rows[0]['sampleId'],'1');self.assertTrue(np.isfinite(rows[0]['measuredLab']).all())
   expected['rgb']=[[60,50,50]]
   with self.assertRaises(ValueError):v4_readings(t,p,expected)
if __name__=='__main__':
 if len(sys.argv)==3 and sys.argv[1]=='--fixture':Path(sys.argv[2]).write_bytes(profile())
 else:unittest.main()
