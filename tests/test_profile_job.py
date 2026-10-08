# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
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

PRE_TI3='\n'.join(['CTI3','ORIGINATOR "test"','DEVICE_CLASS "OUTPUT"','COLOR_REP "RGB_XYZ"','SPECTRAL_BANDS "2"',
 'SPECTRAL_START_NM "380.0"','SPECTRAL_END_NM "390.0"','INKPROF_MEASUREMENT_CONDITION "M0"','NUMBER_OF_FIELDS 10',
 'BEGIN_DATA_FORMAT','SAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z SPEC_380 SPEC_390','END_DATA_FORMAT','NUMBER_OF_SETS 4','BEGIN_DATA',
 '"1" "1A" 0 0 0 0.39 0.41 0.36 0.6 0.7','"2" "2A" 100 100 100 88.1 91.2 76.5 90 91',
 '"3" "3A" 50 20 80 12.5 9.7 30.2 20 30','"4" "4A" 14.117647058823529 0 0 0.75 0.69 0.42 0.5 0.6','END_DATA'])+'\n'

def _grid_patches():
    import itertools
    out=[]
    for r,g,b in itertools.product([0,25,50,75,100],repeat=3):
        L=20+0.6*(r+g+b)/3;out.append(((r,g,b),[max(0.3,(L/100)**3*96.42*(1+0.002*(r-b))),max(0.3,(L/100)**3*100),max(0.3,(L/100)**3*82.49*(1+0.003*(b-g)))]))
    return out
GRID_PATCHES=_grid_patches()

FAKE_PROFCHECK="""#!{python}
import sys
sys.path.insert(0,{profiles!r})
import preregularize as p
from pathlib import Path
if '-?' in sys.argv: sys.exit(1)
t=p.read_ti3(Path(sys.argv[-2]).read_text());k=t['fields'].index('XYZ_X')
def lab(x):
    w=p.ICC_D50;f=lambda v:v**(1/3) if v>216/24389 else (24389/27*v+16)/116
    fx,fy,fz=(f(a/b) for a,b in zip(x,w));return [116*fy-16,500*(fx-fy),200*(fy-fz)]
for i,(row,rgb) in enumerate(zip(t['rows'],t['rgb'])):
    m=[round(v,6) for v in lab([float(v) for v in row[k:k+3]])];q=[round(m[0]+0.3,6),round(m[1]-0.2*(i+1),6),round(m[2]+0.1,6)]
    print('[%f] %s @ %s: %s -> %s should be %s'%(p.delta_e00(q,m),t['ids'][i],t['locations'][i],' '.join('%.8f'%(v/100) for v in rgb),' '.join('%f'%v for v in q),' '.join('%f'%v for v in m)))
"""

