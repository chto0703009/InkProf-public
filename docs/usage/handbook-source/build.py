# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
from pathlib import Path
import json, os, sys
from xml.sax.saxutils import escape
import reportlab
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Flowable, Image
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor, white
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
ROOT=Path(__file__).resolve().parent
VERSION=(ROOT.parents[2]/'VERSION').read_text().strip()
DATE='2026-10-10'
LANG=sys.argv[2] if len(sys.argv)>2 else 'en'
if LANG not in ('sv','en'):raise ValueError('Language must be sv or en.')
def local(sv,en):return sv if LANG=='sv' else en
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parent/('InkProf-anvandarhandbok-svenska.pdf' if LANG=='sv' else 'InkProf-user-handbook-English.pdf')
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
   if self._pageNumber==1:
    super().showPage()
    continue
   self.setFont('VeraBold',11);self.setFillColor(INK);self.drawCentredString(105*mm,283*mm,'InkProf Quality Profiling RGB printer | '+VERSION)
   self.setFillColor(MUTED)
   self.setStrokeColor(LINE);self.setLineWidth(.6)
   self.line(18*mm,273.5*mm,192*mm,273.5*mm);self.line(18*mm,22*mm,192*mm,22*mm)
   self.setFont('Vera',8);self.drawString(18*mm,16*mm,DATE);self.drawCentredString(105*mm,16*mm,'Christer Törnkvist');self.drawRightString(192*mm,16*mm,f'{self._pageNumber-1} ({n-1})')
   self.setFillColor(TEAL);self.drawCentredString(105*mm,11*mm,'christer@borgasundsfotografiska.se')
   url='https://github.com/chto0703009/InkProf-public';self.setFont('Vera',7);self.drawCentredString(105*mm,6*mm,'GitHub | InkProf v'+VERSION);self.linkURL(url,(45*mm,4*mm,165*mm,9*mm),relative=0)
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
class OverviewDiagram(Flowable):
 def __init__(self):Flowable.__init__(self);self.width=174*mm;self.height=49*mm
 def draw(self):
  c=self.canv
  labels=[local('1. Projekt och färgmål','1. Project and target'),local('2. Skriv ut, torka, mät','2. Print, dry, measure'),local('3. Bygg och kontrollera ICC','3. Build and check ICC'),local('4. Verifiera utskriften','4. Verify the print'),local('5. Förbättra vid behov','5. Improve if needed'),local('6. Godkänn och spara','6. Approve and save')]
  positions=[(0,29),(61,29),(122,29),(0,4),(61,4),(122,4)]
  for label,(x,y) in zip(labels,positions):
   c.setFillColor(PALE);c.setStrokeColor(LINE);c.roundRect(x*mm,y*mm,52*mm,13*mm,2*mm,fill=1,stroke=1)
   q=p('<b>'+label+'</b>','cell');_,h=q.wrap(46*mm,13*mm);q.drawOn(c,(x+3)*mm,(y+6.5)*mm-h/2)
  def arrow(points):
   c.setStrokeColor(TEAL);c.setFillColor(TEAL);c.setLineWidth(.9)
   for a,b in zip(points,points[1:]):c.line(a[0]*mm,a[1]*mm,b[0]*mm,b[1]*mm)
   a,b=points[-2:];dx=b[0]-a[0];dy=b[1]-a[1];n=(dx*dx+dy*dy)**.5;ux,uy=dx/n,dy/n
   path=c.beginPath();path.moveTo(b[0]*mm,b[1]*mm);path.lineTo((b[0]-2*ux-uy)*mm,(b[1]-2*uy+ux)*mm);path.lineTo((b[0]-2*ux+uy)*mm,(b[1]-2*uy-ux)*mm);path.close();c.drawPath(path,fill=1,stroke=0)
  for y in [35.5,10.5]:
   for x in [52,113]:arrow([(x,y),(x+9,y)])
  arrow([(148,29),(148,23),(26,23),(26,17)])
  c.setFillColor(MUTED);c.setFont('Vera',7.5);c.drawCentredString(87*mm,0,local('Efter förbättring: bygg igen och verifiera med en ny utskrift (steg 3–4).','After improvement: rebuild and verify with a fresh print (steps 3–4).'))

