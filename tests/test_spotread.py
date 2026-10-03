# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import importlib.util,json,os,subprocess,sys,tempfile,time,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"bridge"))
spec=importlib.util.spec_from_file_location('spot',ROOT/'bridge/spotread_bridge.py');spot=importlib.util.module_from_spec(spec);spec.loader.exec_module(spot)
class SpotTest(unittest.TestCase):
 def test_parser(self):
  s='Spectrum from 380 to 400 nm in 3 steps\n1,2,3\nPeak value 3\nResult is XYZ: 1 2 3, D50 Lab: 4 5 6\n'
  self.assertEqual(spot.parse_reading(s)['spectra'],[1,2,3])
  for bad in [s+s,s.replace('1,2,3','1,2'),s.replace('1,2,3','1,2,3,4'),s.replace('Result is XYZ','Missing XYZ')]:
   with self.assertRaises(ValueError):spot.parse_reading(bad)
 def test_transport(self):
  with tempfile.TemporaryDirectory() as d:
   Path(d,'request.json').write_text(json.dumps({'calibrationStandard':'XRGA','port':0}))
   p=subprocess.Popen([sys.executable,'-u',str(ROOT/'bridge/spotread_bridge.py'),d,str(ROOT/'tests/fixtures/fake_spotread.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
   try:
    states=[];candidate=False
    import selectors
    # reader thread avoids text buffering and enforces an overall deadline.
    import queue,threading
    q=queue.Queue()
    def reader():
     for line in p.stdout:q.put(json.loads(line))
    threading.Thread(target=reader,daemon=True).start()
    deadline=time.monotonic()+15
    while time.monotonic()<deadline:
     e=q.get(timeout=5)
     self.assertNotEqual(e['event'],'error',e)
     if e['event']=='state' and e['kind']!='busy':
      states.append(e['kind']);p.stdin.write(json.dumps({'command':'key','text':' '})+'\n');p.stdin.flush()
     if e['event']=='candidate':candidate=True;break
    self.assertTrue(candidate);self.assertEqual(states,['calibration','calibrationRetry','ready'])
    self.assertEqual(p.wait(timeout=5),0)
    c=json.loads(Path(d,'candidate.json').read_text());self.assertEqual(c['instrumentSerial'],'FIXTURE');self.assertEqual(len(c['spectra']),36)
   finally:
    if p.poll() is None:p.kill();p.wait()
    p.stdin.close();p.stdout.close()
if __name__=='__main__':unittest.main()
