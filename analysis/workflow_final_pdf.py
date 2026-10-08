# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Create the printable counterpart of the persisted InkProf final report."""
from certificate_swatches import enrich, pdf_chips
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape
from certificate_standards import content, appendix_lines, pdf_table
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
    for name in ['Report', 'ReportBold']:
        pdfmetrics.registerFont(TTFont(name, str(Path(__file__).resolve().parents[1]/'resources/fonts/DejaVuSans.ttf')))
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
        text = str(text).replace('–', '-').replace('—', '-')
        return Paragraph(escape(text).replace('\n', '<br/>'), styles[style])

    story += [p('InkProf - Measurement certificate', 'Title'), p(r['project']['name'], 'Heading2'),
              p(f"Iteration {r['iteration']} | {r['createdUTC']}"),
              p('Certificate ID: '+r.get('certificateId','Not specified')),
              p(r.get('certificateScope','')), p('How to interpret these results','Heading2'), p(r.get('resultInterpretation','Interpretation not recorded in this historical certificate.')), p('Project and printing conditions','Heading2')]
    for item in r.get('projectDetails',[]):
        story.append(p(item['label']+': '+item['value']))
    if r.get('deliveryProfile'):
        from delivery_report import details
        story += [p('Delivered ICC profile', 'Heading2')]+[p(x) for x in details(r['deliveryProfile'])]
    story += [p('Checked ICC candidate (project original)' if r.get('deliveryProfile') else 'Saved ICC profile', 'Heading2'), p('profile.icc'), p('SHA-256: ' + r['profile']['sha256']),
              p('Final assessment', 'Heading2'), p(r['approval']['notes'])]
    if r.get('regularization'):
        story += [p('Regularization - method, inputs and results', 'Heading2'), p(r['regularization']['summaryText'])]
    if r.get('patchOutliers'):
        outliers=r['patchOutliers']
        story += [PageBreak(),p('Whole-target result overview','Heading2'),p(outliers.get('overviewText','Whole-target distribution unavailable.')),p('Technical diagnostic colours: deviations above 5 dE00','Heading2'),p('Desired colour, profile prediction and measured colour are shown as sRGB previews. Delta E00 compares measurement with desired colour (above 5). See Appendix A.'),p(outliers['message']),p(outliers.get('contextText','Reachability evidence unavailable.'))]
        # All colours are shown, in target order, before individual diagnostic cards.
        from reportlab.lib.colors import HexColor
        patches=outliers.get('allPatches',[])
        if patches:
            cells=[]
            for patch in patches:
                swatch=Table([['']],colWidths=[18*mm],rowHeights=[8*mm])
                swatch.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),HexColor(patch['hex']))]))
                cells.append([swatch,p(f"{patch['sampleId']} · {patch['deltaE00']:.1f}")])
            rows=[cells[i:i+8]+['']*(8-len(cells[i:i+8])) for i in range(0,len(cells),8)]
            story += [p('Every unique measured colour — target order','Heading3'),Table(rows,colWidths=[22*mm]*8),PageBreak()]
        if r.get('verificationSummary'):
            story += [p('Two separate comparisons (Delta E00)', 'Heading2')]
            for key,label in [('desired','Measured print vs desired colour'),('predicted','Measured print vs current profile prediction')]:
                v=r['verificationSummary'][key]
                story += [p(label+f": mean {v['mean']:.3f}, median {v['median']:.3f}, P95 {v['p95']:.3f}, max {v['max']:.3f} ({v['count']} unique patches)")]
        cards=[]
        patches=outliers['patches']
        if isinstance(patches,dict):patches=[patches]
        patches=enrich(patches,r,folder)
        for patch in patches:
            swatch=pdf_chips(patch)
            marker='*' if patch['clipped'] else ''
            label=f"ID {patch['sampleId']} | page {patch['page']} / {patch['coordinate']}\n{patch['role']} | {patch.get('reachabilityLabel','Reachability unknown')}\nMeasured print vs desired colour | ΔE00 {patch['deltaE00']:.4f}\n{patch['hex']}{marker}"
            card=Table([[swatch],[p(label,'DetailReport')]],colWidths=[54*mm])
            card.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),2),('RIGHTPADDING',(0,0),(-1,-1),2)]))
            cards.append(card)
        if cards:
            rows=[cards[i:i+3]+['']*(3-len(cards[i:i+3])) for i in range(0,len(cards),3)]
            grid=Table(rows,colWidths=[57*mm]*3,hAlign='LEFT')
            grid.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.3,colors.lightgrey),('LEFTPADDING',(0,0),(-1,-1),1),('RIGHTPADDING',(0,0),(-1,-1),1)]))
            story += [grid,Spacer(1,3*mm)]
    story += pdf_table(r, styles, "en")
    if r.get('fwa'):
        story += [KeepTogether([p('FWA/OBA - settings and results','Heading2'),p(r['fwa']['summaryText'])])]
    from lab_views import measured_data, point_drawing
    measured=measured_data(r,folder)
    story += [PageBreak(),p('Measured print colours - L* = 50','Heading2')]
    if measured:
        story += [p('Actual measured Lab. Points within L* = 50 +/- 5 are shown in the a*/b* plane; this band is not a gamut boundary.'),point_drawing(measured['vertices'],measured['rgb'])]
    else:
        story += [p('No measured Lab points available for this profile.')]
    import gamut_surface
    gamut = gamut_surface.load(folder, r)
    story += [PageBreak(), p('ICC gamut - CIELAB D50', 'Heading2')]
    if gamut:
        story += [p(gamut_surface.caption("en")), p('ICC SHA-256: '+r['profile']['sha256']), gamut_surface.pdf_drawing(gamut)]
    else:
        story += [p('Gamut unavailable: '+r.get('gamut', {}).get('reason', 'No surface saved.'))]
    story += [PageBreak(), p('Complete results and history', 'Heading2')]
    # Flowing paragraphs paginate long notes, file paths and histories safely.
    in_results = False
    for line in (folder / 'final-report.txt').read_text(encoding='utf-8').rsplit('\nSIGNATURE\n',1)[0].splitlines():
        if line == 'MEASURED COLOURS AND DELTA E00':
            in_results = True
        elif line == 'PRINTING AND MEASUREMENT':
            in_results = False
        if in_results:
            continue
        if line.strip():
            story.append(p(line, 'DetailHeading' if line.isupper() and len(line)<120 else 'DetailReport'))
        else:
            story.append(Spacer(1, 2*mm))

    if r.get('signature'):
        story += [PageBreak(), p('Measurement certificate signature','Title'),
                  p('Project: '+r['project']['name']),
                  p('Certificate ID: '+r['certificateId']),p('Document date: '+r['reportDate']),
                  p('ICC SHA-256: '+r['profile']['sha256']),
                  Spacer(1,80*mm),p(r['signature']['statement']),Spacer(1,12*mm)]
        for label in ('Place and date','Signature','Printed name','Organisation / role'):
            story += [p(label+': __________________________________________________'),Spacer(1,12*mm)]

    story += [PageBreak(), p(content(r, "en")['appendixTitle'], 'Title')]
    story += [p(line) for line in appendix_lines(r, "en")]
    if r.get('patchOutliers'):
        story += [p(r['patchOutliers']['basis']), p(r['patchOutliers']['colourNote'])]
    if r.get('reproductionLimits'):
        story += [p('Physical reproduction capability and result limitations','Heading2'),p(r['reproductionLimits'])]
    story += [PageBreak(), p('Appendix B - Legal terms', 'Title')]
    for key, title in [('reproductionLiability', 'Responsibility for equipment and material limitations'),
                       ('clientPrintResponsibility', 'Client prints and information'),
                       ('warrantyNotice', 'Warranty and liability'),
                ('licensingNotice', 'Licences and third-party rights')]:
        if r.get(key):
            story += [p(title, 'Heading2'), p(r[key])]

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
                user = r.get('reportUser', 'Not specified')
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
            from pdf_notices import attach
            attach(self)
            super().save()

    SimpleDocTemplate(str(folder / 'final-report.pdf'), pagesize=(210*mm, 297*mm),
                      leftMargin=18*mm, rightMargin=18*mm, topMargin=28*mm, bottomMargin=26*mm,
                      title='InkProf - Measurement certificate', author=r.get('reportUser', 'InkProf')).build(story, canvasmaker=NumberedCanvas)


if __name__ == '__main__':
    create(sys.argv[1])
