# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Reproduce the inverse diagnostic from an existing InkProf grid report.
Usage: python analysis/investigate_inverse.py JOB GRID_REPORT OUTPUT [--xicclu PATH]
No profile or measurement is modified.
"""
import json,argparse,shutil
from pathlib import Path
import numpy as np

from profile_grid import lookup,summary,sha
import colour
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('job',type=Path);parser.add_argument('grid_report',type=Path);parser.add_argument('output',type=Path);parser.add_argument('--xicclu',default=shutil.which('xicclu'))
a=parser.parse_args()
if not a.xicclu: parser.error('xicclu was not found; supply --xicclu.')
if a.output.exists(): parser.error('Output already exists; choose a new filename.')
job=a.job;source=a.grid_report
r=json.loads(source.read_text());g=r['grid'];rgb=np.array(g['rgb']);lab=np.array(g['lab']);b=np.array(g['inverseRGB']);exe=a.xicclu;profile=job/'result/profile.icc'
status=json.loads((job/'status.json').read_text())
if sha(profile)!=status['profileSHA256'] or sha(profile)!=r['profileSHA256']: raise ValueError('Profile hash mismatch.')
x=lookup(exe,profile,lab,'if');flab=lookup(exe,profile,x)
de=colour.delta_E(lab,flab,method='CIE 2000');e=np.max(abs(rgb-b),axis=1);xe=np.max(abs(rgb-x),axis=1)
# Finite differences of the forward map, with one-sided differences at cube edges.
def jacobian(points,h):
 pairs=[]
 for p in points:
  for k in range(3):
   lo=p.copy();hi=p.copy();lo[k]=max(0,p[k]-h);hi[k]=min(1,p[k]+h);pairs.extend([lo,hi])
 vals=lookup(exe,profile,pairs).reshape(len(points),3,2,3);pairs=np.array(pairs).reshape(len(points),3,2,3)
 result=[]
 for i in range(len(points)):
  j=np.column_stack([(vals[i,k,1]-vals[i,k,0])/(pairs[i,k,1,k]-pairs[i,k,0,k]) for k in range(3)])
  u,s,v=np.linalg.svd(j);result.append(dict(matrix=j.tolist(),singularValues=s.tolist(),condition=float(s[0]/max(s[-1],1e-12)),weakDirection=v[-1].tolist(),determinant=float(np.linalg.det(j))))
 return result
indices=np.unique(np.r_[np.argsort(e)[-10:],np.argsort(g['deltaE00'])[-5:]])
points=np.concatenate([rgb[indices],b[indices],x[indices]])
jacs={str(h):jacobian(points,h) for h in [.001,.005,.01]}
worst=int(np.argmax(e));t=np.linspace(0,1,101);line=rgb[worst]+t[:,None]*(b[worst]-rgb[worst]);lineLab=lookup(exe,profile,line);lineDE=colour.delta_E(np.tile(lab[worst],(101,1)),lineLab,method='CIE 2000')
rows=[]
for j,i in enumerate(indices):
 rows.append(dict(index=int(i),originalRGB=rgb[i].tolist(),b2aRGB=b[i].tolist(),numericRGB=x[i].tolist(),lab=lab[i].tolist(),b2aDeltaE00=g['deltaE00'][i],numericDeltaE00=float(de[i]),b2aRGBErrorPercent=float(e[i]*100),numericRGBErrorPercent=float(xe[i]*100),jacobians={h:{'original':v[j],'b2a':v[len(indices)+j],'numeric':v[2*len(indices)+j]} for h,v in jacs.items()}))
bound=np.any((rgb==0)|(rgb==1),axis=1)
result=dict(profileSHA256=sha(profile),sourceCheck=str(source),intent='relative colorimetric',numericMethod='xicclu -fif: numerical inversion of A2B',gridCount=len(rgb),b2aDeltaE00=summary(g['deltaE00']),numericDeltaE00=summary(de),b2aRGBErrorPercent=summary(e*100),numericRGBErrorPercent=summary(xe*100),groups={name:dict(count=int(mask.sum()),b2aDE=summary(np.array(g['deltaE00'])[mask]),numericDE=summary(de[mask]),rgbError=summary(e[mask]*100)) for name,mask in [('boundary',bound),('interior',~bound)]},cases=rows,lineBetweenWorstEndpoints=dict(rgb=line.tolist(),lab=lineLab.tolist(),deltaE00=lineDE.tolist(),maxDeltaE00=float(lineDE.max())),numericInverseRGB=x.tolist(),numericInverseLab=flab.tolist(),numericDeltaE00PerPoint=de.tolist())
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(result,indent=2,allow_nan=False));print(json.dumps({k:v for k,v in result.items() if k not in ['cases','lineBetweenWorstEndpoints','numericInverseRGB','numericInverseLab','numericDeltaE00PerPoint']},indent=2));print('worst path max dE',lineDE.max());print('worst original singular values',jacs['0.005'][list(indices).index(worst)]['singularValues'])
