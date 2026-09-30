function values=cgatsData(document,options)
%CGATSDATA Numeric view of one table; raw document remains authoritative.
% Scales must be supplied for normalization. NaN means unknown, never guessed.
% SpectralScale denotes a reflectance/transmittance scale, not emission units.
arguments
    document (1,1) struct
    options.Table (1,1) double {mustBeInteger,mustBePositive} = 1
    options.RGBScale (1,1) double = NaN
    options.XYZScale (1,1) double = NaN
    options.SpectralScale (1,1) double = NaN
end
assert(options.Table<=numel(document.tables),'inkprof:CGATS','Table does not exist.');
t=document.tables(options.Table);n=size(t.data,1);
values=struct('ids',strings(0,1),'locations',strings(0,1),'rgb',zeros(n,0), ...
    'cmyk',zeros(n,0),'xyz',zeros(n,0),'lab',zeros(n,0), ...
    'wavelengthNm',zeros(1,0),'spectra',zeros(n,0),'rgbPercent',zeros(n,0), ...
    'xyz100',zeros(n,0),'spectralFraction',zeros(n,0),'scales',options, ...
    'metadata',{t.metadata},'colorValueRole',"unspecified; consult source metadata");
if any(t.fields=="SAMPLE_ID"),values.ids=t.data(:,t.fields=="SAMPLE_ID");end
if any(t.fields=="SAMPLE_LOC"),values.locations=t.data(:,t.fields=="SAMPLE_LOC");end
values.idsUnique=~isempty(values.ids)&&numel(unique(values.ids))==n;
values.rgb=group(t,["RGB_R","RGB_G","RGB_B"]);
values.cmyk=group(t,["CMYK_C","CMYK_M","CMYK_Y","CMYK_K"]);
values.xyz=group(t,["XYZ_X","XYZ_Y","XYZ_Z"]);
values.lab=group(t,["LAB_L","LAB_A","LAB_B"]);
indices=[];wavelength=[];
for k=1:numel(t.fields)
    token=regexp(char(t.fields(k)),'^(?:SPEC_|SPECTRAL_NM)(\d+(?:\.\d+)?)$','tokens','once');
    if ~isempty(token),indices(end+1)=k;wavelength(end+1)=str2double(token{1});end %#ok<AGROW>
end
if ~isempty(indices)
    assert(numel(unique(wavelength))==numel(wavelength)&&all(wavelength>0),'inkprof:CGATS','Duplicate or invalid wavelengths.');
    [values.wavelengthNm,order]=sort(wavelength);
    values.spectra=numeric(t.data(:,indices(order)));
    keys=["SPECTRAL_BANDS","SPECTRAL_START_NM","SPECTRAL_END_NM"];
    expected=[numel(wavelength),min(wavelength),max(wavelength)];
    for k=1:3
        entries=t.metadata(cellfun(@(v)v(1)==keys(k),t.metadata));
        if ~isempty(entries)
            assert(numel(entries)==1 && numel(entries{1})==2 && str2double(entries{1}(2))==expected(k), ...
                'inkprof:CGATS','Spectral metadata disagrees with fields: %s.',keys(k));
        end
    end
end
values.rgbPercent=normalize(values.rgb,options.RGBScale,100,true);
values.xyz100=normalize(values.xyz,options.XYZScale,100,false);
values.spectralFraction=normalize(values.spectra,options.SpectralScale,1,false);
if any(t.signature==["CTI1","CTI2"]),values.colorValueRole="target estimates, not measured";end
end
function v=group(t,fields)
[ok,index]=ismember(fields,t.fields);
assert(all(ok)||~any(ok),'inkprof:CGATS','Incomplete colour coordinate group.');
v=zeros(size(t.data,1),0);if all(ok),v=numeric(t.data(:,index));end
end
function v=numeric(text)
v=str2double(text);assert(all(isfinite(v),'all'),'inkprof:CGATS','Nonfinite or nonnumeric colour data.');
end
function v=normalize(raw,scale,multiplier,bounded)
assert(isnan(scale)||(isfinite(scale)&&scale>0),'inkprof:Scale','Scale must be positive or NaN (unknown).');
v=zeros(size(raw,1),0);if isnan(scale),return;end
if bounded,assert(all(raw>=0 & raw<=scale,'all'),'inkprof:Scale','RGB outside declared scale.');end
v=raw/scale*multiplier;
end
