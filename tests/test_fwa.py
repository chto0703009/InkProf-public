import sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from fwa import arguments

TI3 = '\n'.join(['CTI3','TARGET_INSTRUMENT "X-Rite i1 Pro 2"',
 'BEGIN_DATA_FORMAT','SAMPLE_ID RGB_R RGB_G RGB_B SPEC_380 SPEC_390','END_DATA_FORMAT',
 'BEGIN_DATA','1 100 100 100 95 96','END_DATA'])
COLOR = dict(mode='spectral',fwaCompensation=True,fwaIlluminant='D50')
COND = dict(interpreted='M0',instrument='X-Rite i1 Pro 2')
class FWATests(unittest.TestCase):
 def test_native_and_reject_unsupported(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'test.ti3';p.write_text(TI3)
   self.assertEqual(arguments(COLOR,COND,p),['-f','D50'])
   for c in ('M1','M2','unknown'):
    with self.assertRaises(ValueError):arguments(COLOR,COND|dict(interpreted=c),p)
   for c in (dict(instrumentFilter='UVCUT'),dict(fwaApplied=True),dict(instrument='')):
    with self.assertRaises(ValueError):arguments(COLOR,COND|c,p)
   with self.assertRaises(ValueError):arguments(COLOR|dict(mode='storedXYZ'),COND,p)
   for text in (TI3.replace('100 100 100','90 90 90'),TI3.replace('X-Rite i1 Pro 2','Other'),TI3.replace('SPEC_','XYZ_')):
    p.write_text(text)
    with self.assertRaises(ValueError):arguments(COLOR,COND,p)
 def test_legacy_off(self):
  self.assertEqual(arguments(dict(fwaCompensation=False),{},'missing'),[])
