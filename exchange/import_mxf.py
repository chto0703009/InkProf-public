# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Strict positioned RGB CxF3 reflectance import. Originals remain authoritative."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'analysis'))
from spectral_analysis import colorimetry
N={'c':'http://colorexchangeformat.com/CxF3-core'}
P='{http://www.xrite.com/products/prism}'

def require(value,message):
    if not value: raise ValueError(message)

def location(o):
    tags=o.findall('c:TagCollection[@Name="Location"]/c:Tag',N)
    d={t.get('Name'):t.get('Value') for t in tags}
    require(len(d)==len(tags),'Duplicate location tags.')
    try: key=tuple(int(d[k]) for k in ('Page','Row','Column'))
    except (KeyError,ValueError): raise ValueError('MXF requires explicit Page/Row/Column; missing layout cannot be guessed.')
    require(key[0]>=1 and min(key[1:])>=0,'Invalid page or patch coordinate.')
    return key

def letters(n):
    result='';n+=1
    while n: n,r=divmod(n-1,26);result=chr(65+r)+result
    return result

def q(s):
    s=str(s);require(not any(c in s for c in '\r\n"'),'Unsupported CGATS header character.')
    return '"'+s+'"'

def cgats(signature,headers,fields,rows):
    lines=[signature]+[k+' '+q(v) for k,v in headers.items()]
    lines+=['NUMBER_OF_FIELDS '+str(len(fields)),'BEGIN_DATA_FORMAT',' '.join(fields),'END_DATA_FORMAT','NUMBER_OF_SETS '+str(len(rows)),'BEGIN_DATA']
    lines+=[' '.join(q(v) if isinstance(v,str) else format(v,'.17g') for v in row) for row in rows]
    return '\n'.join(lines+['END_DATA',''])

