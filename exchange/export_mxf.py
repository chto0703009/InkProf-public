"""Export native M0 chart data into an observed Prism/CxF3 MXF dialect.
Template-based candidate: recipient application import remains a separate test.
"""
import argparse,copy,hashlib,json,math,re
from xml.sax.saxutils import quoteattr
from pathlib import Path
from datetime import datetime
import xml.etree.ElementTree as ET
NS='http://colorexchangeformat.com/CxF3-core';PR='http://www.xrite.com/products/prism'
ET.register_namespace('cc',NS);ET.register_namespace('pr',PR)
N={'c':NS};tag=lambda s:f'{{{NS}}}{s}'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def export(measurement,template,output):
 measurement,template,output=map(Path,(measurement,template,output))
 if output.exists() or output.with_suffix('.json').exists():raise ValueError('Output already exists.')
 r=json.loads(measurement.read_text());chart_path=measurement.parent/'chart.json';chart=json.loads(chart_path.read_text())
 assert r['documentType']=='inkprof.chart-measurement' and r['complete']
 assert sha(chart_path)==r['chartJSONSHA256']
 assert r['measurementCondition']['interpreted']=='M0' and not r['measurementCondition']['fwaApplied']
 assert ['DEVCALSTD','XRGA'] in r['metadata']
 assert r['data']['wavelengthNm']==list(range(380,731,10)), 'Only observed 36-band grid supported.'
 d=r['data'];count=r['expectedSourcePatches'];assert len(d['ids'])==count==len(set(d['ids']))
 root=ET.parse(template).getroot();objects=root.find('c:Resources/c:ObjectCollection',N)
 targets=[o for o in objects if o.get('ObjectType')=='Target'];measure=[o for o in objects if o.get('ObjectType')=='M0_Measurement']
 assert len(targets)==len(measure)==count, 'Reference target count differs.'
 def location(o):return {t.get('Name'):t.get('Value') for t in o.findall('c:TagCollection[@Name="Location"]/c:Tag',N)}
 def key(o):
  loc=location(o);return tuple(loc[k] for k in ('Page','Column','Row'))
 byloc={key(o):o for o in measure};assert len(byloc)==count
 specs=root.find('c:Resources/c:ColorSpecificationCollection',N)
 for spec in list(specs):
  if spec.get('Id') not in ('M0_Measurement_spec','Unknown'):specs.remove(spec)
 now=datetime.now().astimezone().isoformat(timespec='seconds')
 info=root.find('c:FileInformation',N);info.find('c:Creator',N).text='InkProf'
 info.find('c:CreationDate',N).text=now;info.find('c:Description',N).text='InkProf M0 spectral measurement export; actual chart coordinates; import validation pending'
 # Retain observed Prism dialect/version tags; Creator still identifies InkProf.
 pairs=[];mapping=[];passes=chart['passesInStrips'];passes=passes if isinstance(passes,list) else [passes]
 for idx,(target,chart_idx) in enumerate(zip(targets,r['chartIndex'])):
  patch=chart['patches'][chart_idx-1];assert not patch['isPadding']
  assert patch['sampleId']==d['ids'][idx] and patch['sampleLoc']==d['locations'][idx]
  rgb=d['rgbPercent'][idx];assert max(abs(a-b) for a,b in zip(rgb,patch['rgbPercent']))<1e-8
  color=target.find('c:DeviceColorValues/c:ColorRGB',N)
  assert max(abs(float(color.find('c:'+ch,N).text)/255*100-rgb[j]) for j,ch in enumerate('RGB'))<1e-4, 'Reference target order/RGB differs; refusing ambiguous pairing.'
  measured=copy.deepcopy(byloc[key(target)]);target=copy.deepcopy(target)
  row,letters=re.fullmatch(r'(\d+)([A-Z]+)',patch['sampleLoc']).groups();row=int(row)-1;column=0
  for ch in letters:column=column*26+ord(ch)-64
  column-=1;page=1;localrow=row
  for size in passes:
   if localrow<size:break
   localrow-=size;page+=1
  assert page<=len(passes)
  spectrum=d['spectra'][idx];assert len(spectrum)==36 and all(math.isfinite(x) for x in spectrum)
  for o,kind in [(measured,'M0_Measurement'),(target,'Target')]:
   o.set('ObjectType',kind);o.set('Name',kind+str(idx+1));o.find('c:CreationDate',N).text=now
   for e in o.findall('c:TagCollection[@Name="Location"]/c:Tag',N):
    values={'Column':str(column),'Page':str(page),'Row':str(localrow),'SampleID':str(d['ids'][idx]),'SampleName':letters+str(row+1)}
    e.set('Value',values[e.get('Name')])
  measured.find('c:ColorValues/c:ReflectanceSpectrum',N).text=' '.join(format(x/100,'.17g') for x in spectrum)
  color=target.find('c:DeviceColorValues/c:ColorRGB',N)
  for j,ch in enumerate('RGB'):color.find('c:'+ch,N).text=format(rgb[j]*2.55,'.17g')
  pairs.append(((page,column,localrow),measured,target,idx))
  mapping.append(dict(sampleId=d['ids'][idx],sourceLocation=patch['sampleLoc'],page=page,column=column,row=localrow,xyz=d['xyz'][idx]))
 objects.clear();pairs.sort(key=lambda v:v[0])
 for group in (1,2):
  for _,m,t,idx in pairs:
   o=m if group==1 else t;o.set('Id','c'+str(len(objects)+1));objects.append(o)
 custom=root.find('.//{'+PR+'}CustomAttributes');assert custom is not None
 custom.set('TitleString',output.stem);custom.set('NumberPatchColumns',str(chart['stepsInPass']));custom.set('NumberPatchRows',str(max(passes)));custom.set('NumberPatchPages',str(len(passes)))
 custom.set('SelectedMeasurementCondition','0');custom.set('numberCorePatches',str(count));custom.set('MeasurementDevice','i1Pro 2')
 custom.set('Media_Type','Reflective Media');custom.set('ImagePath','');custom.set('PrinterName','InkProf RGB Printer')
 paper=chart['metadata']['PAPER_SIZE'].split('x');assert len(paper)==2
 custom.set('PageWidth',paper[0]);custom.set('PageHeight',paper[1])
 # The reference's application-specific profile settings are not evidence about this print.
 prism=root.find('c:CustomResources',N)[0]
 for e in list(prism):
  if e is not custom:prism.remove(e)
 output.parent.mkdir(parents=True,exist_ok=True);ET.indent(root)
 # Preserve the known-good outer serialization. Prism's reader may inspect
 # version tags/prefixes before invoking a namespace-aware XML parser.
 raw=template.read_text(encoding='utf-8')
 def replace_block(pattern,value):
  nonlocal raw
  raw,n=re.subn(pattern,lambda _:value,raw,count=1,flags=re.S)
  assert n==1,'Missing template serialization block.'
 def xml(e):return ET.tostring(e,encoding='unicode').replace(' xmlns:cc="'+NS+'"','')
 replace_block(r'<cc:ObjectCollection>.*?</cc:ObjectCollection>',xml(objects))
 replace_block(r'<cc:ColorSpecificationCollection>.*?</cc:ColorSpecificationCollection>',xml(specs))
 match=re.search(r'<([A-Za-z_][\w.-]*):CustomAttributes\b[^>]*?/>',raw)
 assert match is not None
 replacement='<'+match[1]+':CustomAttributes '+' '.join(k+'='+quoteattr(v) for k,v in custom.attrib.items())+'/>'
 replace_block(r'<'+match[1]+r':CustomAttributes\b[^>]*?/>',replacement)
 raw=re.sub(r'<ProfileSettings\b.*?</ProfileSettings>','',raw,flags=re.S)
 raw=re.sub(r'<cc:Creator>[^<]*</cc:Creator>','<cc:Creator>InkProf</cc:Creator>',raw)
 raw=re.sub(r'<cc:CreationDate>[^<]*</cc:CreationDate>','<cc:CreationDate>'+now+'</cc:CreationDate>',raw)
 ET.fromstring(raw)
 with output.open('x',encoding='utf-8') as f:f.write(raw)
 reread=ET.parse(output).getroot();outobjects=reread.findall('c:Resources/c:ObjectCollection/c:Object',N)
 assert len(outobjects)==2*count
 om={key(o):o for o in outobjects if o.get('ObjectType')=='M0_Measurement'}
 ot={key(o):o for o in outobjects if o.get('ObjectType')=='Target'}
 assert len(om)==len(ot)==count and set(om)==set(ot)
 for loc,m,t,idx in pairs:
  color=ot[key(m)].find('c:DeviceColorValues/c:ColorRGB',N)
  assert max(abs(float(color.find('c:'+ch,N).text)/2.55-d['rgbPercent'][idx][j]) for j,ch in enumerate('RGB'))<1e-10
  values=[float(x) for x in om[key(m)].find('c:ColorValues/c:ReflectanceSpectrum',N).text.split()]
  assert max(abs(a*100-b) for a,b in zip(values,d['spectra'][idx]))<1e-10
 report=dict(schemaVersion=1,documentType='inkprof.mxf-export',measurementSHA256=sha(measurement),chartJSONSHA256=sha(chart_path),templateSHA256=sha(template),outputSHA256=sha(output),source=str(measurement.resolve()),patchCount=count,condition='M0 inferred from source native reflection',spectralScaleConversion='TI3 percent / 100 to CxF reflectance factor; no resampling',mapping=mapping,validation='XML roundtrip and all spectra verified; recipient i1Profiler import pending',notes='Standalone full measurement. Separate control/spot sessions are not merged. Reference private profile settings removed; remaining private attributes are template compatibility hints, not verified physical print metadata.')
 output.with_suffix('.json').write_text(json.dumps(report,indent=2))
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('measurement');p.add_argument('template');p.add_argument('output');a=p.parse_args();r=export(a.measurement,a.template,a.output);print(json.dumps({k:r[k] for k in ('patchCount','validation','outputSHA256')}))
