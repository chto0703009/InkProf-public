import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
WORKER=ROOT/'profiles/profile_job.py'

def profile():
    b=bytearray(172);b[8:10]=bytes([4,32]);b[12:24]=b'prtrRGB Lab ';b[36:40]=b'acsp'
    struct.pack_into('>6H',b,24,2026,9,27,12,0,0);struct.pack_into('>I',b,128,2)
    for i,s in enumerate([b'A2B0',b'B2A0']):
        struct.pack_into('>4sII',b,132+i*12,s,156+8*i,8);b[156+8*i:160+8*i]=b'mft2'
    struct.pack_into('>I',b,0,len(b));return bytes(b)

class JobTests(unittest.TestCase):
    def prepare(self,root,mode='ok'):
        root=Path(root);exe=root/'fake-colprof'
        exe.write_text(f'#!{sys.executable}\nimport sys,time\nfrom pathlib import Path\nif "-?" in sys.argv: print("Fake colprof test 1.0");sys.exit(1)\n'+
                       ('time.sleep(30)\n' if mode=='slow' else '')+
                       ('sys.exit(7)\n' if mode=='fail' else '')+
                       f'Path("engine.icc").write_bytes({profile()!r})\n')
        exe.chmod(0o755)
        recipe={'colorimetry':{'mode':'spectral','fwaCompensation':False,'illuminant':'D50','observer':'1931_2'},'engine':{'quality':'medium','algorithm':'Lab cLUT','plannedArguments':['-qm','-al','-i','D50','-o','1931_2','-D','Test']},'description':'Test','printing':{'paperSurface':'Glossy'}}
        (root/'recipe.json').write_text(json.dumps(recipe));(root/'engine.ti3').write_text('synthetic test')
        request={'executable':str(exe),'timeoutSeconds':60,'inputPreparation':'test','files':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in ['recipe.json','engine.ti3']}}
        (root/'request.json').write_text(json.dumps(request));return root
    def execute(self,root):
        subprocess.run([sys.executable,str(WORKER),str(root)],check=True,timeout=20)
        return json.loads((root/'status.json').read_text())
    def test_success(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d);r=self.execute(p);self.assertEqual(r['status'],'succeeded');self.assertTrue((p/r['profileFile']).exists())
    def test_b2a_quality(self):
        for quality,flag in [('high','-bh'),('medium','-bm'),('invalid',None)]:
            with self.subTest(quality=quality), tempfile.TemporaryDirectory() as d:
                p=self.prepare(d)
                recipe=json.loads((p/'recipe.json').read_text())
                recipe['engine']['b2aQuality']=quality
                if flag: recipe['engine']['plannedArguments'].insert(6,flag)
                (p/'recipe.json').write_text(json.dumps(recipe))
                req=json.loads((p/'request.json').read_text())
                req['files']['recipe.json']=hashlib.sha256((p/'recipe.json').read_bytes()).hexdigest()
                (p/'request.json').write_text(json.dumps(req))
                r=self.execute(p)
                self.assertEqual(r['status'],'succeeded' if flag else 'failed')
                if flag: self.assertIn(flag,r['arguments'])
                else: self.assertFalse((p/'work').exists())

    def test_high_quality_smoothing_and_argument_tamper(self):
        for tamper in (False, True):
            with self.subTest(tamper=tamper), tempfile.TemporaryDirectory() as d:
                p=self.prepare(d)
                recipe=json.loads((p/'recipe.json').read_text())
                recipe['engine']['quality']='high'
                recipe['engine']['smoothing']=0.1
                args=recipe['engine']['plannedArguments']
                args[0]='-qh'; args[6:6]=['-r',format(0.1,'.17g')]
                if tamper: args[7]='2'
                (p/'recipe.json').write_text(json.dumps(recipe))
                req=json.loads((p/'request.json').read_text())
                req['files']['recipe.json']=hashlib.sha256((p/'recipe.json').read_bytes()).hexdigest()
                (p/'request.json').write_text(json.dumps(req))
                r=self.execute(p)
                self.assertEqual(r['status'],'failed' if tamper else 'succeeded')
                if tamper:self.assertFalse((p/'work').exists())

    def test_failure(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d,'fail');r=self.execute(p);self.assertEqual(r['status'],'failed');self.assertEqual(r['exitCode'],7);self.assertFalse((p/'result').exists())
    def test_tamper(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d);(p/'engine.ti3').write_text('changed');r=self.execute(p);self.assertEqual(r['status'],'failed');self.assertFalse((p/'work').exists())
    def test_cancel(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d,'slow');proc=subprocess.Popen([sys.executable,str(WORKER),str(p)])
            try:
                deadline=time.monotonic()+10
                while time.monotonic()<deadline:
                    if (p/'status.json').exists() and json.loads((p/'status.json').read_text())['status']=='running':break
                    time.sleep(.05)
                (p/'cancel.request').touch();proc.wait(timeout=8)
                self.assertEqual(json.loads((p/'status.json').read_text())['status'],'cancelled');self.assertFalse((p/'result').exists())
            finally:
                if proc.poll() is None:proc.kill();proc.wait()

if __name__=='__main__':unittest.main()
