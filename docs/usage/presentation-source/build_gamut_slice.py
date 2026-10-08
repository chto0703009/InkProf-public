# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Render a scientific L*=50 section and projected model paper white; no ICC is bundled."""
import argparse,hashlib,json,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageChops
import colour
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'analysis'))
from profile_grid import lookup


def section(vertices,triangles,lightness):
    segments=[]
    for triangle in triangles:
        v=vertices[triangle];points=[]
        for i,j in ((0,1),(1,2),(2,0)):
            a,b=v[i],v[j]
            if (a[0]<lightness<=b[0]) or (b[0]<lightness<=a[0]):
                points.append(a[1:]+(lightness-a[0])/(b[0]-a[0])*(b[1:]-a[1:]))
        if len(points)==2 and np.linalg.norm(points[0]-points[1])>1e-8:segments.append(points)
    # Stitch triangle-plane intersections; do not replace the section with a convex hull.
    edges={}
    for a,b in segments:
        a,b=tuple(np.round(a,6)),tuple(np.round(b,6))
        if a==b:continue
        edges.setdefault(a,set()).add(b);edges.setdefault(b,set()).add(a)
    if not edges or any(len(v)!=2 for v in edges.values()):raise ValueError('Section is not a closed degree-two contour.')
    remaining=set(edges);loops=[]
    while remaining:
        start=min(remaining);loop=[start];previous=None;current=start
        while True:
            nxt=next(x for x in sorted(edges[current]) if x!=previous)
            if nxt==start:break
            if nxt in loop:raise ValueError('Unexpected contour self connection.')
            loop.append(nxt);previous,current=current,nxt
        remaining.difference_update(loop);loops.append(loop)
    return loops,len(segments)


def render(data,white,loops,lang,path):
    im=Image.new('RGB',(1800,1140),'white');draw=ImageDraw.Draw(im)
    regular=ROOT/'resources/fonts/DejaVuSans.ttf'
    def font(size):return ImageFont.truetype(str(regular),size)
    ink='#182f42';teal='#007f83';muted='#50616c';red='#a73f24'
    en=lang=='en'
    draw.text((85,20),'Gamut at L* = 50',font=font(44),fill=ink)
    draw.text((85,80),'CIELAB D50 · Epson 3880 · Photo Rag Baryta 315 · InkProf iteration 3',font=font(23),fill=muted)
    left,top,size=100,155,850;limit=100
    def point(v):return (left+size*(v[0]+limit)/(2*limit),top+size*(limit-v[1])/(2*limit))
    draw.rectangle((left,top,left+size,top+size),fill='#fafcfc')
    mask=Image.new('1',(size,size),0)
    for loop in loops:
        part=Image.new('1',(size,size),0)
        ImageDraw.Draw(part).polygon([(point(v)[0]-left,point(v)[1]-top) for v in loop],fill=1)
        mask=ImageChops.logical_xor(mask,part)
    aa,bb=np.meshgrid(np.linspace(-limit,limit,size),np.linspace(limit,-limit,size))
    lab=np.stack((np.full_like(aa,50),aa,bb),axis=-1)
    d50=colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D50']
    xyz=colour.Lab_to_XYZ(lab,illuminant=d50)
    rgb=np.clip(colour.XYZ_to_sRGB(xyz,illuminant=d50,chromatic_adaptation_transform='Bradford'),0,1)
    im.paste(Image.fromarray(np.rint(rgb*255).astype('uint8')),(left,top),mask.convert('L'))
    for loop in loops:
        xy=[point(p) for p in loop];draw.line(xy+[xy[0]],fill=ink,width=4,joint='curve')
    for tick in range(-100,101,25):
        x,y=point((tick,tick))
        draw.line((x,top,x,top+size),fill='#dde5e8',width=1)
        draw.line((left,y,left+size,y),fill='#dde5e8',width=1)
        draw.text((x,top+size+12),str(tick),font=font(21),fill=muted,anchor='mt')
        draw.text((left-12,y),str(tick),font=font(21),fill=muted,anchor='rm')
    x0,y0=point((0,0));draw.line((left,y0,left+size,y0),fill='#aabac2',width=2);draw.line((x0,top,x0,top+size),fill='#aabac2',width=2)
    draw.rectangle((left,top,left+size,top+size),outline=ink,width=2)
    draw.text((left+size/2,top+size+55),'a*',font=font(28),fill=ink,anchor='mt')
    draw.text((left-55,top+size/2),'b*',font=font(28),fill=ink,anchor='mm')
    wx,wy=point(white[1:]);draw.ellipse((x0-5,y0-5,x0+5,y0+5),fill=muted)
    draw.line((wx-13,wy,wx+13,wy),fill=red,width=5);draw.line((wx,wy-13,wx,wy+13),fill=red,width=5)
    draw.line((wx+18,wy-10,1010,370),fill=red,width=2)
    draw.line((1030,185,1110,185),fill=teal,width=6)
    draw.text((1130,167),'Gamut boundary',font=font(29),fill=ink)
    texts=[('Cross-section at L* = 50.',225),
           ('sRGB preview; colours may be clipped.',263),
           ('Paper white',340),
           (f'L* = {white[0]:.2f}',395),(f'a* = {white[1]:.2f}    b* = {white[2]:.2f}',437),
           ('Predicted at printer RGB = (1, 1, 1).',495),
           ('The cross shows its a*, b* position.',550),
           ('The actual white point lies outside',592),
           ('the L* = 50 plane.',634),
           ('D50 neutral axis: a* = 0, b* = 0.',715),
           ('White is predicted by the profile;',800),
           ('this is not a new paper measurement.',842)]
    for t,y in texts:draw.text((1030,y),t,font=font(27 if y!=340 else 34),fill=red if 340<=y<=437 else ink)
    draw.text((85,1100),'Absolute colorimetric A2B · triangle/plane intersection · profile SHA-256 '+data['profileSHA256'][:16],font=font(20),fill=muted)
    im.save(path)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('surface');p.add_argument('profile');p.add_argument('xicclu');p.add_argument('output');a=p.parse_args()
    data=json.loads(Path(a.surface).read_text());sha=hashlib.sha256(Path(a.profile).read_bytes()).hexdigest()
    if sha!=data['profileSHA256']:raise ValueError('Surface/profile mismatch.')
    if data['method']!='Argyll iccgamut forward A2B, absolute colorimetric, CIELAB D50':raise ValueError('Unsupported surface colour conditions.')
    loops,count=section(np.asarray(data['vertices']),np.asarray(data['triangles']),50)
    white=lookup(a.xicclu,a.profile,[[1,1,1]],intent='a')[0]
    if any(abs(v)>100 for loop in loops for point in loop for v in point):raise ValueError('Contour exceeds plotting limits.')
    out=Path(a.output);out.mkdir(exist_ok=True,parents=True)
    for lang in ('en',):render(data,white,loops,lang,out/f'gamut-L50-{lang}.png')
    metadata=dict(profileSHA256=sha,lightness=50,whitePointLab=white.tolist(),whitePointMethod='xicclu forward absolute colorimetric D50 at device RGB 1 1 1',whitePointDisplay='a,b projection; actual L shown separately',sectionMethod='triangle-plane intersection; no convex hull',segments=count,closedContours=len(loops))
    (out/'gamut-L50.json').write_text(json.dumps(metadata,indent=2)+'\n');print(json.dumps(metadata))
