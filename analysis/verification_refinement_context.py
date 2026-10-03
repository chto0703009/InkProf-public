# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Verified C3 identities and absolute ICC derivatives for MATLAB Base refinement."""
import argparse,json,hashlib
from pathlib import Path
import numpy as np
import colour
from verification_check import validate
from verification_feedback import analyse
from refinement import local_sensitivity
from profile_grid import lookup


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run(source,exe,output,step):
    source=Path(source).resolve();report=json.loads(source.read_text());analyse(report)
    files=[(Path(s['path']),s['sha256']) for s in report['sources']]
    for p,h in files:
        if sha(p)!=h:raise ValueError('C3 source hash mismatch: '+str(p))
    refs=[];measurements=[]
    for p,_ in files:
        if p.suffix=='.json':
            r=json.loads(p.read_text())
            if r.get('documentType')=='inkprof.verification-target':refs.append((p,r))
            if 'data' in r and 'complete' in r:measurements.append((p,r))
    if len(refs)!=1 or len(measurements)!=1:raise ValueError('Ambiguous C3 source identities')
    rf,ref=refs[0];mf,m=measurements[0];validate(ref,m)
    profile=(rf.parent/ref['printerProfile']['file']).resolve()
    if sha(profile)!=ref['printerProfile']['sha256']:raise ValueError('Profile changed')
    byid={str(p['id']):p for p in ref['patches']};groups={}
    if set(byid)!={str(p['sampleId']) for p in report['patches']}:raise ValueError('C3 patch set differs')
    for p in report['patches']:
        r=byid[str(p['sampleId'])]
        if p['coordinate']!=r['placement']['coordinate'] or p['page']!=r['placement']['page'] or p['role']!=r['role']:raise ValueError('C3 layout/role mismatch')
        if not np.allclose(p['desiredLab'],r['referenceLabD50Absolute'],atol=1e-6):raise ValueError('Reference changed')
        key=tuple(r['deviceRGB16']);groups.setdefault(key,[]).append(p)
    rgb=np.array(list(groups),float)*100/65535
    forward=lambda x:lookup(exe,profile,x/100,intent='a')
    pred=forward(rgb);full=local_sensitivity(forward,rgb,step);half=local_sensitivity(forward,rgb,step/2)
    obs=[]
    for (key,ps),x,model in zip(groups.items(),rgb,pred):
        if max(float(colour.delta_E(model,p['predictedLab'])) for p in ps)>.02:raise ValueError('C3 model prediction differs from ICC')
        labs=np.array([p['measuredLab'] for p in ps]);mean=labs.mean(axis=0)
        spread=max(float(colour.delta_E(a,b)) for a in labs for b in labs)
        j=np.array(half[key]['jacobian']);j0=np.array(full[key]['jacobian'])
        obs.append(dict(rgbPercent=x.tolist(),sampleIds=[str(p['sampleId']) for p in ps],
            coordinates=[p['coordinate'] for p in ps],gray=any(p['role']=='gray' for p in ps),
            residualLab=(mean-model).tolist(),deltaE00=float(colour.delta_E(mean,model)),
            repeatMaxDeltaE00=spread,repeatCount=len(ps),jacobian=j.tolist(),
            jacobianStepRelativeChange=float(np.linalg.norm(j-j0)/max(np.linalg.norm(j),1e-12))))
    for p,h in files:
        if sha(p)!=h:raise ValueError('Source changed during calculation')
    result=dict(observations=obs,referenceFile=str(rf),measurementFile=str(mf),profileFile=str(profile),
        profileJob=ref['profileJob'],trainingTI3SHA256=ref['trainingTI3SHA256'],
        sourceReport=dict(path=str(source),sha256=sha(source)),sources=report['sources'],
        derivativeStepPercent=step/2,units='Lab per RGB percentage point; absolute D50/2',
        printChainVerified=report.get('printChainVerified',False))
    Path(output).write_text(json.dumps(result,indent=2,allow_nan=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('executable');p.add_argument('output');p.add_argument('--step',type=float,default=.5)
    a=p.parse_args()
    if not 0<a.step<=10:raise ValueError('Invalid finite difference step')
    run(a.source,a.executable,a.output,a.step)
