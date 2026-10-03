% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function info=targetInfo(rgb,sourcePath,generation,fitIndices)
%TARGETINFO Common provenance and RGB geometry for imports and generators.
if nargin<3,generation=struct('method',"unknown",'settings',struct);end
if nargin<4,fitIndices=(1:size(rgb,1))';end
inkprof.internal.requireRgb(rgb,1);
source=struct('fileName',"",'path',"",'format',"",'sha256',"",'declaredMetadata',struct);
if strlength(string(sourcePath))>0
    source.path=inkprof.internal.absolutePath(sourcePath);
    [~,name,ext]=fileparts(source.path);source.fileName=name+ext;source.format=lower(ext);
    if isfile(source.path),source.sha256=inkprof.internal.sha256(source.path);end
end
u=unique(round(rgb(fitIndices,:),12),'rows');
net=struct('scope',"source RGB",'pointCount',numel(fitIndices),'uniqueCount',size(u,1), ...
    'dimension',rank(u-u(1,:)),'axisLevelCounts',[numel(unique(u(:,1))),numel(unique(u(:,2))),numel(unique(u(:,3)))], ...
    'regularCartesianGrid',false,'metric',"Delaunay edge lengths in normalized device RGB; not measured colour error", ...
    'edgeCount',0,'maxEdge',[],'meanEdge',[],'status',"not a three-dimensional RGB set");
if numel(fitIndices)~=size(rgb,1),net.scope="fitting RGB only";end
net.completeCartesianGrid=prod(net.axisLevelCounts)==size(u,1);
net.regularCartesianGrid=net.completeCartesianGrid;
for axis=1:3
    delta=diff(unique(u(:,axis)));
    if numel(delta)>1 && max(delta)-min(delta)>1e-10,net.regularCartesianGrid=false;end
end
net.grayDiagonalCount=sum(max(u,[],2)-min(u,[],2)<1e-12);
[r,g,b]=ndgrid([0 1],[0 1],[0 1]);net.cubeCornerCount=sum(ismember([r(:) g(:) b(:)],u,'rows'));
if net.dimension==3
    [~,d]=inkprof.internal.rgbMeshEdges(u);
    net.edgeCount=numel(d);net.maxEdge=d(1);net.meanEdge=mean(d);net.status="computed from unique RGB points";
end
info=struct('schemaVersion',1,'source',source,'generation',generation, ...
    'patchCount',size(rgb,1),'uniqueRGBCount',size(unique(round(rgb,12),'rows'),1), ...
    'network',net,'footerText',"");
info.footerText=inkprof.internal.targetInfoText(info);
end
