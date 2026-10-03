function s=shadowSettings(printing)
% InkProf's optional matte strategy, using documented Argyll controls.
s=struct('mode',"auto-matte",'enabled',false,'patchEmphasis',2,'gridEmphasis',1.3, ...
 'extraPatches',48,'source',"InkProf strategy; not an Argyll matte-paper preset");
if isfield(printing,'shadowMode'),s.mode=string(printing.shadowMode);end
assert(isscalar(s.mode)&&any(s.mode==["auto-matte","standard"]),'inkprof:Shadows','Invalid shadow mode.');
for pair={"shadowPatchEmphasis","patchEmphasis",1,4;"shadowGridEmphasis","gridEmphasis",1,3;"shadowExtraPatches","extraPatches",0,256}'
 key=pair{1};dest=pair{2};
 if isfield(printing,key),s.(dest)=str2double(string(printing.(key)));end
 validateattributes(s.(dest),{'double'},{'scalar','finite','>=',pair{3},'<=',pair{4}});
end
assert(s.extraPatches==floor(s.extraPatches),'inkprof:Shadows','Extra shadow patches must be a whole number.');
s.enabled=s.mode=="auto-matte"&&isfield(printing,'paperSurface')&&strcmpi(string(printing.paperSurface),"Matte");
end
