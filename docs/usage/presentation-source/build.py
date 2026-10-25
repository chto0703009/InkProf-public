# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
from pathlib import Path
import json, os, sys
from xml.sax.saxutils import escape
import reportlab
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Flowable, Image, Preformatted
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor, white
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
ROOT=Path(__file__).resolve().parent
VERSION=(ROOT.parents[2]/'VERSION').read_text().strip()
LANG=sys.argv[1] if len(sys.argv)>1 else 'en'
if LANG not in ('en','sv'):raise ValueError('Supported languages: en, sv.')
OUT=Path(sys.argv[2]) if len(sys.argv)>2 else ROOT.parent/('InkProf-presentation-svenska.pdf' if LANG=='sv' else 'InkProf-presentation-English.pdf')
OUT.parent.mkdir(parents=True,exist_ok=True)
fontdir=Path(reportlab.__file__).parent/'fonts'
for name,file in [('Vera','Vera.ttf'),('VeraBold','VeraBd.ttf')]: pdfmetrics.registerFont(TTFont(name,str(fontdir/file)))
pdfmetrics.registerFontFamily('Vera',normal='Vera',bold='VeraBold',italic='Vera',boldItalic='VeraBold')
INK=HexColor('#182F42');TEAL=HexColor('#007F83');MUTED=HexColor('#50616C');PALE=HexColor('#EDF5F5');LINE=HexColor('#D3E1E5')
S={k:ParagraphStyle(k,fontName=f,fontSize=z,leading=l,textColor=c,spaceAfter=a,spaceBefore=b,keepWithNext=k in ('title','h','tag')) for k,f,z,l,c,a,b in [('title','VeraBold',24,29,INK,13,0),('tag','VeraBold',8.5,12,TEAL,7,0),('lead','Vera',11.4,16,INK,12,0),('h','VeraBold',11,15,INK,4,9),('body','Vera',9.7,14,INK,7,0),('cell','Vera',8.4,11.7,INK,0,0),('small','Vera',8.2,11.5,MUTED,5,0)]}
pdfmetrics.registerFont(TTFont('Greek',str(ROOT.parents[2]/'resources/fonts/DejaVuSans.ttf')))
compact=False
SOURCE=Path(sys.argv[3]) if len(sys.argv)>3 else ROOT/(LANG+'.json')
CONTENT=json.loads(SOURCE.read_text())
PRINTED_URL=any(page.get('printedURL') for page in CONTENT)
for key,base in list(S.items()):
 S['compact-'+key]=ParagraphStyle('compact-'+key,parent=base,fontSize=base.fontSize*.94,leading=base.leading*.91,spaceAfter=base.spaceAfter*.75,spaceBefore=base.spaceBefore*.65)
def p(t,k='body'):
 return Paragraph(t.replace('Δ','<font name="Greek">Δ</font>').replace('\n','<br/>'),S['compact-'+k if compact else k])
class TargetExample(Flowable):
 def __init__(self,path,width,height):
  super().__init__();self.path=path;self.width=width;self.height=height
 def draw(self):
  c=self.canv;c.saveState();clip=c.beginPath();clip.rect(0,14*mm,self.width,self.height-28*mm)
  c.clipPath(clip,stroke=0);c.drawImage(str(self.path),0,0,width=self.width,height=self.height);c.restoreState()
  c.setFillColor(INK);c.setFont('VeraBold',9)
  c.drawCentredString(self.width/2,self.height-7*mm,'InkProf quality profiling of an RGB inkjet printer')

