# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Portable numerical-only ICC report, explicitly excluding print validation."""
import html
from certificate_swatches import enrich, html_chips, pdf_chips
import json
import sys
from pathlib import Path
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, KeepTogether
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from certificate_standards import content, appendix_lines, pdf_table, table_html


def create(folder, language="en"):
    folder = Path(folder)
    r = json.loads((folder / 'final-report.json').read_text(encoding='utf-8'))
    from certificate_figure import load, interactive, pdf_drawing
    figure_groups = load(folder, r)
    import gamut_surface
    gamut = gamut_surface.load(folder, r)
    gamut_title = "ICC gamut - CIELAB D50"
    figure_title = 'Profile comparison - 2D and 3D in CIELAB'
    sections = [('InkProf - Measurement certificate', ['Certificate ID: '+r.get('certificateId', 'Not specified'), r.get('certificateScope', ''), r['scopeStatement'],
        f"Project: {r['project']['name']} | Iteration {r['iteration']}",
        'Current profile: numerically checked. Previous print measurements are reported separately as historical evidence.']),
        ('Decision and intended use', [r['decision']['notes']]),
        ('Saved ICC profile', [r['profile']['file'], 'SHA-256: '+r['profile']['sha256']]),
        ('Project and printing settings', [f'{label}: {r["printing"].get(key, "Not specified")}' for key, label in [('printer','Printer'),('paper','Paper'),('paperSurface','Surface'),('ink','Ink'),('inkType','Ink type (dye / pigment)'),('shadowMode','Shadow mode (auto-matte applies only to matte paper)'),('shadowPatchEmphasis','Dark patch weighting'),('shadowGridEmphasis','Model shadow emphasis'),('shadowExtraPatches','Extra shadow patches per iteration (requested count)'),('printerCoating','Printer coating'),('coatingSettings','Coating - product and settings'),('media','Media setting'),('driver','Driver'),('quality','Print quality'),('printPath','Printing application'),('colorManagement','Colour management'),('dryingHours','Drying time (hours)'),('fwaCompensation','Optical brightener compensation'),('settings','Other settings')]])]
    sections[3][1].insert(0, 'Project ID: '+str(r['project']['id']))
    sections[3][1].insert(1, 'Responsible user: '+r['reportUser'])
    if r.get('deliveryProfile'):
        from delivery_report import details
        sections[2] = ('Checked ICC candidate (project original)', sections[2][1])
        sections.insert(3, ('Delivered ICC profile', details(r['deliveryProfile'])))
    evidence = r.get('decisionEvidence', {})
    fit = evidence.get('trainingFit', {})
    def stats(values):
        return ' | '.join(label+': '+format(values[key], '.4f') for key, label in
                         [('mean', 'Mean'), ('p95', '95th percentile'), ('max', 'Max')] if key in values)
    decision_lines = ['Evidence for the user decision to end the iteration only; not evidence of improved print accuracy.']
    for key, label in [('previous', 'Previous iteration'), ('current', 'Current iteration')]:
        if key in fit:
            decision_lines.append(label+' - fit error (Delta E00): '+stats(fit[key])+f" | Patch count: {fit[key].get('count', 'not specified')}")
    if fit.get('previous') and fit.get('current'):
        delta = {k: fit['current'][k]-fit['previous'][k] for k in ('mean', 'p95', 'max') if k in fit['current'] and k in fit['previous']}
        decision_lines.append('Change in fit error, current minus previous: '+stats(delta))
        decision_lines.append('A positive change means higher fit error; negative means lower. Two iterations do not establish general convergence or divergence.')
    if fit.get('caveat'):
        decision_lines.append(fit['caveat'])
    comparison = evidence.get('comparison', {})
    if comparison:
        decision_lines += [f"Profile comparison: iteration {comparison['previousIteration']} vs {comparison['currentIteration']}",
            'Previous profile prediction vs current profile prediction (Delta E00, same RGB): '+stats(comparison['sameRGBDeltaE00']),
            'RGB selection difference for the same Lab (percentage points): '+stats(comparison['sameLabRGBChangePercentagePoints']),
            'These values describe differences between ICC calculations, not errors against a measured verification print.']
    else:
        decision_lines.append('No current profile comparison attached. Run step 18 before export to include it.')
    sections.insert(2, ('Comparison evidence for the decision', decision_lines))
    for key, source in r['sources'].items():
        data = json.loads((folder / source['file']).read_text(encoding='utf-8'))
        lines = [f"Evidence: {source['file']}", 'SHA-256: '+source['sha256']]
        if 'summary' in data:
            lines.append('Fit error (Delta E00): '+stats(data['summary']))
        if 'roundtripDeltaE00' in data:
            lines.append('Numerical round-trip error (Delta E00): '+stats(data['roundtripDeltaE00']))
        if 'allNegativeControlsDetected' in data:
            lines.append('All deliberate negative controls detected: '+('Yes' if data['allNegativeControlsDetected'] else 'No'))
        if 'grossFailureAlerts' in data:
            lines.append('Gross numerical alerts: '+(str(data['grossFailureAlerts']) if data['grossFailureAlerts'] else 'None'))
        sections.append(('Numerical evidence: '+key, lines))
    if r.get('regularization'):
        sections.append(('Regularization - method, inputs and results', r['regularization']['summaryText'].splitlines()))
    if r.get('shadow'):
        sections.append(('Shadow processing in saved profile recipe', [r['shadow']['summaryText']]))
    if r.get('fwa'):
        sections.append(('FWA/OBA - settings and results', [r['fwa']['summaryText']]))
    if figure_groups is not None:
        sections.append((figure_title, ['Blue: previous profile. Orange: current profile. Shared RGB samples predicted in CIELAB D50; not measured gamut boundaries.', 'HTML starts in 2D at L*=50 with half-width 5. Change L* to view other slices. Clear 2D and drag to rotate the 3D view. PDF shows an a*/b* slice at L* = 50 +/- 5.']))
    historical = r.get('historicalCertificate', {})
    historical_patches = []
    historical_measured = None
    measured_title = "Previous measured print colours - historical evidence"
    measurement_explanations = []
    if historical:
        import hashlib
        source = folder / historical['file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != historical['sha256']:
            raise ValueError('Historical certificate checksum mismatch')
        old = json.loads(source.read_text(encoding='utf-8'))
        from lab_views import measured_data
        historical_measured = measured_data(old,source.parent)
        if historical_measured:
            sections.append((measured_title,['Actual measured points for iteration '+str(historical['iteration'])+'; not verification of the current ICC. PDF: L* = 50 +/- 5. HTML: 2D or 3D.']))
        lines = [historical['scope'], 'Iteration: '+str(historical['iteration']),
                 'Previous ICC SHA-256: '+historical['profileSHA256'],
                 'Previous certificate ID: '+old.get('certificateId', 'Not specified')]
        for key, identity in old.get('instruments', {}).items():
            label = 'Profiling measurement' if key == 'measurement' else 'Verification measurement'
            lines.append(label+' - spectrometer: '+str(identity.get('model', 'Not specified'))+
                         '; serial number: '+str(identity.get('serialNumber', 'Not specified')))
        for key, result in old.get('results', {}).items():
            if key == 'c3_report' and result.get('summary'):
                lines.append('Previous verification print (Delta E00): '+stats(result['summary']))
        lines.append('The complete previous certificate is included in the previous-certificate folder in its original language.')
        sections.append(('Previous print measurements - historical evidence', lines))
        outliers = old.get('patchOutliers', {})
        historical_patches = outliers.get('patches', [])
        if isinstance(historical_patches, dict):
            historical_patches = [historical_patches]
        historical_patches = enrich(historical_patches, old, source.parent)
        measurement_explanations = [outliers.get('basis',''), 'Desired, predicted and measured D50 Lab are converted to sRGB using Bradford adaptation to D65. Colours outside sRGB are clipped. Swatches are screen previews; Delta E00 uses original Lab values. Unavailable means no evidence for the swatch.']
        if historical_patches:
            sections.append(('Latest measured print - colour swatches and Delta E00',
                ['Applies to iteration '+str(historical['iteration'])+'. These deviations were not measured for the current profile.',
                 'Desired colour, profile prediction and measured colour are shown as sRGB previews. Delta E00 compares measurement with desired colour (above 5). See Appendix A for selection and colour display.']))
    reference_title = content(r, "en")['title']
    sections.append((reference_title, [content(r, "en")['caption']]))
    sections.append((gamut_title, [gamut_surface.caption(language) if gamut else "Gamut unavailable: "+r.get('gamut', {}).get('reason', 'No surface saved.'), "ICC SHA-256: "+r['profile']['sha256']]))
    explanatory = [
        'Print measurements from previous iterations do not verify this ICC. Small differences between profiles do not prove unchanged print results.',
        'Printer, paper and ink limit the attainable gamut and result. Numerical checks do not replace a separate print and measurement.',
        'Evidence files accompany the report. Verification status and the user decision are stored in final-report.json.']
    sections.append(('Signature', [r['scopeStatement'],
        'By signing I confirm review of this certificate, its conditions, results, stated scope and documented decision.',
        'Place and date: ____________________________________',
        'Signature: ______________________________________',
        'Printed name: _________________________________',
        'Organisation / role: ______________________________']))
    sections.append((content(r, "en")['appendixTitle'], appendix_lines(r, "en") + measurement_explanations + explanatory))
    legal = r.get('legalAppendix', {})
    if legal:
        sections.append(('Appendix B - Legal terms', [
            title+': '+legal[key] for key, title in [
                ('reproductionLiability', 'Responsibility for equipment and material limitations'),
                ('clientPrintResponsibility', 'Client prints and information'),
                ('warrantyNotice', 'Warranty and liability'),
                ('licensingNotice', 'Licences and third-party rights')] if legal.get(key)]))
    project_section = next(section for section in sections if section[0] == 'Project and printing settings')
    sections.remove(project_section)
    sections.insert(1, project_section)
    text = '\n\n'.join(title+'\n'+'\n'.join(lines + [': '.join(row) for row in content(r, "en")['rows']] if title == reference_title else lines) for title, lines in sections)
    (folder / 'final-report.txt').write_text(text, encoding='utf-8')
    # Each HTML section is a page with an explicit footer, also when printed.
    pages = []
    for i, (title, lines) in enumerate(sections, 1):
        body = ''.join('<p>'+html.escape(str(line))+'</p>' for line in lines)
        if title == reference_title:
            body = table_html(r, "en").replace('<h2>'+html.escape(reference_title)+'</h2>', '')
        if title == content(r, "en")['appendixTitle']:
            from certificate_standards import reference
            url = reference(r)['sourceURL']
            body = body.replace(html.escape(url), '<a href="'+html.escape(url, quote=True)+'">MediaStandard Print 2018, table 30, page 50</a>')
        if title == measured_title and historical_measured:
            from lab_views import interactive as measured_view
            body += measured_view(historical_measured)
        if title == gamut_title:
            body += gamut_surface.interactive(gamut, language)
        if title == figure_title:
            body += interactive(figure_groups, language)
        if title == 'Latest measured print - colour swatches and Delta E00':
            body += '<div class="patches">'+''.join(
                '<div class="patch">'+html_chips(p)+'<p>'+html.escape(
                    'ID '+str(p['sampleId'])+' | '+str(p['coordinate'])+' | Delta E00 '+format(p['deltaE00'],'.4f')+' | '+p['hex'])+'</p></div>'
                for p in historical_patches)+'</div>'
        if title == 'Previous print measurements - historical evidence':
            body += "<p><a href='previous-certificate/final-report.html'>Previous certificate (HTML)</a> | <a href='previous-certificate/final-report.pdf'>PDF</a></p>"
        pages.append(f"<article><header>{html.escape(r['pageHeader'])}</header><h1>{html.escape(title)}</h1>{body}"
                     f"<footer>{html.escape(r['reportDate'])} | {html.escape(r['reportUser'])} | {i} ({len(sections)})</footer></article>")
    delivery_link = ''
    if r.get('deliveryProfile'):
        from urllib.parse import quote
        delivery_link = "<a href='"+quote(r['deliveryProfile']['file'])+"'>Named delivery profile</a> | "
    links = ''.join(f"<li><a href='{html.escape(s['file'], quote=True)}'>{html.escape(k)}</a></li>" for k, s in r['sources'].items())
    document = "<!doctype html><html lang='en'><meta charset='utf-8'><title>InkProf - Measurement certificate</title><style>body{font:16px system-ui;background:#eef2f4;color:#19303c}article{background:white;max-width:850px;margin:24px auto;padding:35px;overflow-wrap:anywhere}header,footer{font-size:13px;color:#52656e}footer{border-top:1px solid #ccc;margin-top:30px;padding-top:15px}h1{font-size:24px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:8px;border-bottom:1px solid #ccd8de;text-align:left}.patches{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.patch{border:1px solid #ccc;padding:5px;font-size:12px;break-inside:avoid}@media print{article{break-after:page;margin:0}}</style>"+''.join(pages)+"<nav>"+delivery_link+"<a href='final-report.pdf'>PDF</a> | <a href='final-report.json'>JSON</a> | <a href='profile.icc'>ICC</a><ul>"+links+'</ul></nav></html>'
    (folder / 'final-report.html').write_text(document, encoding='utf-8')
    for name in ['Report', 'ReportBold']:
        pdfmetrics.registerFont(TTFont(name, str(Path(__file__).resolve().parents[1]/'resources/fonts/DejaVuSans.ttf')))
    styles = getSampleStyleSheet()
    for style in styles.byName.values():
        style.fontName = 'Report'
    styles['Heading2'].fontName = styles['Title'].fontName = 'ReportBold'
    styles['Title'].textColor = colors.HexColor('#19303c')
    styles.add(ParagraphStyle('ReportBody', fontName='Report', fontSize=9, leading=13, spaceAfter=7, wordWrap='CJK'))
    story = []
    for title, lines in sections:
        section_start = len(story)
        if title == reference_title:
            story += pdf_table(r, styles, "en")
            continue
        if title in (gamut_title, figure_title, measured_title, 'Latest measured print - colour swatches and Delta E00', 'Signature', 'Appendix B - Legal terms', content(r, "en")['appendixTitle']):
            story.append(PageBreak())
        story.append(Paragraph(html.escape(title), styles['Title'] if title in ('InkProf - Measurement certificate', 'Signature', 'Appendix B - Legal terms', content(r, "en")['appendixTitle']) else styles['Heading2']))
        for line in lines:
            body = html.escape(str(line)).replace('\n', '<br/>')
            story.append(Paragraph(body, styles['ReportBody']))
            if title == 'Signature':
                story.append(Spacer(1, 8*mm))

        if title == gamut_title and gamut:
            story.append(gamut_surface.pdf_drawing(gamut, language))
        if title == figure_title:
            story.append(pdf_drawing(figure_groups, language))
        if title == measured_title and historical_measured:
            from lab_views import point_drawing
            story.append(point_drawing(historical_measured['vertices'],historical_measured['rgb']))
        if title in ('Saved ICC profile', 'Delivered ICC profile', 'Checked ICC candidate (project original)'):
            story[section_start:] = [KeepTogether(story[section_start:])]
        if title == 'Latest measured print - colour swatches and Delta E00':
            cards=[]
            for patch in historical_patches:
                swatch=pdf_chips(patch)
                label='ID '+str(patch['sampleId'])+' | '+str(patch['coordinate'])+'\nDelta E00 '+format(patch['deltaE00'],'.4f')+' | '+patch['hex']
                cards.append(Table([[swatch],[Paragraph(html.escape(label).replace('\n','<br/>'),styles['ReportBody'])]],colWidths=[54*mm]))
            rows=[cards[i:i+3]+['']*(3-len(cards[i:i+3])) for i in range(0,len(cards),3)]
            grid=Table(rows,colWidths=[57*mm]*3)
            grid.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.3,colors.lightgrey)]))
            story.append(grid)

    class NumberedCanvas(Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.pages = []

        def showPage(self):
            self.pages.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            total = len(self.pages)
            for state in self.pages:
                self.__dict__.update(state)
                self.saveState()
                self.resetTransforms()
                self.setFillColorRGB(0, 0, 0)
                self.setFont('Report', 12)
                self.drawCentredString(105*mm, 282*mm, r['pageHeader'])
                self.setFont('Report', 8)
                self.drawString(18*mm, 12*mm, r['reportDate'])
                user = Paragraph(html.escape(r['reportUser']), styles['Normal'])
                _, height = user.wrap(105*mm, 15*mm)
                user.drawOn(self, 53*mm, 12*mm)
                self.drawRightString(192*mm, 12*mm, f'{self._pageNumber} ({total})')
                self.restoreState()
                super().showPage()
            from pdf_notices import attach
            attach(self)
            super().save()

    SimpleDocTemplate(str(folder / 'final-report.pdf'), pagesize=(210*mm, 297*mm),
        leftMargin=18*mm, rightMargin=18*mm, topMargin=28*mm, bottomMargin=28*mm,
        title='InkProf - Measurement certificate', author=r['reportUser']).build(story, canvasmaker=NumberedCanvas)


if __name__ == '__main__':
    create(sys.argv[1])
