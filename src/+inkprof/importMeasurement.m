% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [result,measurementFile,sessionFolder]=importMeasurement(source,options)
%IMPORTMEASUREMENT Select TI3/MXF, validate, preserve source and open patch review.
arguments
 source (1,1) string = ""
 options.TargetFile (1,1) string = ""
 options.SessionFolder (1,1) string = ""
 options.Condition (1,1) string {mustBeMember(options.Condition,["","M0","M1","M2"])} = ""
 options.ShowPreview (1,1) logical = true
end
result=[];measurementFile="";sessionFolder="";
interactive=source=="";
if interactive
 [name,path]=uigetfile({'*.ti3;*.mxf','Measurement files (TI3, MXF)';'*.*','All files'},'Import RGB measurement');
 if isequal(name,0),return;end
 source=fullfile(path,name);
end
source=inkprof.internal.absolutePath(source);assert(isfile(source),'inkprof:Input','Measurement file not found.');
sourceHash=inkprof.internal.sha256(source);raw=strtrim(string(fileread(source)));
work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
info=struct;condition=struct;target=options.TargetFile;
if startsWith(raw,"CTI2")
 error('inkprof:MeasurementFile','TI2 describes a target. Select its measured TI3 or MXF file instead.');
elseif startsWith(raw,"CTI3")
 doc=inkprof.importCgats(source);v=inkprof.cgatsData(doc,RGBScale=100);
 assert(isempty(v.cmyk)&&size(v.rgb,2)==3,'inkprof:ColorFormat','Unsupported colour format: RGB measurements are required.');
 if target==""
  [parent,stem]=fileparts(source);
  candidates=[fullfile(parent,stem+".ti2"),fullfile(parent,'source.ti2'),fullfile(parent,'chart.ti2')];
  for candidate=candidates,if isfile(candidate),target=candidate;break;end,end
 end
 if target=="" && interactive
  [name,path]=uigetfile('*.ti2','Select the TI2 matching the measured print');
  if isequal(name,0),return;end
  target=fullfile(path,name);
 end
 assert(target~="",'inkprof:TargetRequired','This TI3 needs its printed target definition. Specify TargetFile with the matching TI2.');
 dataFile=source;originalName="original.ti3";
 % Existing InkProf session evidence may establish native M0; do not infer
 % conditions from an instrument name alone.
 parent=fileparts(source);chartPath=fullfile(parent,'chart.json');
 if isfile(chartPath)
  condition=inkprof.internal.measurementCondition(parent,inkprof.internal.sha256(chartPath),v.metadata);
 else
  condition=inkprof.internal.measurementCondition(work,"",v.metadata);
 end
 info=struct('schemaVersion',1,'documentType',"inkprof.measurement-import",'format',"TI3", ...
  'source',source,'sourceSHA256',sourceHash,'sourceFile',originalName,'importerVersion',"1.0");
else
 paths=inkprof.paths();converted=fullfile(work,'converted');args=[source,converted];
 if options.Condition~="",args=[args,"--condition",options.Condition];end
 inkprof.runPython(fullfile(paths.Root,'exchange','import_mxf.py'),args,RequiredModules=["numpy","colour"]);
 info=jsondecode(fileread(fullfile(converted,'import-info.json')));condition=info.condition;
 assert(string(info.sourceSHA256)==sourceHash,'inkprof:Integrity','Source changed during conversion.');
 assert(options.TargetFile=="",'inkprof:Layout','Positioned MXF carries its own layout. Do not substitute a different print TI2.');
 target=fullfile(converted,'layout.ti2');dataFile=fullfile(converted,'data.ti3');originalName="original.mxf";
end
if options.Condition~=""
 if isfield(condition,'interpreted')&&string(condition.interpreted)~="unknown"
  assert(string(condition.interpreted)==options.Condition,'inkprof:Condition','Selected condition conflicts with source evidence.');
 else
  condition=struct('requested',options.Condition,'reported',"unknown",'interpreted',options.Condition, ...
   'basis',"Explicit user declaration at import; not verified by the source",'fwaApplied',false);
  for k=1:numel(v.metadata)
   t=string(v.metadata{k});if numel(t)>1 && t(1)=="TARGET_INSTRUMENT",condition.instrument=t(2);end
  end
 end
end
paths=inkprof.paths();sessionFolder=options.SessionFolder;
if sessionFolder==""
 parent=inkprof.internal.findProject(source);base=paths.Projects;
 if parent~="",base=fullfile(parent,'measurements');end
 sessionFolder=fullfile(base,"import-"+string(datetime('now','Format','yyyyMMdd-HHmmssSSS'))+"-"+string(java.util.UUID.randomUUID()));
end
sessionFolder=inkprof.internal.absolutePath(sessionFolder);
assert(~isfolder(sessionFolder)&&~isfile(sessionFolder),'inkprof:Exists','Import folder already exists.');
% Prepare in an isolated staging directory. Invalid measurements never leave
% a partly imported session in the project.
stage=fullfile(work,'session');inkprof.prepareChart(target,stage);
copyfile(source,fullfile(stage,originalName));
assert(inkprof.internal.sha256(fullfile(stage,originalName))==sourceHash,'inkprof:Integrity','Source changed during import.');
if isfield(condition,'transcriptSHA256')
 logs=dir(fullfile(fileparts(source),'transcript-*.txt'));
 for log=reshape(logs,1,[])
  p=fullfile(log.folder,log.name);
  if inkprof.internal.sha256(p)==string(condition.transcriptSHA256)
   copyfile(p,fullfile(stage,log.name));
  end
 end
end
info.importedAt=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ssXXX"));
chart=jsondecode(fileread(fullfile(stage,'chart.json')));
if string(info.format)=="MXF"
 chart.sourceFormat="MXF";chart.sourcePath=source;chart.sourceFile=originalName;chart.sourceSHA256=sourceHash;
 chart.importInfo=info;
 real=~[chart.patches.isPadding];rgb=reshape([chart.patches(real).rgbPercent],3,[])';
 chart.targetInfo=inkprof.internal.importTargetInfo(rgb/100,source,string({chart.patches(real).sampleId}),info.customAttributes);
end
inkprof.internal.writeJson(fullfile(stage,'chart.json'),chart);
result=inkprof.importChartMeasurement(stage,dataFile,ImportInfo=info,ConditionRecord=condition);
files=dir(fullfile(stage,'measurement-*.json'));assert(numel(files)==1);
[~,stem]=fileparts(files(1).name);result.sourcePath=fullfile(sessionFolder,string(stem)+".ti3");
inkprof.internal.writeJson(fullfile(stage,files(1).name),result);
inkprof.internal.writeJson(fullfile(stage,'import-info.json'),info);
parent=fileparts(sessionFolder);if ~isfolder(parent),mkdir(parent);end
[ok,message]=movefile(stage,sessionFolder);assert(ok,'inkprof:IO','%s',message);
measurementFile=fullfile(sessionFolder,files(1).name);
inkprof.internal.recordProjectStep(sessionFolder,"Imported "+string(info.format)+" measurement; preserved source and normalized TI3/JSON");
fprintf('InkProf: imported %d RGB patches from %s.\nSaved measurement: %s\n',result.measuredSourcePatches,info.format,measurementFile);
if options.ShowPreview,inkprof.previewMeasurement(sessionFolder,result);end
end
