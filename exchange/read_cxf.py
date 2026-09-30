"""CxF3 semantic reader. Public MATLAB entry validates against CxF3 XSD first.

Standard-library only. No SDK. Never infer a physical print layout, illuminant,
measurement role or conversion from the filename or document order.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

NS='http://colorexchangeformat.com/CxF3-core'
N={'c':NS}

def tree(e):
    if e is None:return None
    return dict(tag=e.tag,attributes=dict(e.attrib),text=(e.text or '').strip(),children=[tree(c) for c in e])

def finite(v):
    x=float(v)
    if not math.isfinite(x):raise ValueError('Nonfinite colour value.')
    return x

def read(path):
    path=Path(path).resolve();raw=path.read_bytes()
    if len(raw)>64*1024*1024:raise ValueError('CxF exceeds the 64 MiB import limit.')
    text=raw.decode('utf-8-sig')
    if '<!DOCTYPE' in text.upper() or '<!ENTITY' in text.upper():raise ValueError('DTD/entities are not accepted.')
    root=ET.fromstring(text)
    if root.tag!='{'+NS+'}CxF':raise ValueError('Only CxF3 core is supported; CxF1/CxF2 are not inferred.')
    if root.findall('.//c:ColorCMYK',N):raise ValueError('Wrong colour format: InkProf supports RGB, not CMYK.')
    specifications=root.findall('c:Resources/c:ColorSpecificationCollection/c:ColorSpecification',N)
    spec={e.get('Id'):e for e in specifications}
    if len(spec)!=len(specifications) or None in spec:raise ValueError('Missing/duplicate colour specification ID.')
    objects=[];seen=set();warnings=[]
    for obj in root.findall('c:Resources/c:ObjectCollection/c:Object',N):
        identity=obj.get('Id')
        if not identity or identity in seen:raise ValueError('Missing/duplicate object ID.')
        seen.add(identity);values=[];rgb=[];rgb_scale=None
        for group in ('ColorValues','DeviceColorValues'):
            parent=obj.find('c:'+group,N)
            if parent is None:continue
            for value in parent:
                kind=value.tag.removeprefix('{'+NS+'}');sid=value.get('ColorSpecification')
                if sid is not None and sid not in spec:raise ValueError('Unresolved ColorSpecification: '+sid)
                rec=dict(kind=kind,container=group,specificationId=sid,attributes=dict(value.attrib),source=tree(value))
                if kind=='ColorRGB':
                    channels=[finite(value.findtext('c:'+k,namespaces=N)) for k in 'RGB']
                    scale=finite(value.findtext('c:MaxRange',default='255',namespaces=N))
                    if scale<=0 or any(v<0 or v>scale for v in channels):raise ValueError('RGB outside MaxRange.')
                    if rgb:raise ValueError('Multiple RGB definitions in one object need explicit selection.')
                    rgb=channels;rgb_scale=scale;rec.update(values=channels,scale=scale)
                elif kind in ('ColorCIELab','ColorCIEXYZ'):
                    channels='LAB' if kind=='ColorCIELab' else 'XYZ'
                    rec.update(values=[finite(value.findtext('c:'+k,namespaces=N)) for k in channels],scale='CxF native; Lab or XYZ nominal Y=100')
                elif kind=='ReflectanceSpectrum':
                    numbers=[finite(v) for v in (value.text or '').split()]
                    if not numbers or any(v<=-.1 or v>=3 for v in numbers):raise ValueError('Reflectance outside CxF3 bounds (-0.1, 3).')
                    wavelength=spec[sid].find('c:MeasurementSpec/c:WavelengthRange',N) if sid in spec else None
                    waves=[]
                    if wavelength is not None:
                        start=finite(value.get('StartWL',wavelength.get('StartWL')));step=finite(wavelength.get('Increment'))
                        if step<=0:raise ValueError('Wavelength increment must be positive.')
                        waves=[start+i*step for i in range(len(numbers))]
                    else:warnings.append('Unresolved wavelength grid for object '+identity+'; spectrum retained without integration.')
                    rec.update(values=numbers,scale=1,wavelengthNm=waves)
                else:warnings.append('Preserved without numerical interpretation: '+kind)
                values.append(rec)
        tags=[tree(t) for t in obj.findall('c:TagCollection',N)]
        objects.append(dict(id=identity,name=obj.get('Name',''),objectType=obj.get('ObjectType',''),
                            rgb=rgb,rgbScale=rgb_scale,values=values,tags=tags,source=tree(obj)))
    if not objects:raise ValueError('No CxF objects found.')
    return dict(schemaVersion=1,documentType='inkprof.cxf-import',sourcePath=str(path),sourceSHA256=hashlib.sha256(raw).hexdigest(),
                standardBasis='ISO 17972-1:2015 / CxF3; additional CxF/X workflow requirements not certified',
                validation=dict(semanticChecks=True,xsdValidated=False),objectCount=len(objects),rgbObjectCount=sum(bool(o['rgb']) for o in objects),
                objects=objects,fileInformation=tree(root.find('c:FileInformation',N)),
                colourSpecifications=[tree(e) for e in specifications],profiles=tree(root.find('c:Resources/c:ProfileCollection',N)),
                customResources=tree(root.find('c:CustomResources',N)),
                layoutStatus='Source tags retained; physical layout not inferred or verified',
                warnings=sorted(set(warnings)),originalXML=text)

def attach_layout(record, path):
    """Explicit positioned CxF/MXF Target layout; measured objects are ignored."""
    path=Path(path).resolve();raw=path.read_bytes()
    if len(raw)>64*1024*1024:raise ValueError('Layout source exceeds 64 MiB.')
    text=raw.decode('utf-8-sig')
    if '<!DOCTYPE' in text.upper() or '<!ENTITY' in text.upper():raise ValueError('DTD/entities are not accepted.')
    root=ET.fromstring(text)
    if root.tag!='{'+NS+'}CxF':raise ValueError('Layout source requires CxF3 content.')
    targets=[o for o in root.findall('c:Resources/c:ObjectCollection/c:Object',N) if o.get('ObjectType')=='Target']
    if len(targets)!=len(record['objects']):raise ValueError('Layout source target count differs.')
    mapping=[];seen=set()
    for original,positioned in zip(record['objects'],targets):
        colours=positioned.findall('c:DeviceColorValues/c:ColorRGB',N)
        if len(colours)!=1 or not original['rgb']:raise ValueError('One RGB definition required for layout matching.')
        c=colours[0];scale=finite(c.findtext('c:MaxRange',default='255',namespaces=N))
        if scale<=0:raise ValueError('Invalid layout RGB scale.')
        rgb=[finite(c.findtext('c:'+v,namespaces=N))/scale for v in 'RGB']
        if any(abs(a-b/original['rgbScale'])>1e-9 for a,b in zip(rgb,original['rgb'])):
            raise ValueError('Layout RGB sequence differs. No automatic reordering or nearest-colour matching.')
        tags=positioned.findall('c:TagCollection[@Name="Location"]/c:Tag',N)
        attrs={t.get('Name'):t.get('Value') for t in tags}
        if len(attrs)!=len(tags):raise ValueError('Duplicate layout tags.')
        try:page,row,col=[int(attrs[k]) for k in ('Page','Row','Column')]
        except (KeyError,ValueError):raise ValueError('Explicit page, row and column are required.')
        if page<1 or row<0 or col<0 or (page,row,col) in seen:raise ValueError('Invalid/duplicate layout position.')
        seen.add((page,row,col));n=col+1;letters=''
        while n:n,remainder=divmod(n-1,26);letters=chr(65+remainder)+letters
        mapping.append(dict(objectId=original['id'],layoutObjectId=positioned.get('Id'),page=page,row=row+1,column=col+1,coordinate=letters+str(row+1)))
    record['layout']=dict(sourcePath=str(path),sourceSHA256=hashlib.sha256(raw).hexdigest(),
                          basis='Explicit Target positions; all RGB values and sequence match. No measured values copied.',
                          mapping=mapping,physicalPrintVerified=False)
    record['layoutStatus']='Explicit companion layout matched; operator must select the companion belonging to this print.'
    return record

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('output');p.add_argument('--layout');a=p.parse_args()
    result=read(a.source)
    if a.layout:attach_layout(result,a.layout)
    with Path(a.output).open('x') as f:json.dump(result,f,indent=2,allow_nan=False)
