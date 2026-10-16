# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""Named reference colours from the verified C2/C3 evidence, including ColorChecker."""
from html import escape


def patches(report):
    if not report.get('referenceTarget'):
        return []
    values = report.get('patchOutliers', {}).get('allPatches', [])
    return sorted([values] if isinstance(values, dict) else values, key=lambda p: p['deltaE00'])


def title(report):
    return 'Reference target: ' + report['referenceTarget']['name']


NOTE = ('Left: desired colour. Right: measured print. Number below: ΔE00. '
        'Up to 100 deviations above 1 are shown, smallest first. Screen colours are previews; full data are in the supplement.')


def compact_selection(values):
    return sorted((p for p in values if p.get('deltaE00', 0) > 1), key=lambda p: p['deltaE00'])[-100:]


def html_section(report):
    values = report.get('patchOutliers', {}).get('allPatches', [])
    values = compact_selection([values] if isinstance(values, dict) else values)
    if not values:
        return ''
    cells = []
    for patch in values:
        cells.append('<div style="border:1px solid #ccd8de;padding:6px;text-align:center">'
                     '<div style="display:flex;height:28px">'
                     f'<span style="width:50%;background:{escape(patch.get("desiredHex") or "#ffffff")}"></span>'
                     f'<span style="width:50%;background:{escape(patch["hex"])}"></span></div>'
                     f'{patch["deltaE00"]:.2f}</div>')
    return (f'<h2>{escape(title(report))+" – " if report.get("referenceTarget") else ""}Largest measured colour deviations with ΔE00 &gt; 1 ({len(values)} of {len(report.get("patchOutliers", {}).get("allPatches", []))})</h2><p>{escape(NOTE)}</p>'
            '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:6px">'
            + ''.join(cells) + '</div>')


def pdf_section(report, paragraph):
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import Table, TableStyle
    # Every verified target needs the diagnostic overview, not only named sets.
    values = report.get('patchOutliers', {}).get('allPatches', [])
    if isinstance(values, dict):
        values = [values]
    values = compact_selection(values)
    if not values:
        return []
    cells = []
    for patch in values:
        swatch = Table([['', '']], colWidths=[12*mm]*2, rowHeights=[8*mm])
        swatch.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, 0), colors.HexColor(patch.get('desiredHex') or '#ffffff')),
            ('BACKGROUND', (1, 0), (1, 0), colors.HexColor(patch['hex']))]))
        from copy import copy
        label = paragraph(f'{patch["deltaE00"]:.2f}', 'DetailReport')
        label.style = copy(label.style)
        label.style.alignment = 1
        cells.append([swatch, label])
    rows = [cells[i:i+6] + ['']*(6-len(cells[i:i+6])) for i in range(0, len(cells), 6)]
    grid = Table(rows, colWidths=[29*mm]*6, hAlign='LEFT')
    grid.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'),
                             ('GRID', (0, 0), (-1, -1), .3, colors.lightgrey),
                             ('LEFTPADDING', (0, 0), (-1, -1), 2),
                             ('RIGHTPADDING', (0, 0), (-1, -1), 2)]))
    heading = title(report) if report.get('referenceTarget') else 'Measured print vs desired colour'
    return [paragraph(heading+f' – largest deviations with ΔE00 > 1 ({len(values)} of {len(report.get("patchOutliers", {}).get("allPatches", []))})', 'Heading2'),
            paragraph(NOTE), grid]
