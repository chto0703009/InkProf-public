% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
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
                obj.State.mode="profiling";
                if isfield(p,'workflowMode'),obj.State.mode=string(p.workflowMode);end
                if obj.State.mode=="verification",obj.State.currentStep="profile";end
                lock=obj.lock();obj.save();clear lock
                inkprof.updateProject(obj.Root,Step="workflow-created");
            end
        end
        function reload(obj)
            obj.State=jsondecode(fileread(obj.stateFile()));
            assert(obj.State.schemaVersion==1&&string(obj.State.documentType)=="inkprof.workflow",'inkprof:Workflow','Unknown workflow version.');
            obj.State=inkprof.internal.upgradeWorkflowState(obj.State);
        end
        function mode=mode(obj)
            mode="profiling";if isfield(obj.State,'mode'),mode=string(obj.State.mode);end
        end
        function defs=definitions(obj)
            defs=inkprof.internal.workflowSteps(obj.mode());
        end
        function [ok,reason]=ready(obj,id)
            defs=obj.definitions();index=find(string({defs.id})==string(id));
            assert(isscalar(index),'inkprof:Workflow','Unknown step.');
            ok=true;reason="Ready";
            if ~defs(index).enabled,ok=false;reason="Not part of this project mode.";return;end
            if id=="compare"&&isempty(inkprof.internal.comparisonParent(obj.State))
                ok=false;reason="Available after an ICC profile has been built in iteration 2 or later.";return
            end
            for dep=string(defs(index).requires)
                [valid,why]=obj.valid(dep);
                if ~valid,ok=false;reason="Requires "+dep+": "+why;return;end
            end
        end
        function [ok,reason]=valid(obj,id)
            s=obj.State.steps.(id);ok=false;reason=string(s.status);
            if string(s.status)~="completed",return;end
            [ok,reason]=obj.ready(id);if ~ok,return;end
            if id=="refine"&&(~isfield(s,'method')||string(s.method)~="image")
                [ok,reason]=obj.valid('feedback');if ~ok,reason="Requires current feedback: "+reason;return;end
            end
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
            defs=obj.definitions();assessment=struct;
            for d=defs'
                a=struct('valid',false,'ready',true,'reason',"Ready");
                if ~d.enabled,a.ready=false;a.reason="Not part of this project mode.";assessment.(d.id)=a;continue;end
                for dep=string(d.requires)
                    if ~assessment.(dep).valid,a.ready=false;a.reason="Requires "+dep;break;end
                end
                if string(d.id)=="compare"&&isempty(inkprof.internal.comparisonParent(obj.State))
                    a.ready=false;a.reason="Available after an ICC profile has been built in iteration 2 or later.";
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
                if string(d.id)=="refine"&&a.valid&&(~isfield(s,'method')||string(s.method)~="image")
                    a.valid=assessment.feedback.valid;
                    if ~a.valid,a.reason="Error-driven refinement requires current C3 feedback.";end
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
            if id=="profile"&&isfield(options,'FWACompensation')
                assert(~isfield(options,'Mode')||string(options.Mode)~="manual",'inkprof:FWA','Change FWA in B2 before a manual build.');
                assert(islogical(options.FWACompensation)&&isscalar(options.FWACompensation),'inkprof:FWA','FWA selection must be logical.');
                obj.applyFWA(options.FWACompensation,"automatic-profiling");
            end
            if id=="refine"&&(~isfield(options,'Method')||string(options.Method)~="image")
                [ok,reason]=obj.valid('feedback');assert(ok,'inkprof:WorkflowBlocked','Error-driven refinement requires current C3 feedback: %s',reason);
            end
            % Invalidate descendants before starting, including cancelled reruns.
            obj.invalidate(id);obj.State.currentStep=id;
            obj.State.steps.(id).status="running";obj.State.steps.(id).message="Running";obj.event(id,"started",options);obj.save();
            % Keep the manifest consistent while the step runs, so a crash or
            % forced quit does not leave the project failing its integrity check.
            inkprof.updateProject(obj.Root,Step="workflow-"+id+"-started",WorkflowMetadataOnly=true);
            try
                [outputs,files]=inkprof.internal.executeWorkflowStep(obj,id,options);
                if id=="recipe"&&isfield(outputs,'recipe')
                    recipe=jsondecode(fileread(outputs.recipe));obj.applyFWA(logical(recipe.colorimetry.fwaCompensation),"profiling-recipe");
                end
                savingProgress=inkprof.internal.calculationProgress("Saving project results","Checking output files and saving workflow, iteration and result-log records.");
                assert(~isempty(files),'inkprof:Cancelled','Cancelled without saved results.');
                artifacts=struct('path',{},'sha256',{});
                for f=reshape(string(files),1,[])
                    rel=obj.relative(f);assert(isfile(f),'inkprof:Workflow','Missing result: %s',f);
                    artifacts(end+1)=struct('path',rel,'sha256',inkprof.internal.sha256(f)); %#ok<AGROW>
                end
                names=fieldnames(outputs);
                for k=1:numel(names),outputs.(names{k})=obj.relative(outputs.(names{k}));end
                obj.State.steps.(id)=struct('status',"completed",'outputs',outputs,'artifacts',artifacts,'message',"Complete");
                if id=="refine"
                    method="errors";if isfield(options,'Method'),method=string(options.Method);end
                    obj.State.steps.refine.method=method;
                end
                if id=="refine"&&isfield(outputs,'c2reference')
                    obj.invalidate('c2');
                    linked=outputs;linked.reference=linked.c2reference;linked=rmfield(linked,{'c2reference','proposal'});
                    obj.State.steps.c2=struct('status',"completed",'outputs',linked,'artifacts',artifacts,'message',"C2 included in combined image-refinement TIFF16; not yet measured");
                    obj.event('c2',"linked",linked);
                elseif any(id==["c2measurement","refinemeasurement"])&&isfield(outputs,'c3report')
                    obj.invalidate('c2measurement');obj.invalidate('refinemeasurement');
                    linked=struct('status',"completed",'outputs',struct('measurement',outputs.measurement),'artifacts',artifacts,'message',"Combined target measured");
                    obj.State.steps.c2measurement=linked;obj.State.steps.refinemeasurement=linked;
                    obj.State.steps.c3=struct('status',"completed",'outputs',struct('report',outputs.c3report),'artifacts',artifacts,'message',"C2 subset analysed separately from image patches; approval still required");
                    obj.event('c3',"completed",obj.State.steps.c3);
                end
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
                inkprof.internal.recordProjectStep(obj.Root,"workflow-"+id);clear savingProgress;
            catch err
                clear savingProgress;status="failed";if strcmp(err.identifier,'inkprof:Cancelled'),status="pending";end
                obj.State.steps.(id).status=status;obj.State.steps.(id).message=string(err.message);
                obj.event(id,status,string(err.message));obj.save();
                % Record our own state changes even on cancellation/failure. Do not
                % accept changed measurement/target files by rehashing all inputs.
                try
                    inkprof.updateProject(obj.Root,Step="workflow-"+id+"-"+status,WorkflowMetadataOnly=true);
                catch manifestError
                    warning('inkprof:ManifestUpdate','Could not record workflow metadata: %s',manifestError.message);
                end
                rethrow(err)
            end
            clear lock
        end
        function ids=recoverInterrupted(obj)
            %RECOVERINTERRUPTED Mark steps left "running" by a closed MATLAB session as failed
            % and record the workflow files in the manifest. Targets, measurements and
            % profiles are not rehashed, so changed artifacts are still reported.
            lock=obj.lock();ids=strings(0,1);
            for id=reshape(string(fieldnames(obj.State.steps)),1,[])
                if string(obj.State.steps.(id).status)=="running"
                    obj.State.steps.(id).status="failed";
                    obj.State.steps.(id).message="Interrupted: MATLAB closed while the step was running. Run the step again.";
                    obj.event(id,"interrupted","MATLAB closed while the step was running.");ids(end+1)=id; %#ok<AGROW>
                end
            end
            obj.save();
            inkprof.updateProject(obj.Root,Step="workflow-recovered-after-interruption",WorkflowMetadataOnly=true);
            clear lock
        end
        function destination=savePrintCopy(obj,id,parent)
            lock=obj.lock();obj.reload();
            [ok,reason]=obj.valid(id);assert(ok,'inkprof:WorkflowBlocked','%s',reason);
            parent=inkprof.internal.absolutePath(parent);
            assert(isfolder(parent),'inkprof:PrintCopy','Select an existing destination folder.');
            assert(parent~=obj.Root&&~startsWith(parent,obj.Root+filesep),'inkprof:PrintCopy','Select a folder outside the project.');
            outputs=obj.State.steps.(id).outputs;keys=string(fieldnames(outputs));keys=keys(startsWith(keys,"TIFF16_"));
            assert(~isempty(keys),'inkprof:PrintCopy','This step has no saved TIFF16 pages.');
            token=string(java.util.UUID.randomUUID());destination=fullfile(parent,"InkProf-"+id+"-"+token);mkdir(destination);
            files=struct('name',{},'sha256',{});
            for key=keys'
                source=obj.resolve(outputs.(key));[~,name,ext]=fileparts(source);name=name+ext;
                copyfile(source,fullfile(destination,name));hash=inkprof.internal.sha256(source);
                assert(inkprof.internal.sha256(fullfile(destination,name))==hash,'inkprof:Integrity','Print copy checksum mismatch.');
                files(end+1)=struct('name',name,'sha256',hash);
            end
            if string(id)=="c2"
                instructions="C2 verification target. The ICC profile has already been applied once. Print at 100% with ALL further colour conversion OFF."+newline+ ...
                    "Black point compensation (BPC): OFF, deliberately for this verification target. BPC adapts dark tones to the printer and paper black level; it is not used for this measurement.";
            else
                instructions="Profiling target. Print at 100% as device RGB with ALL colour conversion OFF. No ICC profile has been applied.";
            end
            project=jsondecode(fileread(fullfile(obj.Root,'inkprof-project.json')));
            drying="unknown";if isfield(project.printing,'dryingHours'),drying=string(project.printing.dryingHours);end
            instructions=instructions+newline+"Drying time (hours): "+drying+newline+ ...
                "Use the project's printer, paper, ink and print settings. Allow the documented drying time. Return to the same project to measure.";
            f=fopen(fullfile(destination,'PRINTING.txt'),'w','n','UTF-8');assert(f>=0);fprintf(f,'%s',instructions);fclose(f);
            record=struct('documentType',"inkprof.print-delivery",'step',string(id),'iteration',obj.State.cycle,'destination',destination,'files',files,'instructions',instructions);
            folder=obj.newFolder('reports');mkdir(folder);inkprof.internal.writeJson(fullfile(folder,'print-delivery.json'),record);
            obj.event(id,"print-copy-saved",record);obj.save();
            inkprof.updateProject(obj.Root,Step="print-copy-saved");clear lock
        end
        function setFWA(obj,enabled,source)
            arguments
                obj
                enabled (1,1) logical
                source (1,1) string = "later-selection"
            end
            lock=obj.lock();obj.reload();obj.applyFWA(enabled,source);clear lock
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
            paperLayout=struct;if isfield(details,'PaperLayout'),paperLayout=details.PaperLayout;end
            if ~printingChanged&&newName==string(before.name)&&sameUser
                record=before;
                if ~isempty(fieldnames(paperLayout))
                    record=inkprof.updateProject(obj.Root,Step="paper-layout-preferences",PaperLayout=paperLayout);
                end
                return
            end
            if printingChanged
                previousPrinting=before.printing;physicalPrinting=printing;
                if isfield(previousPrinting,'fwaCompensation'),previousPrinting=rmfield(previousPrinting,'fwaCompensation');end
                if isfield(physicalPrinting,'fwaCompensation'),physicalPrinting=rmfield(physicalPrinting,'fwaCompensation');end
                onlyFWA=strcmp(jsonencode(orderfields(previousPrinting)),jsonencode(orderfields(physicalPrinting)));
                if obj.mode()=="verification"
                    obj.invalidate("c2");
                elseif onlyFWA
                    % FWA changes the build recipe, not the frozen raw measurements.
                    obj.invalidate("recipe");
                else
                    obj.invalidate("input");
                end
            else
                obj.invalidate("export");obj.invalidate("numericalExport");
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
                Name=newName,User=details.User,Printing=details.Printing,PaperLayout=paperLayout,Relocations=relocations,FolderName=string(java.io.File(char(obj.Root)).getName()));
            previous=struct('name',before.name,'user',"",'printing',before.printing);
            if isfield(before,'user'),previous.user=before.user;end
            obj.event("project-details","updated",struct('before',previous,'after', ...
                struct('name',record.name,'user',record.user,'printing',record.printing)));
            obj.save();clear lock
            record=inkprof.updateProject(obj.Root,Step="project-details-audited");
        end
        function record=reconcileFolderName(obj,action)
            % Explicit user decision after an external folder rename.
            arguments
                obj
                action (1,1) string {mustBeMember(action,["accept","restore","cancel"])}
            end
            lock=obj.lock();obj.reload();
            mismatch=inkprof.internal.projectFolderStatus(obj.Root);
            before=jsondecode(fileread(fullfile(obj.Root,'inkprof-project.json')));
            if ~mismatch.changed,record=before;return;end
            decision=struct('utc',string(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
                'user',string(java.lang.System.getProperty('user.name')),'action',action, ...
                'savedFolderName',mismatch.savedName,'detectedFolderName',mismatch.actualName, ...
                'previousProjectName',string(before.name),'detectedPath',obj.Root, ...
                'resultingPath',obj.Root,'resultingProjectName',string(before.name),'status',"pending",'message',"");
            try
                if action=="accept"
                    newName=inkprof.internal.projectFolderName(mismatch.actualName);
                    assert(newName==mismatch.actualName,'inkprof:ProjectName','Remove leading or trailing spaces from the folder name before accepting it.');
                    obj.invalidate("export");obj.invalidate("numericalExport");obj.save();
                    record=inkprof.updateProject(obj.Root,Step="external-folder-name-accepted",Name=newName,FolderName=newName);
                    decision.resultingProjectName=newName;
                elseif action=="restore"
                    savedName=inkprof.internal.projectFolderName(mismatch.savedName);
                    previousRoot=obj.Root;newRoot=fullfile(fileparts(obj.Root),savedName);
                    assert(~isfolder(newRoot)&&~isfile(newRoot),'inkprof:Exists','The saved folder name is already occupied. Nothing was overwritten.');
                    manifestLock=fullfile(obj.Root,'.manifest.lock');
                    assert(java.io.File(char(manifestLock)).createNewFile(),'inkprof:ProjectBusy','Project metadata is being updated. Retry when it finishes.');
                    renameCleanup=onCleanup(@()delete(fullfile(obj.Root,'.manifest.lock')));
                    java.nio.file.Files.move(java.io.File(char(obj.Root)).toPath(),java.io.File(char(newRoot)).toPath(),javaArray('java.nio.file.CopyOption',0));
                    obj.Root=newRoot;clear renameCleanup
                    relocations=before.relocations;
                    relocation=struct('from',previousRoot,'to',newRoot,'utc',decision.utc);
                    if isempty(relocations),relocations=relocation;else,relocations(end+1)=relocation;end
                    record=inkprof.updateProject(obj.Root,Step="external-folder-name-restored",FolderName=savedName,Relocations=relocations);
                end
                decision.resultingPath=obj.Root;
                decision.status="completed";if action=="cancel",decision.status="cancelled";end
            catch err
                decision.status="failed";decision.message=string(err.message);
                obj.event("folder-name",decision.status,decision);obj.save();
                inkprof.updateProject(obj.Root,Step="folder-name-decision",FolderDecision=decision);
                rethrow(err)
            end
            obj.event("folder-name",decision.status,decision);obj.save();
            record=inkprof.updateProject(obj.Root,Step="folder-name-decision",FolderDecision=decision);
            clear lock
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
        function applyFWA(obj,enabled,source)
            record=jsondecode(fileread(fullfile(obj.Root,'inkprof-project.json')));
            previous=isfield(record.printing,'fwaCompensation')&&isequal(record.printing.fwaCompensation,true);
            recorded=isfield(record.printing,'fwaCompensation');
            if recorded&&previous==enabled,return;end
            % Raw measurements and B1 remain valid; B2/profile and approvals do not.
            if previous~=enabled,obj.invalidate("recipe");end
            obj.save();
            inkprof.updateProject(obj.Root,Step="fwa-selection",Printing=struct('fwaCompensation',enabled));
            obj.event("fwa-selection","updated",struct('before',previous,'after',enabled,'previouslyRecorded',recorded,'source',source));obj.save();
            inkprof.internal.recordProjectStep(obj.Root,"fwa-selection-audited");
        end
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
            defs=obj.definitions();affected=string(id);changed=true;
            % Automatic profile does not require B2, but changing B2 invalidates it.
            if id=="recipe",affected=[affected,"profile"];end
            if any(id==["c2","c2measurement","c3","feedback"])&& ...
                    (~isfield(obj.State.steps.refine,'method')||string(obj.State.steps.refine.method)~="image")
                affected=[affected,"refine"];
            end
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
