"""ICC numerical diagnostics on a synthetic grid; no independent measurements."""
import argparse,hashlib,json,subprocess
from pathlib import Path
import numpy as np
import colour
from PIL import Image,ImageCms

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def summary(v):
 v=np.asarray(v);return dict(mean=float(v.mean()),p95=float(np.percentile(v,95)),max=float(v.max()))
def lookup(exe,profile,values,direction='f',intent='r'):
 values=np.asarray(values,dtype=float)
 if values.ndim!=2 or values.shape[1]!=3 or not np.isfinite(values).all():raise ValueError('Invalid lookup input.')
 if intent not in ('r','a'):raise ValueError('Supported intents: relative or absolute colorimetric.')
 args=[str(exe),'-v0','-f'+direction,'-i'+intent,'-pl',str(profile)]
 r=subprocess.run(args,input=''.join(' '.join(f'{x:.10f}' for x in row)+'\n' for row in values),text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=120)
 if r.returncode:raise ValueError(r.stderr or r.stdout)
 rows=[line.split() for line in r.stdout.splitlines() if line.strip()]
 out=np.asarray(rows,dtype=float)
 if out.shape!=values.shape or not np.isfinite(out).all():raise ValueError('Invalid/nonfinite xicclu output.')
 return out

def decode_lab8(pixels):
 pixels=np.asarray(pixels).astype(float)
 ab=pixels[:,1:];ab=np.where(ab>=128,ab-256,ab)
 return np.column_stack((pixels[:,0]*100/255,ab))
def encode_lab8(lab):
 lab=np.asarray(lab)
 return np.column_stack((np.clip(lab[:,0]*255/100,0,255).round(),np.mod(np.clip(lab[:,1:],-128,127).round(),256))).astype('uint8')

