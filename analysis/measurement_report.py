# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
import json,re,hashlib,shutil
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4,landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Table,TableStyle

import argparse
import reportlab
import numpy as np
import colour
from target_check import check_target
parser=argparse.ArgumentParser(description="Export a complete InkProf measurement and spectral analysis to PDF.")
parser.add_argument("measurement",type=Path)
parser.add_argument("analysis",type=Path)
parser.add_argument("output",type=Path)
parser.add_argument('--target-warning-threshold',type=float,default=20.0)
args=parser.parse_args()
if args.output.exists() or args.output.with_suffix('.target-check.json').exists(): raise ValueError("Output exists; choose a new PDF filename.")
folder=args.measurement.resolve().parent
a=json.loads(args.analysis.read_text());m=json.loads(args.measurement.read_text())
assert a['documentType']=='inkprof.spectral-analysis' and m['documentType']=='inkprof.chart-measurement'
assert a['source']['sha256']==hashlib.sha256(args.measurement.read_bytes()).hexdigest(), 'Analysis belongs to a different measurement'
d=m['data'];assert d['ids']==a['data']['ids'] and d['locations']==a['data']['locations'], 'Patch identities do not match'
chart=json.loads((folder/'chart.json').read_text())
layout_source=Path(chart['sourcePath'])
for ancestor in [folder,*folder.parents]:
 manifest=ancestor/'inkprof-project.json'
 if manifest.exists():
  project=json.loads(manifest.read_text());relocations=project.get('relocations',[])
  if isinstance(relocations,dict):relocations=[relocations]
  for item in relocations:
   try:tail=layout_source.relative_to(item['originalRoot'])
   except ValueError:continue
   layout_source=ancestor/item['projectRelativeRoot']/tail;break
  break
layout_path=layout_source.parent/'layout.json'
lookup={}
if layout_path.exists():
 layout=json.loads(layout_path.read_text());lookup={p['location']:p for p in layout['patches']}
page_rows=[]
passes=chart['passesInStrips'];passes=passes if isinstance(passes,list) else [passes]
for page_num,count in enumerate(passes,1):page_rows.extend([page_num]*int(count))
groups={}
for i,loc in enumerate(d['locations']):
 match=re.fullmatch(r'(\d+)([A-Z]+)',loc)
 if not match:raise ValueError('Unsupported coordinate: '+loc)
 row=int(match[1]);coord=match[2]+match[1]
 if loc not in lookup:lookup[loc]={'sampleId':d['ids'][i],'coordinate':coord,'page':page_rows[row-1],'strip':row}
 p=lookup[loc];assert p['sampleId']==d['ids'][i];groups.setdefault((p['page'],int(p['strip'])),[]).append(i)
assert len(set(d['ids']))==len(d['ids'])
xyz=np.asarray(d['xyz']);new=np.asarray(a['data']['xyz100'])
observer=colour.MSDS_CMFS['CIE 1931 2 Degree Standard Observer']
# Stored chartread XYZ is D50/2. Do not compare it with another analysis condition.
assert a['calculation']['illuminant']=='D50' and a['calculation']['observer']=='1931_2', 'This report comparison requires D50 / 1931_2'
wp=colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
de=colour.difference.delta_E_CIE2000(colour.XYZ_to_Lab(xyz/100,wp),colour.XYZ_to_Lab(new/100,wp))
check={'patchDeltaE00':de.tolist()}
target=check_target(chart,d,new,args.target_warning_threshold)
target['measurementSHA256']=hashlib.sha256(args.measurement.read_bytes()).hexdigest()
target['analysisSHA256']=hashlib.sha256(args.analysis.read_bytes()).hexdigest()
previews=np.clip(colour.XYZ_to_sRGB(new/100, illuminant=np.asarray(a['calculation']['whiteXY']), chromatic_adaptation_transform='Bradford'),0,1)
assert np.isfinite(previews).all(), 'Nonfinite preview colour'
pdfmetrics.registerFont(TTFont('Arial',str(Path(reportlab.__file__).parent/'fonts'/'Vera.ttf')));pdfmetrics.registerFont(TTFont('Arial-Bold',str(Path(reportlab.__file__).parent/'fonts'/'VeraBd.ttf')))
out=args.output;c=canvas.Canvas(str(out),pagesize=landscape(A4));c.setTitle(f'InkProf - mätrapport, {len(d["ids"])} patchar');W,H=landscape(A4);total=1+len(groups);page=0
navy=colors.HexColor('#183847');gray=colors.HexColor('#526570')
def txt(x,y,s,size=10,bold=False,color=navy):
 c.setFillColor(color);c.setFont('Arial-Bold' if bold else 'Arial',size);c.drawString(x,y,s)
def begin(title,subtitle):
 global page
 page+=1;txt(32,H-37,'InkProf  |  Mätprotokoll',11,True);txt(32,H-68,title,21,True);txt(32,H-89,subtitle,9)
 c.setStrokeColor(colors.HexColor('#CBD7DD'));c.line(32,35,W-32,35);txt(32,21,'D50 / CIE 1931 2°  |  '+args.measurement.name,8)
 c.setFont('Arial',8);c.drawRightString(W-32,21,f'{page} ({total})')
