# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib,json,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from fwa import prepare,reference_from_candidates
EXE=Path('/usr/local/bin/spec2cie')
WAVES=list(range(380,731,10))
COLOR=dict(mode='spectral',fwaCompensation=True,fwaIlluminant='D50',fwaPreparation='white-reference-spec2cie-v1')
COND=dict(interpreted='M0',instrument='X-Rite i1 Pro 2')
def ti3(white=True):
 fields=['SAMPLE_ID','SAMPLE_LOC','RGB_R','RGB_G','RGB_B']+['SPEC_'+str(w) for w in WAVES]
 rows=[['c','A1','20','40','60']+['30']*len(WAVES)]
 if white:rows += [['w1','A2','100','100','100']+['90']*len(WAVES),['w2','A3','100','100','100']+['94']*len(WAVES)]
 return '\n'.join(['CTI3','DESCRIPTOR "Native M0"','DEVICE_CLASS "OUTPUT"','COLOR_REP "RGB_XYZ"','TARGET_INSTRUMENT "X-Rite i1 Pro 2"','DEVCALSTD "XRGA"','SPECTRAL_BANDS "36"','SPECTRAL_START_NM "380"','SPECTRAL_END_NM "730"','NUMBER_OF_FIELDS '+str(len(fields)),'BEGIN_DATA_FORMAT',' '.join(fields),'END_DATA_FORMAT','NUMBER_OF_SETS '+str(len(rows)),'BEGIN_DATA']+[' '.join(row) for row in rows]+['END_DATA',''])
def candidate(value=92):return dict(documentType='inkprof.spot-candidate',wavelengthNm=WAVES,spectra=[value]*36,spectralScale=100,calibrationStandard='XRGA',instrumentSerial='s1',measurementCondition='M0 (inferred from i1 Pro 2 native unfiltered reflection)',mode='native reflection; no FWA',instrumentEvidence='Instrument Type: X-Rite i1 Pro 2\nU.V. filter ? : No')
class Tests(unittest.TestCase):
 @unittest.skipUnless(EXE.exists(),'Argyll spec2cie not installed')
 def test_actual_argyll_average_and_preserve_raw(self):
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'source.ti3';p.write_text(ti3());raw=p.read_bytes()
   converted,e=prepare(COLOR,COND,p,Path(folder)/'fwa',EXE)
   self.assertEqual(p.read_bytes(),raw);self.assertEqual(e['white']['count'],2)
   self.assertEqual(e['meanWhiteSpectrum'],[92]*36);self.assertAlmostEqual(e['whiteSpectrumSampleStdDev'][0],8**.5)
   self.assertNotIn('SPEC_380',converted.read_text());self.assertIn('XYZ_X',converted.read_text())
   self.assertEqual(e['sourceTI3SHA256'],hashlib.sha256(raw).hexdigest())
 @unittest.skipUnless(EXE.exists(),'Argyll spec2cie not installed')
 def test_blank_paper_reference_not_training_patch(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);p=root/'source.ti3';p.write_text(ti3(False));raw=p.read_bytes()
   with self.assertRaisesRegex(ValueError,'No measured paper-white'):prepare(COLOR,COND,p,root/'missing',EXE)
   paths=[]
   for i,v in enumerate([90,94]):
    path=root/f'candidate-{i}.json';path.write_text(json.dumps(candidate(v)));paths.append(path)
   ref=reference_from_candidates(paths);self.assertEqual(ref['count'],2);self.assertEqual(ref['meanSpectrum'],[92]*36)
   converted,e=prepare(COLOR|dict(paperWhiteReference=ref),COND,p,root/'fwa',EXE)
   self.assertTrue(e['addedReferenceExcludedFromFit']);self.assertEqual(p.read_bytes(),raw)
   self.assertNotIn('INKPROF_FWA_WHITE_REFERENCE',converted.read_text());self.assertIn('NUMBER_OF_SETS 1',converted.read_text())
   ref['meanSpectrum'][0]=95
   with self.assertRaisesRegex(ValueError,'mean'):prepare(COLOR|dict(paperWhiteReference=ref),COND,p,root/'tamper',EXE)
 def test_reject_missing_short_wave_or_already_corrected(self):
  with tempfile.TemporaryDirectory() as folder:
   p=Path(folder)/'source.ti3';p.write_text(ti3())
   for condition in [COND|dict(interpreted='M1'),COND|dict(fwaApplied=True),COND|dict(instrumentFilter='UVCUT')]:
    with self.assertRaises(ValueError):prepare(COLOR,condition,p,Path(folder)/'reject',EXE)
   p.write_text(ti3().replace('SPEC_380','BAD_380').replace('SPEC_390','BAD_390').replace('SPEC_400','BAD_400'))
   with self.assertRaisesRegex(ValueError,'short-wave'):prepare(COLOR,COND,p,Path(folder)/'range',EXE)
 @unittest.skipUnless(EXE.exists(),'Argyll spec2cie not installed')
 def test_matlab_singleton_reference_and_profile_anchor(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);c=root/'candidate.json';c.write_text(json.dumps(candidate()|dict(wavelengthNm=[float(w) for w in WAVES])))
   ref=reference_from_candidates([c]);ref['readings']=ref['readings'][0]
   ref['readings']['candidate']['wavelengthNm']=[int(w) for w in WAVES]
   p=root/'source.ti3';p.write_text(ti3(False))
   converted,e=prepare(COLOR|dict(paperWhiteReference=ref),COND,p,root/'profile',EXE,profile_white_anchor=True)
   self.assertTrue(e['additionalProfileWhiteAnchor']);self.assertIn('INKPROF_FWA_WHITE_REFERENCE',converted.read_text())
   self.assertIn('NUMBER_OF_SETS 2',converted.read_text())
   self.assertIsNotNone(e['referenceWhiteXYZ'])

 def test_blank_reference_serial_and_candidate_tamper(self):
  with tempfile.TemporaryDirectory() as folder:
   a=Path(folder)/'a.json';b=Path(folder)/'b.json';a.write_text(json.dumps(candidate()));b.write_text(json.dumps(candidate()|dict(instrumentSerial='other')))
   with self.assertRaises(ValueError):reference_from_candidates([a,b])
if __name__=='__main__':unittest.main()
