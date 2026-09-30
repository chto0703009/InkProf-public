import sys, unittest, copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from verification_feedback import analyse
import colour


def patch(id, role, desired, predicted, measured):
 return dict(sampleId=id,role=role,page=1,coordinate='A'+id,desiredLab=desired,predictedLab=predicted,measuredLab=measured,
             deltaE00=float(colour.delta_E(desired,measured)),predictedDeltaE00=float(colour.delta_E(predicted,measured)))

class FeedbackTests(unittest.TestCase):
 def fixture(self):
  return dict(documentType='inkprof.verification-check',patches=[
   patch('1','colour',[50,0,0],[50,0,0],[65,0,0]),
   patch('2','challenge',[20,0,0],[50,0,0],[50,0,0]),
   patch('3','repeat',[50,0,0],[50,0,0],[65,0,0])],repeatedPrintedPatches=dict(pairs=[]))
 def test_expected_limit_not_model_priority_and_no_repeat_weight(self):
  r=analyse(self.fixture())
  self.assertEqual([p['sampleId'] for p in r['priorities']],['1'])
  self.assertEqual(r['patches'][1]['classification'],'predicted-limitation')
  self.assertEqual(r['groups']['allUnique']['count'],2)
  self.assertFalse(r['qualityApproved']);self.assertEqual(r['isoConformity'],'not-assessed')
 def test_small_acceptable_error_no_priority(self):
  r=self.fixture();r['patches']=[patch('1','gray',[50,0,0],[50,0,0],[50.7,0,0])]
  self.assertEqual(analyse(r)['priorities'],[])
 def test_limit_config_and_repeat_gate(self):
  r=self.fixture();r['repeatedPrintedPatches']['pairs']=[dict(deltaE00=1.5)]
  self.assertEqual(analyse(r)['repeatability']['status'],'review')
  self.assertEqual(analyse(r,dict(ModelTolerance=50))['priorities'],[])
 def test_bad_input(self):
  for kind in ['duplicate','nonfinite','inconsistent','role']:
   r=self.fixture()
   if kind=='duplicate':r['patches'][1]['sampleId']='1'
   if kind=='nonfinite':r['patches'][0]['measuredLab'][0]=float('nan')
   if kind=='inconsistent':r['patches'][0]['deltaE00']=0
   if kind=='role':r['patches'][0]['role']='other'
   with self.assertRaises(ValueError):analyse(r)
  with self.assertRaises(ValueError):analyse(self.fixture(),dict(MaxPriorityPatches=1.5))
  with self.assertRaises(ValueError):analyse(self.fixture(),dict(PatchLimit=-1))
if __name__=='__main__':unittest.main()