class WorkflowDiagram(Flowable):
 def __init__(self):Flowable.__init__(self);self.width=174*mm;self.height=160*mm
 def draw(self):
  c=self.canv
  def box(y,title,detail,x=0,w=119,h=13):
   c.setFillColor(PALE);c.setStrokeColor(LINE);c.roundRect(x*mm,y*mm,w*mm,h*mm,2*mm,fill=1,stroke=1)
   q=p('<b>'+title+'</b><br/>'+detail,'cell');_,qh=q.wrap((w-6)*mm,h*mm);q.drawOn(c,(x+3)*mm,(y+h)*mm-qh-2*mm)
  def arrow(points):
   c.setStrokeColor(TEAL);c.setLineWidth(1)
   for a,b in zip(points,points[1:]):c.line(a[0]*mm,a[1]*mm,b[0]*mm,b[1]*mm)
   a,b=points[-2:];dx=b[0]-a[0];dy=b[1]-a[1];length=(dx*dx+dy*dy)**.5;ux,uy=dx/length,dy/length
   path=c.beginPath();path.moveTo(b[0]*mm,b[1]*mm);path.lineTo((b[0]-ux*2-uy)*mm,(b[1]-uy*2+ux)*mm);path.lineTo((b[0]-ux*2+uy)*mm,(b[1]-uy*2-ux)*mm);path.close();c.setFillColor(TEAL);c.drawPath(path,fill=1,stroke=0)
  labels=[
   (local('1. Planera projekt och grundmål','1. Plan project and base target'),local('Villkor, kriterier; start-ICC om lämplig','Conditions, criteria; starting ICC if suitable')),
   (local('2. Skriv ut, torka och mät','2. Print, dry and measure'),local('Oförändrat mål-RGB; rätt TI2; kalibrering','Unchanged target RGB; matching TI2; calibration')),
   (local('3. Granska och lås underlaget','3. Review and lock inputs'),local('Mätrevision, B1 och dokumenterat OBA-beslut','Measurement revision, B1 and recorded OBA decision')),
   (local('4. Bygg och kontrollera ICC','4. Build and check ICC'),local('Recept, B3, numerisk kontroll och gradienter','Recipe, B3, numerical checks and gradients')),
   (local('5. Verifiera slutprofilens utskrift','5. Verify the final profile in print'),local('Ny C2-utskrift, mätning, C3 och helhetsbedömning','Fresh C2 print, measurement, C3 and overall assessment'))]
  for i,(title,detail) in enumerate(labels):box(142-i*20,title,detail)
  for y in [142,122,102,82]:arrow([(59.5,y),(59.5,y-7)])
  y=42;path=c.beginPath();path.moveTo(0*mm,(y+6.5)*mm);path.lineTo(59.5*mm,(y+15)*mm);path.lineTo(119*mm,(y+6.5)*mm);path.lineTo(59.5*mm,(y-2)*mm);path.close();c.setFillColor(PALE);c.setStrokeColor(TEAL);c.drawPath(path,fill=1,stroke=1)
  c.setFillColor(INK);c.setFont('VeraBold',8.4);c.drawCentredString(59.5*mm,(y+5)*mm,local('Godkänd för avsedd användning?','Approved for intended use?'))
  arrow([(59.5,62),(59.5,57)]);arrow([(59.5,40),(59.5,35)])
  c.setFont('Vera',8);c.setFillColor(TEAL);c.drawString(64*mm,37*mm,local('Ja','Yes'))
  box(22,local('6. Godkänn och spara leveransen','6. Approve and save delivery'),local('ICC, mätcertifikat, begränsningar och historik','ICC, certificate, limitations and history'))
  box(72,local('Förbättra vid behov','Refine if needed'),local('Nya färgprov;<br/>skriv ut och mät','Additional patches;<br/>print and measure'),x=130,w=44,h=25)
  arrow([(119,48.5),(152,48.5),(152,72)])
  c.setFont('Vera',8);c.setFillColor(TEAL);c.drawString(124*mm,52*mm,local('Nej / utred','No / review'))
  arrow([(152,97),(152,104),(125,104),(125,88.5),(119,88.5)])
  c.setFillColor(MUTED);c.setFont('Vera',7.5);c.drawString(0,9*mm,local('Figur 7. Exempel på arbetsgång. Beslut fattas från aktuellt underlag.','Figure 7. Example workflow. Decisions use current evidence.'))

