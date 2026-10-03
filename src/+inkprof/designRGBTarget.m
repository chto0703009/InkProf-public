% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function design=designRGBTarget(options)
%DESIGNRGBTARGET FEM-inspired RGB refinement or Argyll OFPS, before layout.
arguments
    options.Name (1,1) string = "RGB target"
    options.Method (1,1) string {mustBeMember(options.Method,["mesh","argyll"])} = "mesh"
    options.Refinement (1,1) string {mustBeMember(options.Refinement,["interior","edge"])} = "interior"
    options.InteriorPlacement (1,1) string {mustBeMember(options.InteriorPlacement,["circumcenter","centroid","contained-circumcenter"])} = "centroid"
    options.Levels (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.Levels,2)} = 5
    options.MaxPoints (1,1) double {mustBeInteger,mustBePositive} = 575
    options.GraySteps (1,1) double {mustBeInteger,mustBeNonnegative} = 33
    options.ControlCount (1,1) double {mustBeInteger,mustBeNonnegative} = 64
    options.RepeatCount (1,1) double {mustBeInteger,mustBeNonnegative} = 12
    options.MaxEdge (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    options.GapRatio (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    options.Refine (1,1) logical = true
    options.ArgyllBin (1,1) string = ""
    options.ShadowEmphasis (1,1) double {mustBeFinite,mustBeGreaterThanOrEqual(options.ShadowEmphasis,1),mustBeLessThanOrEqual(options.ShadowEmphasis,4)} = 1
    options.Progress (1,1) function_handle = @(~)true
end
assert(strlength(strtrim(options.Name))>0,'inkprof:Design','Enter a target name.');
assert(options.GraySteps~=1,'inkprof:Design','Gray steps must be zero or at least two.');
assert(options.GapRatio==0||options.GapRatio>1,'inkprof:Design','Gap ratio must be zero (off) or greater than one.');
budget=options.MaxPoints-options.ControlCount-options.RepeatCount;
if options.Method=="mesh"
    levels=linspace(0,1,options.Levels);
    grayLevels=linspace(0,1,options.GraySteps);
    extraGray=options.GraySteps-numel(intersect(levels,grayLevels));
    required=options.Levels^3+extraGray;
    reason=sprintf('%d^3 = %d grid points + %d additional gray points',options.Levels,options.Levels^3,extraGray);
else
    required=options.GraySteps+8;
    reason=sprintf('8 cube corners + a reservation of %d gray points',options.GraySteps);
end
checkBudget(options,required,reason);
notify=options.Progress;
assert(notify(struct('count',0,'maxEdge',NaN)),'inkprof:Cancelled','Generation cancelled.');
log=struct;history=zeros(0,5);parents=zeros(0,2);
if options.Method=="mesh"
    axis=linspace(0,1,options.Levels);[r,g,b]=ndgrid(axis,axis,axis);rgb=[r(:) g(:) b(:)];
    if options.GraySteps>0
        rgb=unique([rgb;repmat(linspace(0,1,options.GraySteps)',1,3)],'rows','stable');
    end
    checkBudget(options,size(rgb,1),'unique grid and gray points');
    parents=zeros(size(rgb,1),2);
else
    w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
    bin=inkprof.internal.argyllBin(options.ArgyllBin);suffix="";if ispc,suffix=".exe";end
    exe=fullfile(bin,"targen"+suffix);
    args=["-d2","-e1","-B1","-g"+options.GraySteps,"-m2","-f"+budget,"design"];
    if options.ShadowEmphasis>1,args=[args(1:end-1),"-A1","-V"+options.ShadowEmphasis,args(end)];end
    log=inkprof.internal.runTool(exe,args,w,300);
    versionInfo=inkprof.internal.runTool(exe,"-?",w,30,true);log.version=versionInfo.output;
    target=inkprof.importTarget(fullfile(w,'design.ti1'));
    rgb=unique(target.rgbPercent/100,'rows','stable');
    assert(size(rgb,1)<=budget,'inkprof:Design','Argyll exceeded the fitting budget.');
    parents=zeros(size(rgb,1),2);
end
assert(notify(struct('count',size(rgb,1),'maxEdge',NaN)),'inkprof:Cancelled','Generation cancelled.');
initialRGB=rgb;
interior=options.Method=="mesh" && options.Refinement=="interior";
parentTetrahedra=zeros(size(rgb,1),4);insertionKinds=repmat("initial",size(rgb,1),1);
historyColumns=["fitCount","splitEdgeLength","newMaxEdgeLength","parent1","parent2"];
if interior,history=zeros(0,7);historyColumns=["fitCount","candidateGapBefore","candidateGapAfter","parent1","parent2","parent3","parent4"];end
[pairs,lengths]=inkprof.internal.rgbMeshEdges(rgb);initialDistances=lengths;
refinementDistances=lengths;candidates=zeros(0,3);candidateKinds=strings(0,1);
if interior,[candidates,tetrahedra,refinementDistances,candidateKinds]=inkprof.internal.interiorCandidates(rgb,options.InteriorPlacement);end
initialRefinementDistances=refinementDistances;
% A gap is an optional geometric threshold, frozen from the initial spectrum.
gap=struct('ratio',0,'rank',0,'upperDistance',0,'lowerDistance',0,'applied',false);
if numel(refinementDistances)>1
    ratios=refinementDistances(1:end-1)./refinementDistances(2:end);[gap.ratio,gap.rank]=max(ratios);
    gap.upperDistance=refinementDistances(gap.rank);gap.lowerDistance=refinementDistances(gap.rank+1);
end
threshold=options.MaxEdge;
if options.Method=="mesh" && options.GapRatio>1 && gap.ratio>=options.GapRatio
    gap.applied=true;threshold=max(threshold,gap.lowerDistance);
end
reason="point limit";
if options.Method=="mesh" && options.Refine
    while size(rgb,1)<budget
        if threshold>0 && refinementDistances(1)<=threshold+1e-12,reason="distance threshold";break;end
        before=refinementDistances(1);
        if interior
            point=candidates(1,:);tetra=tetrahedra(1,:);kind=candidateKinds(1);
        else
            pair=pairs(1,:);point=mean(rgb(pair,:),1);
        end
        assert(~any(max(abs(rgb-point),[],2)<1e-12),'inkprof:Design','Refinement candidate already exists.');
        rgb(end+1,:)=point;
        if interior
            parents(end+1,:)=[0 0];parentTetrahedra(end+1,:)=tetra;insertionKinds(end+1,1)=kind;
            [candidates,tetrahedra,refinementDistances,candidateKinds]=inkprof.internal.interiorCandidates(rgb,options.InteriorPlacement);
            history(end+1,:)=[size(rgb,1),before,refinementDistances(1),tetra]; %#ok<AGROW>
        else
            parents(end+1,:)=pair;parentTetrahedra(end+1,:)=zeros(1,4);insertionKinds(end+1,1)="edge midpoint";
            [pairs,lengths]=inkprof.internal.rgbMeshEdges(rgb);refinementDistances=lengths;
            history(end+1,:)=[size(rgb,1),before,lengths(1),pair]; %#ok<AGROW>
        end
        assert(notify(struct('count',size(rgb,1),'maxEdge',refinementDistances(1))),'inkprof:Cancelled','Generation cancelled.');
    end
elseif options.Method=="mesh"
    reason="base preview";
else
    reason="Argyll generation complete";
end
if interior,[pairs,lengths]=inkprof.internal.rgbMeshEdges(rgb);end
coverage=inkprof.internal.rgbCoverage(rgb);
fitCount=size(rgb,1);
% Independent low-discrepancy controls: deterministic and disjoint from fitting RGB.
controls=zeros(0,3);index=0;
while size(controls,1)<options.ControlCount
    index=index+1;v=[radicalInverse(index,2),radicalInverse(index,3),radicalInverse(index,5)];
    if ~any(max(abs(rgb-v),[],2)<1e-10),controls(end+1,:)=v;end %#ok<AGROW>
end
% Distribute repetitions over fitted colors; references retain source IDs.
if options.RepeatCount>0
    refs=1+mod(round(linspace(0,fitCount-1,options.RepeatCount)),fitCount);
else
    refs=zeros(1,0);
end
allRGB=[rgb;controls;rgb(refs,:)];n=size(allRGB,1);
roles=[repmat("fit",fitCount,1);repmat("control",size(controls,1),1);repmat("repeat",numel(refs),1)];
repeatOf=[zeros(fitCount+size(controls,1),1);refs(:)];
settings=rmfield(options,'Progress');
design=struct('schemaVersion',1,'documentType',"inkprof.rgb-design", ...
    'name',options.Name,'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    'algorithmVersion',"2.1",'matlabVersion',string(version),'options',settings, ...
    'metric',"Euclidean RGB geometry; interior mode ranks empty-sphere centers and centroid fallbacks by nearest-fit distance, edge mode ranks edges; not measured colour error", ...
    'sampleId',string((1:n)'),'rgb',allRGB,'roles',roles,'repeatOf',repeatOf, ...
    'fitCount',fitCount,'controlCount',size(controls,1),'repeatCount',numel(refs), ...
    'initialRGB',initialRGB,'parentEdges',parents,'initialDistances',initialDistances, ...
    'sortedEdges',pairs,'sortedDistances',lengths,'history',history, ...
    'historyColumns',historyColumns,'parentTetrahedra',parentTetrahedra, ...
    'candidatePoints',candidates,'candidateKinds',candidateKinds,'insertionKinds',insertionKinds,'initialRefinementDistances',initialRefinementDistances,'sortedRefinementDistances',refinementDistances,'coverage',coverage, ...
    'gap',gap,'effectiveThreshold',threshold,'stopReason',reason,'argyllRun',log, ...
    'controlMethod',"Unscrambled radical inverses, bases 2/3/5; disjoint from fitting set", ...
    'colorimetry',"None: device RGB geometry only. Control roles must be excluded from future profile fitting.");
generation=struct('algorithmVersion',"2.1",'method',options.Method,'name',options.Name,'settings',settings, ...
    'initialLevels',options.Levels,'iterations',size(history,1),'stopReason',reason, ...
    'history',history,'historyColumns',historyColumns,'initialRGB',initialRGB,'parentEdges',parents, ...
    'parentTetrahedra',parentTetrahedra,'insertionKinds',insertionKinds,'interiorPlacement',options.InteriorPlacement,'refinement',options.Refinement,'coverage',coverage,'gap',gap,'argyllRun',log);
if options.Method=="argyll",generation=rmfield(generation,{'initialLevels','iterations'});end
design.targetInfo=inkprof.internal.targetInfo(allRGB,"",generation,(1:fitCount)');
end
function v=radicalInverse(index,base)
v=0;factor=1/base;
while index>0
    v=v+mod(index,base)*factor;index=floor(index/base);factor=factor/base;
end
end

function checkBudget(options,required,reason)
available=options.MaxPoints-options.ControlCount-options.RepeatCount;
minimum=required+options.ControlCount+options.RepeatCount;
assert(available>=required,'inkprof:Design', ...
    ['Not enough patches for these settings.\n\n' ...
     'Maximum total patches: %d\nControl patches: %d\nExtra repeat patches: %d\n' ...
     'Available fitting points: %d - %d - %d = %d\n\n' ...
     'Required fitting points: %d (%s).\n\n' ...
     'Set Maximum total patches to at least %d, or reduce the grid/gray settings, Control patches or Extra repeat patches.\n' ...
     'For a grid-only experiment, Control patches and Extra repeat patches may both be 0; the grid and gray points must still fit.'], ...
     options.MaxPoints,options.ControlCount,options.RepeatCount, ...
     options.MaxPoints,options.ControlCount,options.RepeatCount,available,required,reason,minimum);
end
