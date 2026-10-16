# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Shared, explicitly non-certifying standards reference for certificates."""
import html
import json
from pathlib import Path


def reference(report):
    return report.get('standardsReference') or json.loads(
        (Path(__file__).resolve().parents[1] / 'resources' / 'certificate-standards.json').read_text(encoding='utf-8'))


def content(report, language='sv'):
    data = json.loads(json.dumps(reference(report)[language]))
    def edit(value):
        if isinstance(value,list):return [edit(v) for v in value]
        if isinstance(value,dict):return {k:edit(v) for k,v in value.items()}
        if not isinstance(value,str):return value
        from certificate_editorial import english
        if language=='en':
            value=english(value).replace('summarizes','summarises').replace('job-related digital proof control','job-specific digital proof control')
            value=value.replace('A list of ΔE00 values above 5 identifies patches for closer review.', 'The supplement flags ΔE00 values above 5 for closer review. The certificate summary shows up to 100 deviations above 1.')
        else:
            for a,b in [('Fogra MediaWedge','Fogra Media Wedge'),('InkProfs valfria','InkProfs egna'),('solider','heltoner'),('jobbrelaterad digital provtryckskontroll','jobbspecifik kontroll av digitala provtryck'),('Bilaga A -','Bilaga A –'),('Jämförelsereferens - bvdm /','Jämförelsereferens – bvdm/')]:value=value.replace(a,b)
            value=value.replace('En lista med ΔE00 över 5 markerar prov för närmare granskning.', 'Supplementet markerar prov med ΔE00 över 5; certifikatets färgöversikt visar högst 100 avvikelser över 1.')
        return value
    return edit(data)


def table_html(report, language='sv'):
    c = content(report, language)
    rows = '<tr>'+''.join('<th>'+html.escape(v)+'</th>' for v in c['columns'])+'</tr>'
    rows += ''.join('<tr>'+''.join('<td>'+html.escape(v)+'</td>' for v in row)+'</tr>' for row in c['rows'])
    return '<section class="standards-reference"><h2>'+html.escape(c['title'])+'</h2><p>'+html.escape(c['caption'])+'</p><table>'+rows+'</table></section>'


def appendix_lines(report, language='sv'):
    c = content(report, language)
    return c['paragraphs'] + [reference(report)['sourceURL']]


def pdf_table(report, styles, language='sv'):
    from reportlab.platypus import Paragraph, Table, TableStyle, KeepTogether
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    c = content(report, language)
    style = styles['BodyText']
    rows = [[Paragraph(html.escape(v), style) for v in row] for row in [c['columns']]+c['rows']]
    table = Table(rows, colWidths=[126*mm, 45*mm], repeatRows=1)
    table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#edf5f5')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.4,colors.lightgrey),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
    return [KeepTogether([Paragraph(html.escape(c['title']),styles['Heading2']),Paragraph(html.escape(c['caption']),style),table])]
