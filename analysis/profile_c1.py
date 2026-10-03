# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""C1 supplementary diagnostics: float CMM, inverse neighbourhoods, negative controls."""
import argparse,json,sys,tempfile,struct
from pathlib import Path
import numpy as np
import colour
from profile_grid import lookup,sha,summary
from lcms_float import LittleCMS
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'profiles'))
from read_icc import inspect_bytes


def require_profile(data):
    r=inspect_bytes(data)
    if not r['capabilities']['rgbOutputCandidate'] or r['diagnostics']:
        raise ValueError('Expected structurally valid RGB output profile without A1 warnings.')
    if not {'A2B1','B2A1'}.issubset({t['signature'] for t in r['tags']}):
        raise ValueError('Relative-colorimetric A2B1/B2A1 required for this diagnostic.')
    return r


def numerical_alerts(de,rgb):
    # Deliberately broad gross-failure detector, not a print-quality acceptance threshold.
    alerts=[]
    if not np.isfinite(de).all() or not np.isfinite(rgb).all(): alerts.append('nonfinite')
    if np.any((rgb < -1e-6)|(rgb > 1+1e-6)): alerts.append('rgb-out-of-range')
    if np.max(de)>10: alerts.append('roundtrip-over-10-dE00')
    return alerts


def negative_controls(profile,exe,rgb,lab):
    data=profile.read_bytes();results=[]
    for name,mutated in [('truncated',data[:-32]),('bad-signature',data[:36]+b'xxxx'+data[40:]),('wrong-device-space',data[:16]+b'CMYK'+data[20:])]:
        try: require_profile(mutated);detected=False;reason='not detected'
        except ValueError as exc: detected=True;reason=str(exc)
        results.append(dict(case=name,detected=detected,reason=reason))
    damaged=bytearray(data);inspection=require_profile(data)
    tag=next(t for t in inspection['tags'] if t['signature']=='B2A1')
    off=tag['offset'];n=tag['size']
    if data[off:off+4]!=b'mft2':
        results.append(dict(case='zero-B2A1-CLUT',detected=False,reason='unsupported negative-control LUT type'))
    else:
        channels,out_channels,points=data[off+8:off+11]
        entries=struct.unpack_from('>H',data,off+48)[0]
        start=off+52+2*channels*entries;end=start+2*out_channels*points**channels
        if end>off+n: raise ValueError('Invalid mft2 CLUT bounds.')
        damaged[start:end]=bytes(end-start)
        # Correct outer structure, but mathematically destroyed inverse table.
        require_profile(damaged)
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder)/'deliberately-damaged.icc';p.write_bytes(damaged)
            b=lookup(exe,p,lab,'b');fl=lookup(exe,p,b)
            de=colour.delta_E(lab,fl,method='CIE 2000');alerts=numerical_alerts(de,b)
            results.append(dict(case='zero-B2A1-CLUT',detected=bool(alerts),alerts=alerts,maxDeltaE00=float(de.max())))
    return results