class JobTests(unittest.TestCase):
    def prepare(self,root,mode='ok'):
        root=Path(root);exe=root/'fake-colprof'
        exe.write_text(f'#!{sys.executable}\nimport sys,time\nfrom pathlib import Path\nif "-?" in sys.argv: print("Fake colprof test 1.0");sys.exit(1)\n'+
                       ('time.sleep(30)\n' if mode=='slow' else '')+
                       ('sys.exit(7)\n' if mode=='fail' else '')+
                       f'Path(sys.argv[-1]+".icc").write_bytes({profile()!r})\n')
        exe.chmod(0o755)
        recipe={'colorimetry':{'mode':'spectral','fwaCompensation':False,'illuminant':'D50','observer':'1931_2'},'engine':{'quality':'medium','algorithm':'Lab cLUT','plannedArguments':['-qm','-al','-i','D50','-o','1931_2','-D','Test']},'description':'Test','printing':{'paperSurface':'Glossy'}}
        (root/'recipe.json').write_text(json.dumps(recipe));(root/'engine.ti3').write_text('synthetic test')
        request={'executable':str(exe),'timeoutSeconds':60,'inputPreparation':'test','files':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in ['recipe.json','engine.ti3']}}
        (root/'request.json').write_text(json.dumps(request));return root
    def execute(self,root):
        subprocess.run([sys.executable,str(WORKER),str(root)],check=True,timeout=20)
        return json.loads((root/'status.json').read_text())
    def test_missing_intent_tables_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d);recipe=json.loads((p/'recipe.json').read_text())
            recipe['engine']['gamutMapping']={'method':'generic-compression','compressionPercent':20}
            recipe['engine']['plannedArguments'][-2:-2]=['-s','20']
            (p/'recipe.json').write_text(json.dumps(recipe))
            req=json.loads((p/'request.json').read_text())
            req['files']={n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in req['files']}
            (p/'request.json').write_text(json.dumps(req));result=self.execute(p)
            self.assertEqual(result['status'],'failed')
            self.assertIn('media white',result['error'])
            self.assertFalse((p/'result').exists())

    def test_success(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare(d);r=self.execute(p);self.assertEqual(r['status'],'succeeded');self.assertTrue((p/r['profileFile']).exists())
    def test_fwa_worker_arguments_and_rejection(self):
        from test_fwa import TI3, COND
        for condition in ('M0','M2'):
            with tempfile.TemporaryDirectory() as d:
                p=self.prepare(d);recipe=json.loads((p/'recipe.json').read_text())
                recipe['colorimetry'].update(fwaCompensation=True,fwaIlluminant='D50')
                recipe['measurementCondition']=COND|dict(interpreted=condition)
                recipe['engine']['plannedArguments'][6:6]=['-f','D50']
                (p/'recipe.json').write_text(json.dumps(recipe));(p/'engine.ti3').write_text(TI3)
                req=json.loads((p/'request.json').read_text())
                req['files']={n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in req['files']}
                (p/'request.json').write_text(json.dumps(req));result=self.execute(p)
                self.assertEqual(result['status'],'succeeded' if condition=='M0' else 'failed')
                if condition=='M0':self.assertIn('-f',result['arguments'])

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

    def test_matte_shadow_arguments(self):
        for value in (1.3, 4):
            with tempfile.TemporaryDirectory() as d:
                p=self.prepare(d); recipe=json.loads((p/'recipe.json').read_text())
                recipe['printing']['paperSurface']='Matte'
                recipe['engine']['shadow']={'enabled':True,'gridEmphasis':value}
                recipe['engine']['plannedArguments'] += ['-Z','m','-V',format(value,'.17g')]
                (p/'recipe.json').write_text(json.dumps(recipe))
                req=json.loads((p/'request.json').read_text())
                req['files']['recipe.json']=hashlib.sha256((p/'recipe.json').read_bytes()).hexdigest()
                (p/'request.json').write_text(json.dumps(req)); r=self.execute(p)
                self.assertEqual(r['status'],'succeeded' if value==1.3 else 'failed')
                if value==1.3:self.assertIn('-V',r['arguments'])

    def prepare_pre(self,root,avgdev=1.0,tamper=False,fwa=False,profcheck=True):
        p=self.prepare(root)
        (p/'engine.ti3').write_text(PRE_TI3)
        if profcheck:
            fake=p/'profcheck';fake.write_text(FAKE_PROFCHECK.format(python=sys.executable,profiles=str(ROOT/'profiles')));fake.chmod(0o755)
        recipe=json.loads((p/'recipe.json').read_text())
        recipe['engine']['plannedArguments']=['-qm','-al','-D','Test']
        pre=['-qm','-al','-i','D50','-o','1931_2','-r',format(avgdev,'.17g'),'-bl','-nc','-D','InkProf pre-regularization model']
        if tamper: pre[7]='9'
        recipe['engine']['preRegularization']={'enabled':True,'method':'argyll-colprof-a2b-resample','avgdev':avgdev,'plannedArguments':pre}
        if fwa: recipe['colorimetry'].update(fwaCompensation=True,fwaIlluminant='D50')
        (p/'recipe.json').write_text(json.dumps(recipe))
        req=json.loads((p/'request.json').read_text())
        req['files']={n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in req['files']}
        (p/'request.json').write_text(json.dumps(req));return p

    @unittest.skipUnless(Path('/usr/local/bin/spec2cie').exists(),'Argyll spec2cie unavailable')
    def test_fwa_preparation_once_before_both_passes(self):
        from test_fwa_preparation import ti3, COND, COLOR
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare_pre(d)
            (p/'engine.ti3').write_text(ti3());raw=(p/'engine.ti3').read_bytes()
            (p/'spec2cie').symlink_to('/usr/local/bin/spec2cie')
            recipe=json.loads((p/'recipe.json').read_text());recipe['colorimetry']=COLOR|dict(illuminant='D50',observer='1931_2');recipe['measurementCondition']=COND
            recipe['engine']['preRegularization']['plannedArguments']=['-qm','-al','-r','1','-bl','-nc','-D','InkProf pre-regularization model']
            (p/'recipe.json').write_text(json.dumps(recipe));request=json.loads((p/'request.json').read_text());request['files']={f:hashlib.sha256((p/f).read_bytes()).hexdigest() for f in request['files']};(p/'request.json').write_text(json.dumps(request))
            result=self.execute(p);self.assertEqual(result['status'],'succeeded',result.get('error'))
            self.assertEqual((p/'engine.ti3').read_bytes(),raw)
            self.assertEqual(result['fwaPreparation']['white']['count'],2)
            self.assertNotIn('-f',result['arguments']);self.assertNotIn('-f',result['preRegularization']['arguments']);self.assertNotIn('-f',result['preRegularization']['profcheckArguments'])
            self.assertEqual(result['preRegularization']['rawTI3SHA256'],hashlib.sha256(raw).hexdigest())
            self.assertEqual(result['preRegularization']['referenceTI3SHA256'],result['compensatedTI3SHA256'])

    def test_preregularization_builds_from_derived_model_values(self):
        sys.path.insert(0,str(ROOT/'profiles'));import preregularize
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare_pre(d);raw=(p/'engine.ti3').read_bytes();r=self.execute(p)
            self.assertEqual(r['status'],'succeeded',r.get('error'))
            self.assertEqual(r['arguments'],['-v','-qm','-al','-D','Test','derived'])
            self.assertEqual(r['preRegularization']['arguments'][-1],'pre')
            self.assertEqual((p/'engine.ti3').read_bytes(),raw)
            self.assertEqual(r['engineTI3SHA256'],hashlib.sha256(raw).hexdigest())
            derived=(p/'preregularization/derived.ti3').read_text()
            self.assertEqual(r['buildTI3SHA256'],hashlib.sha256(derived.encode()).hexdigest())
            self.assertNotIn('SPEC_',derived);self.assertNotIn('SPECTRAL_',derived)
            self.assertIn('INKPROF_DERIVED_DATA',derived);self.assertIn('COLOR_REP "RGB_XYZ"',derived)
            a=preregularize.read_ti3(PRE_TI3);b=preregularize.read_ti3(derived)
            self.assertEqual((a['ids'],a['locations'],a['rgb']),(b['ids'],b['locations'],b['rgb']))
            result=json.loads((p/'preregularization/patch-comparison.json').read_text())
            self.assertEqual(result['summary']['count'],4)
            for patch in result['patches']:
                k=b['fields'].index('XYZ_X');row=b['rows'][patch['sourceIndex']-1]
                xyz=[float(v) for v in row[k:k+3]]
                for x,y in zip(xyz,preregularize.lab_to_xyz(patch['modelLab'])):self.assertAlmostEqual(x,y,places=9)
                self.assertGreater(patch['deltaE00'],0)

    def test_preregularization_rejections(self):
        for case in ('tamper','fwa','profcheck','avgdev'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as d:
                p=self.prepare_pre(d,avgdev=0 if case=='avgdev' else 1.0,tamper=case=='tamper',fwa=case=='fwa',profcheck=case!='profcheck')
                r=self.execute(p);self.assertEqual(r['status'],'failed')
                self.assertFalse((p/'result').exists());self.assertFalse((p/'preregularization').exists())

    def prepare_conditioning(self,root,mode='spectral',spec2cie=True,**extra):
        """Legacy recipe with the removed InkProf grid regularization."""
        p=self.prepare(root)
        rows=['"%d" "%dA" %s %s %s %s'%(i+1,i+1,*['%.6g'%v for v in rgb],' '.join('%.10g'%v for v in xyz)) for i,(rgb,xyz) in enumerate(GRID_PATCHES)]
        ti3=PRE_TI3.split('BEGIN_DATA_FORMAT')[0].replace('NUMBER_OF_FIELDS 10','NUMBER_OF_FIELDS 8')
        ti3+='\n'.join(['BEGIN_DATA_FORMAT','SAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z','END_DATA_FORMAT',f'NUMBER_OF_SETS {len(rows)}','BEGIN_DATA',*rows,'END_DATA'])+'\n'
        (p/'engine.ti3').write_text(ti3)
        if spec2cie:
            fake=p/'spec2cie';fake.write_text(f'#!{sys.executable}\nimport sys,shutil\nif "-?" in sys.argv: sys.exit(1)\nshutil.copyfile(sys.argv[-2],sys.argv[-1])\n');fake.chmod(0o755)
        recipe=json.loads((p/'recipe.json').read_text())
        if mode=='storedXYZ':recipe['colorimetry']={'mode':'storedXYZ','fwaCompensation':False}
        recipe['engine']['plannedArguments']=['-qm','-al','-D','Test']
        recipe['engine']['preRegularization']={'enabled':True,'method':'inkprof-grid-regularization','operator':'axial','operatorVersion':1,
            'grid':5,'lambdaSelection':'grouped-cross-validation','folds':3,'seed':1,'lambdaCandidates':[1e-6,1e-4,1e-2],
            'plannedArguments':['-n','-i','D50','-o','1931_2'] if mode=='spectral' else []}|extra
        (p/'recipe.json').write_text(json.dumps(recipe))
        req=json.loads((p/'request.json').read_text())
        req['files']={n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in req['files']}
        (p/'request.json').write_text(json.dumps(req));return p

    def test_removed_inkprof_grid_regularization_is_rejected(self):
        # The InkProf grid regularization (axial/Hessian) has been removed; legacy recipes must fail cleanly.
        with tempfile.TemporaryDirectory() as d:
            p=self.prepare_conditioning(d)
            r=self.execute(p);self.assertEqual(r['status'],'failed');self.assertIn('has been removed',r.get('error',''))
            self.assertFalse((p/'preregularization').exists());self.assertFalse((p/'result').exists())

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
