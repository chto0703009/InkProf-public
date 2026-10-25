# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
from pathlib import Path
import re,html,shutil,hashlib
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,PageBreak,Table,TableStyle,Image,Flowable
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT
ROOT=Path(__file__).resolve().parents[2]
VERSION=(ROOT/'VERSION').read_text().strip()
pdfmetrics.registerFont(TTFont('Body',str(ROOT/'resources/fonts/DejaVuSans.ttf')))
bold=Path('/System/Library/Fonts/Supplemental/Arial Bold.ttf')
pdfmetrics.registerFont(TTFont('Head',str(bold)))
C=colors.HexColor('#153b50');ACC=colors.HexColor('#0e7c86')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='BodyDoc',fontName='Body',fontSize=9.2,leading=13.3,spaceAfter=9,textColor=colors.HexColor('#23323b'),splitLongWords=True))
styles.add(ParagraphStyle(name='HeadDoc',fontName='Head',fontSize=19,leading=23,spaceAfter=17,textColor=C,keepWithNext=True))
styles.add(ParagraphStyle(name='CoverDoc',fontName='Head',fontSize=32,leading=38,spaceAfter=25,textColor=C,keepWithNext=True))
styles.add(ParagraphStyle(name='CellDoc',fontName='Body',fontSize=8.1,leading=11,spaceAfter=0,splitLongWords=True))
styles.add(ParagraphStyle(name='SubheadDoc',fontName='Head',fontSize=11,leading=15,spaceBefore=8,spaceAfter=5,textColor=C,keepWithNext=True))
styles.add(ParagraphStyle(name='CaptionDoc',fontName='Body',fontSize=7.8,leading=10.5,spaceAfter=12,textColor=colors.HexColor('#51636e')))
def inline(s):
 s=html.escape(s)
 s=re.sub(r'`([^`]+)`',r'<font color="#075b6c">\1</font>',s)
 s=re.sub(r'(https://[^\s]+)',lambda m:'<link href="'+m[1].rstrip('.')+'" color="#075b6c">'+m[1]+'</link>',s)
 return s
class Flow(Flowable):
 def __init__(self,sv):super().__init__();self.width=487;self.height=163;self.sv=sv
 def draw(self):
  cv=self.canv
  labels=(['RGB-definition','Utskrift / mätning','Låst indata / recept','ICC-bygge','Fit / Grid / C1','C2-utskrift / C3'] if self.sv else ['RGB definition','Print / measure','Locked input / recipe','ICC build','Fit / Grid / C1','C2 print / C3'])
  for i,t in enumerate(labels):
   row=i//3;col=i%3;x=col*165;y=108-row*77
   cv.setFillColor(colors.HexColor('#eaf3f5'));cv.setStrokeColor(ACC);cv.roundRect(x,y,151,42,5,fill=1,stroke=1)
   cv.setFillColor(C);cv.setFont('Head',9);cv.drawCentredString(x+75.5,y+17,t)
   if col<2:
    cv.setStrokeColor(ACC);cv.line(x+151,y+21,x+163,y+21)
  cv.setFont('Body',8);cv.drawString(0,7,'Data + identitet + SHA-256' if self.sv else 'Data + identity + SHA-256')
def footer(cv,doc):
 cv.saveState();cv.setStrokeColor(colors.HexColor('#bad0d7'));cv.line(54,50,541,50)
 cv.setFont('Body',7);cv.setFillColor(C);cv.drawString(54,39,f'InkProf {VERSION} | 2026-10-25');cv.drawRightString(541,39,str(doc.page))
 cv.setFont('Body',6.6);cv.drawString(54,27,'christer@borgasundsfotografiska.se | https://github.com/chto0703009/InkProf-public');cv.restoreState()
def build(lang):
 path=ROOT/'docs'/f'TECHNICAL_DESCRIPTION_{lang}.md';lines=path.read_text().splitlines();story=[];i=0
 while i<len(lines):
  s=lines[i].strip();i+=1
  if not s:continue
  if s=='---PAGE---':story.append(PageBreak());continue
  if s=='[FLOW]':story.extend([Flow(lang=='SV'),Spacer(1,10)]);continue
  if s.startswith('# '):story.extend([Spacer(1,44),Paragraph(inline(s[2:]),styles['CoverDoc'])]);continue
  if s.startswith('### '):story.append(Paragraph(inline(s[4:]),styles['SubheadDoc']));continue
  if s.startswith('## '):story.append(Paragraph(inline(s[3:]),styles['HeadDoc']));continue
  if s.startswith('!['):
   f=ROOT/re.search(r'\]\((.+)\)',s)[1];im=Image(str(f));scale=min(487/im.imageWidth,198/im.imageHeight);im.drawWidth=im.imageWidth*scale;im.drawHeight=im.imageHeight*scale;im.hAlign='CENTER';story.extend([im,Spacer(1,7)]);continue
  if s.startswith('|'):
   rows=[s]
   while i<len(lines) and lines[i].strip().startswith('|'):rows.append(lines[i].strip());i+=1
   data=[]
   for row in rows:
    cells=[t.strip() for t in row.strip('|').split('|')]
    if all(re.fullmatch(r'[- :]+',v) for v in cells):continue
    data.append([Paragraph(inline(c),styles['CellDoc']) for c in cells])
   n=len(data[0]);widths=[148,339] if n==2 else [76,200,211]
   t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
   t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#d9e9ee')),('VALIGN',(0,0),(-1,-1),'TOP'),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#f3f7f8')]),('LINEBELOW',(0,0),(-1,0),.6,ACC),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),4 if len(data)>15 else 6),('BOTTOMPADDING',(0,0),(-1,-1),4 if len(data)>15 else 6)]));story.extend([t,Spacer(1,14)]);continue
  group=[s]
  while i<len(lines) and lines[i].strip() and not lines[i].startswith(('##','---PAGE---','|','![')):
   group.append(lines[i].strip());i+=1
  text=' '.join(group);st=styles['CaptionDoc'] if text.startswith(('Figure ','Figur ')) else styles['BodyDoc'];story.append(Paragraph(inline(text),st))
 out=ROOT/'docs/usage'/('InkProf_Technical_Description_EN.pdf' if lang=='EN' else 'InkProf_Teknisk_beskrivning_SV.pdf')
 doc=SimpleDocTemplate(str(out),pagesize=(595.276,841.89),leftMargin=54,rightMargin=54,topMargin=53,bottomMargin=66,title='InkProf - '+('Technical description' if lang=='EN' else 'Teknisk beskrivning'),author='Christer Törnkvist',subject=f'InkProf {VERSION} technical architecture and data contracts')
 doc.build(story,onFirstPage=footer,onLaterPages=footer)
 print(out)
if __name__=='__main__':
 for lang in ['SV','EN']:build(lang)
