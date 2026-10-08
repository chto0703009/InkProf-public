# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Compare successive RGB printer ICCs on shared samples, not their LUT nodes.
No measurement or profile approval is implied by numerical differences.
"""
import argparse, json, hashlib, shutil
from pathlib import Path
import numpy as np
import colour
from profile_grid import lookup

def stats(values):
    a=np.asarray(values)
    return dict(mean=float(a.mean()),median=float(np.median(a)),p95=float(np.percentile(a,95)),max=float(a.max()))

def run(old,new,exe,out,iteration=2,levels=9):
    old,new,out=Path(old),Path(new),Path(out)
    if iteration<2 or levels<3: raise ValueError('Iteration >=2 and grid levels >=3 required.')
    for p in (old,new):
        b=p.read_bytes()
        if len(b)<128 or b[36:40]!=b'acsp' or b[12:20]!=b'prtrRGB ':raise ValueError('Expected RGB output ICC profiles.')
    hashes=[hashlib.sha256(p.read_bytes()).hexdigest() for p in (old,new)]
    grid=np.stack(np.meshgrid(*([np.linspace(0,1,levels)]*3),indexing='ij'),-1).reshape(-1,3)
    forward=[lookup(exe,p,grid,'f','a') for p in (old,new)]
    de=colour.delta_E(*forward,method='CIE 2000')
    # Shared Lab targets are the union of both profiles' forward predictions.
    targets=np.concatenate(forward)
    inverse=[lookup(exe,p,targets,'b','a') for p in (old,new)]
    rgbdiff=np.max(np.abs(inverse[1]-inverse[0]),axis=1)*100
    # Local probes around the largest differences: reducing the interval
    # distinguishes a steep gradient from a candidate finite jump, not proof.
    worst=np.argsort(de)[-20:][::-1];local=[]
    for step in (.01,.001,.0001):
        samples=np.clip(np.array([grid[i]+sign*step*np.eye(3)[axis] for i in worst for axis in range(3) for sign in (-1,1)]),0,1)
        changes=[]
        for p in (old,new):
            lab=lookup(exe,p,samples,'f','a').reshape(-1,2,3)
            changes.append(stats(colour.delta_E(lab[:,0],lab[:,1],method='CIE 2000')))
        local.append(dict(rgbHalfStep=step,previous=changes[0],current=changes[1]))
    ramps=np.array([[t,a,b] if axis==0 else [a,t,b] if axis==1 else [a,b,t] for axis in range(3) for a in (0,.5,1) for b in (0,.5,1) for t in np.linspace(0,1,257)])
    rampstats=[]
    for p in (old,new):
        lab=lookup(exe,p,ramps,'f','a').reshape(27,257,3)
        rampstats.append(dict(adjacentDeltaE00=stats(colour.delta_E(lab[:,:-1],lab[:,1:],method='CIE 2000')),secondDifferenceLab=stats(np.linalg.norm(np.diff(lab,n=2,axis=1),axis=2))))
    r=dict(schemaVersion=1,documentType='inkprof.profile-comparison',previousIteration=iteration-1,currentIteration=iteration,
        profileSHA256=dict(previous=hashes[0],current=hashes[1]),settings=dict(gridLevels=levels,gridCount=len(grid),intent='absolute colorimetric',illuminant='D50',bpc=False,sharedLabCount=len(targets),rampCount=27,rampSamples=257),
        conclusion='Numerical comparison complete. Improvement in print accuracy has not yet been established by this comparison.',
        metricLabels=dict(sameRGBDeltaE00='Previous profile prediction vs current profile prediction'),measuredImprovement='not-assessed',sameRGBDeltaE00=stats(de),sameLabRGBChangePercentagePoints=stats(rgbdiff),localProbes=local,ramps=dict(previous=rampstats[0],current=rampstats[1]),
        worst=[dict(rgb=grid[i].tolist(),previousLab=forward[0][i].tolist(),currentLab=forward[1][i].tolist(),deltaE00=float(de[i])) for i in worst],
        grid=dict(rgb=grid.tolist(),previousLab=forward[0].tolist(),currentLab=forward[1].tolist(),deltaE00=de.tolist()),
        limitations=['Different original measurement meshes are handled by evaluating both profiles on identical inputs.',
        'Smaller profile differences or smoother ramps do not prove better print accuracy.',
        'Shared Lab targets may be outside one profile gamut. Inverse differences include clipping and table approximation.',
        'Finite sampling cannot prove continuity or establish the physical gamut. These are predicted colours, not measured surfaces.',
        'New independent printed and measured verification is required to assess progress.'])
    if hashes!=[hashlib.sha256(p.read_bytes()).hexdigest() for p in (old,new)]:raise ValueError('Profile changed during comparison.')
    out.mkdir(parents=True,exist_ok=False)
    for p,name in [(old,'previous.icc'),(new,'current.icc')]:shutil.copy2(p,out/name)
    import gamut_surface
    r['gamuts']={}
    gamut_exe=Path(exe).resolve().with_name('iccgamut')
    for name in ('previous','current'):
        folder=out/('gamut-'+name)
        try:
            ref=gamut_surface.generate(out/(name+'.icc'),folder,gamut_exe)
            r['gamuts'][name]=dict(ref,folder=folder.name)
        except Exception as error:
            if gamut_surface.digest(out/(name+'.icc')) != r['profileSHA256'][name]:
                raise ValueError('ICC changed during gamut calculation.') from error
            r['gamuts'][name]=dict(status='unavailable',reason=str(error))
    (out/'comparison.json').write_text(json.dumps(r,indent=2,allow_nan=False))
    render_reports(r,out)
    return r


def srgb_preview(lab):
    """D50 Lab to display sRGB, Bradford adapted to D65 and clipped."""
    white=colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    xyz=colour.Lab_to_XYZ(np.asarray(lab,dtype=float),illuminant=white)
    rgb=np.clip(colour.XYZ_to_sRGB(xyz,illuminant=white,chromatic_adaptation_transform='Bradford'),0,1)
    return '#' + ''.join(f'{int(v):02x}' for v in np.rint(rgb*255))


def render_reports(r,out):
    """Render saved comparison evidence without recalculating or approving it."""
    from html import escape
    out=Path(out)
    iteration=r['currentIteration'];previous=r['previousIteration'];grid=r['grid']['rgb'];local=r['localProbes']
    forward=[np.asarray(r['grid'][key]) for key in ('previousLab','currentLab')]
    preview_note='sRGB previews of predicted D50 Lab colours, adapted to D65. Colours outside sRGB are clipped; the colour chips are screen approximations. Delta E00 uses the original Lab values.'
    def chip(lab,label):
        value=srgb_preview(lab)
        return f'<span title="{label}: {value}" aria-label="{label}: {value}" style="display:inline-block;width:56px;height:30px;background:{value};border:1px solid #777;print-color-adjust:exact;-webkit-print-color-adjust:exact"></span>'
    summary=f'Iteration {previous} compared with iteration {iteration}. {len(grid)} shared RGB samples; absolute colorimetric, D50. Black point compensation disabled.'
    rows=''.join(f'<tr><td>{chip(x["previousLab"],"Previous")}</td><td>{chip(x["currentLab"],"Current")}</td><td>{x["rgb"]}</td><td>{x["deltaE00"]:.3f}</td><td>{x["previousLab"]}</td><td>{x["currentLab"]}</td></tr>' for x in r['worst'])
    text=f'''<!doctype html><meta charset="utf-8"><title>InkProf profile comparison</title><style>body{{font:16px system-ui;max-width:1100px;margin:32px auto;padding:16px;color:#183343}}table{{border-collapse:collapse;width:100%}}td,th{{padding:8px;border:1px solid #ccd}}canvas{{background:#f3f6f8;max-width:100%}}</style><h1>Profile comparison: iteration {previous} to {iteration}</h1><p>{summary}</p><p><b>{r['conclusion']}</b></p><h2>Previous profile prediction vs current profile prediction</h2><p>Same device RGB in both profiles; this is a prediction difference, not measured print error.</p><p>ΔE00 colour difference: mean {r['sameRGBDeltaE00']['mean']:.3f}; median {r['sameRGBDeltaE00']['median']:.3f}; 95th percentile {r['sameRGBDeltaE00']['p95']:.3f}; maximum {r['sameRGBDeltaE00']['max']:.3f}.</p><h2>Same desired Lab: difference in printer RGB</h2><p>Largest channel change, percentage points: mean {r['sameLabRGBChangePercentagePoints']['mean']:.3f}; maximum {r['sameLabRGBChangePercentagePoints']['max']:.3f}.</p><h2>Predicted colours: 2D lightness slice or 3D Lab</h2><p>Blue: iteration {previous}. Orange: iteration {iteration}. Shared RGB samples, not measured gamut boundaries. In 2D, move L* to inspect the a*/b* plane. Uncheck 2D for the full rotatable 3D view.</p><p><label><input type="checkbox" id="slice" checked> 2D a*/b* at selected L*</label> <label>L*: <input id="lightness" type="range" min="0" max="100" value="50" step="1"> <output id="level">50</output></label> <label>Half-width: <input id="width" type="number" min="1" max="50" value="5"> L*</label></p><p id="counts"></p><canvas id="view" width="900" height="460"></canvas><h2>Largest profile differences</h2><p>{preview_note}</p><table><tr><th>Previous sRGB</th><th>Current sRGB</th><th>Printer RGB (0–1)</th><th>ΔE00</th><th>Previous Lab</th><th>Current Lab</th></tr>{rows}</table><h2>Local behaviour</h2>'''
    for x in local:text+=f'<p>RGB half-step {x["rgbHalfStep"]}: maximum colour change across interval, previous {x["previous"]["max"]:.4f}, current {x["current"]["max"]:.4f} ΔE00.</p>'
    text+='<h2>Interpretation</h2><ul>'+''.join('<li>'+escape(t)+'</li>' for t in r['limitations'])+'</ul><p><a href="comparison.pdf">PDF report</a> · <a href="comparison.json">Full numerical results</a></p>'
    script = Path(__file__).with_name('profile_comparison_view.js').read_text(encoding='utf-8')
    text += '<script>const groups=' + json.dumps([x.tolist() for x in forward]) + ';const viewLabels='+json.dumps(dict(previous=f'Iteration {previous}',current=f'Iteration {iteration}'))+';\n' + script + '</script>'
    import gamut_surface
    text+='<h2>ICC gamut surfaces - CIELAB D50</h2><p>'+escape(gamut_surface.caption('en'))+'</p>'
    for name,number in [('previous',previous),('current',iteration)]:
        text+=f'<h3>Iteration {number} - {name} profile gamut</h3>'
        ref=r.get('gamuts',{}).get(name,{})
        if ref.get('status')=='available':
            data=gamut_surface.load(out/ref['folder'],dict(gamut=ref,profile=dict(sha256=r['profileSHA256'][name])))
            text+='<p>ICC SHA-256: '+escape(r['profileSHA256'][name])+'</p>'+gamut_surface.interactive(data,'en')
        else:
            text+='<p>Gamut unavailable: '+escape(ref.get('reason','No saved surface. Regenerate the comparison.'))+'</p>'
    (out/'comparison.html').write_text(text)
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,PageBreak
    from reportlab.lib import colors
    from reportlab.graphics.shapes import Drawing,Rect
    from reportlab.lib.styles import getSampleStyleSheet
    styles=getSampleStyleSheet();story=[Paragraph('InkProf - Profile comparison',styles['Title']),Paragraph(summary,styles['BodyText']),Spacer(1,12),Paragraph(r['conclusion'],styles['BodyText'])]
    for label,key in [('Previous profile prediction vs current profile prediction (Delta E00, same RGB)','sameRGBDeltaE00'),('Same Lab: RGB channel change (percentage points)','sameLabRGBChangePercentagePoints')]:
        story.extend([Spacer(1,14),Paragraph(label,styles['Heading2']),Table([['Mean','Median','95th percentile','Maximum'],[f'{r[key][k]:.4f}' for k in ('mean','median','p95','max')]])])
    story+=[Spacer(1,14),Paragraph('Local probes: maximum Delta E00 across each interval',styles['Heading2']),Table([['RGB half-step','Previous','Current']]+[[str(x['rgbHalfStep']),f"{x['previous']['max']:.4f}",f"{x['current']['max']:.4f}"] for x in local])]
    for line in r['limitations']:story.extend([Spacer(1,8),Paragraph(escape(line),styles['BodyText'])])
    from certificate_figure import ComparisonGroups, pdf_drawing as comparison_drawing
    groups=ComparisonGroups([r['grid']['previousLab'],r['grid']['currentLab']]);groups.iterations=(previous,iteration)
    story += [PageBreak(),Paragraph('Predicted colours - L* = 50 +/- 5',styles['Heading2']),Paragraph('Shared RGB predictions, not measured points. No new print measurements are included in this comparison.',styles['BodyText']),comparison_drawing(groups,'en')]
    for name,number in [('previous',previous),('current',iteration)]:
        story += [PageBreak(),Paragraph(f'Iteration {number} - ICC gamut at L* = 50',styles['Heading2'])]
        ref=r.get('gamuts',{}).get(name,{})
        if ref.get('status')=='available':
            data=gamut_surface.load(out/ref['folder'],dict(gamut=ref,profile=dict(sha256=r['profileSHA256'][name])))
            story += [Paragraph(escape(gamut_surface.caption('en')),styles['BodyText']),gamut_surface.pdf_drawing(data,'en')]
        else:
            story += [Paragraph('Gamut unavailable: '+escape(ref.get('reason','No surface saved.')),styles['BodyText'])]
    story.extend([PageBreak(),Paragraph('Largest profile differences',styles['Heading2']),Paragraph(preview_note,styles['BodyText']),Spacer(1,12)])
    def pdf_chip(lab):
        drawing=Drawing(42,22)
        drawing.add(Rect(0,0,42,22,fillColor=colors.HexColor(srgb_preview(lab)),strokeColor=colors.HexColor('#777777'),strokeWidth=.5))
        return drawing
    def coordinates(values):return ', '.join(f'{v:.2f}' for v in values)
    cells=[['Previous','Current','Printer RGB','Delta E00','Previous Lab','Current Lab']]
    for x in r['worst']:
        cells.append([pdf_chip(x['previousLab']),pdf_chip(x['currentLab']),coordinates(x['rgb']),f"{x['deltaE00']:.3f}",coordinates(x['previousLab']),coordinates(x['currentLab'])])
    table=Table(cells,colWidths=[53,53,89,57,108,108],repeatRows=1)
    table.setStyle([('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),('FONTSIZE',(0,0),(-1,-1),7),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e5eef4')),('GRID',(0,0),(-1,-1),.3,colors.HexColor('#ccd0d8')),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4)])
    story.append(table)
    SimpleDocTemplate(str(out/'comparison.pdf'),leftMargin=36,rightMargin=36).build(story)
    return r
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('previous');p.add_argument('current');p.add_argument('executable');p.add_argument('output');p.add_argument('--iteration',type=int,default=2);a=p.parse_args();run(a.previous,a.current,a.executable,a.output,a.iteration)
