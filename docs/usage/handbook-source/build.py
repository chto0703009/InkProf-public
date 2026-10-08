# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
from pathlib import Path
import json, os, sys
from xml.sax.saxutils import escape
import reportlab
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Flowable
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor, white
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
ROOT=Path(__file__).resolve().parent
LANG=sys.argv[2] if len(sys.argv)>2 else 'en'
if LANG not in ('sv','en'):raise ValueError('Language must be sv or en.')
def local(sv,en):return sv if LANG=='sv' else en
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parent/('InkProf-anvandarhandbok.pdf' if LANG=='sv' else 'InkProf-user-handbook-English.pdf')
OUT.parent.mkdir(parents=True,exist_ok=True)
fontdir=Path(reportlab.__file__).parent/'fonts'
for name,file in [('Vera','Vera.ttf'),('VeraBold','VeraBd.ttf')]: pdfmetrics.registerFont(TTFont(name,str(fontdir/file)))
pdfmetrics.registerFontFamily('Vera',normal='Vera',bold='VeraBold',italic='Vera',boldItalic='VeraBold')
INK=HexColor('#182F42');TEAL=HexColor('#007F83');MUTED=HexColor('#50616C');PALE=HexColor('#EDF5F5');LINE=HexColor('#D3E1E5')
S={k:ParagraphStyle(k,fontName=f,fontSize=z,leading=l,textColor=c,spaceAfter=a,spaceBefore=b,keepWithNext=k in ('title','h','tag')) for k,f,z,l,c,a,b in [('title','VeraBold',24,29,INK,13,0),('tag','VeraBold',8.5,12,TEAL,7,0),('lead','Vera',11.4,16,INK,12,0),('h','VeraBold',11,15,INK,4,9),('body','Vera',9.7,14,INK,7,0),('cell','Vera',8.4,11.7,INK,0,0),('small','Vera',8.2,11.5,MUTED,5,0)]}
pdfmetrics.registerFont(TTFont('Greek',str(ROOT.parents[2]/'resources/fonts/DejaVuSans.ttf')))
def p(t,k='body'):return Paragraph(t.replace('Δ','<font name="Greek">Δ</font>'),S[k])
class Pages(canvas.Canvas):
 def __init__(self,*a,**kw):super().__init__(*a,**kw);self.states=[]
 def showPage(self):self.states.append(dict(self.__dict__));self._startPage()
 def save(self):
  n=len(self.states);ann=self._annotationCount
  for st in self.states:
   self.__dict__.update(st);self._annotationCount=ann
   self.setFont('VeraBold',11);self.setFillColor(INK);self.drawCentredString(105*mm,283*mm,'InkProf Quality Profiling RGB printer | 1.0.0-rc.2')
   self.setFont('Vera',7.7);self.setFillColor(MUTED);self.drawCentredString(105*mm,277.5*mm,'Christer Törnkvist  |  christer@borgasundsfotografiska.se')
   self.setStrokeColor(LINE);self.setLineWidth(.6)
   self.line(18*mm,273.5*mm,192*mm,273.5*mm);self.line(18*mm,22*mm,192*mm,22*mm)
   self.setFont('Vera',8);self.drawString(18*mm,16*mm,'2026-10-08');self.drawCentredString(105*mm,16*mm,'Christer Törnkvist');self.drawRightString(192*mm,16*mm,f'{self._pageNumber} ({n})')
   self.setFillColor(TEAL);self.drawCentredString(105*mm,11*mm,'christer@borgasundsfotografiska.se')
   url='https://github.com/chto0703009/InkProf-public';self.setFont('Vera',7);self.drawCentredString(105*mm,6*mm,url);self.linkURL(url,(45*mm,4*mm,165*mm,9*mm),relative=0)
   ann=self._annotationCount;super().showPage()
  sys.path.insert(0,str(ROOT.parents[2]/'analysis'))
  from pdf_notices import attach
  attach(self)
  super().save()
class Diagram(Flowable):
 def __init__(self):Flowable.__init__(self);self.width=174*mm;self.height=59*mm
 def draw(self):
  c=self.canv
  def box(x,y,w,h,txt,bg=PALE):
   c.setFillColor(bg);c.setStrokeColor(LINE);c.roundRect(x*mm,y*mm,w*mm,h*mm,2*mm,fill=1,stroke=1)
   q=p(txt,'cell');qw,qh=q.wrap((w-6)*mm,h*mm);q.drawOn(c,(x+3)*mm,(y+h)*mm-qh-3*mm)
  box(0,43,174,14,local('<b>Projektverktyg</b> | namn, inställningar, logg, historik och rapport','<b>Project tools</b> | name, settings, log, history and report'))
  box(0,9,63,31,local('<b>Vänster: steg 1-19</b><br/>Välj rad.<br/>Läs statusen.','<b>Left: steps 1-19</b><br/>Select a row.<br/>Read the status.'))
  box(66,9,108,31,local('<b>Höger: valt steg</b><br/>Beskrivning och sparade resultat.<br/>Kör steget eller öppna resultatet.','<b>Right: selected step</b><br/>Description and saved results.<br/>Run the step or open its result.'))
  c.setFillColor(MUTED);c.setFont('Vera',7.5);c.drawString(0,1*mm,local('Schematisk läshjälp, inte skärmbild. Status och aktivitet visas också i appen.','Schematic guide, not a screenshot. The app also displays status and activity.'))
def table(rows):
 n=len(rows[0]);widths=([15,81,78] if n==3 else [51,123]);t=Table([[p(escape(v),'cell') for v in r] for r in rows],colWidths=[w*mm for w in widths],repeatRows=1,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),PALE),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.4,LINE),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4)]));return t
story=[]
for i,page in enumerate(json.loads((ROOT/f'content-{LANG}.json').read_text())):
 if i:story.append(PageBreak())
 story.extend([p(escape(page['tag']),'tag'),p(escape(page['title']),'title')])
 if page.get('lead'):story.append(p(escape(page['lead']),'lead'))
 if page.get('diagram'):story.extend([Diagram(),Spacer(1,3*mm)])
 if page.get('rows'):story.extend([table(page['rows']),Spacer(1,3*mm)])
 for title,body in page.get('sections',[]):story.extend([p(escape(title),'h'),p(escape(body))])
 if page.get('callout'):
  t=Table([[p(escape(page['callout']))]],colWidths=[174*mm]);t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),.5,LINE),('LEFTPADDING',(0,0),(-1,-1),11),('RIGHTPADDING',(0,0),(-1,-1),11),('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),6)]));story.extend([Spacer(1,4*mm),t])
 for label,url in page.get('links',[]):story.append(p(f'<link href="{url}" color="#007F83">{escape(label)}</link>','small'))
doc=SimpleDocTemplate(str(OUT),pagesize=(210*mm,297*mm),leftMargin=18*mm,rightMargin=18*mm,topMargin=32*mm,bottomMargin=29*mm,title=local('InkProf - Användarhandbok','InkProf - User Handbook'),author='Christer Törnkvist',subject='App windows, workflow steps, measurements, iterations and measurement certificates')
doc.build(story,canvasmaker=Pages)
print(OUT)
