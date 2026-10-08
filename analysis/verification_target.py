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
import reference_sets


def select_indices(rgb,training,count,min_distance,used=None):
    if count==0:return []
    chosen=[];used=[] if used is None else list(used)
    for i,v in enumerate(rgb):
        if training.size and np.min(np.max(abs(training-v),axis=1))<min_distance: continue
        if used and np.min(np.max(abs(np.asarray(used)-v),axis=1))<1/65535: continue
        chosen.append(i);used.append(v)
        if len(chosen)==count: return chosen
    if count==0:return []
    raise ValueError('Not enough distinct verification colours separated from training data.')


def balanced_indices(lab,rgb,count,used=None,gray=False):
    """Deterministic marginal coverage, then farthest Lab; exclude RGB16 duplicates."""
    available=np.ones(len(lab),bool)
    for v in ([] if used is None else used):
        available &= np.max(abs(rgb-v),axis=1)>=1/65535
    light=np.digitize(lab[:,0],[25,50,75])
    hue=(np.mod(np.arctan2(lab[:,2],lab[:,1]),2*np.pi)/(np.pi/6)).astype(int)
    chroma=np.digitize(np.linalg.norm(lab[:,1:],axis=1),[20,45])
    bins=[light,hue,chroma];loads=[np.zeros(4),np.zeros(12),np.zeros(3)]
    distance=np.full(len(lab),np.inf);chosen=[]
    gray_targets=np.linspace(float(lab[:,0].min()),float(lab[:,0].max()),count) if gray and count else []
    for k in range(count):
        ids=np.flatnonzero(available)
        if not len(ids):break
        if gray:
            i=ids[np.argmin(abs(lab[ids,0]-gray_targets[k]))]
        else:
            # Lightness is primary; hue and chroma balance within that choice.
            for b,load in zip(bins,loads):
                ids=ids[load[b[ids]]==np.min(load[b[ids]])]
            i=ids[np.argmax(distance[ids])]
        chosen.append(int(i))
        for b,load in zip(bins,loads):load[b[i]]+=1
        distance=np.minimum(distance,np.linalg.norm(lab-lab[i],axis=1))
        available &= np.max(abs(rgb-rgb[i]),axis=1)>=1/65535
    return chosen


def external_selection(lab,rgb,reach,n,counts):
    """Own photographic target: reserved skin/shadow coverage plus balanced colours."""
    records=[];used=[];summary={}
    colour_ids=np.flatnonzero(reach[:n]<=.5)
    skin=(lab[:,0]>=35)&(lab[:,0]<=80)&(lab[:,1]>=5)&(lab[:,1]<=25)&(lab[:,2]>=8)&(lab[:,2]<=30)
    shadow=lab[:,0]<18
    def take(category,role,pool,count,gray=False):
        chosen=balanced_indices(lab[pool],rgb[pool],count,used,gray)
        for local in chosen:
            i=int(pool[local]);used.append(rgb[i]);records.append(dict(sourceIndex=i,role=role,repeatOf=None,selectionCategory=category))
        summary[category]={'requested':count,'selected':len(chosen)}
        return len(chosen)
    # Reserve neutrals first so clipped colour candidates cannot consume the endpoints.
    take('neutral','gray',np.arange(n,len(lab)),counts[1],True)
    if summary['neutral']['selected']!=counts[1]:raise ValueError('Not enough distinct neutral patches for this profile; reduce the count.')
    skin_count=int(np.floor(counts[0]*.15+.5));shadow_count=int(np.floor(counts[0]*.10+.5))
    selected=take('skin-tone','colour',colour_ids[skin[colour_ids]],skin_count)
    selected+=take('shadow','colour',colour_ids[shadow[colour_ids]],shadow_count)
    broad=colour_ids[~skin[colour_ids]&~shadow[colour_ids]]
    selected+=take('broad-colour','colour',broad,counts[0]-selected)
    if selected<counts[0]:selected+=take('coverage-fallback','colour',colour_ids,counts[0]-selected)
    if selected!=counts[0]:raise ValueError('Not enough distinct reachable colours for this profile; reduce the count.')
    got=take('challenge','challenge',np.flatnonzero(reach[:n]>3),counts[2])
    if got!=counts[2]:raise ValueError('Not enough distinct challenge colours for this profile; reduce the count.')
    return records,summary


