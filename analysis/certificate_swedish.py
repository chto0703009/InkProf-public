# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Swedish PDF companion; never rewrites English HTML or measurement appendix."""
import json
from pathlib import Path
from xml.sax.saxutils import escape

LABELS = {'Project':'Projekt','Project ID':'Projekt-ID','Document date':'Dokumentdatum','Prepared by':'Upprättat av',
 'Project owner':'Projektägare','Project created (local time)':'Projekt skapat (lokal tid)',
 'Printer':'Skrivare','Paper':'Papper','Paper surface':'Pappersyta','Ink / ink set':'Bläck / bläckuppsättning',
 'Ink type (dye / pigment)':'Bläcktyp (färgämne / pigment)','Driver media selection':'Medietyp i drivrutinen',
 'Driver / RIP':'Drivrutin / RIP','Print quality':'Utskriftskvalitet','Printing application':'Utskriftsprogram',
 'Print colour management':'Färghantering vid utskrift','Drying time (hours)':'Torktid (timmar)',
 'Other printer settings':'Övriga skrivarinställningar','Printer coating':'Skrivarens ytbehandling',
 'Coating - product and settings':'Ytbehandling – produkt och inställningar',
 'Profiling measurement – instrument':'Profilmätning – instrument','Verification measurement – instrument':'Verifieringsmätning – instrument',
 'Profiling measurement - serial number':'Profilmätning – serienummer','Verification measurement - serial number':'Verifieringsmätning – serienummer',
 'Imported ICC - original filename':'Importerad ICC – ursprungligt filnamn','Verification mode':'Verifieringsläge',
 'Shadow setting in saved profile recipe':'Skugginställning i sparat profilrecept',
 'Shadow mode (auto-matte applies only to matte paper)':'Skuggläge (auto-matte gäller endast matt papper)',
 'Dark patch weighting':'Viktning av mörka färgprov','Model shadow emphasis':'Modellens skuggviktning',
 'Extra shadow patches per iteration (requested count)':'Extra skuggfärgprov per iteration (önskat antal)'}
VALUES = {'Not specified':'Ej angivet','Not recorded':'Ej registrerat','automatic':'Automatisk','Automatic':'Automatisk',
 'standard':'Standard','Glossy':'Blankt','High Quality (600 × 600 dpi, 12-bit)':'Hög kvalitet (600 × 600 dpi, 12 bitar)',
 'External ICC; no new profile built':'Extern ICC; ingen ny profil har byggts'}