def table(data,top,widths,size=8,height=17):
 t=Table(data,colWidths=widths,rowHeights=[height]*len(data));t.setStyle(TableStyle([('FONTNAME',(0,0),(-1,-1),'Arial'),('FONTNAME',(0,0),(-1,0),'Arial-Bold'),('FONTSIZE',(0,0),(-1,-1),size),('BACKGROUND',(0,0),(-1,0),navy),('TEXTCOLOR',(0,0),(-1,0),colors.white),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#EFF4F6')]),('ALIGN',(0,0),(-1,-1),'RIGHT'),('ALIGN',(0,0),(1,-1),'LEFT'),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('LEFTPADDING',(0,0),(-1,-1),4),('RIGHTPADDING',(0,0),(-1,-1),4)]));t.wrap(W,H);t.drawOn(c,32,top-height*len(data))
begin(f'{len(d["ids"])} patchar - fullständigt mätunderlag','XYZ, Lab, färgprover och beräkningskontroll')
lines=[('Omfattning',f'{len(d["ids"])} uppmätta patchar; {len(groups)} rader.'),
('Koordinater','Bokstav och radnummer, exempelvis A4. Utskriftssida anges i sidrubrikerna.'),
('Färgvärden','Beräknat XYZ/Lab och originalets XYZ. Alla tillförda mätrader ingår.'),
('Färgprover','Ungefärlig sRGB-visning av beräknat XYZ, adapterat till D65 med Bradford. Utanför sRGB klipps.'),
('Beräkning','Linjär interpolation, trapezoidintegration på mätintervallet. Ingen extrapolation.'),
('Lab-vitpunkt',', '.join(f'{v:.4f}' for v in a['calculation']['whiteXYZ100'])),
('dE00','Omräknat XYZ jämfört med sparat XYZ, båda konverterade med standardvitpunkt D50.'),
('Tolkning','Detta är beräkningsöverensstämmelse, inte profilfel eller färgfel mot ett referensmål.'),
('Resultat',f'Medel {de.mean():.4f}; 95-percentil {np.percentile(de,95):.4f}; maximum {de.max():.4f} dE00.'),
('TI2-kontroll',f"Gräns {args.target_warning_threshold:g} dE00: {target['flaggedCount']} flaggade patchar." if target['available'] else target['reason']),
('TI2-vitpunkt','APPROX_WHITE_POINT används som antagen referensvit; Bradford-adaptation till D50.'),
('Mätvillkor',str(m.get('measurementCondition',{}).get('interpreted','unknown'))),
('Begränsningar','Ingen fluorescenskompensation. Värden över 100 % bevaras. Se även analysfilens varningar.')]
y=H-120
for title,text in lines:txt(32,y,title,9,True);txt(135,y,text,8);y-=23
txt(32,y-10,'Mätfil: '+args.measurement.name,8)
txt(32,y-28,'Analysfil: '+args.analysis.name,8)
txt(32,y-46,'SHA256: '+hashlib.sha256(args.measurement.read_bytes()).hexdigest(),7)
c.showPage()
for (sheet,row),idx in sorted(groups.items()):
 begin(f'Färgvärden | Utskriftssida {sheet}, rad {row}',f'{len(idx)} patchar. XYZ på skalan Y=100. Beräknade värden = B, sparade Argyll-värden = A.')
 head=['Koord.','ID','Färg','X B','Y B','Z B','L* B','a* B','b* B','X A','Y A','Z A','dE ber.','dE TI2']
 rows=[head]
 for i in idx:
  p=lookup[d['locations'][i]];vals=a['data']['xyz100'][i]+a['data']['lab'][i]+d['xyz'][i]+[check['patchDeltaE00'][i]]
  rows.append([p['coordinate'],d['ids'][i],'']+[f'{v:.3f}' for v in vals]+[(f"{target['patchDeltaE00'][i]:.2f}"+(' !' if target['flagged'][i] else '')) if target['available'] else '-'])
 widths=[44,32,44]+[(W-64-120)/11]*11
 height=min(18,420/(len(idx)+1));top=H-112
 table(rows,top,widths,8,height)
 for ordinal,i in enumerate(idx,1):
  if target['available'] and target['flagged'][i]:
   c.setStrokeColor(colors.HexColor('#BF4020'));c.setLineWidth(1);c.line(W-32-widths[-1],top-(ordinal+1)*height+1,W-32,top-(ordinal+1)*height+1)
  rgb=previews[i];c.setFillColor(colors.Color(*rgb));c.setStrokeColor(colors.HexColor('#808080'))
  c.rect(32+44+32+7,top-(ordinal+1)*height+3,30,height-6,fill=1,stroke=1)
 txt(32,57,f'! = dE TI2 > {args.target_warning_threshold:g}. Grovkontroll mot uppskattade färger, inte profilfel. Färgrutan är en sRGB-förhandsvisning.',8)
 c.showPage()
from pdf_notices import attach
attach(c)
c.save()
sidecar=out.with_suffix('.target-check.json')
with sidecar.open('x') as handle:json.dump(target,handle,indent=2,allow_nan=False)
print(json.dumps({'outputPath':str(out.resolve()),'pages':total,'patches':len(d['ids'])}))
