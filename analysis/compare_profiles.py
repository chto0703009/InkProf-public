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
        measuredImprovement='not-assessed',sameRGBDeltaE00=stats(de),sameLabRGBChangePercentagePoints=stats(rgbdiff),localProbes=local,ramps=dict(previous=rampstats[0],current=rampstats[1]),
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
    (out/'comparison.json').write_text(json.dumps(r,indent=2,allow_nan=False))
    from html import escape
    summary=f'Iteration {iteration-1} compared with iteration {iteration}. {len(grid)} shared RGB samples; absolute colorimetric, D50. Black point compensation disabled.'
    rows=''.join(f'<tr><td>{x["rgb"]}</td><td>{x["deltaE00"]:.3f}</td><td>{x["previousLab"]}</td><td>{x["currentLab"]}</td></tr>' for x in r['worst'])
    text=f'''<!doctype html><meta charset="utf-8"><title>InkProf profile comparison</title><style>body{{font:16px system-ui;max-width:1100px;margin:32px auto;padding:16px;color:#183343}}table{{border-collapse:collapse;width:100%}}td,th{{padding:8px;border:1px solid #ccd}}canvas{{background:#f3f6f8;max-width:100%}}</style><h1>Profile comparison: iteration {iteration-1} to {iteration}</h1><p>{summary}</p><p><b>{r['conclusion']}</b></p><h2>Same RGB: difference in predicted colour</h2><p>ΔE00 colour difference: mean {r['sameRGBDeltaE00']['mean']:.3f}; median {r['sameRGBDeltaE00']['median']:.3f}; 95th percentile {r['sameRGBDeltaE00']['p95']:.3f}; maximum {r['sameRGBDeltaE00']['max']:.3f}.</p><h2>Same desired Lab: difference in printer RGB</h2><p>Largest channel change, percentage points: mean {r['sameLabRGBChangePercentagePoints']['mean']:.3f}; maximum {r['sameLabRGBChangePercentagePoints']['max']:.3f}.</p><h2>Predicted colours: 2D lightness slice or 3D Lab</h2><p>Blue: previous profile. Orange: current profile. Shared RGB samples, not measured gamut boundaries. In 2D, move L* to inspect the a*/b* plane. Uncheck 2D for the full rotatable 3D view.</p><p><label><input type="checkbox" id="slice" checked> 2D a*/b* at selected L*</label> <label>L*: <input id="lightness" type="range" min="0" max="100" value="50" step="1"> <output id="level">50</output></label> <label>Half-width: <input id="width" type="number" min="1" max="50" value="5"> L*</label></p><p id="counts"></p><canvas id="view" width="900" height="460"></canvas><h2>Largest profile differences</h2><table><tr><th>RGB (0–1)</th><th>ΔE00</th><th>Previous Lab</th><th>Current Lab</th></tr>{rows}</table><h2>Local behaviour</h2>'''
    for x in local:text+=f'<p>RGB half-step {x["rgbHalfStep"]}: maximum colour change across interval, previous {x["previous"]["max"]:.4f}, current {x["current"]["max"]:.4f} ΔE00.</p>'
    text+='<h2>Interpretation</h2><ul>'+''.join('<li>'+escape(t)+'</li>' for t in r['limitations'])+'</ul><p><a href="comparison.pdf">PDF report</a> · <a href="comparison.json">Full numerical results</a></p>'
    script = Path(__file__).with_name('profile_comparison_view.js').read_text(encoding='utf-8')
    text += '<script>const groups=' + json.dumps([x.tolist() for x in forward]) + ';\n' + script + '</script>'
    (out/'comparison.html').write_text(text)
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table
    from reportlab.lib.styles import getSampleStyleSheet
    styles=getSampleStyleSheet();story=[Paragraph('InkProf - Profile comparison',styles['Title']),Paragraph(summary,styles['BodyText']),Spacer(1,12),Paragraph(r['conclusion'],styles['BodyText'])]
    for label,key in [('Same RGB: colour difference (Delta E00)','sameRGBDeltaE00'),('Same Lab: RGB channel change (percentage points)','sameLabRGBChangePercentagePoints')]:
        story.extend([Spacer(1,14),Paragraph(label,styles['Heading2']),Table([['Mean','Median','95th percentile','Maximum'],[f'{r[key][k]:.4f}' for k in ('mean','median','p95','max')]])])
    story+=[Spacer(1,14),Paragraph('Local probes: maximum Delta E00 across each interval',styles['Heading2']),Table([['RGB half-step','Previous','Current']]+[[str(x['rgbHalfStep']),f"{x['previous']['max']:.4f}",f"{x['current']['max']:.4f}"] for x in local])]
    for line in r['limitations']:story.extend([Spacer(1,8),Paragraph(escape(line),styles['BodyText'])])
    SimpleDocTemplate(str(out/'comparison.pdf')).build(story)
    return r
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('previous');p.add_argument('current');p.add_argument('executable');p.add_argument('output');p.add_argument('--iteration',type=int,default=2);a=p.parse_args();run(a.previous,a.current,a.executable,a.output,a.iteration)