def generate(job,exe,request,out):
    out=Path(out);job=Path(job);external=bool(request.get('externalProfile',False));profile=job/('profile.icc' if external else 'result/profile.icc')
    if out.exists(): raise ValueError('Output already exists.')
    if external:
        source=json.loads((job/'source.json').read_text())
        status={'profileSHA256':source['profileSHA256']}
        recipe={'printing':request['printing'],'colorimetry':{'fwaCompensation':False}}
        if sha(profile)!=status['profileSHA256']:raise ValueError('Imported profile changed.')
    else:
        status=json.loads((job/'status.json').read_text());recipe=json.loads((job/'recipe.json').read_text())
        if status['status']!='succeeded' or sha(profile)!=status['profileSHA256']: raise ValueError('Profile integrity failure.')
        if sha(job/'recipe.json')!=status['recipeSHA256']:raise ValueError('Profile recipe integrity failure.')
    require_profile(profile.read_bytes())
    reference=None
    if request.get('referenceSet'):
        reference=reference_sets.load(request['referenceSet']['file'])
        if not 1<=reference['count']<=2000:raise ValueError('Reference set must have 1..2000 patches.')
        counts=[0,0,0,request.get('repeats',0)]
        if type(counts[3])!=int or not 0<=counts[3]<=reference['count']:raise ValueError('Repeats must be 0..number of reference patches.')
    else:
        counts=[request[k] for k in ('colourPatches','grayPatches','challengePatches','repeats')]
    if reference is None and (any(type(x)!=int or x<0 for x in counts) or not 8<=sum(counts)<=2000 or counts[0]<1 or counts[1]<2 or counts[3]>sum(counts[:3])):
        raise ValueError('Invalid patch counts; require colours, at least two grays, and repeats <= unique patches.')
    train=np.asarray(request['trainingRGB'],float)
    if external and not train.size:train=np.empty((0,3))
    if train.ndim!=2 or train.shape[1]!=3 or not np.isfinite(train).all() or np.any((train<0)|(train>1)):raise ValueError('Invalid training RGB.')
    separation=float(request['minTrainingRGBDistance'])
    if not 0<separation<.1:raise ValueError('Invalid training separation.')
    seed=request['seed']
    if not isinstance(seed,(int,float)) or not np.isfinite(seed) or seed!=int(seed) or not 0<=seed<=2147483647:raise ValueError('Invalid seed.')
    rng=np.random.default_rng(int(seed))
    if reference is not None:
        return generate_reference(job,exe,request,out,profile,status,recipe,external,train,reference,counts[3],rng)
    n=max(4096,sum(counts)*20)
    # PCS coordinates are chosen without using measured training Lab or model predictions.
    candidates=np.column_stack((rng.uniform(18,90,n),rng.uniform(-75,75,n),rng.uniform(-75,75,n)))
    gray=np.column_stack((np.linspace(18,90,max(300,counts[1]*10)),np.zeros((max(300,counts[1]*10),2))))
    if external:
        # Explicit dark and photographic skin-tone candidates, plus broad colour coverage.
        reserve=max(512,n//8)
        candidates[:reserve]=np.column_stack((rng.uniform(5,18,reserve),rng.uniform(-20,20,reserve),rng.uniform(-20,20,reserve)))
        candidates[reserve:2*reserve]=np.column_stack((rng.uniform(35,80,reserve),rng.uniform(5,25,reserve),rng.uniform(8,30,reserve)))
        gray[:,0]=np.linspace(3,95,len(gray))
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
    if external:
        if train.size:raise ValueError('External verification expects unavailable training data.')
        records,selection_summary=external_selection(all_lab,rgb,reach,n,counts)
    else:
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
            minTrainingRGBDistance=float(np.min(np.max(abs(train-output_rgb[j]),axis=1))) if train.size else None))
    if external:
        for patch,rec in zip(patches,records):patch['selectionCategory']=rec.get('selectionCategory','repeat')
    return write_definition(job,exe,request,out,profile,status,recipe,external,patches,output_rgb,predicted,
                            selection_summary if external else None)


