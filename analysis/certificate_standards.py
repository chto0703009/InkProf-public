"""Shared, explicitly non-certifying standards reference for certificates."""
import html
import json
from pathlib import Path


def reference(report):
    return report.get('standardsReference') or json.loads(
        (Path(__file__).resolve().parents[1] / 'resources' / 'certificate-standards.json').read_text(encoding='utf-8'))


def content(report, language='sv'):
    return reference(report)[language]


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
