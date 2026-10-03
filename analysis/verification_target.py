# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""C2 absolute D50 Lab verification definitions; profile applied once to device RGB."""
import argparse,json,shutil
from pathlib import Path
import numpy as np
import colour
from profile_grid import lookup,sha
from profile_c1 import require_profile
from lcms_float import LittleCMS


def select_indices(rgb,training,count,min_distance,used=None):
    if count==0:return []
    chosen=[];used=[] if used is None else list(used)
    for i,v in enumerate(rgb):
        if np.min(np.max(abs(training-v),axis=1))<min_distance: continue
        if used and np.min(np.max(abs(np.asarray(used)-v),axis=1))<1/65535: continue
        chosen.append(i);used.append(v)
        if len(chosen)==count: return chosen
    if count==0:return []
    raise ValueError('Not enough distinct verification colours separated from training data.')


def generate(job,exe,request,out):
    out=Path(out);job=Path(job);profile=job/'result/profile.icc'
    if out.exists(): raise ValueError('Output already exists.')
    status=json.loads((job/'status.json').read_text());recipe=json.loads((job/'recipe.json').read_text())
    if status['status']!='succeeded' or sha(profile)!=status['profileSHA256']: raise ValueError('Profile integrity failure.')
    if sha(job/'recipe.json')!=status['recipeSHA256']:
        raise ValueError('Profile recipe integrity failure.')
    require_profile(profile.read_bytes())
    counts=[request[k] for k in ('colourPatches','grayPatches','challengePatches','repeats')]
    if any(type(x)!=int or x<0 for x in counts) or not 8<=sum(counts)<=2000 or counts[0]<1 or counts[1]<2 or counts[3]>sum(counts[:3]):
        raise ValueError('Invalid patch counts; require colours, at least two grays, and repeats <= unique patches.')
    train=np.asarray(request['trainingRGB'],float)
    if train.ndim!=2 or train.shape[1]!=3 or not np.isfinite(train).all() or np.any((train<0)|(train>1)):raise ValueError('Invalid training RGB.')
    separation=float(request['minTrainingRGBDistance'])
    if not 0<separation<.1:raise ValueError('Invalid training separation.')
    seed=request['seed']
    if not isinstance(seed,(int,float)) or not np.isfinite(seed) or seed!=int(seed) or not 0<=seed<=2147483647:raise ValueError('Invalid seed.')
    rng=np.random.default_rng(int(seed));n=max(4096,sum(counts)*20)
    # PCS coordinates are chosen without using measured training Lab or model predictions.
    candidates=np.column_stack((rng.uniform(18,90,n),rng.uniform(-75,75,n),rng.uniform(-75,75,n)))
    gray=np.column_stack((np.linspace(18,90,max(300,counts[1]*10)),np.zeros((max(300,counts[1]*10),2))))
    # Shuffle the denser gray pool so training exclusions do not bias toward dark patches.
    gray=gray[rng.permutation(len(gray))]
    all_lab=np.concatenate((candidates,gray))
    raw=lookup(exe,profile,all_lab,'b',intent='a')
    if np.any((raw<0)|(raw>1)):raise ValueError('Inverse returned out-of-range device RGB.')
    rgb=np.rint(raw*65535)/65535
    numerical=lookup(exe,profile,all_lab,'if',intent='a')
    numeric_lab=lookup(exe,profile,numerical,intent='a')
    reach=colour.delta_E(all_lab,numeric_lab,method='CIE 2000')
    masks=[np.where(reach[:n]<=.5)[0],np.arange(n,len(all_lab)),np.where(reach[:n]>3)[0]]
    records=[];used=[]
    for role,mask,count in zip(('colour','gray','challenge'),masks,counts[:3]):
        ids=select_indices(rgb[mask],train,count,separation,used)
        for local in ids:
            i=int(mask[local]);used.append(rgb[i]);records.append(dict(sourceIndex=i,role=role,repeatOf=None))
    for i in rng.choice(len(records),size=counts[3],replace=False):
        records.append(dict(sourceIndex=records[i]['sourceIndex'],role='repeat',repeatOf=int(i)+1))
    output_rgb=np.array([rgb[p['sourceIndex']] for p in records]);predicted=lookup(exe,profile,output_rgb,intent='a')
    patches=[]
    for j,rec in enumerate(records):
        i=rec['sourceIndex'];patches.append(dict(id=str(j+1),role=rec['role'],repeatOf=None if rec['repeatOf'] is None else str(rec['repeatOf']),
            referenceLabD50Absolute=all_lab[i].tolist(),deviceRGB16=np.rint(output_rgb[j]*65535).astype(int).tolist(),deviceRGB=output_rgb[j].tolist(),
            predictedLabD50Absolute=predicted[j].tolist(),numericalInverseResidualDE00=float(reach[i]),
            gamutAssessment='model-reachable' if reach[i]<=.5 else 'outside-or-inversion-unresolved',
            minTrainingRGBDistance=float(np.min(np.max(abs(train-output_rgb[j]),axis=1)))))
    if recipe['colorimetry'].get('fwaCompensation'):
        white=lookup(exe,profile,np.ones((1,3)),intent='a')[0]
        patches.append(dict(id=str(len(patches)+1),role='paperwhite',repeatOf=None,
            referenceLabD50Absolute=white.tolist(),deviceRGB16=[65535]*3,deviceRGB=[1.0]*3,
            predictedLabD50Absolute=white.tolist(),numericalInverseResidualDE00=0,
            gamutAssessment='paper-white-reference-not-independent',minTrainingRGBDistance=0))
        output_rgb=np.vstack((output_rgb,np.ones((1,3))));predicted=np.vstack((predicted,white))
    if sha(profile)!=status['profileSHA256']:raise ValueError('Profile changed during generation.')
    out.mkdir(parents=True);shutil.copy2(profile,out/'printer.icc');cmm=LittleCMS();cmm.save_lab_profile(out/'source-Lab-D50.icc')
    xyz=100*colour.Lab_to_XYZ(predicted,illuminant=colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50'])
    lines=['CTI1','DESCRIPTOR "InkProf C2 verification; profile already applied"','ORIGINATOR "InkProf"','COLOR_REP "iRGB"','NUMBER_OF_FIELDS 7','BEGIN_DATA_FORMAT','SAMPLE_ID RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z','END_DATA_FORMAT',f'NUMBER_OF_SETS {len(patches)}','BEGIN_DATA']
    for j,(v,x) in enumerate(zip(output_rgb,xyz)):lines.append(str(j+1)+' '+' '.join(f'{z:.17g}' for z in np.r_[v*100,x]))
    lines.append('END_DATA');(out/'verification.ti1').write_text('\n'.join(lines)+'\n')
    record=dict(schemaVersion=1,documentType='inkprof.verification-target',name=request['name'],status='definition-created-not-printed',
        sourceColourSpace='ICC Lab D50 absolute; direct PCS coordinates',sourceProfile=dict(file='source-Lab-D50.icc',sha256=sha(out/'source-Lab-D50.icc'),role='reference encoding; xicclu receives Lab directly'),
        printerProfile=dict(file='printer.icc',sha256=sha(profile)),intent='absolute colorimetric',bpc=False,profileApplications=1,
        pipeline='Desired absolute D50 Lab -> xicclu -fb -ia -pl -> device RGB -> 16-bit quantization -> layout only -> print with ALL further colour conversion OFF',
        trainingTI3SHA256=sha(job/'engine.ti3'),generation={k:v for k,v in request.items() if k!='trainingRGB'},printing=recipe['printing'],
        measurementCondition=recipe.get('measurementCondition'),illuminant='D50',observer='1931_2',
        fwaCompensation=recipe['colorimetry'].get('fwaCompensation',False),fwaIlluminant=recipe['colorimetry'].get('fwaIlluminant'),
        criteria=dict(status='awaiting user acceptance before ranking profiles',deltaE00Limit=None,grayBalanceLimit=None),
        classification='Model reachability diagnostic only: numerical inverse residual <=0.5 dE00. Failure does not prove outside gamut. Challenge residual >3. Not a print acceptance threshold.',
        independence='New device RGB separated from training; model-informed gamut screening is disclosed. Independent measured validation remains to be performed. Any paperwhite patch is a model reference, excluded from independent scores.',
        referencePolicy='Compare measured absolute D50 Lab against referenceLabD50Absolute; predictedLabD50Absolute is diagnostic only. Stratify gamutAssessment and role; do not score padding or contrast bars.',
        definitions=dict(file='verification.ti1',sha256=sha(out/'verification.ti1')),patches=patches)
    (out/'verification.json').write_text(json.dumps(record,indent=2,allow_nan=False));return record

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('job');p.add_argument('executable');p.add_argument('request');p.add_argument('output');a=p.parse_args();generate(a.job,a.executable,json.loads(Path(a.request).read_text()),a.output)
