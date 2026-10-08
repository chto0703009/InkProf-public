# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit approximate v2 RGB output copy; original never modified."""
import argparse,json,sys,subprocess,hashlib
from pathlib import Path
import numpy as np
import colour
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from lcms_float import LittleCMS
from profile_grid import lookup
from profile_c1 import require_profile

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(source,folder,colprof,xicclu,levels=17):
 source=Path(source);folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
 data=source.read_bytes()
 if data[8]!=4 or data[12:16]!=b'prtr' or data[16:20]!=b'RGB ':raise ValueError('Conversion supports ICC v4 RGB output profiles only.')
 digest=sha(source);cms=LittleCMS();axis=np.linspace(0,1,levels)
 rgb=np.array(np.meshgrid(axis,axis,axis,indexing='ij')).reshape(3,-1).T
 lab=cms.transform(source,rgb,intent=3)
 lines=['CTI3','DESCRIPTOR "InkProf approximate v2 copy; synthetic original ICC A2B samples"','DEVICE_CLASS "OUTPUT"','COLOR_REP "RGB_LAB"','NUMBER_OF_FIELDS 7','BEGIN_DATA_FORMAT','SAMPLE_ID RGB_R RGB_G RGB_B LAB_L LAB_A LAB_B','END_DATA_FORMAT',f'NUMBER_OF_SETS {len(rgb)}','BEGIN_DATA']
 lines += [str(i+1)+' '+' '.join(f'{v:.10g}' for v in [*(x*100),*y]) for i,(x,y) in enumerate(zip(rgb,lab))]
 lines += ['END_DATA',''];(folder/'conversion.ti3').write_text('\n'.join(lines))
 output=folder/'profile-v2.icc'
 args=[str(colprof),'-v','-qh','-al','-bh','-r','0.1','-s','20','-D','InkProf approximate v2 compatibility copy','-O',str(output),'conversion']
 with (folder/'conversion.log').open('wb') as log:
  p=subprocess.run(args,cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
 if p.returncode:raise ValueError('v2 build failed; see conversion.log')
 converted=output.read_bytes();require_profile(converted)
 if converted[8]!=2:raise ValueError('Converter did not produce ICC v2')
 probes=np.random.default_rng(42).random((512,3))
 differences={}
 for name,intent in [('relative',1),('absolute',3)]:
  a=cms.transform(source,probes,intent=intent);b=lookup(xicclu,output,probes,intent='r' if intent==1 else 'a')
  de=colour.delta_E(a,b,method='CIE 2000');differences[name]=dict(count=len(de),mean=float(de.mean()),p95=float(np.percentile(de,95)),max=float(de.max()))
 if sha(source)!=digest:raise ValueError('Original ICC changed during conversion')
 record=dict(documentType='inkprof.icc-v2-conversion',originalSHA256=digest,convertedSHA256=sha(output),method='LittleCMS absolute A2B samples; Argyll colprof v2 reconstruction',approximate=True,gridLevels=levels,sampleCount=len(rgb),validation=differences,limitations=['Original A2B/B2A tables are not copied exactly.','Inverse tables and perceptual mapping are rebuilt; original rendering behaviour is not guaranteed.','Validation samples are numerical and do not establish print quality.'],arguments=args)
 (folder/'conversion.json').write_text(json.dumps(record,indent=2));return record
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('folder');p.add_argument('colprof');p.add_argument('xicclu');a=p.parse_args();run(a.source,a.folder,a.colprof,a.xicclu)
