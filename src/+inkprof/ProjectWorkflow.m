classdef ProjectWorkflow < handle
    % Persistent project-scoped workflow. No step is completed by opening a UI.
    properties (SetAccess=private)
        Root
        State
    end
    methods
        function obj=ProjectWorkflow(root)
            obj.Root=inkprof.internal.absolutePath(root);
            assert(isfile(fullfile(obj.Root,'inkprof-project.json')),'inkprof:Project','Select a project folder containing inkprof-project.json.');
            p=jsondecode(fileread(fullfile(obj.Root,'inkprof-project.json')));
            assert(string(p.documentType)=="inkprof.profiling-project",'inkprof:Project','Incorrect project type.');
            if isfile(obj.stateFile())
                obj.reload();
                assert(string(obj.State.projectId)==string(p.projectId),'inkprof:Workflow','The workflow belongs to another project.');
            else
                defs=inkprof.internal.workflowSteps();steps=struct;
                for d=defs',steps.(d.id)=struct('status',"pending",'outputs',struct,'artifacts',struct([]),'message',"");end
                obj.State=struct('schemaVersion',1,'documentType',"inkprof.workflow", ...
                    'workflowRevision',2,'projectId',p.projectId,'iterationId',string(java.util.UUID.randomUUID()),'parentIterationId',"",'revision',0,'currentStep',"definition",'cycle',1, ...
                    'steps',steps,'history',{{}});
                lock=obj.lock();obj.save();clear lock
                inkprof.updateProject(obj.Root,Step="workflow-created");
            end
        end
        function reload(obj)
            obj.State=jsondecode(fileread(obj.stateFile()));
            assert(obj.State.schemaVersion==1&&string(obj.State.documentType)=="inkprof.workflow",'inkprof:Workflow','Unknown workflow version.');
            obj.State=inkprof.internal.upgradeWorkflowState(obj.State);
        end
        function [ok,reason]=ready(obj,id)
            defs=inkprof.internal.workflowSteps();index=find(string({defs.id})==string(id));
            assert(isscalar(index),'inkprof:Workflow','Unknown step.');
            ok=true;reason="Ready";
            for dep=string(defs(index).requires)
                [valid,why]=obj.valid(dep);
                if ~valid,ok=false;reason="Requires "+dep+": "+why;return;end
            end
        end
        function [ok,reason]=valid(obj,id)
            s=obj.State.steps.(id);ok=false;reason=string(s.status);
            if string(s.status)~="completed",return;end
            [ok,reason]=obj.ready(id);if ~ok,return;end
            for a=reshape(s.artifacts,1,[])
                file=obj.resolve(a.path);
                if ~isfile(file)||inkprof.internal.sha256(file)~=string(a.sha256)
                    ok=false;reason="Input is missing or has changed: "+string(a.path);return
                end
            end
            reason="Complete";
        end
        function assessment=inspect(obj)
            % One pass for UI: hash each artifact once per refresh.
            defs=inkprof.internal.workflowSteps();assessment=struct;
            for d=defs'
                a=struct('valid',false,'ready',true,'reason',"Ready");
                for dep=string(d.requires)
                    if ~assessment.(dep).valid,a.ready=false;a.reason="Requires "+dep;break;end
                end
                s=obj.State.steps.(d.id);
                if a.ready&&string(s.status)=="completed"
                    a.valid=true;
                    for f=reshape(s.artifacts,1,[])
                        path=obj.resolve(f.path);
                        if ~isfile(path)||inkprof.internal.sha256(path)~=string(f.sha256)
                            a.valid=false;a.reason="Input is missing or has changed: "+string(f.path);break;
                        end
                    end
                end
                assessment.(d.id)=a;
            end
        end
        function file=output(obj,id,key)
            file=obj.resolve(obj.State.steps.(id).outputs.(key));
        end
        function result=run(obj,id,options)
            arguments
                obj
                id (1,1) string
                options (1,1) struct = struct
            end
            lock=obj.lock();obj.reload();
            [ok,reason]=obj.ready(id);assert(ok,'inkprof:WorkflowBlocked','%s',reason);
            if id=="profile"&&isfield(options,'Mode')&&string(options.Mode)=="manual"
                assert(~isfield(obj.State,'activeContinuation'),'inkprof:WorkflowBlocked','A continued iteration uses the combined inputs through automatic continuation.');
                [ok,reason]=obj.valid('recipe');assert(ok,'inkprof:WorkflowBlocked','B2 is required: %s',reason);
            end
            % Invalidate descendants before starting, including cancelled reruns.
            obj.invalidate(id);obj.State.currentStep=id;
            obj.State.steps.(id).status="running";obj.State.steps.(id).message="Running";obj.event(id,"started",options);obj.save();
            try
                [outputs,files]=inkprof.internal.executeWorkflowStep(obj,id,options);
                assert(~isempty(files),'inkprof:Cancelled','Cancelled without saved results.');
                artifacts=struct('path',{},'sha256',{});
                for f=reshape(string(files),1,[])
                    rel=obj.relative(f);assert(isfile(f),'inkprof:Workflow','Missing result: %s',f);
                    artifacts(end+1)=struct('path',rel,'sha256',inkprof.internal.sha256(f)); %#ok<AGROW>
                end
                names=fieldnames(outputs);
                for k=1:numel(names),outputs.(names{k})=obj.relative(outputs.(names{k}));end
                obj.State.steps.(id)=struct('status',"completed",'outputs',outputs,'artifacts',artifacts,'message',"Complete");
                details=struct('result',obj.State.steps.(id),'summary',struct);
                for name=string(fieldnames(outputs))'
                    file=obj.resolve(outputs.(name));
                    if endsWith(file,".json")
                        r=jsondecode(fileread(file));
                        for field=["summary","status","recommendation","priorities","roundtripDeltaE00","selection","errorNorm","patchCount","notes"]
                            if isfield(r,field),details.summary.(name).(field)=r.(field);end
                        end
                    end
                end
                obj.event(id,"completed",details);
                if id=="continue",obj.nextCycle(outputs,artifacts);end
                obj.save();result=obj.State.steps.(id);
                inkprof.internal.recordProjectStep(obj.Root,"workflow-"+id);
            catch err
                status="failed";if strcmp(err.identifier,'inkprof:Cancelled'),status="pending";end
                obj.State.steps.(id).status=status;obj.State.steps.(id).message=string(err.message);
                obj.event(id,status,string(err.message));obj.save();rethrow(err)
            end
            clear lock
        end
        function record=editDetails(obj,details)
            % Update shared metadata and rename the project folder without changing evidence.
            lock=obj.lock();obj.reload();
            assert(isstruct(details)&&isscalar(details)&&all(isfield(details,{'Name','User','Printing'})), ...
                'inkprof:ProjectDetails','Project name, user and printing details are required.');
            assert(strlength(strtrim(string(details.Name)))>0&&strlength(strtrim(string(details.User)))>0, ...
                'inkprof:ProjectDetails','Enter a project name and user.');
            before=jsondecode(fileread(fullfile(obj.Root,'inkprof-project.json')));
            newName=inkprof.internal.projectFolderName(details.Name);oldRoot=obj.Root;
            newRoot=oldRoot;
            if newName~=string(before.name),newRoot=fullfile(fileparts(oldRoot),newName);end
            if newRoot~=oldRoot
                assert(~isfolder(newRoot)&&~isfile(newRoot),'inkprof:Exists','A file or folder with the new project name already exists.');
            end
            printing=before.printing;
            for field=string(fieldnames(details.Printing))',printing.(field)=details.Printing.(field);end
            printingChanged=~strcmp(jsonencode(orderfields(printing)),jsonencode(orderfields(before.printing)));
            sameUser=isfield(before,'user')&&string(before.user)==strtrim(string(details.User));
            if ~printingChanged&&newName==string(before.name)&&sameUser,record=before;return;end
            if printingChanged
                obj.invalidate("input");
            else
                obj.invalidate("export");
            end
            % Save invalidation first: an interrupted edit must not leave an old report current.
            obj.save();
            relocations=before.relocations;
            if newRoot~=oldRoot
                manifestLock=fullfile(obj.Root,'.manifest.lock');
                assert(java.io.File(char(manifestLock)).createNewFile(),'inkprof:ProjectBusy','Project metadata is being updated. Retry when it finishes.');
                renameCleanup=onCleanup(@()delete(fullfile(obj.Root,'.manifest.lock')));
                src=java.io.File(char(oldRoot)).toPath();dst=java.io.File(char(newRoot)).toPath();
                java.nio.file.Files.move(src,dst,javaArray('java.nio.file.CopyOption',0));
                obj.Root=newRoot;clear renameCleanup
                relocation=struct('from',oldRoot,'to',newRoot,'utc',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
                if isempty(relocations),relocations=relocation;else,relocations(end+1)=relocation;end
            end
            record=inkprof.updateProject(obj.Root,Step="project-details-edited", ...
                Name=newName,User=details.User,Printing=details.Printing,Relocations=relocations);
            previous=struct('name',before.name,'user',"",'printing',before.printing);
            if isfield(before,'user'),previous.user=before.user;end
            obj.event("project-details","updated",struct('before',previous,'after', ...
                struct('name',record.name,'user',record.user,'printing',record.printing)));
            obj.save();clear lock
            record=inkprof.updateProject(obj.Root,Step="project-details-audited");
        end
        function file=resolve(obj,relative)
            file=inkprof.internal.absolutePath(fullfile(obj.Root,string(relative)));
            assert(startsWith(file,obj.Root+filesep),'inkprof:WorkflowPath','The file must be inside the selected project.');
        end
        function rel=relative(obj,file)
            file=inkprof.internal.absolutePath(file);
            assert(startsWith(file,obj.Root+filesep),'inkprof:WorkflowPath','The file must be inside the selected project: %s',file);
            rel=replace(extractAfter(file,strlength(obj.Root)+1),"\","/");
        end
        function folder=newFolder(obj,parent)
            folder=fullfile(obj.Root,parent,string(java.util.UUID.randomUUID()));
        end
    end
    methods (Access=private)
        function file=stateFile(obj),file=fullfile(obj.Root,'workflow.json');end
        function cleanup=lock(obj)
            file=fullfile(obj.Root,'.workflow.lock');
            assert(java.io.File(char(file)).createNewFile(),'inkprof:WorkflowBusy', ...
                'The project is in use by another operation. After an interrupted MATLAB session, make sure no operation is running before removing .workflow.lock.');
            cleanup=onCleanup(@()delete(fullfile(obj.Root,'.workflow.lock')));
        end
        function save(obj)
            obj.State.revision=obj.State.revision+1;
            obj.State.updatedUTC=string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
            stage=fullfile(obj.Root,".workflow-"+string(java.util.UUID.randomUUID())+".json");
            inkprof.internal.writeJson(stage,obj.State);
            [ok,msg]=movefile(stage,obj.stateFile(),'f');assert(ok,'inkprof:IO','%s',msg);
        end
        function invalidate(obj,id)
            if any(id==["definition","render","measurement","review","input"])&&isfield(obj.State,'activeContinuation')
                obj.State=rmfield(obj.State,'activeContinuation');
            end
            defs=inkprof.internal.workflowSteps();affected=string(id);changed=true;
            % Automatic profile does not require B2, but changing B2 invalidates it.
            if id=="recipe",affected=[affected,"profile"];end
            while changed
                changed=false;
                for d=defs'
                    if ~ismember(string(d.id),affected)&&any(ismember(string(d.requires),affected))
                        affected(end+1)=string(d.id);changed=true; %#ok<AGROW>
                    end
                end
            end
            for key=affected
                s=obj.State.steps.(key);
                if string(s.status)~="pending"
                    obj.event(key,"superseded",s);
                    obj.State.steps.(key).status="stale";
                end
            end
        end
        function event(obj,id,status,details)
            e=struct('step',id,'status',status,'cycle',obj.State.cycle,'iterationId',obj.State.iterationId,'details',details, ...
                'utc',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
            h=obj.State.history;if isempty(h),h={};elseif isstruct(h),h=num2cell(h);end
            h{end+1}=e;obj.State.history=h;
            % Append-only human and machine logs; state history is authoritative.
            for format=["txt","jsonl"]
                file=fullfile(obj.Root,"result-log."+format);
                fid=fopen(file,'a','n','UTF-8');assert(fid>=0,'inkprof:IO','Cannot open the results log.');
                cleanup=onCleanup(@()fclose(fid));
                if format=="jsonl",fprintf(fid,'%s\n',jsonencode(e));
                else,fprintf(fid,'[%s] Iteration %d | %s | %s\n%s\n\n',e.utc,e.cycle,id,status,jsonencode(details,PrettyPrint=true));end
                clear cleanup
            end
        end
        function nextCycle(obj,outputs,artifacts)
            obj.event("cycle","archived",obj.State.steps);
            obj.State=inkprof.internal.advanceWorkflowCycle(obj.State,outputs,artifacts);
            obj.event("cycle","started",struct('parentIterationId',obj.State.parentIterationId,'candidate',outputs));
        end
    end
end