def write_definition(job,exe,request,out,profile,status,recipe,external,patches,output_rgb,predicted,selection_summary=None,reference=None):
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
        pipeline='Desired absolute D50 Lab -> xicclu -fb -ia -pl -> device RGB -> 16-bit quantization -> layout only (printer ICC embedded as TIFF tag, pixels unchanged) -> print with ALL further colour conversion OFF',
        trainingTI3SHA256=None if external else sha(job/'engine.ti3'),generation={k:v for k,v in request.items() if k!='trainingRGB'},printing=recipe['printing'],
        measurementCondition=recipe.get('measurementCondition'),illuminant='D50',observer='1931_2',
        fwaCompensation=recipe['colorimetry'].get('fwaCompensation',False),fwaIlluminant=recipe['colorimetry'].get('fwaIlluminant'),fwaPreparation=recipe['colorimetry'].get('fwaPreparation'),paperWhiteReference=recipe['colorimetry'].get('paperWhiteReference'),
        criteria=dict(status='awaiting user acceptance before ranking profiles',deltaE00Limit=None,grayBalanceLimit=None),
        classification='Model reachability diagnostic only: numerical inverse residual <=0.5 dE00. Failure does not prove outside gamut. Challenge residual >3. Not a print acceptance threshold.',
        independence='New device RGB separated from training; model-informed gamut screening is disclosed. Independent measured validation remains to be performed. Any paperwhite patch is a model reference, excluded from independent scores.',
        referencePolicy='Compare measured absolute D50 Lab against referenceLabD50Absolute; predictedLabD50Absolute is diagnostic only. Stratify gamutAssessment and role; do not score padding or contrast bars.',
        definitions=dict(file='verification.ti1',sha256=sha(out/'verification.ti1')),patches=patches)
    if external:
        record.update(externalProfile=True,trainingIndependence='unknown: original training data unavailable',
            independence='New verification print; original training data unavailable, so independence from training cannot be established. Model-informed gamut screening is disclosed.')
        if selection_summary is not None:
            record['selection']=dict(method='inkprof-balanced-photographic-v1',groups=selection_summary,reference='Own synthetic Lab selection; not a reproduction of ColorChecker SG.')
    if reference is not None:
        source=Path(request['referenceSet']['file'])
        stored='reference-set'+(source.suffix or '.txt')
        shutil.copy2(source,out/stored)
        if sha(out/stored)!=reference['sha256']:raise ValueError('Reference set changed while copying.')
        kind=reference['kind']
        record['referenceSet']=dict(name=request['referenceSet'].get('name') or source.stem,file=stored,originalFileName=reference['fileName'],
            sha256=reference['sha256'],kind=kind,basis=reference['basis'],patchCount=reference['count'],notes=reference['notes'],
            comparison=('Measured Lab vs the reference Lab: tests B2A, print and measurement together (round trip).' if kind=='lab' else
                        'Device RGB printed as-is; reference Lab = profile A2B prediction: tests the forward model (A2B) against the print.'))
        record['selection']=dict(method='reference-set-'+kind,reference=record['referenceSet']['name'],
            roles='gray: reference C*ab <= 2.5; challenge: numerical inverse residual > 3 dE00 (likely outside gamut); otherwise colour')
        if kind=='rgb':
            record['referencePolicy']=('Reference Lab is the profile A2B prediction for the given device RGB (absolute colorimetric); '
                                       'deltaE00 is the forward-model error at these RGB values. Stratify by role; do not score padding or contrast bars.')
            record['pipeline']='Given device RGB -> 16-bit quantization -> layout only (printer ICC embedded as TIFF tag, pixels unchanged) -> print with ALL further colour conversion OFF; reference = A2B(RGB)'
            record['profileApplications']=0
    (out/'verification.json').write_text(json.dumps(record,indent=2,allow_nan=False));return record


def generate_reference(job,exe,request,out,profile,status,recipe,external,train,reference,repeats,rng):
    """C2 from a fixed reference set (Lab or device RGB); IDs keep the set's patch names."""
    values=np.asarray(reference['values'],float)
    if reference['kind']=='lab':
        all_lab=values
        raw=lookup(exe,profile,all_lab,'b',intent='a')
        if np.any((raw<0)|(raw>1)):raise ValueError('Inverse returned out-of-range device RGB.')
        rgb=np.rint(raw*65535)/65535
        numerical=lookup(exe,profile,all_lab,'if',intent='a')
        reach=colour.delta_E(all_lab,lookup(exe,profile,numerical,intent='a'),method='CIE 2000')
    else:
        rgb=np.rint(values/100*65535)/65535
        all_lab=lookup(exe,profile,rgb,intent='a')
        reach=np.zeros(len(rgb))
    chroma=np.hypot(all_lab[:,1],all_lab[:,2])
    records=[]
    for i in range(len(all_lab)):
        role='challenge' if reach[i]>3 else ('gray' if chroma[i]<=2.5 else 'colour')
        records.append(dict(sourceIndex=i,role=role,repeatOf=None))
    candidates=[k for k,r in enumerate(records)]
    for i in (rng.choice(len(candidates),size=repeats,replace=False) if repeats else []):
        records.append(dict(sourceIndex=records[int(i)]['sourceIndex'],role='repeat',repeatOf=int(i)+1))
    output_rgb=np.array([rgb[p['sourceIndex']] for p in records]);predicted=lookup(exe,profile,output_rgb,intent='a')
    patches=[]
    for j,rec in enumerate(records):
        i=rec['sourceIndex']
        patches.append(dict(id=str(j+1),referenceName=reference['names'][i],role=rec['role'],repeatOf=None if rec['repeatOf'] is None else str(rec['repeatOf']),
            referenceLabD50Absolute=all_lab[i].tolist(),deviceRGB16=np.rint(output_rgb[j]*65535).astype(int).tolist(),deviceRGB=output_rgb[j].tolist(),
            predictedLabD50Absolute=predicted[j].tolist(),numericalInverseResidualDE00=float(reach[i]),
            gamutAssessment='model-reachable' if reach[i]<=.5 else 'outside-or-inversion-unresolved',
            minTrainingRGBDistance=float(np.min(np.max(abs(train-output_rgb[j]),axis=1))) if train.size else None))
    return write_definition(job,exe,request,out,profile,status,recipe,external,patches,output_rgb,predicted,reference=reference)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('job');p.add_argument('executable');p.add_argument('request');p.add_argument('output');a=p.parse_args();generate(a.job,a.executable,json.loads(Path(a.request).read_text()),a.output)
