"""Portable numerical-only ICC report, explicitly excluding print validation."""
import html
import json
import sys
from pathlib import Path
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak


def create(folder):
    folder = Path(folder)
    r = json.loads((folder / 'final-report.json').read_text(encoding='utf-8'))
    sections = [('InkProf - numerisk profilrapport', [r['scopeStatement'],
        f"Projekt: {r['project']['name']} | Iteration {r['iteration']}",
        'Dokumentet redovisar numeriska kontroller och användarens beslut. Det är inte ett mätcertifikat över denna iterations utskriftsnoggrannhet eller ett intyg om ISO-överensstämmelse.']),
        ('Beslut och avsedd användning', [r['decision']['notes']]),
        ('Sparad ICC-profil', [r['profile']['file'], 'SHA-256: '+r['profile']['sha256']]),
        ('Projekt och utskriftsinställningar', [f'{label}: {r["printing"].get(key, "Ej angivet")}' for key, label in [('printer','Skrivare'),('paper','Papper'),('paperSurface','Yta'),('ink','Bläck'),('media','Mediainställning'),('driver','Drivrutin'),('quality','Utskriftskvalitet'),('colorManagement','Färghantering'),('dryingHours','Torktid (timmar)'),('fwaCompensation','Kompensation för optiska vitmedel'),('settings','Övriga inställningar')]])]
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
    sections.append(('Omfattning och begränsningar', [
        'Tidigare iterationers utskriftsmätningar används inte som verifiering av denna ICC. Små skillnader mellan profiler bevisar inte att utskriftsresultatet är oförändrat.',
        'Skrivare, papper och bläck begränsar det möjliga färgomfånget och resultatet. Numeriska kontroller ersätter inte en separat utskrift och mätning.',
        'Underlagsfilerna medföljer rapporten. Verifieringsstatus och användarens beslut finns i final-report.json.']))
    sections.append(('Underskrift', [r['scopeStatement'],
        'Underskriften bekräftar rapportens begränsade omfattning och det dokumenterade beslutet.',
        'Ort och datum: ____________________________________',
        'Underskrift: ______________________________________',
        'Namnförtydligande: _________________________________']))
    legal = r.get('legalAppendix', {})
    if legal:
        sections.append(('Bilaga A - Juridiska villkor', [
            title+': '+legal[key] for key, title in [
                ('reproductionLiability', 'Ansvar för utrustningens och materialens begränsningar'),
                ('clientPrintResponsibility', 'Beställarens utskrifter och uppgifter'),
                ('warrantyNotice', 'Garanti och ansvar')] if legal.get(key)]))
    text = '\n\n'.join(title+'\n'+'\n'.join(lines) for title, lines in sections)
    (folder / 'final-report.txt').write_text(text, encoding='utf-8')
    # Each HTML section is a page with an explicit footer, also when printed.
    pages = []
    for i, (title, lines) in enumerate(sections, 1):
        body = ''.join('<p>'+html.escape(str(line))+'</p>' for line in lines)
        pages.append(f"<article><header>{html.escape(r['pageHeader'])}</header><h1>{html.escape(title)}</h1>{body}"
                     f"<footer>{html.escape(r['reportDate'])} | {html.escape(r['reportUser'])} | {i} ({len(sections)})</footer></article>")
    links = ''.join(f"<li><a href='{html.escape(s['file'], quote=True)}'>{html.escape(k)}</a></li>" for k, s in r['sources'].items())
    document = "<!doctype html><html lang='sv'><meta charset='utf-8'><title>InkProf - numerisk profilrapport</title><style>body{font:16px system-ui;background:#eef2f4;color:#19303c}article{background:white;max-width:850px;margin:24px auto;padding:35px;overflow-wrap:anywhere}header,footer{font-size:13px;color:#52656e}footer{border-top:1px solid #ccc;margin-top:30px;padding-top:15px}h1{font-size:24px}@media print{article{break-after:page;margin:0}}</style>"+''.join(pages)+"<nav><a href='final-report.pdf'>PDF</a> | <a href='final-report.json'>JSON</a> | <a href='profile.icc'>ICC</a><ul>"+links+'</ul></nav></html>'
    (folder / 'final-report.html').write_text(document, encoding='utf-8')
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle('ReportBody', fontName='Helvetica', fontSize=10, leading=14, spaceAfter=9, wordWrap='CJK'))
    story = []
    for title, lines in sections:
        if title in ('Projekt och utskriftsinställningar', 'Bilaga A - Juridiska villkor'):
            story.append(PageBreak())
        story.append(Paragraph(html.escape(title), styles['Heading2']))
        for line in lines:
            story.append(Paragraph(html.escape(str(line)).replace('\n', '<br/>'), styles['ReportBody']))
            if title == 'Underskrift':
                story.append(Spacer(1, 8*mm))

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
                self.setFont('Helvetica', 12)
                self.drawCentredString(105*mm, 282*mm, r['pageHeader'])
                self.setFont('Helvetica', 8)
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
        title='InkProf - numerisk profilrapport', author=r['reportUser']).build(story, canvasmaker=NumberedCanvas)


if __name__ == '__main__':
    create(sys.argv[1])