class Pages(canvas.Canvas):
 def __init__(self,*a,**kw):super().__init__(*a,**kw);self.states=[]
 def showPage(self):self.states.append(dict(self.__dict__));self._startPage()
 def save(self):
  n=len(self.states);ann=self._annotationCount
  for st in self.states:
   self.__dict__.update(st);self._annotationCount=ann
   self.setFont('VeraBold',10);self.setFillColor(INK);self.drawCentredString(105*mm,283*mm,('InkProf - Kvalitetsprofilering för RGB-skrivare | ' if LANG=='sv' else 'InkProf - Quality profiling for RGB printers | ')+VERSION)
   self.setFillColor(MUTED)
   self.setStrokeColor(LINE);self.setLineWidth(.6)
   self.line(18*mm,273.5*mm,192*mm,273.5*mm);self.line(18*mm,22*mm,192*mm,22*mm)
   self.setFont('Vera',8);self.drawString(18*mm,16*mm,'2026-10-25');self.drawCentredString(105*mm,16*mm,'Christer Törnkvist');self.drawRightString(192*mm,16*mm,f'{self._pageNumber} ({n})')
   self.setFillColor(TEAL);self.drawCentredString(105*mm,11*mm,'christer@borgasundsfotografiska.se')
   url='https://github.com/chto0703009/InkProf-public';self.setFont('Vera',7);self.drawCentredString(105*mm,6*mm,url if PRINTED_URL else 'GitHub | InkProf v'+VERSION);self.linkURL(url,(45*mm,4*mm,165*mm,9*mm),relative=0)
   ann=self._annotationCount;super().showPage()
  sys.path.insert(0,str(ROOT.parents[2]/'analysis'))
  from pdf_notices import attach
  attach(self)
  super().save()
def table(rows):
 n=len(rows[0]);widths=([15,81,78] if n==3 else [51,123]);t=Table([[p(escape(v),'cell') for v in r] for r in rows],colWidths=[w*mm for w in widths],repeatRows=1,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),PALE),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.4,LINE),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4)]));return t
story=[]
for i,page in enumerate(CONTENT):
 compact=bool(page.get('compact'))
 if i:story.append(PageBreak())
 story.extend([p(escape(page['tag']),'tag'),p(escape(page['title']),'title')])
 if page.get('lead'):story.append(p(escape(page['lead']),'lead'))
 if page.get('requirements'):
  box=Table([[p(escape(page['requirementsTitle']),'h')],[p(escape(page['requirements']))]],colWidths=[174*mm])
  box.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),.5,LINE),('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9)]));story.extend([box,Spacer(1,3*mm)])
 if page.get('rows'):story.extend([table(page['rows']),Spacer(1,3*mm)])
 for filename,w,h,caption in page.get('images',[]):
  picture=TargetExample(ROOT/filename,w*mm,h*mm) if page.get('targetExample') else Image(str(ROOT/filename),width=w*mm,height=h*mm,kind='proportional')
  story.extend([picture,Spacer(1,2*mm),p(escape(caption),'small'),Spacer(1,2*mm)])
 for title,body in page.get('sections',[]):story.extend([p(escape(title),'h'),p(escape(body))])
 for code in page.get('codeBlocks',[]):
  story.extend([Preformatted(code,ParagraphStyle('command',fontName='Courier',fontSize=10,leading=15,textColor=INK,backColor=PALE,borderPadding=8)),Spacer(1,4*mm)])
 if page.get('callout'):
  t=Table([[p(escape(page['callout']))]],colWidths=[174*mm]);t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),.5,LINE),('LEFTPADDING',(0,0),(-1,-1),11),('RIGHTPADDING',(0,0),(-1,-1),11),('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),6)]));story.extend([Spacer(1,4*mm),t])
 if page.get('small'):story.append(p(escape(page['small']),'small'))
 for label,url in page.get('links',[]):story.append(p(f'<link href="{url}" color="#007F83">{escape(label)}</link>','small'))
doc=SimpleDocTemplate(str(OUT),pagesize=(210*mm,297*mm),leftMargin=18*mm,rightMargin=18*mm,topMargin=32*mm,bottomMargin=29*mm,title='InkProf - Presentation',author='Christer Törnkvist',subject='Why colour matters, the InkProf workflow and documented results')
doc.build(story,canvasmaker=Pages)
print(OUT)
