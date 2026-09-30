"""Compare a proposed spot replacement with stored XYZ, D50/2, not target accuracy."""
import json,sys,hashlib
from pathlib import Path
import numpy as np
import colour
r=json.loads(Path(sys.argv[1]).read_text());c=json.loads(Path(sys.argv[2]).read_text())
a=np.asarray(r['data']['xyz'][c['request']['measurementIndex']-1],dtype=float)
b=np.asarray(c['xyz'],dtype=float)
if a.shape!=(3,) or b.shape!=(3,) or not np.isfinite([a,b]).all():raise ValueError('Invalid XYZ.')
lab=colour.XYZ_to_Lab(np.array([a,b])/100,colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50'])
result=dict(schemaVersion=1,documentType='inkprof.spot-comparison',parentMeasurementSHA256=hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest(),candidateSHA256=hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest(),deltaE00=float(colour.difference.delta_E_CIE2000(lab[0],lab[1])),previousLab=lab[0].tolist(),newLab=lab[1].tolist(),method='CIEDE2000; XYZ/100; D50/2; previous value versus spot replacement')
with open(sys.argv[3],'x') as f:json.dump(result,f,indent=2,allow_nan=False)