def table(rows):
 n=len(rows[0]);widths=([15,81,78] if n==3 else [51,123]);t=Table([[p(escape(v),'cell') for v in r] for r in rows],colWidths=[w*mm for w in widths],repeatRows=1,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),PALE),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.4,LINE),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4)]));return t
coverTitle=ParagraphStyle('coverTitle',parent=S['title'],fontSize=44,leading=52,spaceAfter=8)
coverSubtitle=ParagraphStyle('coverSubtitle',parent=S['lead'],fontSize=24,leading=30,spaceAfter=12)
coverAuthor=ParagraphStyle('coverAuthor',parent=S['lead'],alignment=2)
coverDetails=ParagraphStyle('coverDetails',parent=S['body'],alignment=2)
story=[Spacer(1,8*mm),p(local('ANVÄNDARHANDBOK','USER HANDBOOK'),'tag'),
 Paragraph('InkProf',coverTitle),
 Paragraph(local('Handbok','User Handbook'),coverSubtitle),
 p('Quality Profiling RGB printer','lead'),
 p(local('Profilering, mätning och verifiering av RGB-skrivare','Profiling, measurement and verification of RGB printers'),'body'),
 Spacer(1,9*mm),
 Image(str(ROOT/'examples/cover-gamut.png'),width=174*mm,height=100*mm,kind='proportional'),
 Spacer(1,5*mm),Paragraph('<b>Christer Törnkvist</b>',coverAuthor),
 Paragraph(local('Datum: ','Date: ')+DATE+'<br/>'+local('Programversion: ','Program version: ')+escape(VERSION),coverDetails),PageBreak()]
for i,page in enumerate(json.loads((ROOT/f'content-{LANG}.json').read_text())):
 if i:story.append(PageBreak())
 story.extend([p(escape(page['tag']),'tag'),p(escape(page['title']),'title')])
 if page.get('lead'):story.append(p(escape(page['lead']),'lead'))
 if page.get('diagram'):story.extend([Diagram(),Spacer(1,3*mm)])
 if page.get('overviewDiagram'):story.extend([OverviewDiagram(),Spacer(1,3*mm)])
 if page.get('workflowDiagram'):story.extend([WorkflowDiagram(),Spacer(1,3*mm)])
 for filename,w,h,caption in page.get('images',[]):
  story.extend([Image(str(ROOT/filename),width=w*mm,height=h*mm,kind='proportional'),p(escape(caption),'small'),Spacer(1,3*mm)])
 if page.get('rows'):story.extend([table(page['rows']),Spacer(1,3*mm)])
 for title,body in page.get('sections',[]):story.extend([p(escape(title),'h'),p(escape(body).replace('\n','<br/>'))])
 if page.get('callout'):
  t=Table([[p(escape(page['callout']))]],colWidths=[174*mm]);t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),PALE),('BOX',(0,0),(-1,-1),.5,LINE),('LEFTPADDING',(0,0),(-1,-1),11),('RIGHTPADDING',(0,0),(-1,-1),11),('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),6)]));story.extend([Spacer(1,4*mm),t]);
  if page.get('links'):story.append(Spacer(1,4*mm))
 for label,url in page.get('links',[]):story.append(p(f'<link href="{url}" color="#007F83">{escape(label)}</link>','small'))
doc=SimpleDocTemplate(str(OUT),pagesize=(210*mm,297*mm),leftMargin=18*mm,rightMargin=18*mm,topMargin=32*mm,bottomMargin=29*mm,title=local('InkProf - Användarhandbok','InkProf - User Handbook'),author='Christer Törnkvist',subject='App windows, workflow steps, measurements, iterations and measurement certificates')
doc.build(story,canvasmaker=Pages)
print(OUT)
