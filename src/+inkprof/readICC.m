function [result,jsonFile,window]=readICC(source,options)
%READICC Inspect ICC v2/v4 without modifying the profile or evaluating its LUTs.
arguments
 source (1,1) string = ""
 options.OutputFolder (1,1) string = ""
 options.ShowDialog (1,1) logical = true
end
result=[];jsonFile="";window=[];
if source==""
 [name,folder]=uigetfile({'*.icc;*.icm','ICC profiles (*.icc, *.icm)';'*.*','All files'},'Read ICC profile');
 if isequal(name,0),return;end
 source=fullfile(folder,name);
end
source=inkprof.internal.absolutePath(source);
assert(isfile(source),'inkprof:ICCInput','ICC profile not found.');
paths=inkprof.paths();work=string(tempname);mkdir(work);cleanup=onCleanup(@()rmdir(work,'s'));
stage=fullfile(work,'inspection.json');
inkprof.runPython(fullfile(paths.Root,'profiles','read_icc.py'),[source,stage]);
result=jsondecode(fileread(stage));
assert(inkprof.internal.sha256(source)==string(result.source.sha256),'inkprof:Integrity','ICC source changed during inspection.');
folder=options.OutputFolder;
if folder==""
 project=inkprof.internal.findProject(source);
 if project=="",folder=fullfile(paths.Projects,'icc-inspections');
 else,folder=fullfile(project,'profiles','inspections');end
end
folder=inkprof.internal.absolutePath(folder);
if ~isfolder(folder),mkdir(folder);end
[~,stem]=fileparts(source);
jsonFile=fullfile(folder,stem+"-"+string(java.util.UUID.randomUUID())+".json");
[ok,message]=movefile(stage,jsonFile);assert(ok,'inkprof:IO','%s',message);
inkprof.internal.recordProjectStep(folder,"Inspected ICC profile (A1); source unchanged");
fprintf('InkProf: ICC %s, %s / %s / %s.\nMetadata: %s\n',result.header.version, ...
 result.header.profileClass,result.header.deviceSpace,result.header.pcs,jsonFile);
if ~options.ShowDialog,return;end
window=uifigure('Name','InkProf - ICC profile inspection','Position',[150 150 980 700]);
g=uigridlayout(window,[5 1]);g.RowHeight={125,'1x',110,48,32};
h=result.header;description="";
if ~isempty(result.descriptions),description=string(result.descriptions(1).text);end
summary=sprintf('%s\nICC %s | Class: %s | Device: %s | PCS: %s | Tags: %d\nStatus: %s | RGB output candidate: %d\n%s', ...
 description,h.version,h.profileClass,h.deviceSpace,h.pcs,numel(result.tags),result.status,result.capabilities.rgbOutputCandidate,source);
uitextarea(g,'Value',splitlines(string(summary)),'Editable','off');
rows=cell(numel(result.tags),6);
for k=1:numel(result.tags)
 t=result.tags(k);rows(k,:)={t.signature,t.type,t.offset,t.size,char(strjoin(string(t.sharedWith),', ')),t.summary};
end
uitable(g,'Data',rows,'ColumnName',{'Tag','Type','Offset','Bytes','Shared with','Summary'}, ...
 'ColumnWidth',{65,65,85,85,100,'auto'},'RowName',{});
messages="No structural warnings. This is not a full ICC conformance or colour-quality validation.";
if ~isempty(result.diagnostics),messages=string({result.diagnostics.message})';end
uitextarea(g,'Value',messages,'Editable','off');
uilabel(g,'Text',"Metadata: "+jsonFile,'WordWrap','on');
buttons=uigridlayout(g,[1 3]);buttons.Padding=[0 0 0 0];
uibutton(buttons,'Text','Import into project','ButtonPushedFcn',@(~,~)iccAction(window,source,"import"));
uibutton(buttons,'Text','Save copy as...','ButtonPushedFcn',@(~,~)iccAction(window,source,"save"));
uibutton(buttons,'Text','Close','ButtonPushedFcn',@(~,~)delete(window));
drawnow;figure(window);
end

function iccAction(window,source,action)
try
 if action=="import",file=inkprof.importICC(source);
 else,file=inkprof.saveICC(source);end
 if file~="",uialert(window,"Saved unchanged profile: "+file,'ICC profile saved','Icon','success');end
catch err
 uialert(window,err.message,'ICC operation failed');
end
end
