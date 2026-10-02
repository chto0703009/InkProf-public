function folder=createProject(folder,options)
%CREATEPROJECT Create a portable container for one profiling workflow.
arguments
 folder (1,1) string
 options.Name (1,1) string = ""
 options.User (1,1) string = ""
 options.Printing (1,1) struct = struct
end
folder=inkprof.internal.absolutePath(folder);
assert(~isfolder(folder)&&~isfile(folder),'inkprof:Exists','Project already exists.');
if options.Name=="",[~,options.Name]=fileparts(folder);end
[~,folderName]=fileparts(folder);
mkdir(folder);
for name=["sources","targets","measurements","analyses","reports","profiles"]
 mkdir(fullfile(folder,name));
end
record=struct('schemaVersion',1,'documentType',"inkprof.profiling-project", ...
 'projectId',string(java.util.UUID.randomUUID()),'name',options.Name,'folderName',folderName,'revision',0, ...
 'createdUTC',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
 'files',struct([]),'history',struct([]),'relocations',struct([]), ...
 'paperLayout',inkprof.internal.paperPreferences(),'printing',struct('status',"not recorded",'printer',"unknown",'paper',"unknown", ...
 'driver',"unknown",'quality',"unknown",'colorManagement',"unknown"));
inkprof.internal.writeJson(fullfile(folder,'inkprof-project.json'),record);
inkprof.updateProject(folder,Step="project-created",User=options.User,Printing=options.Printing);
end
