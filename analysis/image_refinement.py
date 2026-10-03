# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Image-selected device RGB probes. No print accuracy or gamut claim.
MATLAB supplies full precision 8/16-bit samples; ICC metadata comes from Pillow.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageCms
from scipy.spatial import cKDTree
import colour
from lcms_float import LittleCMS
from profile_grid import lookup


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_profile(image, choice, destination):
    with Image.open(image) as im:
        embedded = im.info.get('icc_profile')
    if choice == 'embedded':
        if not embedded:
            raise ValueError('Image has no embedded ICC profile. Choose sRGB explicitly or select the correct RGB ICC profile.')
        data = embedded
    elif choice == 'sRGB':
        data = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
    else:
        data = Path(choice).read_bytes()
    if len(data) < 128 or data[36:40] != b'acsp' or data[16:20] != b'RGB ':
        raise ValueError('The image source profile must be a valid RGB ICC profile.')
    profile = ImageCms.ImageCmsProfile(io.BytesIO(data))
    Path(destination).write_bytes(data)
    return dict(choice=choice if choice in ('embedded','sRGB') else 'selected-ICC',
                file='sources/image-profile.icc', sha256=sha(destination),
                description=ImageCms.getProfileDescription(profile).strip(), embeddedAvailable=bool(embedded))


def representatives(lab, max_count):
    """Frequency-weighted farthest sampling of occupied Lab cells; deterministic."""
    cells=np.floor(lab/4).astype(int)
    _,first,counts=np.unique(cells,axis=0,return_index=True,return_counts=True)
    # Bound the pool deterministically; frequency only selects the initial pool.
    order=np.lexsort((first,-counts))[:8192]
    first,counts=first[order],counts[order]
    values=lab[first];chosen=[];distance=np.full(len(first),np.inf)
    for _ in range(min(max_count,len(first))):
        score=counts.astype(float) if not chosen else distance*np.sqrt(counts/counts.max())
        score[chosen]=-1
        j=int(np.argmax(score));chosen.append(j)
        distance=np.minimum(distance,np.sum((values-values[j])**2,axis=1))
    return first[chosen],counts[chosen]


def choose_candidates(device, desired, predicted, counts, existing, budget, spacing, radius):
    tree=cKDTree(existing) if len(existing) else None
    selected=[];skipped=0
    # Interleave each representative with its optional neighboring probes.
    proposals=[]
    for i,v in enumerate(device):
        proposals.append((i,'image-colour',v))
        if radius>0:
            proposals.extend((i,f'neighbor-{axis+1}-{sign:+d}',np.clip(v+sign*radius*np.eye(3)[axis],0,100)) for axis in range(3) for sign in (-1,1))
    for i,kind,value in proposals:
        rgb=np.round(value/100*65535)/65535*100
        if tree is not None and tree.query(rgb,p=np.inf)[0]<spacing:
            skipped+=1;continue
        if selected and np.min(np.max(np.abs(np.array([p['rgbPercent'] for p in selected])-rgb),axis=1))<spacing:
            skipped+=1;continue
        selected.append(dict(patchId=f'IMG-{len(selected)+1:04d}',rgbPercent=rgb.tolist(),
            desiredLab=desired[i].tolist(),mappedLab=predicted[i].tolist(),pixelCount=int(counts[i]),
            representativeIndex=int(i+1),kind=kind,sourceMappingDeltaE00=float(colour.delta_E(desired[i],predicted[i],method='CIE 2000'))))
        if len(selected)>=budget:break
    return selected,skipped


def attach_fit_estimates(candidates, fit_file, profile_hash, training_hash, output):
    """Local training residuals, not independent predictions of print error."""
    summary=dict(available=False, reason='No current profile-fit report available')
    for c in candidates:
        c['estimatedLocalFitDeltaE00']=None
        c['localFitSupportCount']=0
        c['nearestFitRGBDistancePercent']=None
    if not fit_file:
        return summary
    source=Path(fit_file);raw=source.read_bytes();fit=json.loads(raw)
    if (fit.get('documentType')!='inkprof.profile-fit' or fit.get('profileSHA256')!=profile_hash
        or fit.get('sourceTI3SHA256')!=training_hash):
        raise ValueError('Fit report does not belong to the current profile and training measurements.')
    patches=fit['patches']
    rgb=np.asarray([p['rgbPercent'] for p in patches],dtype=float)
    errors=np.asarray([p['deltaE00'] for p in patches],dtype=float)
    if rgb.shape!=(len(errors),3) or not len(errors) or not np.isfinite(rgb).all() or not np.isfinite(errors).all() or np.any(errors<0):
        raise ValueError('Invalid fit report measurements.')
    for c in candidates:
        distance=np.max(np.abs(rgb-np.asarray(c['rgbPercent'])),axis=1)
        indices=np.argsort(distance,kind='stable')[:4]
        c['nearestFitRGBDistancePercent']=float(distance[indices[0]])
        indices=indices[distance[indices]<=10]
        if len(indices):
            weights=1/np.maximum(distance[indices],.1)
            c['estimatedLocalFitDeltaE00']=float(np.average(errors[indices],weights=weights))
            c['localFitSupportCount']=int(len(indices))
    target=Path(output)/'sources/profile-fit.json';target.write_bytes(raw)
    return dict(available=True,file='sources/profile-fit.json',sha256=sha(target),
        summary=dict(count=len(errors),mean=float(errors.mean()),p95=float(np.percentile(errors,95)),max=float(errors.max())),
        method='Inverse-distance weighted training residual from up to four nearest device-RGB measurements within 10 percentage points in every channel; weight floor 0.1 percentage points.',
        limitation='Local fitting-error estimate, not an independently measured print error or confidence bound. Blank means insufficient nearby measurements.')


