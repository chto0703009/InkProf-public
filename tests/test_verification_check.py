"""C3 identities, reference semantics and repeat statistics, no instrument."""
import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_check import analyse, validate, run
import json
import tempfile


def fixture():
    patches=[]
    for i,role in enumerate(('gray','repeat'),1):
        patches.append(dict(id=str(i),role=role,repeatOf='1' if i==2 else [],
                            referenceLabD50Absolute=[50,0,0],predictedLabD50Absolute=[60,0,0],
                            deviceRGB=[.5,.5,.5],deviceRGB16=[32768]*3,gamutAssessment='model-reachable',
                            placement=dict(page=1,coordinate=f'A{i}',location=f'{i}A')))
    ref=dict(documentType='inkprof.verification-target',intent='absolute colorimetric',bpc=False,patches=patches)
    m=dict(complete=True,data=dict(ids=['2','1'],locations=['2A','1A'],rgbPercent=[[50]*3]*2,spectra=[[20,30]]*2,wavelengthNm=[400,410]))
    readings=[dict(sampleId='2',measuredLab=[51,0,0]),dict(sampleId='1',measuredLab=[50,0,0])]
    return ref,m,readings


class C3Tests(unittest.TestCase):
    def test_paperwhite_excluded_from_independent_score(self):
        ref,m,readings=fixture()
        p=copy.deepcopy(ref['patches'][0]);p.update(id='3',role='paperwhite',repeatOf=None)
        p['placement']=dict(page=1,coordinate='A3',location='3A');ref['patches'].append(p)
        for key,value in [('ids','3'),('locations','3A'),('rgbPercent',[50]*3),('spectra',[20,30])]:m['data'][key].append(value)
        readings.append(dict(sampleId='3',measuredLab=[90,0,0]))
        result=analyse(ref,m,readings)
        self.assertEqual(result['summary']['count'],1)
        self.assertEqual(result['summary']['mean'],0)

    def test_rendered_ids_are_mapped_without_changing_reference_or_repeat_ids(self):
        ref,m,readings=fixture()
        ref['patches'][0]['placement']['sampleId']='2'
        ref['patches'][1]['placement']['sampleId']='1'
        m['data']['ids']=['1','2']
        readings[0]['sampleId']='1'
        readings[1]['sampleId']='2'
        result=analyse(ref,m,readings)
        self.assertEqual(result['patches'][0]['sampleId'],'1')
        self.assertEqual(result['patches'][0]['measurementSampleId'],'2')
        self.assertEqual(result['patches'][0]['measuredLab'],[50,0,0])
        self.assertEqual(result['summary']['max'],0)
        self.assertGreater(result['repeatedPrintedPatches']['summary']['mean'],0)
        ref['patches'][1]['placement']['sampleId']='2'
        with self.assertRaises(ValueError):validate(ref,m)

    def test_desired_not_prediction_and_no_duplicate_weight(self):
        ref,m,readings=fixture();r=analyse(ref,m,readings)
        self.assertEqual(r['summary']['count'],1)
        self.assertEqual(r['summary']['max'],0)
        self.assertGreater(r['patches'][0]['predictedDeltaE00'],5)
        self.assertGreater(r['repeatedPrintedPatches']['summary']['mean'],0)
        self.assertEqual(r['patches'][0]['coordinate'],'A1')

    def test_invalid_identity_location_rgb_and_repeat(self):
        for mutation in ('id','location','rgb','repeat','incomplete','spectra'):
            with self.subTest(mutation=mutation):
                ref,m,_=fixture()
                if mutation=='id':m['data']['ids']=['1','1']
                if mutation=='location':m['data']['locations'][0]='3A'
                if mutation=='rgb':m['data']['rgbPercent'][0]=[10,20,30]
                if mutation=='repeat':ref['patches'][1]['repeatOf']='2'
                if mutation=='incomplete':m['complete']=False
                if mutation=='spectra':m['data']['spectra'][0]=[float('nan'),20]
                with self.assertRaises(ValueError):validate(ref,m)

    def test_missing_reading(self):
        ref,m,r=fixture()
        with self.assertRaises(ValueError):analyse(ref,m,r[:1])

    def test_hash_failure_before_external_tool(self):
        ref,m,_=fixture()
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp); (p/'profile.icc').write_bytes(b'wrong')
            ref.update(printerProfile=dict(file='profile.icc',sha256='0'*64),printPackage=dict(ti2='target.ti2',ti2SHA256='1'*64))
            m.update(sourceTI3SHA256='2'*64,chartJSONSHA256='3'*64)
            (p/'verification.json').write_text(json.dumps(ref));(p/'measurement.json').write_text(json.dumps(m))
            with self.assertRaisesRegex(ValueError,'hash mismatch'):
                run(p/'verification.json',p/'measurement.json','does-not-exist',p/'output')
            self.assertFalse((p/'output').exists())

if __name__=='__main__':unittest.main()
