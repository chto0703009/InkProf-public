"""Accepted spectral-payload MXF compatibility route; reference layout retained.
Not a reconstruction of the source print. Sidecar carries actual provenance.
"""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
import xml.etree.ElementTree as ET
from import_mxf import N, location, require


def export(measurement, template, output):
    measurement,template,output=map(Path,(measurement,template,output))
    require(not output.exists() and not output.with_suffix('.json').exists(),'Output already exists.')
    r=json.loads(measurement.read_text());d=r['data'];raw=template.read_bytes()
    require(r['complete'] and r['documentType']=='inkprof.chart-measurement','Complete measurement required.')
    require(r['measurementCondition']['interpreted']=='M0' and not r['measurementCondition']['fwaApplied'],'Native M0 required.')
    require(['DEVCALSTD','XRGA'] in r['metadata'],'XRGA required.')
    require(d['wavelengthNm']==list(range(380,731,10)),'Observed 36-band grid required.')
    sha=lambda b:hashlib.sha256(b).hexdigest()
    require(sha((measurement.parent/'chart.json').read_bytes())==r['chartJSONSHA256'],'Chart hash differs.')
    require(b'<!DOCTYPE' not in raw and b'<!ENTITY' not in raw,'DTD/entities unsupported.')
    root=ET.fromstring(raw);objects=root.findall('c:Resources/c:ObjectCollection/c:Object',N)
    targets=[o for o in objects if o.get('ObjectType')=='Target'];measured=[o for o in objects if o.get('ObjectType')=='M0_Measurement']
    require(len(objects)==len(targets)+len(measured)==2*len(d['ids']),'M0-only reference with matching count required.')
    index={str(v):i for i,v in enumerate(d['ids'])};require(len(index)==len(d['ids']),'Duplicate source IDs.')
    byloc={};seen=set()
    for t in targets:
        # This compatibility route requires the reference's TargetN names
        # to correspond to source IDs. Never match duplicate colours alone.
        name=t.get('Name','');require(name.startswith('Target'),'Expected TargetN identity.')
        sid=name[len('Target'):];require(sid in index,'Reference target identity is absent from measurement.')
        i=index[sid];require(i not in seen,'Duplicate target identity.');seen.add(i)
        rgb=[float(t.find('c:DeviceColorValues/c:ColorRGB/c:'+ch,N).text)/255*100 for ch in 'RGB']
        require(max(abs(a-b) for a,b in zip(rgb,d['rgbPercent'][i]))<1e-4,'Target RGB differs.')
        key=location(t);require(key not in byloc,'Duplicate target location.');byloc[key]=i
    require(len(seen)==len(index) and len({location(o) for o in measured})==len(index) and {location(o) for o in measured}==set(byloc),'Reference measurement locations differ.')
    specs={s.get('Id'):s for s in root.findall('c:Resources/c:ColorSpecificationCollection/c:ColorSpecification',N)}
    for o in measured:
        sp=o.find('c:ColorValues/c:ReflectanceSpectrum',N);require(sp is not None,'Reflectance spectrum required.')
        spec=specs[sp.get('ColorSpecification')];wl=spec.find('c:MeasurementSpec/c:WavelengthRange',N)
        require(float(wl.get('StartWL'))==380 and float(wl.get('Increment'))==10 and float(sp.get('StartWL'))==380,'Reference wavelength grid differs.')
        require(len(sp.text.split())==36,'Reference band count differs.')
        require(spec.findtext('c:MeasurementSpec/c:CalibrationStandard',namespaces=N)=='XRGA','Reference calibration standard differs.')
        require(spec.findtext('c:MeasurementSpec/c:Device/c:DeviceIllumination',namespaces=N)=='M0_Incandescent','Reference condition differs.')
    pattern=rb'(<cc:ReflectanceSpectrum\b[^>]*>)([^<]*)(</cc:ReflectanceSpectrum>)'
    matches=list(re.finditer(pattern,raw));require(len(matches)==len(measured),'Unsupported spectrum serialization.')
    pieces=[];last=0;mapping=[]
    for o,m in zip(measured,matches):
        i=byloc[location(o)];values=d['spectra'][i]
        require(len(values)==36 and all(math.isfinite(v) and v>=0 for v in values),'Invalid source spectrum.')
        payload=' '.join(format(v/100,'.10g') for v in values).encode()
        require(max(abs(float(a)*100-b) for a,b in zip(payload.split(),values))<1e-8,'Spectral roundtrip failed.')
        pieces.extend([raw[last:m.start(2)],payload]);last=m.end(2)
        mapping.append(dict(sourceId=d['ids'][i],sourceLocation=d['locations'][i],referencePageRowColumn=location(o)))
    pieces.append(raw[last:]);data=b''.join(pieces);ET.fromstring(data)
    report=dict(schemaVersion=1,documentType='inkprof.mxf-compatibility-export',createdBy='InkProf',source=str(measurement.resolve()),measurementSHA256=sha(measurement.read_bytes()),referenceSHA256=sha(raw),outputSHA256=sha(data),patchCount=len(index),recipientImportVerified=False,mapping=mapping,notes='Only spectral payload changed. Reference Creator, dates, private settings and layout retained for recipient compatibility, not evidence of source print provenance. Use source JSON/TI3 for the actual print layout.')
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open('xb') as f:f.write(data)
    with output.with_suffix('.json').open('x') as f:json.dump(report,f,indent=2)
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('measurement');p.add_argument('template');p.add_argument('output');a=p.parse_args();r=export(a.measurement,a.template,a.output);print(json.dumps({'patchCount':r['patchCount'],'outputSHA256':r['outputSHA256']}))