def run(job,exe,out,n=9):
 if not 3<=n<=25:raise ValueError('GridLevels must be 3..25.')
 job=Path(job);out=Path(out);out.mkdir(exist_ok=False)
 status=json.loads((job/'status.json').read_text());profile=job/'result/profile.icc'
 if status['status']!='succeeded' or sha(profile)!=status['profileSHA256']:raise ValueError('Invalid or changed profile job.')
 grid=np.array(np.meshgrid(*[np.linspace(0,1,n)]*3,indexing='ij')).reshape(3,-1).T
 lab=lookup(exe,profile,grid);back=lookup(exe,profile,lab,'b');roundlab=lookup(exe,profile,back)
 de=colour.delta_E(lab,roundlab,method='CIE 2000');rgb_err=np.max(np.abs(grid-back),axis=1)
 outside=np.any((back < -1e-6)|(back > 1+1e-6),axis=1)
 edge=[];cube=lab.reshape(n,n,n,3)
 for axis in range(3):edge.extend(np.linalg.norm(np.diff(cube,axis=axis),axis=-1).ravel())
 ramps=[]
 for axis in range(3):
  for a in (0,.5,1):
   for b in (0,.5,1):
    v=np.empty((257,3));v[:,axis]=np.linspace(0,1,257);other=[k for k in range(3) if k!=axis];v[:,other[0]]=a;v[:,other[1]]=b
    ramps.append(v)
 ramp_rgb=np.concatenate(ramps);ramp_lab=lookup(exe,profile,ramp_rgb).reshape(27,257,3)
 second=np.linalg.norm(np.diff(ramp_lab,n=2,axis=1),axis=2)
 gray_rgb=np.repeat(np.linspace(0,1,257)[:,None],3,axis=1);gray_lab=lookup(exe,profile,gray_rgb)
 neutral=np.column_stack((np.linspace(float(gray_lab[0,0]),100,257),np.zeros((257,2))))
 neutral_rgb=lookup(exe,profile,neutral,'b');neutral_lab=lookup(exe,profile,neutral_rgb)
 # Compare both CMMs at identical quantized inputs; Pillow RGB/LAB are 8 bit.
 rgb8=np.round(grid*255).astype('uint8');rgbq=rgb8/255
 lab_profile=ImageCms.createProfile('LAB',5000);icc=ImageCms.getOpenProfile(str(profile))
 f=ImageCms.buildTransform(icc,lab_profile,'RGB','LAB',renderingIntent=1,flags=0)
 pixels=np.asarray(ImageCms.applyTransform(Image.fromarray(rgb8.reshape(1,-1,3),'RGB'),f)).reshape(-1,3).astype(float)
 lcms_lab=decode_lab8(pixels)
 cmm_de=colour.delta_E(lookup(exe,profile,rgbq),lcms_lab,method='CIE 2000')
 lab8=encode_lab8(lab)
 labq=decode_lab8(lab8)
 inv=ImageCms.buildTransform(lab_profile,icc,'LAB','RGB',renderingIntent=1,flags=0)
 lcms_rgb=np.asarray(ImageCms.applyTransform(Image.fromarray(lab8.reshape(1,-1,3),'LAB'),inv)).reshape(-1,3)/255
 cmm_rgb=np.max(np.abs(lookup(exe,profile,labq,'b')-lcms_rgb),axis=1)*100
 version=subprocess.run([str(exe),'-?'],capture_output=True,text=True,timeout=15)
 if sha(profile)!=status['profileSHA256']:raise ValueError('Profile changed during check.')
 result=dict(schemaVersion=1,documentType='inkprof.profile-grid-check',purpose='Synthetic profile consistency, not measured validation',profileSHA256=sha(profile),
  settings=dict(gridLevels=n,gridCount=len(grid),intent='relative colorimetric',inverse='Stored B2A table, not numerical inversion of A2B',rampCount=27,rampSamples=257,bpc=False),
  tools=dict(xiccluVersion=(version.stdout+version.stderr).splitlines()[0],littleCMS=ImageCms.core.littlecms_version,colour=colour.__version__),
  roundtripDeltaE00=summary(de),roundtripRGBErrorPercent=summary(rgb_err*100),outOfBoundsCount=int(outside.sum()),
  gridNeighbourDeltaLab76=summary(edge),rampSecondDifferenceLab76=summary(second),rampRoughnessCandidates=int((second>1).sum()),
  gray=dict(lightnessReversals=int((np.diff(gray_lab[:,0]) < -1e-3).sum()),maxChroma=float(np.hypot(gray_lab[:,1],gray_lab[:,2]).max()),rgb=gray_rgb.tolist(),lab=gray_lab.tolist()),
  neutral=dict(deltaE00=summary(colour.delta_E(neutral,neutral_lab,method='CIE 2000')),outOfBoundsCount=int(np.any((neutral_rgb< -1e-6)|(neutral_rgb>1+1e-6),axis=1).sum()),targetLab=neutral.tolist(),rgb=neutral_rgb.tolist(),predictedLab=neutral_lab.tolist()),
  cmmComparison=dict(forwardDeltaE00=summary(cmm_de),backwardRGBErrorPercent=summary(cmm_rgb),limitation='Pillow RGB/LAB 8-bit quantization and possible Lab clipping; diagnostic only, not float precision equivalence'),
  grid=dict(rgb=grid.tolist(),lab=lab.tolist(),inverseRGB=back.tolist(),roundtripLab=roundlab.tolist(),deltaE00=de.tolist()),
  caveats=['Roundtrip need not recover original RGB: nonunique mapping and inverse approximation may contribute. These PCS targets come from A2B, so each has a known RGB preimage; residual is not proof of an out-of-gamut target.','Adjacent colour distance is a gradient, not proof of discontinuity.','Second difference > 1 Lab unit at step 1/256 is a diagnostic candidate, not automatic rejection.','Finite samples cannot prove smoothness everywhere.','Neutral PCS points are not guaranteed in gamut.','RGB-gray chroma measures profile prediction, not independently measured gray neutrality.'])
 (out/'grid-check.json').write_text(json.dumps(result,indent=2,allow_nan=False))
 lines=['# ICC – nät, invers och övergångar','','Syntetisk konsistenskontroll; inte oberoende mätvalidering.','',f'Grid: {n}³ = {len(grid)} RGB-punkter, relativ kolorimetri, BPC av.', '',f'Roundtrip ΔE00: {result["roundtripDeltaE00"]}',f'RGB-fel i procentenheter: {result["roundtripRGBErrorPercent"]}',f'RGB utanför kuben: {result["outOfBoundsCount"]}',f'Gråramp: {result["gray"]["lightnessReversals"]} minskningar i L*, max C*ab {result["gray"]["maxChroma"]:.4f}',f'Övergångskandidater: {result["rampRoughnessCandidates"]}',f'LittleCMS framåt: {result["cmmComparison"]["forwardDeltaE00"]}',f'LittleCMS bakåt, RGB-procentenheter: {result["cmmComparison"]["backwardRGBErrorPercent"]}','','## Begränsningar','',*['- '+x for x in result['caveats']],'- '+result['cmmComparison']['limitation']]
 (out/'grid-check.md').write_text('\n'.join(lines)+'\n');return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('job');p.add_argument('executable');p.add_argument('output');p.add_argument('--levels',type=int,default=9);a=p.parse_args();run(a.job,a.executable,a.output,a.levels)