def create(folder):
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Table,TableStyle,PageBreak,Spacer
    from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from certificate_reference import compact_selection
    from certificate_standards import pdf_table,appendix_lines,content
    from lab_views import measured_data,point_drawing
    folder=Path(folder);r=json.loads((folder/'final-report.json').read_text());root=Path(__file__).resolve().parents[1]
    pdfmetrics.registerFont(TTFont('CertificateSV',str(root/'resources/fonts/DejaVuSans.ttf')))
    styles=getSampleStyleSheet()
    for name,style in styles.byName.items():
        style.fontName='CertificateSV'
        if name=='Title' or name.startswith('Heading'):style.keepWithNext=True
    styles['BodyText'].fontSize=9;styles['BodyText'].leading=13
    styles.add(ParagraphStyle('NumberSV',parent=styles['BodyText'],alignment=1))
    def p(text,style='BodyText'):return Paragraph(escape(str(text)).replace('\n','<br/>'),styles[style])
    def number(v):return f'{v:.2f}'.replace('.',',')
    numerical=r.get('documentType')=='inkprof.numerical-report'
    story=[p('InkProf – Mätcertifikat','Title'),p(r['project']['name'],'Heading2'),
      p(f"Iteration {r['iteration']} | {r.get('createdLocal',r.get('reportDate',''))}"),
      p('Certifikat-ID: '+r.get('certificateId','Ej angivet')),p('Iterationens UUID: '+r.get('iterationId','Ej angivet'))]
    scope=('Den aktuella profilen är numeriskt kontrollerad men har inte verifierats genom en separat utskrift och mätning.' if numerical else
      'Certifikatet redovisar den aktuella ICC-profilen, en separat verifieringsutskrift och användarens bedömning under de angivna förhållandena.')
    story += [p(scope+' Resultatet gäller den angivna kombinationen av skrivare, bläck, papper och utskriftsinställningar. Detta är ingen ackrediterad certifiering och inget bevis för ISO-överensstämmelse. Krav som inte uppfylls redovisas som ej uppfyllda.'),
      p('Så läser du resultatet','Heading2'),p('ΔE00 beskriver färgskillnaden; lägre är bättre. Verifieringen jämför uppmätt utskrift med önskad färg. Profilanpassningen jämför modellen med dess egna underlagsmätningar och är ingen oberoende verifiering. Skrivarens, bläckets och papprets fysiska förmåga begränsar återgivningen. Metoder, fullständiga mätdata och spårbarhet finns i det engelska supplementet.'),
      p('Projekt och utskriftsförhållanden','Heading2')]
    for item in r.get('projectDetails',[]):
        label=LABELS.get(item['label'],item['label']);value=VALUES.get(item['value'],item['value'])
        if item['label'] in ['Model shadow emphasis','Dark patch weighting']:value=value.replace('.',',')
        if item['label']=='Shadow setting in saved profile recipe':value=('Skuggbearbetning vid profilering: av. Standardfördelning av färgprov användes. Sparade vikter och önskat antal extra färgprov visar inte att skuggbearbetning användes.' if 'off' in item['value'] else 'Sparad skuggbearbetning redovisas i supplementets profilrecept.')
        story.append(p(label+': '+value))
    story += [p('Kontrollerad ICC-profil','Heading2'),p('profile.icc'),p('SHA-256: '+r['profile']['sha256'])]
    for key,heading in [('deliveryProfile','Levererad ICC-profil'),('secondaryDeliveryProfile','Ytterligare levererad ICC-version')]:
        d=r.get(key)
        if d:story += [p(heading,'Heading2'),p('Fil: '+Path(d['file']).name),p('Internt profilnamn: '+d['internalName']),p('SHA-256: '+d['sha256']),p('Källprofilens SHA-256: '+d['sourceSHA256']),p('Leveransfilen har ett nytt namn. För v2 är färgtabellerna byte-identiska med den kontrollerade profilen; endast namnfält och nödvändiga identitetsfält har ändrats.' if key=='deliveryProfile' and not r.get('deliveryConversion') else 'v4.4-kopian behåller de kolorimetriska tabellerna men har ny perceptuell mappning och mättnadsmappning. Certifikatet gäller den kontrollerade originalprofilen; bedöm v4.4-utskrifter i avsett program. Källprofilens kontrollsumma ovan avser v4.4-filen före namnändringen, inte den kontrollerade originalprofilen.')]
    story += [p('Användarens bedömning','Heading2'),p({'Profile is in the limit of printer, ink and paper limitations.':'Profilen når gränsen för vad skrivare, bläck och papper klarar.'}.get(r.get('approval',r.get('decision',{})).get('notes',''),r.get('approval',r.get('decision',{})).get('notes','Ej angivet')))]
    summaries=r.get('verificationSummary',{})
    if summaries:
        story.append(p('Sammanfattning av mätresultatet','Heading2'))
        for key,label in [('desired','Uppmätt utskrift mot önskad färg'),('predicted','Uppmätt utskrift mot profilens förutsägelse')]:
            v=summaries.get(key)
            if v:story.append(p(f"{label}: medel {number(v['mean'])}, median {number(v['median'])}, P95 {number(v['p95'])}, högsta {number(v['max'])} ΔE00 ({v['count']} unika färger)."))
    patches=r.get('patchOutliers',{}).get('allPatches',[])
    if isinstance(patches,dict):patches=[patches]
    selected=compact_selection(patches)
    if selected:
        story += [p(f'Största färgavvikelser med ΔE00 > 1 ({len(selected)} av {len(patches)} färger)','Heading2'),p('Vänster: önskad färg. Höger: uppmätt utskrift. Talet under paret är ΔE00. Högst 100 avvikelser över 1 visas, sorterade från minst till störst. Skärmfärgerna är förhandsvisningar; alla data finns i supplementet.')]
        cells=[]
        for patch in selected:
            swatch=Table([['','']],colWidths=[12*mm]*2,rowHeights=[8*mm]);swatch.setStyle(TableStyle([('BACKGROUND',(0,0),(0,0),colors.HexColor(patch.get('desiredHex') or '#fff')),('BACKGROUND',(1,0),(1,0),colors.HexColor(patch['hex']))]))
            cells.append([swatch,p(number(patch['deltaE00']),'NumberSV')])
        rows=[cells[i:i+6]+['']*(6-len(cells[i:i+6])) for i in range(0,len(cells),6)]
        table=Table(rows,colWidths=[29*mm]*6);table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.3,colors.lightgrey)]));story.append(table)
    story += [p('Fullständigt mätunderlag','Heading2'),p('measurement-appendix.pdf är certifikatets engelska supplement med samtliga patchar, avvikelser, Lab-värden, SHA-256-kontrollsummor, arbetssteg och historik. Supplementet och den interaktiva HTML-rapporten finns endast på engelska. Den svenska PDF-versionen gäller samma certifikat-ID och samma kontrollerade ICC-profil som den engelska versionen.')]
    from certificate_editorial import swedish_evidence
    story.append(p('Regularisering, resultatfördelning och gradientdiagnostik','Heading2'))
    story.extend(p(text) for text in swedish_evidence(r))
    story += pdf_table(r,styles,'sv')
    if r.get('fwa'):story += [p('Optiska vitmedel (OBA/FWA)','Heading2'),p('Vald kompensation, mätbetingelse och beräkningsmetod dokumenteras i supplementet. D50-simulering från M0 är inte en direkt M1-mätning.')]
    measured=measured_data(r,folder)
    if measured:
        drawing=point_drawing(measured['vertices'],measured['rgb'],title='Uppmätta verifieringsfärger',level=50,half=10)
        from reportlab.graphics.shapes import String
        for node in drawing.contents:
            if isinstance(node,String) and 'of ' in node.text:node.text=f'{sum(abs(v[0]-50)<=10 for v in measured["vertices"])} av {len(measured["vertices"])} färger inom L* 40–60; inte en gamutgräns.'
        story += [PageBreak(),p('Uppmätta verifieringsfärger – L* 40–60','Heading2'),p('Aktuell verifieringsmätning utan repetitioner och pappersvitkontroller. Färger inom L* 40–60 visas i a*/b*-planet.'),drawing]
    import gamut_surface
    gamut=gamut_surface.load(folder,r)
    if gamut:story += [PageBreak(),p('ICC-profilens gamut – CIELAB D50','Heading2'),p(gamut_surface.caption('sv')),gamut_surface.pdf_drawing(gamut,'sv')]
    story += [PageBreak(),p('Underskrift av mätcertifikatet','Title'),p('Projekt: '+r['project']['name']),p('Certifikat-ID: '+r.get('certificateId','Ej angivet')),p('ICC SHA-256: '+r['profile']['sha256']),p('Dokumentdatum: '+r.get('reportDate','Ej angivet')),p('Genom underskriften bekräftar jag att jag har granskat certifikatets förhållanden, resultat, begränsningar och ansvarsfördelning.')]
    for label in ['Ort och datum','Underskrift','Namnförtydligande','Organisation / roll']:story += [Spacer(1,12*mm),p(label+': _____________________________________')]
    story += [PageBreak(),p(content(r,'sv')['appendixTitle'],'Title')]+[p(line) for line in appendix_lines(r,'sv')]
    story += [p('Fysiska begränsningar','Heading2'),p('Profilen kan inte skapa färger, svärta eller kontrast utöver skrivarens, papprets och bläckets förmåga. Torktid, stabilitet, mätbetingelser och betraktningsljus påverkar resultatet. Fler mätningar garanterar inte förbättring. Ändrade förhållanden kan kräva ny profilering och verifiering.')]
    legal=json.loads((root/'resources/certificate-legal-sv.json').read_text())
    story += [PageBreak(),p('Bilaga B – Ansvar och licenser','Title')]
    for key,label in [('reproductionLiability','Utrustning och material'),('clientPrintResponsibility','Beställarens utskrifter och uppgifter'),('warrantyNotice','Garanti och ansvar'),('licensingNotice','Licenser och tredje parts rättigheter')]:story += [p(label,'Heading2'),p(legal[key])]
    from reportlab.pdfgen.canvas import Canvas
    class NumberedCanvas(Canvas):
        def __init__(self,*args,**kwargs):
            super().__init__(*args,**kwargs);self.saved_pages=[]
        def showPage(self):
            self.saved_pages.append(dict(self.__dict__));self._startPage()
        def save(self):
            total=len(self.saved_pages)
            for state in self.saved_pages:
                self.__dict__.update(state);self.setFont('CertificateSV',12)
                self.drawCentredString(105*mm,282*mm,'InkProf – Kvalitetsprofilering av RGB-skrivare')
                self.setFont('CertificateSV',8);self.drawString(18*mm,12*mm,r.get('reportDate',''))
                footer=Paragraph(escape(r.get('reportUser','')),styles['NumberSV']);footer.wrap(102*mm,20*mm);footer.drawOn(self,56*mm,12*mm)
                self.drawRightString(192*mm,12*mm,f'{self._pageNumber} ({total})')
                self.setFont('CertificateSV',7);self.drawCentredString(105*mm,6*mm,'https://github.com/chto0703009/InkProf-public')
                super().showPage()
            from pdf_notices import attach
            attach(self);super().save()
    path=folder/'final-report-sv.pdf'
    SimpleDocTemplate(str(path),pagesize=(210*mm,297*mm),leftMargin=18*mm,rightMargin=18*mm,topMargin=28*mm,bottomMargin=26*mm,title='InkProf – Mätcertifikat',author=r.get('reportUser','InkProf')).build(story,canvasmaker=NumberedCanvas)
    return path
