% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function receipt=saveWorkflowDelivery(folder,iccDestination,reportDestination,options)
% Publish user-selected copies; project copies remain authoritative.
arguments
 folder (1,1) string
 iccDestination (1,1) string
 reportDestination (1,1) string
 options.Overwrite (1,1) logical = false
end
iccDestination=inkprof.internal.absolutePath(iccDestination);
reportDestination=inkprof.internal.absolutePath(reportDestination);
[iccParent,iccName,iccExt]=fileparts(iccDestination);[reportParent,stem,reportExt]=fileparts(reportDestination);
assert(any(lower(iccExt)==[".icc",".icm"]),'inkprof:Delivery','Select .icc or .icm for the profile.');
assert(any(lower(reportExt)==[".html",".pdf",".txt"]),'inkprof:Delivery','Select .html, .pdf or .txt for the measurement certificate.');
assert(isfolder(iccParent)&&isfolder(reportParent),'inkprof:Delivery','The selected destination folders must exist.');
folder=inkprof.internal.absolutePath(folder);
assert(reportParent~=folder&&~startsWith(reportParent,folder+filesep),'inkprof:Delivery','Choose a report location outside the project internal export package.');
root=inkprof.internal.findProject(folder);
if root~="",assert(~startsWith(iccDestination,root+filesep),'inkprof:Delivery','Choose an external destination for the delivery.');end
assert(strlength(stem)>0&&strlength(stem)<=220&&~any(stem==[".",".."])&& ...
 isempty(regexp(char(stem),'[<>:"/\\|?*\x00-\x1F]','once'))&&~endsWith(stem,"."), ...
 'inkprof:Delivery','Use a portable certificate name without path separators.');
% Give each delivery one portable folder; never overwrite an older bundle.
baseStem=stem;reportBundle=fullfile(reportParent,stem);suffix=1;
while isfolder(reportBundle)||isfile(reportBundle)
 suffix=suffix+1;stem=baseStem+"-"+suffix;reportBundle=fullfile(reportParent,stem);
end
reportParent=reportBundle;reportDestination=fullfile(reportParent,stem+reportExt);
iccParent=reportBundle;iccDestination=fullfile(iccParent,iccName+iccExt);
destinations=unique([iccDestination,reportDestination,fullfile(reportParent,stem+".pdf"),fullfile(reportParent,stem+".html")],'stable');
variant=struct('primaryFile',"profile.icc",'secondaryFile',"");
if isfile(fullfile(folder,'icc-variants.json')),variant=jsondecode(fileread(fullfile(folder,'icc-variants.json')));end
secondaryIndex=0;
if string(variant.secondaryFile)~=""
 secondaryIndex=numel(destinations)+1;destinations(secondaryIndex)=fullfile(iccParent,iccName+"-v4.4"+iccExt);
end
for file=destinations
 assert(~isfolder(file),'inkprof:Delivery','The destination is a folder.');
 assert(~isfile(file)||options.Overwrite,'inkprof:Exists','File already exists: %s',file);
 assert(~isfile(file)||~startsWith(file,root+filesep),'inkprof:Delivery','Existing project files cannot be replaced. Choose a new name.');
