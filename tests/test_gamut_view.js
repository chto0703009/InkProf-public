// Exercise the offline viewer without a browser or external assets.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
let polygons=0,frame,ready;const context=new Proxy({fill(){polygons++}}, {get(o,k){if(k in o)return o[k];return (...args)=>{for(const v of args)if(typeof v==='number')assert(Number.isFinite(v));}},set(o,k,v){o[k]=v;return true;}});
const canvas={width:850,height:520,getContext:()=>context,setPointerCapture:()=>{}};
const auto={checked:true},payload={vertices:[[0,0,0],[50,20,10],[100,0,0]],triangles:[[0,1,2]],rgb:[[0,0,0],[.5,.2,.1],[1,1,1]]};
const root={querySelector:q=>q==='canvas'?canvas:q==='input'?auto:{textContent:JSON.stringify(payload)}};
let nodes=[root];
vm.runInNewContext(fs.readFileSync('analysis/gamut_view.js','utf8'),{document:{currentScript:{previousElementSibling:root},addEventListener:(n,f)=>ready=f,querySelectorAll:()=>nodes},requestAnimationFrame:f=>frame=f});
assert.equal(polygons,1);frame(100);assert.equal(polygons,2);
canvas.onpointerdown({clientX:5,clientY:6,pointerId:1});assert.equal(auto.checked,false);
canvas.onpointermove({clientX:12,clientY:10});assert.equal(polygons,3);
canvas.onpointerup();canvas.onpointermove({clientX:20,clientY:20});assert.equal(polygons,3);
console.log('Gamut canvas rendering, rotation and drag passed.');

ready();assert.equal(polygons,3); // Existing nodes are not initialized twice.
nodes=[{querySelector:root.querySelector}];ready();assert.equal(polygons,4); // Paginator clones receive a new renderer.