def convert(source,destination,condition=''):
    source=Path(source);out=Path(destination);require(not out.exists(),'Conversion directory already exists.')
    raw=source.read_bytes();require(b'<!DOCTYPE' not in raw and b'<!ENTITY' not in raw,'DTD/entity declarations are unsupported.')
    root=ET.fromstring(raw);require(root.tag=='{'+N['c']+'}CxF','Expected CxF3 MXF content.')
    attrs=root.find('.//'+P+'CustomAttributes');require(attrs is not None,'Missing Prism layout metadata.')
    attrs=dict(attrs.attrib);require(attrs.get('ColorSpace')=='RGB','Unsupported colour format: RGB required, not CMYK.')
    objects=root.findall('c:Resources/c:ObjectCollection/c:Object',N)
    ids=[o.get('Id') for o in objects];require(all(ids) and len(set(ids))==len(ids),'Duplicate/missing object identity.')
    targets=[o for o in objects if o.get('ObjectType')=='Target']
    modes=sorted({o.get('ObjectType').split('_')[0] for o in objects if o.get('ObjectType') in ('M0_Measurement','M1_Measurement','M2_Measurement')})
    require(modes,'No supported M0/M1/M2 measurements.')
    require(condition or len(modes)==1,'Multiple measurement conditions: specify Condition explicitly: '+', '.join(modes))
    mode=condition or modes[0];require(mode in modes,'Requested condition is absent.')
    measured=[o for o in objects if o.get('ObjectType')==mode+'_Measurement']
    byloc={location(o):o for o in measured};tloc={location(o):o for o in targets}
    require(len(byloc)==len(measured) and len(tloc)==len(targets),'Ambiguous repeated patch coordinates.')
    require(tloc and set(tloc)==set(byloc),'Targets and measurements do not have identical coordinates.')
    specs={s.get('Id'):s for s in root.findall('c:Resources/c:ColorSpecificationCollection/c:ColorSpecification',N)}
    require(len(specs)==len(root.findall('c:Resources/c:ColorSpecificationCollection/c:ColorSpecification',N)),'Duplicate colour specifications.')
    cols=int(attrs['NumberPatchColumns']);pages=int(attrs['NumberPatchPages']);height=int(attrs['NumberPatchRows'])
    require(0<cols<=1000 and 0<pages<=1000 and 0<height<=10000 and cols*pages*height<=1000000,'Invalid/excessive chart dimensions.')
    require({k[0] for k in tloc}==set(range(1,pages+1)),'Missing or inconsistent page numbers.')
    counts=[max(k[1] for k in tloc if k[0]==page)+1 for page in range(1,pages+1)]
    require(all(n<=height for n in counts) and all(k[2]<cols for k in tloc),'Coordinate exceeds declared layout.')
    records=[];wave=None;standard=None
    for ordinal,t in enumerate(targets,1):
        key=location(t);m=byloc[key]
        color=t.find('c:DeviceColorValues/c:ColorRGB',N);require(color is not None,'Missing RGB target values.')
        rgb=[float(color.find('c:'+ch,N).text) for ch in 'RGB'];require(all(math.isfinite(v) and 0<=v<=255 for v in rgb),'RGB outside CxF 0..255 scale.')
        spectral=m.findall('c:ColorValues/c:ReflectanceSpectrum',N);require(len(spectral)==1,'Exactly one reflectance spectrum per selected measurement is required.')
        sp=spectral[0];spec=specs.get(sp.get('ColorSpecification'));require(spec is not None,'Unresolved spectral specification.')
        require(spec.findtext('c:MeasurementSpec/c:MeasurementType',namespaces=N)=='Spectrum_Reflectance','Unsupported measurement type.')
        declared=spec.findtext('c:MeasurementSpec/c:Device/c:DeviceIllumination',default='',namespaces=N)
        require(declared.startswith(mode+'_'),'Object condition conflicts with spectral specification.')
        wl=spec.find('c:MeasurementSpec/c:WavelengthRange',N);require(wl is not None,'Missing wavelength grid.')
        start=float(wl.get('StartWL'));step=float(wl.get('Increment'));require(step>0 and math.isfinite(step) and float(sp.get('StartWL',start))==start,'Inconsistent spectral grid.')
        values=[float(v) for v in sp.text.split()];require(len(values)>=3 and all(math.isfinite(v) and v>=0 for v in values),'Invalid reflectance values.')
        waves=[start+i*step for i in range(len(values))]
        require(all(v==int(v) for v in waves),'Fractional-nanometre grid is not supported by this TI3 adapter.')
        calibration=spec.findtext('c:MeasurementSpec/c:CalibrationStandard',default='unknown',namespaces=N)
        if wave is None: wave=waves;standard=calibration
        require(waves==wave and calibration==standard,'Mixed spectral grids or calibration standards need separate imports.')
        row=sum(counts[:key[0]-1])+key[1]+1;loc=str(row)+letters(key[2])
        records.append(dict(sampleId=str(ordinal),sampleLoc=loc,key=key,rgbPercent=[v/255*100 for v in rgb],spectra=[v*100 for v in values],targetObjectId=t.get('Id'),targetName=t.get('Name'),measurementObjectId=m.get('Id'),originalTargetXML=ET.tostring(t,encoding='unicode'),originalMeasurementXML=ET.tostring(m,encoding='unicode')))
    spectra=np.asarray([r['spectra'] for r in records])/100
    xyz,lab,_,_=colorimetry(wave,spectra)
    fields=['SAMPLE_ID','SAMPLE_LOC','RGB_R','RGB_G','RGB_B'];fields3=fields+['XYZ_X','XYZ_Y','XYZ_Z']+['SPEC_'+str(int(v)) for v in wave]
    rows3=[[r['sampleId'],r['sampleLoc'],*r['rgbPercent'],*xyz[i],*r['spectra']] for i,r in enumerate(records)]
    lookup={r['key']:r for r in records};rows2=[]
    for page,nrows in enumerate(counts,1):
        for row in range(nrows):
            for col in range(cols):
                r=lookup.get((page,row,col));loc=str(sum(counts[:page-1])+row+1)+letters(col)
                rows2.append([r['sampleId'] if r else '0',loc,*(r['rgbPercent'] if r else [0,0,0])])
    common={'ORIGINATOR':'InkProf MXF import','TARGET_INSTRUMENT':attrs.get('MeasurementDevice','unknown')}
    h2=dict(common,COLOR_REP='RGB',STEPS_IN_PASS=cols,PASSES_IN_STRIPS2=','.join(map(str,counts)),STRIP_INDEX_PATTERN='0-9,@-9,@-9;1-999',PATCH_INDEX_PATTERN='A-Z, A-Z',INDEX_ORDER='STRIP_THEN_PATCH')
    if attrs.get('PageWidth') and attrs.get('PageHeight'):h2['PAPER_SIZE']=attrs['PageWidth']+'x'+attrs['PageHeight']
    h3=dict(common,DEVICE_CLASS='OUTPUT',COLOR_REP='RGB_XYZ',DEVCALSTD=standard,SPECTRAL_BANDS=len(wave),SPECTRAL_START_NM=wave[0],SPECTRAL_END_NM=wave[-1],INKPROF_MEASUREMENT_CONDITION=mode,INKPROF_INSTRUMENT_SERIAL=attrs.get('MeasurementDeviceSerialNumber',''))
    info=dict(schemaVersion=1,documentType='inkprof.measurement-import',format='MXF',source=str(source.resolve()),sourceSHA256=hashlib.sha256(raw).hexdigest(),sourceFile='original.mxf',importerVersion='1.0',availableConditions=modes,selectedCondition=mode,patchCount=len(records),layoutBasis='Explicit source Page/Row/Column; zero-based row/column; pages one-based. Missing grid cells are display padding, not measured or invented print patches.',customAttributes=attrs,sourceFileInformationXML=ET.tostring(root.find('c:FileInformation',N),encoding='unicode'),sourceSpecificationsXML=ET.tostring(root.find('c:Resources/c:ColorSpecificationCollection',N),encoding='unicode'),mapping=records,unselectedMeasurementObjectsXML=[ET.tostring(o,encoding='unicode') for o in objects if o.get('ObjectType','').endswith('_Measurement') and o.get('ObjectType')!=mode+'_Measurement'],colorimetry='XYZ derived from reflectance with InkProf D50/CIE1931 2deg on measured support; original colour values retained in source object XML.',condition=dict(requested='unknown',reported=mode,interpreted=mode,basis='MXF object group and spectral DeviceIllumination agree',fwaApplied=False,instrument=attrs.get('MeasurementDevice','unknown'),instrumentSerial=attrs.get('MeasurementDeviceSerialNumber',''),calibrationStandard=standard))
    # Validate all content before writing anything.
    ti2=cgats('CTI2',h2,fields,rows2);ti3=cgats('CTI3',h3,fields3,rows3)
    out.mkdir(parents=True);(out/'layout.ti2').write_text(ti2);(out/'data.ti3').write_text(ti3);(out/'import-info.json').write_text(json.dumps(info,indent=2,allow_nan=False))
    return info

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('destination');p.add_argument('--condition',default='');a=p.parse_args()
    info=convert(a.source,a.destination,a.condition);print(json.dumps({k:info[k] for k in ('patchCount','selectedCondition','availableConditions')}))