end
source=fullfile(folder,string(variant.primaryFile));hash=inkprof.internal.sha256(source);
assets=fullfile(reportParent,"underlag");
stages=strings(size(destinations));
backups=strings(size(destinations));published=false(size(destinations));
cleanup=onCleanup(@()removeTemps(stages,backups));
try
 mkdir(reportBundle);
 for k=1:numel(stages),stages(k)=string(tempname(fileparts(destinations(k))));end
 % Freeze a complete portable report bundle before publishing either file.
 copyfile(folder,assets);
 naming=inkprof.internal.nameICC(source,stages(1),iccName);
 mkdir(fullfile(assets,'delivered'));naming.file="delivered/"+iccName+iccExt;
 copyfile(stages(1),fullfile(assets,naming.file));
 inkprof.internal.writeJson(fullfile(assets,'icc-delivery.json'),naming);
 if secondaryIndex>0
  second=fullfile(folder,string(variant.secondaryFile));
  secondaryNaming=inkprof.internal.nameICC(second,stages(secondaryIndex),iccName+"-v4.4");
  secondaryNaming.file="delivered/"+iccName+"-v4.4"+iccExt;
  copyfile(stages(secondaryIndex),fullfile(assets,secondaryNaming.file));
  inkprof.internal.writeJson(fullfile(assets,'icc-delivery-secondary.json'),secondaryNaming);
 end
 config=inkprof.paths();
 inkprof.runPython(fullfile(config.Root,'analysis','delivery_report.py'),assets,RequiredModules="reportlab",WorkingDirectory=config.Root);
 % Display previews use the exact named ICC included in this delivery.
 inkprof.runPython(fullfile(config.Root,'analysis','delivery_gradients.py'), ...
  [stages(1),reportBundle],RequiredModules="PIL",WorkingDirectory=config.Root);
 for k=2:numel(destinations)
  if k==secondaryIndex,continue;end
  [~,~,ext]=fileparts(destinations(k));
  if lower(ext)==".pdf"
   copyfile(fullfile(assets,'final-report.pdf'),stages(k));
  else
   if lower(ext)==".html"
    text=string(fileread(fullfile(assets,'final-report.html')));
    [~,assetName]=fileparts(assets);
    prefix=string(java.net.URLEncoder.encode(char(assetName),'UTF-8'));prefix=replace(prefix,"+","%20");
    text=regexprep(text,"(href|src)='(?![A-Za-z][A-Za-z0-9+.-]*:|//|#)","$1='"+prefix+"/");
    text=replace(text,"</body>","<p><a href='gradients.html'>Gradient soft proof / Gradienter med ICC-profilen</a></p></body>");
   else
    text=string(fileread(fullfile(assets,'final-report.txt')))+newline+newline+"Rapportunderlag: "+assets;
   end
   fid=fopen(stages(k),'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot save the report.');
   closer=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',text);clear closer
  end
 end
 if secondaryIndex>0,assert(inkprof.internal.sha256(stages(secondaryIndex))==string(secondaryNaming.sha256),'inkprof:Integrity','Secondary ICC copy changed.');end
 assert(inkprof.internal.sha256(stages(1))==string(naming.sha256),'inkprof:Integrity','The ICC copy has changed.');
 for k=1:numel(destinations)
  if isfile(destinations(k)),backups(k)=string(tempname(fileparts(destinations(k))));copyfile(destinations(k),backups(k));end
 end
 for k=1:numel(destinations)
  if ~options.Overwrite,assert(~isfile(destinations(k)),'inkprof:Exists','The destination file was created while saving.');end
  [ok,msg]=movefile(stages(k),destinations(k),'f');assert(ok,'inkprof:IO','%s',msg);published(k)=true;
 end
 previewFiles=fullfile(reportBundle,["gradients.html","gradients-original.jpg","gradients-soft-proof.jpg","gradients.json"]);
 previewFiles=previewFiles(isfile(previewFiles));
 receipt=struct('documentType',"inkprof.delivery",'iccFile',iccDestination,'iccSHA256',string(naming.sha256),'sourceICCSHA256',hash,'internalName',iccName,'colourTagPayloadsUnchanged',true, ...
  'reportFolder',reportBundle,'reportFile',reportDestination,'reportSHA256',inkprof.internal.sha256(reportDestination),'reportAssets',assets, ...
  'files',[destinations,previewFiles], ...
  'savedUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
catch err
 for k=1:numel(destinations)
  if published(k)
   if backups(k)~="",copyfile(backups(k),destinations(k),'f');else,delete(destinations(k));end
  end
 end
 if isfolder(reportBundle),rmdir(reportBundle,'s');end
 removeTemps(stages,backups);rethrow(err)
end
removeTemps(stages,backups);
end
function removeTemps(stages,backups)
for f=[stages,backups],if f~=""&&isfile(f),delete(f);end,end
end
