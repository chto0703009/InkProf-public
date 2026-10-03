"""Portable numerical-only ICC report, explicitly excluding print validation."""
import html
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
import reportlab


def create(folder, language="sv"):
    folder = Path(folder)
    r = json.loads((folder / 'final-report.json').read_text(encoding='utf-8'))
    from certificate_figure import load, interactive, pdf_drawing
    figure_groups = load(folder, r)
    figure_title = 'Profiljämförelse - 2D och 3D i CIELAB'
    sections = [('InkProf - mätcertifikat', ['Certifikat-ID: '+r.get('certificateId', 'Ej angivet'), r.get('certificateScope', ''), r['scopeStatement'],
        f"Projekt: {r['project']['name']} | Iteration {r['iteration']}",
        'Aktuell profil: numeriskt kontrollerad. Tidigare utskriftsmätningar redovisas separat som historiskt underlag.']),
        ('Beslut och avsedd användning', [r['decision']['notes']]),
        ('Sparad ICC-profil', [r['profile']['file'], 'SHA-256: '+r['profile']['sha256']]),
        ('Projekt och utskriftsinställningar', [f'{label}: {r["printing"].get(key, "Ej angivet")}' for key, label in [('printer','Skrivare'),('paper','Papper'),('paperSurface','Yta'),('ink','Bläck'),('media','Mediainställning'),('driver','Drivrutin'),('quality','Utskriftskvalitet'),('printPath','Utskriftsprogram'),('colorManagement','Färghantering'),('dryingHours','Torktid (timmar)'),('fwaCompensation','Kompensation för optiska vitmedel'),('settings','Övriga inställningar')]])]
    sections[3][1].insert(0, 'Projekt-ID: '+str(r['project']['id']))
    sections[3][1].insert(1, 'Ansvarig användare: '+r['reportUser'])
    if r.get('deliveryProfile'):
        from delivery_report import details
        sections[2] = ('Kontrollerad ICC-kandidat (projektoriginal)', sections[2][1])
        sections.insert(3, ('Levererad ICC-profil', details(r['deliveryProfile'])))
    evidence = r.get('decisionEvidence', {})
    fit = evidence.get('trainingFit', {})
    def stats(values):
        return ' | '.join(label+': '+format(values[key], '.4f') for key, label in
                         [('mean', 'Medel'), ('p95', '95:e percentil'), ('max', 'Max')] if key in values)
    decision_lines = ['Endast underlag för användarens beslut att avsluta iterationen; inte belägg för förbättrad utskriftsnoggrannhet.']
    for key, label in [('previous', 'Föregående iteration'), ('current', 'Aktuell iteration')]:
        if key in fit:
            decision_lines.append(label+' - anpassningsfel (Delta E00): '+stats(fit[key])+f" | Antal patchar: {fit[key].get('count', 'ej angivet')}")
    if fit.get('previous') and fit.get('current'):
        delta = {k: fit['current'][k]-fit['previous'][k] for k in ('mean', 'p95', 'max') if k in fit['current'] and k in fit['previous']}
        decision_lines.append('Förändring av anpassningsfel, aktuell minus föregående: '+stats(delta))
        decision_lines.append('Positiv förändring betyder högre anpassningsfel; negativ betyder lägre. Två iterationer räcker inte för att fastställa generell konvergens eller divergens.')
    if fit.get('caveat'):
        decision_lines.append(fit['caveat'])
    comparison = evidence.get('comparison', {})
    if comparison:
        decision_lines += [f"Profiljämförelse: iteration {comparison['previousIteration']} mot {comparison['currentIteration']}",
            'Skillnad mellan profilerna vid samma RGB (Delta E00): '+stats(comparison['sameRGBDeltaE00']),
            'Skillnad i RGB-val vid samma Lab (procentenheter): '+stats(comparison['sameLabRGBChangePercentagePoints']),
            'Dessa värden beskriver skillnader mellan ICC-beräkningar, inte fel mot en uppmätt kontrollutskrift.']
    else:
        decision_lines.append('Ingen aktuell profiljämförelse bifogad. Kör steg 18 före export om den ska ingå.')
    sections.insert(2, ('Jämförelse som beslutsunderlag', decision_lines))
    for key, source in r['sources'].items():
        data = json.loads((folder / source['file']).read_text(encoding='utf-8'))
        lines = [f"Underlag: {source['file']}", 'SHA-256: '+source['sha256']]
        if 'summary' in data:
            lines.append('Anpassningsfel (Delta E00): '+stats(data['summary']))
        if 'roundtripDeltaE00' in data:
            lines.append('Numeriskt framåt-/återfel (Delta E00): '+stats(data['roundtripDeltaE00']))
        if 'allNegativeControlsDetected' in data:
            lines.append('Alla avsiktliga fel i kontrollproven upptäckta: '+('Ja' if data['allNegativeControlsDetected'] else 'Nej'))
        if 'grossFailureAlerts' in data:
            lines.append('Allvarliga numeriska varningar: '+(str(data['grossFailureAlerts']) if data['grossFailureAlerts'] else 'Inga'))
        sections.append(('Numeriskt underlag: '+key, lines))
    if r.get('fwa'):
        sections.append(('FWA/OBA - val och resultat', [r['fwa']['summaryText']]))
    if figure_groups is not None:
        sections.append((figure_title, ['Blå: föregående profil. Orange: aktuell profil. Gemensamma RGB-provpunkter, beräknade i CIELAB D50; inte uppmätta färgomfångsgränser.', 'HTML startar i 2D vid L*=50 med halvbredd 5. Ändra L* för att se andra snitt. Avmarkera 2D och dra i figuren för att rotera 3D-vyn. PDF visar en fast 3D-vy.']))
    historical = r.get('historicalCertificate', {})
    historical_patches = []
    if historical:
        import hashlib
        source = folder / historical['file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != historical['sha256']:
            raise ValueError('Historical certificate checksum mismatch')
        old = json.loads(source.read_text(encoding='utf-8'))
        lines = [historical['scope'], 'Iteration: '+str(historical['iteration']),
                 'Tidigare ICC SHA-256: '+historical['profileSHA256'],
                 'Tidigare certifikat-ID: '+old.get('certificateId', 'Ej angivet')]
        for key, identity in old.get('instruments', {}).items():
            label = 'Profileringsmätning' if key == 'measurement' else 'Kontrollmätning'
            lines.append(label+' - spektrometer: '+str(identity.get('model', 'Ej angivet'))+
                         '; serienummer: '+str(identity.get('serialNumber', 'Ej angivet')))
        for key, result in old.get('results', {}).items():
            if key == 'c3_report' and result.get('summary'):
                lines.append('Tidigare kontrollutskrift (Delta E00): '+stats(result['summary']))
        lines.append('Det fullständiga tidigare mätcertifikatet medföljer i mappen previous-certificate.')
        sections.append(('Tidigare utskriftsmätningar - historiskt underlag', lines))
        outliers = old.get('patchOutliers', {})
        historical_patches = outliers.get('patches', [])
        if isinstance(historical_patches, dict):
            historical_patches = [historical_patches]
        if historical_patches:
            sections.append(('Sista mätresultat - färgprov och Delta E00',
                ['Gäller iteration '+str(historical['iteration'])+'. Dessa avvikelser är inte uppmätta för aktuell profil.',
                 outliers.get('basis',''), outliers.get('colourNote',''),
                 'Källa: Bundesverband Druck und Medien (bvdm), Tysklands tryck- och medieförbund: MediaStandard Print 2018, tabell 30 (ISO 12647-7:2016).']))
    sections.append(('Omfattning och begränsningar', [
        'Tidigare iterationers utskriftsmätningar används inte som verifiering av denna ICC. Små skillnader mellan profiler bevisar inte att utskriftsresultatet är oförändrat.',
        'Skrivare, papper och bläck begränsar det möjliga färgomfånget och resultatet. Numeriska kontroller ersätter inte en separat utskrift och mätning.',
        'Underlagsfilerna medföljer rapporten. Verifieringsstatus och användarens beslut finns i final-report.json.']))
    sections.append(('Underskrift', [r['scopeStatement'],
        'Med min underskrift bekräftar jag att jag granskat mätcertifikatets förutsättningar, resultat, angivna omfattning och dokumenterade beslut.',
        'Ort och datum: ____________________________________',
        'Underskrift: ______________________________________',
        'Namnförtydligande: _________________________________',
        'Organisation / roll: ______________________________']))
    legal = r.get('legalAppendix', {})
    if legal:
        sections.append(('Bilaga A - Juridiska villkor', [
            title+': '+legal[key] for key, title in [
                ('reproductionLiability', 'Ansvar för utrustningens och materialens begränsningar'),
                ('clientPrintResponsibility', 'Beställarens utskrifter och uppgifter'),
                ('warrantyNotice', 'Garanti och ansvar')] if legal.get(key)]))
    project_section = next(section for section in sections if section[0] == 'Projekt och utskriftsinställningar')
    sections.remove(project_section)
    sections.insert(1, project_section)
    text = '\n\n'.join(title+'\n'+'\n'.join(lines) for title, lines in sections)
    (folder / 'final-report.txt').write_text(text, encoding='utf-8')
    # Each HTML section is a page with an explicit footer, also when printed.
    pages = []
    for i, (title, lines) in enumerate(sections, 1):
        body = ''.join('<p>'+html.escape(str(line))+'</p>' for line in lines)
        if title == figure_title:
            body += interactive(figure_groups, language)
        if title == 'Sista mätresultat - färgprov och Delta E00':
            body += '<div class="patches">'+''.join(
                '<div class="patch"><div style="height:45px;background:'+html.escape(p['hex'],quote=True)+'"></div><p>'+html.escape(
                    'ID '+str(p['sampleId'])+' | '+str(p['coordinate'])+' | Delta E00 '+format(p['deltaE00'],'.4f')+' | '+p['hex'])+'</p></div>'
                for p in historical_patches)+'</div>'
        if title == 'Tidigare utskriftsmätningar - historiskt underlag':
            body += "<p><a href='previous-certificate/final-report.html'>Tidigare mätcertifikat (HTML)</a> | <a href='previous-certificate/final-report.pdf'>PDF</a></p>"
        pages.append(f"<article><header>{html.escape(r['pageHeader'])}</header><h1>{html.escape(title)}</h1>{body}"
                     f"<footer>{html.escape(r['reportDate'])} | {html.escape(r['reportUser'])} | {i} ({len(sections)})</footer></article>")
    delivery_link = ''
    if r.get('deliveryProfile'):
        from urllib.parse import quote
        delivery_link = "<a href='"+quote(r['deliveryProfile']['file'])+"'>Namngiven leveransprofil</a> | "
    links = ''.join(f"<li><a href='{html.escape(s['file'], quote=True)}'>{html.escape(k)}</a></li>" for k, s in r['sources'].items())
    document = "<!doctype html><html lang='sv'><meta charset='utf-8'><title>InkProf - mätcertifikat</title><style>body{font:16px system-ui;background:#eef2f4;color:#19303c}article{background:white;max-width:850px;margin:24px auto;padding:35px;overflow-wrap:anywhere}header,footer{font-size:13px;color:#52656e}footer{border-top:1px solid #ccc;margin-top:30px;padding-top:15px}h1{font-size:24px}.patches{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.patch{border:1px solid #ccc;padding:5px;font-size:12px;break-inside:avoid}@media print{article{break-after:page;margin:0}}</style>"+''.join(pages)+"<nav>"+delivery_link+"<a href='final-report.pdf'>PDF</a> | <a href='final-report.json'>JSON</a> | <a href='profile.icc'>ICC</a><ul>"+links+'</ul></nav></html>'
    (folder / 'final-report.html').write_text(document, encoding='utf-8')
    fonts = Path(reportlab.__file__).parent / 'fonts'
    for name, filename in [('Report','Vera.ttf'),('ReportBold','VeraBd.ttf')]:
        font = TTFont(name,str(fonts/filename))
        # Vera has the triangular increment glyph but no U+0394 Greek Delta.
        # Reuse that glyph while preserving U+0394 in the PDF text mapping.
        if 0x394 not in font.face.charToGlyph:
            font.face.charToGlyph[0x394] = font.face.charToGlyph[0x2206]
            font.face.charWidths[0x394] = font.face.charWidths[0x2206]
        pdfmetrics.registerFont(font)
    styles = getSampleStyleSheet()
    for style in styles.byName.values():
        style.fontName = 'Report'
    styles['Heading2'].fontName = styles['Title'].fontName = 'ReportBold'
    styles['Title'].textColor = colors.HexColor('#19303c')
    styles.add(ParagraphStyle('ReportBody', fontName='Report', fontSize=9, leading=13, spaceAfter=7, wordWrap='CJK'))
    story = []
    for title, lines in sections:
        section_start = len(story)
        if title in (figure_title, 'Sista mätresultat - färgprov och Delta E00', 'Underskrift', 'Bilaga A - Juridiska villkor'):
            story.append(PageBreak())
        story.append(Paragraph(html.escape(title), styles['Title'] if title in ('InkProf - mätcertifikat', 'Underskrift', 'Bilaga A - Juridiska villkor') else styles['Heading2']))
        for line in lines:
            body = html.escape(str(line)).replace('\n', '<br/>')
            story.append(Paragraph(body, styles['ReportBody']))
            if title == 'Underskrift':
                story.append(Spacer(1, 8*mm))

        if title == figure_title:
            story.append(pdf_drawing(figure_groups, language))
        if title in ('Sparad ICC-profil', 'Levererad ICC-profil', 'Kontrollerad ICC-kandidat (projektoriginal)'):
            story[section_start:] = [KeepTogether(story[section_start:])]
        if title == 'Sista mätresultat - färgprov och Delta E00':
            cards=[]
            for patch in historical_patches:
                swatch=Table([['']],colWidths=[49*mm],rowHeights=[13*mm])
                swatch.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor(patch['hex']))]))
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
            super().save()

    SimpleDocTemplate(str(folder / 'final-report.pdf'), pagesize=(210*mm, 297*mm),
        leftMargin=18*mm, rightMargin=18*mm, topMargin=28*mm, bottomMargin=28*mm,
        title='InkProf - mätcertifikat', author=r['reportUser']).build(story, canvasmaker=NumberedCanvas)


if __name__ == '__main__':
    create(sys.argv[1])
