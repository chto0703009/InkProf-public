# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Complete, traceable patch tables, without diagnostic-threshold exclusions."""
import hashlib
import json
from pathlib import Path


def complete_rows(report, folder):
    rows=[];root=Path(folder).resolve()
    for key,label in [('checks_fit','Fitting'),('c3_report','Verification')]:
        source=report.get('sources',{}).get(key)
        if not source:
            continue
        path=(root/source['file']).resolve()
        if not path.is_relative_to(root) or hashlib.sha256(path.read_bytes()).hexdigest()!=source['sha256']:
            raise ValueError('Supplement evidence integrity mismatch.')
        data=json.loads(path.read_text())
        for patch in data.get('patches',[]):
            rows.append(dict(group=label,id=str(patch.get('sampleId','')),role=patch.get('role','fitting'),
                coordinate=patch.get('coordinate',''),reference=patch.get('desiredLab') if key=='c3_report' else patch.get('predictedLab'),
                measured=patch.get('measuredLab'),predicted=patch.get('predictedLab'),delta=patch['deltaE00']))
    if not any(row['group']=='Verification' for row in rows):
        legacy=report.get('patchOutliers',{}).get('allPatches',[])
        if isinstance(legacy,dict):legacy=[legacy]
        for patch in legacy:
            rows.append(dict(group='Verification',id=str(patch.get('sampleId','')),role=patch.get('role','colour'),
                coordinate=patch.get('coordinate',''),reference=patch.get('desiredLab'),measured=patch.get('measuredLab'),
                predicted=patch.get('predictedLab'),delta=patch['deltaE00']))
    return sorted(rows,key=lambda row: row['delta'])


def complete_table(report, folder, paragraph):
    from reportlab.platypus import Table,TableStyle
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    rows=complete_rows(report,folder)
    note='All saved fitting and current verification patches, including repeats and paper white. No Delta E00 cutoff. Ordered from smallest to largest unrounded deviation. Fitting compares model with measured Lab; verification compares measured with desired Lab. These comparisons are distinct. Lab order: L*, a*, b*. Each group retains its saved colourimetry.'
    if not rows:
        return [paragraph('No per-patch evidence available.')]
    def lab(value):
        return ', '.join(f'{x:.2f}' for x in value) if value is not None else 'Unavailable'
    def coloured_lab(value):
        from certificate_swatches import lab_hex
        if value is None:
            return paragraph('Unavailable','DetailReport')
        swatch=Table([['']],colWidths=[27*mm],rowHeights=[6*mm])
        swatch.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor(lab_hex(value))),
            ('BOX',(0,0),(-1,-1),.3,colors.grey)]))
        cell=Table([[swatch],[paragraph(lab(value),'DetailReport')]],colWidths=[29*mm])
        cell.setStyle(TableStyle([('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0)]))
        return cell
    cells=[[paragraph(s,'DetailHeading') for s in ['Group / role','Patch / location','Reference Lab','Measured Lab','Predicted Lab','Delta E00']]]
    for row in rows:
        cells.append([paragraph(row['group']+' / '+row['role'],'DetailReport'),
            paragraph(row['id']+' / '+row['coordinate'],'DetailReport'),
            coloured_lab(row['reference']),coloured_lab(row['measured']),coloured_lab(row['predicted']),
            paragraph(f"{row['delta']:.4f}",'DetailReport')])
    table=Table(cells,colWidths=[29*mm,22*mm,34*mm,34*mm,34*mm,21*mm],repeatRows=1,hAlign='LEFT')
    table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.25,colors.HexColor('#ccd8de')),('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eef3f5')),('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5)]))
    return [paragraph(note),paragraph(f'{len(rows)} patches; patch IDs and locations retained for traceability.'),table]
