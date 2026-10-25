# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Compare both ICCs against the same original measured training observations."""
import json,sys,hashlib
from pathlib import Path
import numpy as np
from colour import delta_E
from icc_lookup import lookup

def run(request_file,output):
    r=json.loads(Path(request_file).read_text());fit_file=Path(r['fitReport'])
    if hashlib.sha256(fit_file.read_bytes()).hexdigest()!=r['fitSHA256']:raise ValueError('Original fit report changed.')
    fit=json.loads(fit_file.read_text());candidate=Path(r['candidate'])
    if hashlib.sha256(candidate.read_bytes()).hexdigest()!=r['candidateSHA256']:raise ValueError('Candidate changed.')
    p=fit['patches'];rgb=np.asarray([a['rgbPercent'] for a in p]);measured=np.asarray([a['measuredLab'] for a in p])
    new_lab=lookup(r['xicclu'],candidate,rgb/100,intent='a');new=np.asarray(delta_E(new_lab,measured,method='CIE 2000'));old=np.asarray([a['deltaE00'] for a in p]);change=new-old
    rows=[dict(sourceIndex=a['sourceIndex'],sampleId=a['sampleId'],sourceLab=a['measuredLab'],originalDeltaE00=float(o),trialDeltaE00=float(n),changeDeltaE00=float(d)) for a,o,n,d in zip(p,old,new,change)]
    def summary(mask):
        if not np.any(mask):return dict(count=0)
        return dict(count=int(np.sum(mask)),originalMean=float(np.mean(old[mask])),trialMean=float(np.mean(new[mask])),meanChange=float(np.mean(change[mask])),worstRegression=float(np.max(change[mask])),trialMax=float(np.max(new[mask])))
    kept=np.isin(np.arange(1,len(p)+1),r['selectedRows'])
    result=dict(documentType='inkprof.density-common-fit-comparison',basis='Both profiles evaluated against ALL unchanged original fitting observations; includes omitted rows. Training error, not independent print accuracy.',
                sourceProfileSHA256=fit['profileSHA256'],candidateSHA256=r['candidateSHA256'],all=summary(np.ones(len(p),bool)),retained=summary(kept),omitted=summary(~kept),patches=rows)
    Path(output).write_text(json.dumps(result,indent=2,allow_nan=False))
if __name__=='__main__':run(*sys.argv[1:])