def run(job,exe,out):
    job=Path(job);out=Path(out)
    if out.exists(): raise ValueError('Output directory already exists.')
    status=json.loads((job/'status.json').read_text());p=job/'result/profile.icc'
    if status['status']!='succeeded' or sha(p)!=status['profileSHA256']: raise ValueError('Job integrity failure.')
    require_profile(p.read_bytes())
    rgb=np.array(np.meshgrid(*[np.linspace(0,1,9)]*3,indexing='ij')).reshape(3,-1).T
    lab=lookup(exe,p,rgb);back=lookup(exe,p,lab,'b');rt=lookup(exe,p,back)
    de=colour.delta_E(lab,rt,method='CIE 2000')
    cmm=LittleCMS();fl=cmm.transform(p,rgb);bl=cmm.transform(p,lab,'b')
    other_rt=lookup(exe,p,bl)
    rgbdiff=np.max(abs(back-bl),axis=1)*100
    fd=colour.delta_E(lab,fl,method='CIE 2000');bd=colour.delta_E(rt,other_rt,method='CIE 2000')
    order=np.argsort(rgbdiff)[-10:][::-1]
    comparison=dict(library=cmm.path,encodedVersion=cmm.version,bufferType='float64 RGB 0..1; Lab L* a* b*',flags=['NOOPTIMIZE','NOCACHE'],
        forwardDeltaE00=summary(fd),backwardRGBPercent=summary(rgbdiff),backwardColourDeltaE00ViaArgyll=summary(bd),
        worstCases=[dict(index=int(i),targetLab=lab[i].tolist(),argyllRGB=back[i].tolist(),lcmsRGB=bl[i].tolist(),rgbPercent=float(rgbdiff[i]),colourDeltaE00=float(bd[i])) for i in order],
        limitation='No 8-bit conversion. CMM internals and ICC table precision remain finite; xicclu text output has six decimals.')
    local=[]
    for eps in (.1,.01,.001):
        pairs=np.repeat(lab[:,None,None,:],3,axis=1);pairs=np.repeat(pairs,2,axis=2)
        for axis in range(3):
            pairs[:,axis,0,axis]-=eps;pairs[:,axis,1,axis]+=eps
        vals=lookup(exe,p,pairs.reshape(-1,3),'b').reshape(-1,3,2,3)
        shifts=np.max(abs(vals[:,:,1]-vals[:,:,0]),axis=2)*100
        k=np.unravel_index(np.argmax(shifts),shifts.shape)
        local.append(dict(halfStepLab=eps,maxChannelChangePercent=summary(shifts),maxGainPercentPerLab=float(shifts.max()/(2*eps)),
            worst=dict(gridIndex=int(k[0]),axis=int(k[1]),labPair=pairs[k].tolist(),rgbPair=vals[k].tolist())))
    # Continuous PCS paths follow A2B of 27 RGB ramps; paths stay on the modeled gamut.
    paths=[]
    for axis in range(3):
        for a in (0,.5,1):
            for b in (0,.5,1):
                v=np.empty((1025,3));v[:,axis]=np.linspace(0,1,1025);other=[k for k in range(3) if k!=axis];v[:,other[0]]=a;v[:,other[1]]=b;paths.append(v)
    path_lab=lookup(exe,p,np.concatenate(paths));path_back=lookup(exe,p,path_lab,'b').reshape(27,1025,3)
    path_out=lookup(exe,p,path_back.reshape(-1,3)).reshape(27,1025,3)
    first=np.max(abs(np.diff(path_back,axis=1)),axis=2)*100
    second=np.max(abs(np.diff(path_back,n=2,axis=1)),axis=2)*100
    step_de=colour.delta_E(path_out[:,:-1],path_out[:,1:],method='CIE 2000')
    worst=np.unravel_index(np.argmax(first),first.shape)
    ramps=dict(count=27,samples=1025,rgbStepPercent=summary(first),rgbSecondDifferencePercent=summary(second),colourStepDeltaE00=summary(step_de),
        worst=dict(pathIndex=int(worst[0]),stepIndex=int(worst[1]),targetLabPair=path_lab.reshape(27,1025,3)[worst[0],worst[1]:worst[1]+2].tolist(),rgbPair=path_back[worst[0],worst[1]:worst[1]+2].tolist()),
        caveat='Steep gradients or interpolation knots are not proof of discontinuity; finite sampling cannot prove global continuity.')
    controls=negative_controls(p,exe,rgb,lab)
    if sha(p)!=status['profileSHA256']: raise ValueError('Profile changed during check.')
    result=dict(schemaVersion=1,documentType='inkprof.profile-c1-check',profileSHA256=sha(p),intent='relative colorimetric',bpc=False,gridCount=729,
        cmmFloat=comparison,inverseLocalPerturbations=local,inverseRamps=ramps,negativeControls=controls,
        grossFailureAlerts=numerical_alerts(de,back),allNegativeControlsDetected=all(c['detected'] for c in controls),
        measurementNoiseIssue='ISSUE-001 remains open. PCS perturbations are not measurement-noise propagation through refitting.',qualityValidated=False)
    out.mkdir(parents=True);(out/'c1-check.json').write_text(json.dumps(result,indent=2,allow_nan=False))
    lines=['# C1 – kompletterande numerisk kontroll','',f'Profil: {sha(p)}','',
        f'LittleCMS framåt ΔE00: {comparison["forwardDeltaE00"]}',f'LittleCMS invers RGB, procentenheter: {comparison["backwardRGBPercent"]}',
        f'Färgskillnad mellan inverslösningarna via Argyll A2B: {comparison["backwardColourDeltaE00ViaArgyll"]}',
        '',f'Lokala inversprov: {local}', '',f'Inversramper: {ramps}', '',f'Negativa kontroller: {controls}',
        '', 'ISSUE-001 kvarstår öppen. Dessa prov är inte fysisk utskriftsvalidering eller ett bevis på brusorsakade fel.']
    (out/'c1-check.md').write_text('\n'.join(lines)+'\n');return result

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('job');a.add_argument('executable');a.add_argument('output');v=a.parse_args();run(v.job,v.executable,v.output)
