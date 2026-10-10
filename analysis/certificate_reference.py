# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Named reference colours from the verified C2/C3 evidence, including ColorChecker."""
from html import escape


def patches(report):
    if not report.get('referenceTarget'):
        return []
    values = report.get('patchOutliers', {}).get('allPatches', [])
    return [values] if isinstance(values, dict) else values


def title(report):
    return 'Reference target: ' + report['referenceTarget']['name']


NOTE = ('Measured print vs desired reference colour: Delta E00 calculated from Lab. '
        'Each pair shows reference (left) and measured print (right) as sRGB previews. '
        'Target order; repeats and paper-white controls excluded. Screen colours may be clipped. '
        'This section does not by itself establish certification or ISO conformity.')


def html_section(report):
    values = patches(report)
    if not values:
        return ''
    cells = []
    for patch in values:
        name = patch.get('referenceName') or patch['sampleId']
        cells.append('<div style="border:1px solid #ccd8de;padding:6px">'
                     '<div style="display:flex;height:28px">'
                     f'<span style="width:50%;background:{escape(patch.get("desiredHex") or "#ffffff")}"></span>'
                     f'<span style="width:50%;background:{escape(patch["hex"])}"></span></div>'
                     f'<strong>{escape(name)}</strong><br>Delta E00 {patch["deltaE00"]:.2f}</div>')
    return (f'<h2>{escape(title(report))}</h2><p>{escape(NOTE)}</p>'
            '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:6px">'
            + ''.join(cells) + '</div>')


def pdf_section(report, paragraph):
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import PageBreak, Table, TableStyle
    values = patches(report)
    if not values:
        return []
    cells = []
    for patch in values:
        swatch = Table([['', '']], colWidths=[12*mm]*2, rowHeights=[8*mm])
        swatch.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, 0), colors.HexColor(patch.get('desiredHex') or '#ffffff')),
            ('BACKGROUND', (1, 0), (1, 0), colors.HexColor(patch['hex']))]))
        name = patch.get('referenceName') or patch['sampleId']
        cells.append([swatch, paragraph(f'{name}\nDelta E00 {patch["deltaE00"]:.2f}', 'DetailReport')])
    rows = [cells[i:i+6] + ['']*(6-len(cells[i:i+6])) for i in range(0, len(cells), 6)]
    grid = Table(rows, colWidths=[29*mm]*6, hAlign='LEFT')
    grid.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'),
                             ('GRID', (0, 0), (-1, -1), .3, colors.lightgrey),
                             ('LEFTPADDING', (0, 0), (-1, -1), 2),
                             ('RIGHTPADDING', (0, 0), (-1, -1), 2)]))
    return [PageBreak(), paragraph(title(report), 'Heading2'), paragraph(NOTE), grid]
