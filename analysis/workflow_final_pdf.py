"""Create the printable counterpart of the persisted InkProf final report."""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape
import reportlab
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak, KeepTogether


def create(folder):
    folder = Path(folder)
    r = json.loads((folder / 'final-report.json').read_text(encoding='utf-8'))
    fonts = Path(reportlab.__file__).parent / 'fonts'
    for name, file in [('Report', 'Vera.ttf'), ('ReportBold', 'VeraBd.ttf')]:
        pdfmetrics.registerFont(TTFont(name, str(fonts / file)))
    styles = getSampleStyleSheet()
    for s in styles.byName.values():
        s.fontName = 'Report'
    styles.add(ParagraphStyle('BodyReport', fontName='Report', fontSize=9, leading=13, spaceAfter=7, wordWrap='CJK'))
    styles.add(ParagraphStyle('DetailReport', fontName='Report', fontSize=8, leading=11, spaceAfter=5, wordWrap='CJK'))
    styles.add(ParagraphStyle('DetailHeading', fontName='ReportBold', fontSize=8, leading=11, spaceAfter=5, keepWithNext=True))
    styles.add(ParagraphStyle('FooterUser', fontName='Report', fontSize=8, leading=10, alignment=1))
    styles['Title'].fontName = styles['Heading2'].fontName = 'ReportBold'
    styles['Title'].textColor = colors.HexColor('#19303c')
    story = []

    def p(text, style='BodyReport'):
        text = str(text).replace('Δ', 'Delta ').replace('–', '-').replace('—', '-')
        return Paragraph(escape(text).replace('\n', '<br/>'), styles[style])

    story += [p('InkProf - mätcertifikat', 'Title'), p(r['project']['name'], 'Heading2'),
              p(f"Iteration {r['iteration']} | {r['createdUTC']}"),
              p('Certifikat-ID: '+r.get('certificateId','Ej angivet')),
              p(r.get('certificateScope','')), p('Projekt och utskriftsvillkor','Heading2')]
    for item in r.get('projectDetails',[]):
        story.append(p(item['label']+': '+item['value']))
    story += [p('Sparad ICC-profil', 'Heading2'), p('profile.icc'), p('SHA-256: ' + r['profile']['sha256']),
              p('Slutlig bedömning', 'Heading2'), p(r['approval']['notes'])]
    rows = [[p(x) for x in ['Grupp', 'Antal', 'Medel', 'Median', 'P95', 'Max']]]
    c3 = r['results']['c3_report']
    groups = [('C3: unika kontrollpatchar', c3.get('summary'))]
    groups += [(label, c3.get('groups', {}).get(key)) for key, label in
               [('gray', 'C3: gråskala'), ('colour', 'C3: färgprov'), ('challenge', 'C3: challenge')]]
    groups += [('Upprepade utskriftsfält', c3.get('repeatedPrintedPatches', {}).get('summary')),
               ('Träningsdata (inte oberoende)', r['results']['checks_fit'].get('summary'))]
    for label, stats in groups:
        if not stats:
            continue
        values = [label]
        for key in ['count', 'mean', 'median', 'p95', 'max']:
            v = stats.get(key)
            values.append('-' if v is None else str(v) if key == 'count' else f'{v:.3f}')
        rows.append([p(x) for x in values])
    table = Table(rows, colWidths=[65*mm, 18*mm, 22*mm, 22*mm, 22*mm, 22*mm], repeatRows=1)
    table.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e7eff2')),
                              ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                              ('LINEBELOW', (0, 0), (-1, -1), .3, colors.lightgrey)]))
    story += [KeepTogether([p('Mätresultat - ΔE00', 'Heading2'),table]), Spacer(1, 5*mm), p('Träningsfel är inte oberoende verifiering. Utskriften görs separat av användaren. Utskriftskedjan är inte verifierad av appen.')]
    if r.get('patchOutliers'):
        outliers=r['patchOutliers']
        story += [p(outliers['title'],'Heading2'),p(outliers['basis']),p(outliers['message']),p(outliers['colourNote'])]
        cards=[]
        patches=outliers['patches']
        if isinstance(patches,dict):patches=[patches]
        for patch in patches:
            swatch=Table([['']],colWidths=[8*mm],rowHeights=[8*mm])
            swatch.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor(patch['hex'])),('BOX',(0,0),(-1,-1),.3,colors.grey)]))
            marker='*' if patch['clipped'] else ''
            label=f"ID {patch['sampleId']} | sida {patch['page']} / {patch['coordinate']}\n{patch['role']} | ΔE00 {patch['deltaE00']:.4f}\n{patch['hex']}{marker}"
            card=Table([[swatch,p(label,'DetailReport')]],colWidths=[11*mm,43*mm])
            card.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),2),('RIGHTPADDING',(0,0),(-1,-1),2)]))
            cards.append(card)
        if cards:
            rows=[cards[i:i+3]+['']*(3-len(cards[i:i+3])) for i in range(0,len(cards),3)]
            grid=Table(rows,colWidths=[57*mm]*3,hAlign='LEFT')
            grid.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.3,colors.lightgrey),('LEFTPADDING',(0,0),(-1,-1),1),('RIGHTPADDING',(0,0),(-1,-1),1)]))
            story += [grid,Spacer(1,3*mm)]
        story += [p('Källa: MediaStandard Print 2018, tabell 30 (ISO 12647-7:2016).')]
    if r.get('fwa'):
        story += [KeepTogether([p('FWA/OBA - val och resultat','Heading2'),p(r['fwa']['summaryText'])])]
    if r.get('reproductionLimits'):
        story += [KeepTogether([p('Fysisk återgivningsförmåga och resultatets gränser','Heading2'),p(r['reproductionLimits'])])]
    if r.get('reproductionLiability'):
        story += [KeepTogether([p('Ansvar för utrustningens och materialens begränsningar','Heading2'),p(r['reproductionLiability'])])]
    if r.get('clientPrintResponsibility'):
        story += [KeepTogether([p('Beställarens utskrifter och uppgifter','Heading2'),p(r['clientPrintResponsibility'])])]
    if r.get('warrantyNotice'):
        story += [p('Garanti och ansvar', 'Heading2'), p(r['warrantyNotice'])]
    if (folder / 'profile-lab-3d.png').is_file():
        story += [PageBreak(), p('Profilens beräknade kontrollfärger i 3D', 'Heading2'),
                  p('Kontrollmålets patchar i CIELAB D50. Detta är profilens beräknade värden, inte mätningar eller hela skrivarens färgomfång.'),
                  Image(str(folder / 'profile-lab-3d.png'), width=170*mm, height=121*mm, kind='proportional')]
    story += [PageBreak(), p('Fullständig redovisning och historik', 'Heading2')]
    # Flowing paragraphs paginate long notes, file paths and histories safely.
    for line in (folder / 'final-report.txt').read_text(encoding='utf-8').rsplit('\nUNDERSKRIFT\n',1)[0].splitlines():
        if line.strip():
            story.append(p(line, 'DetailHeading' if line.isupper() and len(line)<120 else 'DetailReport'))
        else:
            story.append(Spacer(1, 2*mm))

    if r.get('signature'):
        story += [PageBreak(), p('Underskrift av mätcertifikat','Title'),
                  p('Projekt: '+r['project']['name']),
                  p('Certifikat-ID: '+r['certificateId']),p('Dokumentdatum: '+r['reportDate']),
                  p('ICC SHA-256: '+r['profile']['sha256']),
                  Spacer(1,80*mm),p(r['signature']['statement']),Spacer(1,12*mm)]
        for label in ('Ort och datum','Underskrift','Namnförtydligande','Organisation / roll'):
            story += [p(label+': __________________________________________________'),Spacer(1,12*mm)]

    class NumberedCanvas(Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.saved_pages = []

        def showPage(self):
            self.saved_pages.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            total = len(self.saved_pages)
            annotation_count = self._annotationCount
            for state in self.saved_pages:
                self.__dict__.update(state)
                self._annotationCount = annotation_count
                self.setFillColor(colors.HexColor('#19303c'))
                self.setFont('Report', 15)
                self.drawCentredString(105*mm, 281*mm, r.get('pageHeader', 'InkProf Quality Profiling RGB printer'))
                self.setFillColor(colors.HexColor('#52656e'))
                self.setFont('Report', 8)
                self.drawString(18*mm, 12*mm, r.get('reportDate', r['createdUTC'][:10]))
                user = r.get('reportUser', 'Ej angivet')
                # Wrap long user names inside the middle footer column.
                label = Paragraph(escape(user), styles['FooterUser'])
                _, height = label.wrap(102*mm, 20*mm)
                label.drawOn(self, 56*mm, 12*mm)
                self.drawRightString(192*mm, 12*mm, f'{self._pageNumber} ({total})')
                url = 'https://github.com/chto0703009/InkProf-public'
                self.setFont('Report', 7)
                self.drawCentredString(105*mm, 6*mm, url)
                self.linkURL(url, (55*mm, 5*mm, 155*mm, 9*mm), relative=0)
                annotation_count = self._annotationCount
                super().showPage()
            super().save()

    SimpleDocTemplate(str(folder / 'final-report.pdf'), pagesize=(210*mm, 297*mm),
                      leftMargin=18*mm, rightMargin=18*mm, topMargin=28*mm, bottomMargin=26*mm,
                      title='InkProf - mätcertifikat', author=r.get('reportUser', 'InkProf')).build(story, canvasmaker=NumberedCanvas)


if __name__ == '__main__':
    create(sys.argv[1])