def run(request_file, output):
    request=json.loads(Path(request_file).read_text());out=Path(output);(out/'sources').mkdir(parents=True,exist_ok=True)
    image=Path(request['image']);digest=sha(image)
    if digest!=request['imageSHA256']:raise ValueError('Image changed after sampling.')
    samples=np.asarray(request['samples'],dtype=float).reshape(-1,3);existing=np.asarray(request['existingRGBPercent'],dtype=float).reshape(-1,3)
    if existing.size==0:existing=np.empty((0,3))
    if samples.ndim!=2 or samples.shape[1]!=3 or not len(samples) or not np.isfinite(samples).all() or np.any((samples<0)|(samples>1)):
        raise ValueError('Expected normalized finite RGB image samples.')
    budget=int(request['maxPatches']);spacing=float(request['minSpacingPercent']);radius=float(request['neighborRadiusPercent'])
    if not 1<=budget<=500 or not 0<spacing<=10 or not 0<=radius<=10:raise ValueError('Invalid patch budget, spacing or radius.')
    source=source_profile(image,request['sourceProfile'],out/'sources/image-profile.icc')
    lab=LittleCMS().transform(out/'sources/image-profile.icc',samples)
    indexes,counts=representatives(lab,min(max(budget*5,100),2500))
    desired=lab[indexes]
    profile=Path(request['profile']);profile_hash=sha(profile)
    # Relative D50 with no BPC: image appearance normalized to media white.
    rgb=np.clip(lookup(request['xicclu'],profile,desired,'b','r'),0,1)
    predicted=lookup(request['xicclu'],profile,rgb,'f','r')
    candidates,skipped=choose_candidates(rgb*100,desired,predicted,counts,existing,budget,spacing,radius)
    fit_estimates=attach_fit_estimates(candidates,request.get('fitReport',''),profile_hash,request.get('trainingSHA256',''),out)
    # Human preview in sRGB, separate from the raw device RGB sent to the printer.
    srgb=out/'sources/preview-srgb.icc';srgb.write_bytes(ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
    if candidates:
        preview=LittleCMS().transform(srgb,np.asarray([c['desiredLab'] for c in candidates]),'b')
        for c,v in zip(candidates,preview):c['previewRGB']=np.clip(v,0,1).tolist()
    if sha(image)!=digest or sha(profile)!=profile_hash:raise ValueError('Image or ICC changed during proposal generation.')
    result=dict(schemaVersion=1,documentType='inkprof.image-refinement',status='proposal-review-required',
        profileApplied=False,qualityApproved=False,measurementRole='adaptive_validation',
        image=dict(file='sources/image'+image.suffix.lower(),sha256=digest,originalName=image.name,selection=request['selection'],sampleCount=len(samples)),
        imageProfile=source,sourceProfileSHA256=profile_hash,fitEstimates=fit_estimates,
        method='Frequency-weighted farthest selection in 4-unit Lab cells; relative D50 inversion; 16-bit device RGB spacing; no colour-family preference.',
        parameters=dict(MaxNewPatches=budget,MinSpacingPercent=spacing,NeighborRadiusPercent=radius,ImageIntent='relative colorimetric',BPC=False),
        candidates=candidates,representativeCount=len(indexes),excludedNearExistingOrDuplicate=skipped,
        stopReason='Patch budget reached' if len(candidates)==budget else 'No further distinct candidates at the selected spacing',
        limitations=['Image colours guide sampling, not predicted improvement.','Mapping Delta E00 compares the desired image colour and the model round trip; it is not measured error or proof of being out of gamut.',
        'Neighbor probes retain the source image colour for context; they are not colour corrections.','Print device RGB with colour management disabled. A separate validation print is still required to assess accuracy.'])
    (out/'proposal.json').write_text(json.dumps(result,indent=2,ensure_ascii=False,allow_nan=False),encoding='utf-8')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('request');parser.add_argument('output');parser.add_argument('--inspect',action='store_true');args=parser.parse_args()
    if args.inspect:
        with Image.open(args.request) as image:
            data=image.info.get('icc_profile')
            result=dict(hasEmbeddedProfile=bool(data),mode=image.mode,size=list(image.size))
            if data:
                result['description']=ImageCms.getProfileDescription(ImageCms.ImageCmsProfile(io.BytesIO(data))).strip()
            Path(args.output).write_text(json.dumps(result),encoding='utf-8')
    else:run(args.request,args.output)
