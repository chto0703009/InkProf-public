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
[iccParent,~,iccExt]=fileparts(iccDestination);[reportParent,stem,reportExt]=fileparts(reportDestination);
assert(any(lower(iccExt)==[".icc",".icm"]),'inkprof:Delivery','Välj .icc eller .icm för profilen.');
assert(any(lower(reportExt)==[".html",".pdf",".txt"]),'inkprof:Delivery','Välj .html, .pdf eller .txt för slutrapporten.');
assert(isfolder(iccParent)&&isfolder(reportParent),'inkprof:Delivery','Valda målmappar måste finnas.');
folder=inkprof.internal.absolutePath(folder);
assert(reportParent~=folder&&~startsWith(reportParent,folder+filesep),'inkprof:Delivery','Välj rapportplats utanför projektets interna exportpaket.');
root=inkprof.internal.findProject(folder);
destinations=[iccDestination,reportDestination];
if lower(reportExt)==".pdf",destinations(3)=fullfile(reportParent,stem+".html");end
if lower(reportExt)==".html",destinations(3)=fullfile(reportParent,stem+".pdf");end
for file=destinations
 assert(~isfolder(file),'inkprof:Delivery','Målet är en mapp.');
 assert(~isfile(file)||options.Overwrite,'inkprof:Exists','Filen finns redan: %s',file);
 assert(~isfile(file)||~startsWith(file,root+filesep),'inkprof:Delivery','Befintliga projektfiler får inte ersättas. Välj ett nytt namn.');
end
source=fullfile(folder,'profile.icc');hash=inkprof.internal.sha256(source);
assets=fullfile(reportParent,stem+"-underlag-"+string(java.util.UUID.randomUUID()));
stages=strings(size(destinations));for k=1:numel(stages),stages(k)=string(tempname(fileparts(destinations(k))));end
backups=strings(size(destinations));published=false(size(destinations));
cleanup=onCleanup(@()removeTemps(stages,backups));
try
 % Freeze a complete portable report bundle before publishing either file.
 copyfile(folder,assets);
 copyfile(source,stages(1));
 for k=2:numel(destinations)
  [~,~,ext]=fileparts(destinations(k));
  if lower(ext)==".pdf"
   copyfile(fullfile(folder,'final-report.pdf'),stages(k));
  else
   if lower(ext)==".html"
    text=string(fileread(fullfile(folder,'final-report.html')));
    [~,assetName]=fileparts(assets);
    prefix=string(java.net.URLEncoder.encode(char(assetName),'UTF-8'));prefix=replace(prefix,"+","%20");
    text=replace(text,["href='","src='"],["href='"+prefix+"/","src='"+prefix+"/"]);
   else
    text=string(fileread(fullfile(folder,'final-report.txt')))+newline+newline+"Rapportunderlag: "+assets;
   end
   fid=fopen(stages(k),'w','n','UTF-8');assert(fid>=0,'inkprof:IO','Kan inte spara rapporten.');
   closer=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',text);clear closer
  end
 end
 assert(inkprof.internal.sha256(stages(1))==hash,'inkprof:Integrity','ICC-kopian ändrades.');
 for k=1:numel(destinations)
  if isfile(destinations(k)),backups(k)=string(tempname(fileparts(destinations(k))));copyfile(destinations(k),backups(k));end
 end
 for k=1:numel(destinations)
  if ~options.Overwrite,assert(~isfile(destinations(k)),'inkprof:Exists','Målfilen skapades under sparningen.');end
  [ok,msg]=movefile(stages(k),destinations(k),'f');assert(ok,'inkprof:IO','%s',msg);published(k)=true;
 end
 receipt=struct('documentType',"inkprof.delivery",'iccFile',iccDestination,'iccSHA256',hash, ...
  'reportFile',reportDestination,'reportSHA256',inkprof.internal.sha256(reportDestination),'reportAssets',assets, ...
  'files',destinations,'savedUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
catch err
 for k=1:numel(destinations)
  if published(k)
   if backups(k)~="",copyfile(backups(k),destinations(k),'f');else,delete(destinations(k));end
  end
 end
 if isfolder(assets),rmdir(assets,'s');end
 removeTemps(stages,backups);rethrow(err)
end
removeTemps(stages,backups);
end
function removeTemps(stages,backups)
for f=[stages,backups],if f~=""&&isfile(f),delete(f);end,end
end
