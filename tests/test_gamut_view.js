// Copyright (c) 2026 Christer Törnkvist.
// SPDX-License-Identifier: GPL-3.0-or-later
// InkProf is free software under GNU GPL version 3 or later.
// Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
let frames,draws=0;
const ctx=new Proxy({}, {get:(o,k)=>k==='clearRect'?()=>draws++:()=>{},set:(o,k,v)=>{o[k]=v;return true;}});
const nodes={canvas:{width:850,height:520,getContext:()=>ctx,setPointerCapture:()=>{}},
 '.lab-mode':{value:'2d'},'.lab-level':{value:'50'},'.lab-band':{value:'5'},'.lab-auto':{checked:false},'.lab-status':{},'.lab-band-label':{},output:{},
 script:{textContent:JSON.stringify({kind:'surface',label:'Test',vertices:[[0,0,0],[50,20,10],[100,0,0]],triangles:[[0,1,2]],rgb:[[0,0,0],[.5,.2,.1],[1,1,1]]})}};
const root={isConnected:true,querySelector:k=>nodes[k]};
vm.runInNewContext(fs.readFileSync('analysis/gamut_view.js','utf8'),{window:{},document:{currentScript:{previousElementSibling:root},addEventListener:()=>{},querySelectorAll:()=>[root]},requestAnimationFrame:f=>frames=f});
assert.equal(nodes['.lab-auto'].disabled,false);
nodes['.lab-auto'].checked=true;nodes['.lab-auto'].onchange({target:nodes['.lab-auto']});
assert.equal(nodes['.lab-mode'].value,'3d');let before=draws;frames(100);assert(draws>before);
nodes['.lab-mode'].value='2d';nodes['.lab-mode'].onchange({target:nodes['.lab-mode']});assert.equal(nodes['.lab-auto'].checked,false);
console.log('Change-event controls and direct 3D auto-rotation passed.');
