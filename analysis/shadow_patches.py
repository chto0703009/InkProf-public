# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Additional, model-selected dark fitting patches for a matte iteration."""
import json
import sys
import subprocess
from pathlib import Path
import numpy as np
from profile_grid import lookup, sha


def neutral_pool():
    """Device RGB probes; no ICC is applied to their eventual print values."""
    gray = np.repeat(np.linspace(0, 100, 129)[:, None], 3, axis=1)
    rows = [gray]
    for channel in range(3):
        for offset in (-3., -1., 1., 3.):
            probe = gray.copy()
            probe[:, channel] += offset
            rows.append(np.clip(probe, 0, 100))
    return np.unique(np.round(np.vstack(rows)/100*65535), axis=0)/65535*100


def select(rgb, lab, existing, count, black, white):
    # Relative range remains usable when matte-paper black is above L*=20.
    ceiling = black + .25 * (white-black)
    rgb = np.round(np.asarray(rgb)/100*65535)/65535*100
    lab = np.asarray(lab, dtype=float)
    used = {tuple(v) for v in np.round(np.asarray(existing)/100*65535).astype(int)}
    candidates = []
    for i, row in enumerate(rgb):
        key = tuple(np.round(row/100*65535).astype(int))
        if key not in used and np.isfinite(lab[i]).all() and black-1 <= lab[i,0] <= ceiling:
            candidates.append(i)
            used.add(key)
    chosen = []

    def take(pool, budget):
        pool = [i for i in pool if i not in chosen]
        for _ in range(min(budget, len(pool))):
            if not chosen:
                j = min(range(len(pool)), key=lambda k: lab[pool[k], 0])
            else:
                distances = np.min(np.sum((lab[pool, None, :]-lab[chosen][None, :, :])**2, axis=2), axis=1)
                j = int(np.argmax(distances))
            chosen.append(pool.pop(j))

    chroma = np.hypot(lab[:, 1], lab[:, 2])
    # Device gray is retained even if the current model predicts a colour cast.
    neutral = [i for i in candidates if np.ptp(rgb[i]) <= .01 or chroma[i] <= 3]
    weak = [i for i in candidates if i not in neutral and chroma[i] <= 10]
    neutral_budget = (count+2)//3
    weak_budget = (count+1)//3
    take(neutral, neutral_budget)
    take(weak, weak_budget)
    take(candidates, count-len(chosen))
    return rgb[chosen], lab[chosen], ceiling


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
    rgb=np.unique(np.round(np.vstack([rgb,neutral_pool()])/100*65535),axis=0)/65535*100
    lab=lookup(xicclu,profile,rgb/100,intent='a')
    ends=lookup(xicclu,profile,np.asarray([[0,0,0],[1,1,1]]),intent='a')
    if not ends[0,0] < ends[1,0]:raise ValueError('ICC black/white lightness range is invalid.')
    selected,predicted,ceiling=select(rgb,lab,json.loads(Path(excluded).read_text()),count,float(ends[0,0]),float(ends[1,0]))
    if sha(profile)!=digest:raise ValueError('ICC changed during shadow selection.')
    data=dict(schemaVersion=1,documentType='inkprof.shadow-patches',sourceProfileSHA256=digest,
              requestedCount=count,actualCount=len(selected),rgbPercent=selected.tolist(),predictedLab=predicted.tolist(),
              blackL=float(ends[0,0]),whiteL=float(ends[1,0]),maximumL=ceiling,patchEmphasis=emphasis,
              method='Argyll targen -A1 -V plus dense device-gray and channel-offset probes; absolute D50 Lab lower 25% lightness range; neutral/weak-chroma quotas followed by maximin Lab spacing',
              selectionPolicy=dict(neutralBudget=(count+2)//3,weakChromaBudget=(count+1)//3,neutralMaximumChroma=3,weakMaximumChroma=10,deviceGrayTolerance=.01,quantizationBits=16,unusedBudget='Reassigned to remaining dark candidates'),
              profileApplied=False,
              scope='Additional fitting patches, not independent verification or guaranteed improvement')
    (folder/'shadow-patches.json').write_text(json.dumps(data,allow_nan=False))

if __name__=='__main__':run(*sys.argv[1:6],int(sys.argv[6]),float(sys.argv[7]))
