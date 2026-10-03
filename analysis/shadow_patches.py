"""Additional, model-selected dark fitting patches for a matte iteration."""
import json
import sys
import subprocess
from pathlib import Path
import numpy as np
from profile_grid import lookup, sha


def select(rgb, lab, existing, count, black, white):
    # A relative threshold also works when matte-paper black is above L*=20.
    ceiling = black + .25 * (white-black)
    rgb = np.round(np.asarray(rgb)/100*65535)/65535*100
    used = {tuple(v) for v in np.round(np.asarray(existing)/100*65535).astype(int)}
    candidates = []
    for i, row in enumerate(rgb):
        key = tuple(np.round(row/100*65535).astype(int))
        if key not in used and np.isfinite(lab[i]).all() and black-1 <= lab[i,0] <= ceiling:
            candidates.append(i); used.add(key)
    chosen=[]
    if candidates and count:
        chosen=[min(candidates,key=lambda i: lab[i,0])];candidates.remove(chosen[0])
    while candidates and len(chosen)<count:
        distances=np.min(np.sum((lab[candidates,None,:]-lab[chosen][None,:,:])**2,axis=2),axis=1)
        i=candidates.pop(int(np.argmax(distances)));chosen.append(i)
    return rgb[chosen],lab[chosen],ceiling


def run(profile, excluded, folder, targen, xicclu, count, emphasis):
    folder=Path(folder);folder.mkdir(exist_ok=True)
    profile=Path(profile).resolve();digest=sha(profile)
    if not 0<=count<=256 or not 1<=emphasis<=4:raise ValueError('Invalid shadow sampling settings.')
    base=folder/'shadow-pool'
    # Add samples instead of taking away already selected image/C3 patches.
    args=[str(targen),'-d2','-e1','-B1','-g65','-m2','-A1','-V'+str(emphasis),'-c',str(profile),'-f'+str(max(512,count*12)),str(base)]
    result=subprocess.run(args,capture_output=True,text=True,timeout=240)
    (folder/'shadow-targen.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise RuntimeError('Argyll shadow target failed: '+result.stderr[-1000:])
    import re, shlex
    text=base.with_suffix('.ti1').read_text()
    fields=shlex.split(re.search(r'BEGIN_DATA_FORMAT\s+(.*?)\s+END_DATA_FORMAT',text,re.S)[1])
    rows=[shlex.split(line) for line in re.search(r'BEGIN_DATA\s+(.*?)\s+END_DATA',text,re.S)[1].splitlines() if line.strip()]
    rgb=np.asarray([[float(row[fields.index(k)]) for k in ['RGB_R','RGB_G','RGB_B']] for row in rows])
    rgb=np.round(rgb/100*65535)/65535*100
    lab=lookup(xicclu,profile,rgb/100,intent='a')
    ends=lookup(xicclu,profile,np.asarray([[0,0,0],[1,1,1]]),intent='a')
    if not ends[0,0] < ends[1,0]:raise ValueError('ICC black/white lightness range is invalid.')
    selected,predicted,ceiling=select(rgb,lab,json.loads(Path(excluded).read_text()),count,float(ends[0,0]),float(ends[1,0]))
    if sha(profile)!=digest:raise ValueError('ICC changed during shadow selection.')
    data=dict(schemaVersion=1,documentType='inkprof.shadow-patches',sourceProfileSHA256=digest,
              requestedCount=count,actualCount=len(selected),rgbPercent=selected.tolist(),predictedLab=predicted.tolist(),
              blackL=float(ends[0,0]),whiteL=float(ends[1,0]),maximumL=ceiling,patchEmphasis=emphasis,
              method='Argyll targen -A1 -V with current ICC; absolute D50 Lab selection in lower 25% of model lightness range; maximin Lab spacing',
              scope='Additional fitting patches, not independent verification or guaranteed improvement')
    (folder/'shadow-patches.json').write_text(json.dumps(data,allow_nan=False))

if __name__=='__main__':run(*sys.argv[1:6],int(sys.argv[6]),float(sys.argv[7]))
