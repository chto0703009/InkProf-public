% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fig=app(projectFolder)
%APP Project workflow for the complete InkProf profiling chain.
% inkprof.app() or inkprof.app('/path/to/existing/project')
arguments
 projectFolder (1,1) string = ""
end
w=[];busy=false;selected="definition";defs=inkprof.internal.workflowSteps();
fig=uifigure('Name',char("InkProf "+inkprof.version()+" | Projects and iterations"),'Position',[80 70 1220 810],'Tag','InkProfWorkflow');
fig.CloseRequestFcn=@closeApp;
g=uigridlayout(fig,[5 1]);g.RowHeight={42,40,48,'1x',42};g.Padding=[18 14 18 14];
heading=uilabel(g,'Text','InkProf | Project-based profiling','FontSize',23,'FontWeight','bold');
bar=uigridlayout(g,[1 8]);bar.Padding=[0 0 0 0];bar.ColumnWidth={115,115,130,85,130,130,135,90};
uibutton(bar,'Text','New project','Tag','newProject','ButtonPushedFcn',@newProject);
uibutton(bar,'Text','Open project','Tag','openProject','ButtonPushedFcn',@openProject);
detailsButton=uibutton(bar,'Text','Project details','Tag','editProjectDetails','Enable','off','ButtonPushedFcn',@editDetails);
uibutton(bar,'Text','Refresh','ButtonPushedFcn',@(~,~)refresh());
uibutton(bar,'Text','Open results log','Tag','openResultLog','ButtonPushedFcn',@openLog);
uibutton(bar,'Text','Iteration history','Tag','iterationHistory','ButtonPushedFcn',@history);
reportButton=uibutton(bar,'Text','Open report','Tag','openFinalReport','Enable','off','ButtonPushedFcn',@openReport);
labButton=uibutton(bar,'Text','View 3D','Tag','showProfile3D','Enable','off','ButtonPushedFcn',@show3D);
projectBar=uigridlayout(g,[1 4]);projectBar.ColumnWidth={'1x',200,120,140};projectBar.Padding=[0 0 0 0];
projectLabel=uilabel(projectBar,'Text','Create a new project or select an existing one.','WordWrap','on');
remeasureButton=uibutton(projectBar,'Text','Remeasure saved refinement','Tag','remeasureSavedRefinement','Enable','off','ButtonPushedFcn',@remeasureRefinement);
gamutButton=uibutton(projectBar,'Text','View gamut','Tag','showGamut','Enable','off','ButtonPushedFcn',@showGamutView);
verifyButton=uibutton(projectBar,'Text','Verify project','Tag','verifyProject','Enable','off','ButtonPushedFcn',@verifyCurrentProject);
body=uigridlayout(g,[1 2]);body.ColumnWidth={490,'1x'};body.Padding=[0 0 0 0];
table=uitable(body,'ColumnName',{'Step','Status'},'ColumnWidth',{350,105},'ColumnEditable',false,'Tag','workflowSteps','CellSelectionCallback',@select);
right=uigridlayout(body,[9 1]);right.RowHeight={34,100,'1x',42,42,42,36,36,36};right.Padding=[10 0 0 0];
titleLabel=uilabel(right,'FontSize',18,'FontWeight','bold','Text','Workflow');
hint=uitextarea(right,'Editable','off','Value',{'Select a project.'});
details=uitextarea(right,'Editable','off','Tag','workflowDetails');
runButton=uibutton(right,'Text','Run selected step','Tag','runWorkflowStep','Enable','off','ButtonPushedFcn',@run);
uibutton(right,'Text','Open selected step results','ButtonPushedFcn',@openResult);
printButton=uibutton(right,'Text','Copy TIFF16 for printing…','Tag','copyPrintTIFF','Enable','off','ButtonPushedFcn',@copyPrint);
compareButton=uibutton(right,'Text','Compare accuracy and gradients','Tag','compareProfileTradeoffs','Enable','off','ButtonPushedFcn',@compareTradeoffs);
photoButton=uibutton(right,'Text','Photographic gradients','Tag','photoGradientCheck','Enable','off','ButtonPushedFcn',@photoCheck);
legal=uigridlayout(right,[1 2]);legal.Padding=[0 0 0 0];legal.ColumnWidth={'1x',170};
uilabel(legal,'Text','Results and progress are saved in the project.','WordWrap','on');
uibutton(legal,'Text','Licence and liability','Tag','licenseNotice','ButtonPushedFcn',@showLicense);
footer=uigridlayout(g,[1 2]);footer.Padding=[0 0 0 0];footer.ColumnWidth={'1x',120};
status=uilabel(footer,'Text','Ready','WordWrap','on','Tag','workflowStatus');
uibutton(footer,'Text','Close app','Tag','closeWorkflowApp','ButtonPushedFcn',@closeApp);
if projectFolder~=""
    try,loadProject(projectFolder);catch err,uialert(fig,err.message,'Open project');end
end
    function showLicense(~,~)
        config=inkprof.paths();
        message=inkprof.internal.warrantyNotice("en")+newline+newline+ ...
            "InkProf: GNU GPL version 3 or later. Full licence: "+ ...
            string(fullfile(config.Root,'LICENSE'))+newline+"https://www.gnu.org/licenses/gpl-3.0.html";
        uialert(fig,message,'Licence and liability','Icon','info');
    end
    function verifyCurrentProject(~,~)
        if isempty(w)||busy,return;end
        try
            check=inkprof.verifyProject(w.Root);
            if check.passed,message="Integrity verified: "+check.checkedFiles+" files match their SHA-256 checksums.";icon='success';
            else,message=strjoin(check.issues,newline);icon='warning';end
            uialert(fig,message,'Project integrity','Icon',icon);
        catch err,uialert(fig,err.message,'Project integrity');end
    end
    function remeasureRefinement(~,~)
        if isempty(w)||busy,return;end
        busy=true;
        try
            w.restoreRefinementForRemeasurement();selected="refinemeasurement";
            message='Existing refinement target restored. Step 16: Run selected step, then Measure the corrected print.';
        catch err,message=string(err.message);uialert(fig,message,'Remeasure saved refinement');end
        busy=false;refresh();status.Text=message;
    end
    function loadProject(folder)
        check=inkprof.verifyProject(folder);
        if ~check.passed
            % Only the workflow records differ: typical after MATLAB was closed or
            % force-quit during a step. Offer to record them; anything else stays blocked.
            metadata="Changed file: "+["workflow.json","result-log.jsonl","result-log.txt"];
            if ~all(ismember(check.issues,metadata))
                uialert(fig,strjoin(check.issues,newline),'Project integrity check failed');return;
            end
            message="The project was interrupted while a step was running (for example after a forced quit)."+newline+newline+ ...
                "Only the workflow records differ from the manifest:"+newline+strjoin(extractAfter(check.issues,"Changed file: "),newline)+newline+newline+ ...
                "Targets, measurements and profiles are unchanged. Record the current workflow state and mark the interrupted step as failed?";
            choice=uiconfirm(fig,message,'Project was interrupted','Icon','warning','Options',{'Record and open','Cancel'},'DefaultOption',1,'CancelOption',2);
            if ~strcmp(choice,'Record and open'),return;end
            try
                candidate=inkprof.ProjectWorkflow(folder);candidate.recoverInterrupted();
            catch err,uialert(fig,err.message,'Project recovery');return;end
            check=inkprof.verifyProject(folder);
            if ~check.passed,uialert(fig,strjoin(check.issues,newline),'Project integrity check failed');return;end
        end
        candidate=inkprof.ProjectWorkflow(folder);
        mismatch=inkprof.internal.projectFolderStatus(candidate.Root);
        if mismatch.changed
            message="The project folder name differs from the saved name."+newline+newline+ ...
                "Saved folder name: "+mismatch.savedName+newline+"Current folder name: "+mismatch.actualName+newline+newline+ ...
                "Use the current folder name as the new project name, or restore the saved folder name?";
            choice=uiconfirm(fig,message,'Project folder renamed','Icon','warning', ...
                'Options',{'Use folder name','Restore saved name','Cancel'},'DefaultOption',3,'CancelOption',3);
            action="cancel";if strcmp(choice,'Use folder name'),action="accept";elseif strcmp(choice,'Restore saved name'),action="restore";end
            candidate.reconcileFolderName(action);
            if action=="cancel",return;end
        end
        w=candidate;defs=w.definitions();defs=defs([defs.enabled]);selected=string(w.State.currentStep);refresh();
    end
    function newProject(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if busy,return;end
        paths=inkprof.paths();[n,p]=inkprof.internal.withFocus(fig,@uiputfile,'*','New project name',fullfile(paths.Projects,'New-paper'));
        if isequal(n,0),return;end
        try
            modeChoice=uiconfirm(fig,'Create a new profile or verify an existing printer ICC?', 'Project purpose', ...
                'Options',{'Profile printer','Verify existing ICC','Cancel'},'CancelOption',3);
            if strcmp(modeChoice,'Cancel'),return;end
            mode="profiling";if strcmp(modeChoice,'Verify existing ICC'),mode="verification";end
            d=inkprof.projectDetailsDialog(struct('name',string(n)));if isempty(d),return;end
            folder=inkprof.createProject(string(fullfile(p,inkprof.internal.projectFolderName(d.Name))),Name=d.Name,User=d.User,Printing=d.Printing,Mode=mode);
            if isfield(d,'PaperLayout'),inkprof.updateProject(folder,Step="paper-layout-preferences",PaperLayout=d.PaperLayout);end
            loadProject(folder);
        catch err,uialert(fig,err.message,'Project');end
    end
    function editDetails(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if isempty(w)||busy,return;end
        try
            record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
            d=inkprof.projectDetailsDialog(record);if isempty(d),return;end
            w.editDetails(d);refresh();
        catch err,uialert(fig,err.message,'Project details');end
    end
    function openProject(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if busy,return;end
        paths=inkprof.paths();p=inkprof.internal.withFocus(fig,@uigetdir,char(paths.Projects),'Select an existing InkProf project');
        if isequal(p,0),return;end
        try,loadProject(string(p));catch err,uialert(fig,err.message,'Project');end
    end
    function select(~,e)
        if isempty(e.Indices)||busy,return;end
        selected=string(defs(e.Indices(1),1).id);refresh();
        % Approval is an interactive review: open it on selection rather than
        % leaving the user with an instruction and no assessment field.
        if selected=="approve"&&~isempty(w)&&strcmp(runButton.Enable,'on')
            run([],[]);
        end
    end
    function refresh()
        if isempty(w)||busy,return;end
        try
            w.reload();detailsButton.Enable='on';verifyButton.Enable='on';assessment=w.inspect();data=cell(numel(defs),2);
            remeasureButton.Enable=matlab.lang.OnOffSwitchState(isfield(w.State.steps.refine.outputs,'proposal')&&isfield(w.State.steps.refine.outputs,'target'));
            for k=1:numel(defs)
                id=string(defs(k).id);valid=assessment.(id).valid;ready=assessment.(id).ready;
                s=string(w.State.steps.(id).status);
                if valid,s="Complete";elseif s=="completed",s="Out of date";elseif s=="running",s="Interrupted / running";elseif s=="failed",s="Failed";elseif ready,s="Ready";else,s="Locked";end
                data(k,:)={defs(k).label,char(s)};
            end
            reportButton.Enable=matlab.lang.OnOffSwitchState((assessment.export.valid&&isfield(w.State.steps.export.outputs,'finalReport'))||(assessment.numericalExport.valid&&isfield(w.State.steps.numericalExport.outputs,'finalReport')));
            labButton.Enable=matlab.lang.OnOffSwitchState(assessment.c2.valid);
            gamutButton.Enable=matlab.lang.OnOffSwitchState(assessment.profile.valid);
            compareButton.Enable=matlab.lang.OnOffSwitchState(assessment.input.valid);
            photoButton.Enable=matlab.lang.OnOffSwitchState(assessment.profile.valid);
            table.Data=data;index=find(string({defs.id})==selected);titleLabel.Text=defs(index).label;
            ok=assessment.(selected).ready;reason=assessment.(selected).reason;runButton.Enable=matlab.lang.OnOffSwitchState(ok);
            runButton.Text='Run selected step';
            if selected=="approve",runButton.Text='Open review and approval';end
            guide=instruction(selected);
            if w.mode()=="verification"
                guide="Verify the imported ICC using the documented printer, paper, ink and settings. The original profile is preserved.";
                if selected=="c2",guide="Save TIFF16 with the ICC applied once. Print at 100% with further colour management OFF. Let the print dry before measuring.";end
                if selected=="export",guide="Save the measurement certificate and its evidence in a portable folder. Results apply to this print and these settings; no new ICC is built.";end
            end
            hint.Value=cellstr([reason;guide]);
            printButton.Enable=matlab.lang.OnOffSwitchState(assessment.(selected).valid&&any(startsWith(string(fieldnames(w.State.steps.(selected).outputs)),"TIFF16_")));
            printButton.Text='Copy TIFF16 for printing…';
            if any(selected==["export","numericalExport"])
                printButton.Text='Save delivery elsewhere…';
                printButton.Enable=matlab.lang.OnOffSwitchState(assessment.(selected).ready);
            end
            step=w.State.steps.(selected);lines=["Iteration "+w.State.cycle;"Status: "+string(data{index,2});""];
            names=string(fieldnames(step.outputs));
            resultStep=selected;
            if isempty(names)
                complete=string({defs.id});
                complete=complete(arrayfun(@(id)assessment.(id).valid,complete));
                if isempty(complete)
                    lines=[lines;"Ready to begin. Completed work and saved files will appear here."];
                else
                    lines=[lines;"Completed work in this iteration:"];
                    for id=complete
                        label=string(defs(find(string({defs.id})==id,1)).label);
                        lines(end+1)="✓ "+label;
                    end
                    previous=string(w.State.currentStep);
                    if previous~=selected&&isfield(w.State.steps,previous)&&assessment.(previous).valid
                        resultStep=previous;
                        step=w.State.steps.(previous);names=string(fieldnames(step.outputs));
                        label=string(defs(find(string({defs.id})==previous,1)).label);
                        lines=[lines;"";"Last completed step: "+label];
                    end
                end
                if assessment.(selected).ready
                    lines=[lines;"";"Next: "+string(defs(index).label);"Use Run selected step to continue."];
                else
                    lines=[lines;"";"Selected step: "+string(defs(index).label);string(assessment.(selected).reason)];
                end
                if ~isempty(names),lines=[lines;"";"Results saved from the completed step:"];end
            else
                if assessment.(selected).valid
                    lines=[lines;string(step.message);"";"Saved results for this step:"];
                else
                    lines=[lines;"These saved results are not current. Inputs or prerequisites have changed."; ...
                        "Complete the required preceding steps, then run this step again before using its results."; ...
                        "";"Previous results (out of date):"];
                end
            end
            if assessment.(resultStep).valid
                lines=[lines;inkprof.internal.savedTargetSummary(w,resultStep);""];
            end
            for name=names',lines=[lines;name+":";w.resolve(step.outputs.(name));""];end %#ok<AGROW>
            details.Value=cellstr(lines);
            record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
            projectLabel.Text=string(record.name)+" | "+string(record.printing.printer)+" | "+string(record.printing.paper)+newline+w.Root;
            heading.Text="InkProf | Iteration "+w.State.cycle;
            if w.mode()=="verification",heading.Text="InkProf | Verify existing ICC";end
            status.Text="Last active step: "+string(w.State.currentStep)+" | saved revision "+w.State.revision;
        catch err,status.Text=err.message;runButton.Enable='off';end
    end
    function photoCheck(~,~)
        if isempty(w)||busy,return;end
        busy=true;
        try,inkprof.checkPhotoGradients(fileparts(w.output('profile','job')));catch err,uialert(fig,err.message,'Photographic gradients');end
        busy=false;refresh();
    end
    function compareTradeoffs(~,~)
        if isempty(w)||busy,return;end
        busy=true;compareButton.Enable='off';
        try,inkprof.internal.profileTradeoffDialog(w,fig);catch err,uialert(fig,err.message,'Profile comparison');end
        busy=false;refresh();
    end
    function run(~,~,saveElsewhere)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if nargin<3,saveElsewhere=false;end
        if isempty(w)||busy,return;end
        progress=[];watch=[];started=[];finished=false;message="";
        active=selected;
        try
            preflight=inkprof.internal.calculationProgress("Checking project inputs","Checking saved files and prerequisites before starting.",Parent=fig);
            w.reload();
            [ready,reason]=w.ready(active);clear preflight;
            if ~ready
                if active=="export"
                    reason="Step 14 requires print verification and approval for the current profile. An approval from an earlier iteration cannot be reused."+newline+newline+ ...
                        "To save a numerically checked profile without a separate verification print, select step 19: Save ICC + measurement certificate without print verification.";
                end
                uialert(fig,reason,'Step not available','Icon','info');return;
            end
            o=optionsFor(selected,saveElsewhere);if isempty(o),return;end
            busy=true;setappdata(fig,'InkProfRunning',true);fig.Visible='on';figure(fig);runButton.Enable='off';started=datetime('now');
            index=find(string({defs.id})==active);
            data=table.Data;data{index,2}='Running';table.Data=data;
            titleLabel.Text="Running — "+string(defs(index).label);
            hint.Value={'Work is in progress. No need to click Run again.'; ...
                'If an input or measurement window opens, complete it there.'};
            details.Value={'Running. Results will appear when this step finishes.'};
            status.Text="Running: "+string(defs(index).label);drawnow;
            if w.mode()~="verification"&&active=="profile"&&(~isfield(o,'Mode')||string(o.Mode)~="manual")
                progress=uiprogressdlg(fig,'Title','Building ICC profile','Message', ...
                    'Preparing measurements. This can take several minutes.', ...
                    'Indeterminate','on','Cancelable','off');
            end
            watch=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop','TimerFcn',@updateProgress);
            start(watch);
            w.run(active,o);finished=true;
            message="Complete: "+string(defs(index).label)+". Results saved.";
            saved=inkprof.internal.savedTargetSummary(w,active);
            if ~isempty(saved),message=message+" "+saved(1);end
        catch err
            clear preflight;message=string(err.message);
            stopProgress();
            if ~strcmp(err.identifier,'inkprof:Cancelled'),uialert(fig,err.message,'InkProf');end
        end
        stopProgress();busy=false;
        if finished&&active~="export"
            w.reload();assessment=w.inspect();
            for next=index+1:numel(defs)
                id=string(defs(next).id);
                if assessment.(id).ready&&~assessment.(id).valid
                    selected=id;table.Selection=[next 1];
                    message=message+" Next: "+string(defs(next).label);break
                end
            end
        end
        refresh();status.Text=message;
        if finished&&any(active==["render","c2","refine"])
            outputs=w.State.steps.(active).outputs;keys=string(fieldnames(outputs));keys=keys(startsWith(keys,"TIFF16_"));
            paths=strings(0,1);for key=keys',paths(end+1)=w.resolve(outputs.(key));end
            choice=uiconfirm(fig,strjoin(inkprof.internal.savedTargetSummary(w,active),newline)+newline+strjoin(paths,newline)+newline+newline+ ...
                "Keep the project originals. You can copy the print files to another folder.",'TIFF16 saved', ...
                'Options',{'Copy for printing','Done'},'DefaultOption',1,'CancelOption',2,'Icon','success');
            if strcmp(choice,'Copy for printing'),copyPrintStep(active);end
        end
        function updateProgress(~,~)
            if ~isvalid(fig),return;end
            elapsed=seconds(datetime('now')-started);
            phase=string(defs(index).label);
            if isappdata(fig,'InkProfCalculationPhase'),phase=getappdata(fig,'InkProfCalculationPhase');end
            text=phase+" — elapsed "+floor(elapsed/60)+" min "+mod(floor(elapsed),60)+" sec";
            logs=dir(fullfile(w.Root,'profiles','iterations','*','progress.log'));
            if any(active==["profile","continue"])&&~isempty(logs)
                [~,last]=max([logs.datenum]);entry=logs(last);
                if entry.datenum>=datenum(started)
                    try
                        lines=splitlines(strtrim(string(fileread(fullfile(entry.folder,entry.name)))));
                        text=text+newline+lines(end);
                    catch
                        % The writer may be replacing the progress file.
                    end
                end
            end
            if ~isempty(progress)&&isvalid(progress),progress.Message=char(text);end
            details.Value=cellstr(splitlines(text+newline+"Work is in progress. Complete any open input dialog; otherwise please wait."));status.Text="Running: "+phase+". Please wait.";
        end
        function stopProgress()
            if isgraphics(fig),setappdata(fig,'InkProfRunning',false);end
            if ~isempty(watch)&&isvalid(watch),stop(watch);delete(watch);end
            if ~isempty(progress)&&isvalid(progress),close(progress);end
        end
    end
    function copyPrint(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if isempty(w)||busy,return;end
        if any(selected==["export","numericalExport"])
            run([],[],true);return;
        end
        copyPrintStep(selected);
    end
    function copyPrintStep(id)
        parent=inkprof.internal.withFocus(fig,@uigetdir,char(fileparts(w.Root)),'Choose destination for TIFF16 print copies');
        if isequal(parent,0),return;end
        try
            destination=w.savePrintCopy(id,string(parent));refresh();
            uialert(fig,"TIFF16 print copies and PRINTING.txt saved in:"+newline+destination,'Print files saved','Icon','success');
        catch err,uialert(fig,err.message,'Print copy');end
    end
    function o=optionsFor(id,saveElsewhere)
        o=struct;
        if w.mode()=="verification"&&id=="profile"
            o.Source=pick('*.icc;*.icm','Select existing RGB printer ICC');
            if o.Source=="",o=[];end
            return
        elseif id=="c2"
            choice=uiconfirm(fig,'Create a new verification target or select one you have already printed?', ...
                'Verification target','Options',{'Select existing target','Create new target','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Select existing target')
                targets=inkprof.internal.savedVerificationTargets(w);
                if isempty(targets),uialert(fig,'No saved verification targets for the current ICC were found.','Verification target');o=[];return;end
                [index,ok]=inkprof.internal.withFocus(fig,@listdlg,'ListString',cellstr(string({targets.label})), ...
                    'SelectionMode','single','PromptString','Select the target matching your printed sheet:', ...
                    'Name','Saved verification targets','ListSize',[720 220]);
                if ~ok,o=[];return;end
                o.Source=targets(index).file;return
            end
            % Profile test target: fixed reference set (e.g. ColorChecker SG Lab) or generated colours.
            [o.ReferenceSet,cancelled]=inkprof.internal.chooseReferenceSet(fig,w.mode()~="verification");
            if cancelled,o=[];return;end
            if o.ReferenceSet~=""
                a=inkprof.internal.withFocus(fig,@inputdlg,{'Extra repeat patches (0 = none)'},'Profile test target',1,{'12'});
                if isempty(a),o=[];return;end
                o.Repeats=str2double(a{1});validateattributes(o.Repeats,{'double'},{'scalar','integer','>=',0,'<=',500});
                return
            end
            if w.mode()=="verification"
                project=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));count=575;
                if isfield(project,'verificationPatchCount'),count=project.verificationPatchCount;end
                a=inkprof.internal.withFocus(fig,@inputdlg,{'Total control patches (including repeats, 64–2000)'},'Verification target',1,{char(string(count))});
                if isempty(a),o=[];return;end
                o.PatchCount=str2double(a{1});validateattributes(o.PatchCount,{'double'},{'scalar','integer','>=',64,'<=',2000});
            end
            return
        end
        if id=="definition"
            choice=uiconfirm(fig,'Create an RGB target or import an existing definition?','RGB target','Options',{'Create','Import','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Import')
                o.Source=pick('*.ti1;*.pxf;*.txf;*.cxf;*.txt;*.cgats','Select RGB definition');
                if o.Source=="",o=[];return;end
                [~,~,ext]=fileparts(o.Source);
                if any(lower(ext)==[".txt",".cgats"])
                    a=inkprof.internal.withFocus(fig,@inputdlg,'RGB scale (1, 100 or 255)','RGB scale',1,{'100'});if isempty(a),o=[];return;end;o.RGBScale=str2double(a{1});
                end
            end
        elseif id=="render"
            choice=uiconfirm(fig,'Render a new target or use an existing TIFF16 package?','Print target', ...
                'Options',{'Render new','Select existing','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Select existing'),o.Source=pick('target.ti2','Select TI2 in an existing print package');if o.Source=="",o=[];end,end
        elseif any(id==["measurement","c2measurement","refinemeasurement"])
            choice=uiconfirm(fig,'Measure, choose a saved project revision, or import a file?','Measurement','Options',{'Measure','Saved revisions','Import file','Cancel'},'CancelOption',4);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Measure')&&id=="c2measurement"
                ref=jsondecode(fileread(w.output('c2','reference')));
                name=string(ref.name)+" ("+numel(ref.patches)+" patches)";
                confirm=uiconfirm(fig,"Selected target: "+name+newline+"Use the matching printed sheet.", ...
                    'Confirm measurement target','Options',{'Measure this target','Cancel'},'CancelOption',2);
                if strcmp(confirm,'Cancel'),o=[];return;end
            end
            if strcmp(choice,'Saved revisions')
                parents=struct('measurement','render','c2measurement','c2','refinemeasurement','refine');
                o.Source=inkprof.selectMeasurementRevision(fullfile(w.Root,'measurements'),w.output(parents.(id),'target'),Parent=fig);
                if o.Source=="",o=[];end
            elseif strcmp(choice,'Import file')
                o.Source=pick('*.json;*.ti3;*.mxf','Import measurement revision');if o.Source=="",o=[];end
            end
        elseif id=="approve"
            o=inkprof.internal.approvalDialog(w);
        elseif any(id==["review","refine"])
            if id=="refine"
                choice=uiconfirm(fig,'Choose how to propose additional patches. Image and gamut selections require a current checked ICC. For gamut patches, first select an area in View gamut and save the selection. Error-driven refinement also requires C3 feedback.', ...
                    'Refinement source','Options',{'From image','From gamut selection','From verification errors','Cancel'},'CancelOption',4);
                if strcmp(choice,'Cancel'),o=[];return;end
                o.Method="image";
                if strcmp(choice,'From gamut selection')
                    o.Method="gamut";latest=inkprof.internal.latestGamutProposal(w.Root,w.output('profile','profile'));
                    useLatest=false;
                    if latest~=""
                        saved=jsondecode(fileread(latest));
                        action=uiconfirm(fig,sprintf('Use the latest gamut selection with %d selected patches? Step 15 creates the print package to measure in step 16.',numel(saved.candidates)), ...
                            'Gamut selection','Options',{'Use latest selection','Choose another','Cancel'},'CancelOption',3);
                        if strcmp(action,'Cancel'),o=[];return;end
                        useLatest=strcmp(action,'Use latest selection');
                    end
                    if useLatest,o.ExistingProposal=latest;else,o.ExistingProposal=pick('proposal.json','Select saved gamut proposal.json');end
                    if o.ExistingProposal=="",o=[];return;end
                    saved=jsondecode(fileread(o.ExistingProposal));
                    assert(string(saved.documentType)=="inkprof.gamut-refinement",'inkprof:Gamut','Select a gamut-area proposal.');
                end
                if strcmp(choice,'From verification errors')
                    mode=uiconfirm(fig,'Argyll only: preconditioned targen patches, colprof -r 1.0, no InkProf Jacobian or pre-regularization. Current InkProf: C3 residuals and Jacobian-guided patches. Both require a new measurement and independent print verification.', ...
                        'Refinement method','Options',{'1. Argyll only','2. Current InkProf (Jacobian sampling)','Cancel'},'DefaultOption',1,'CancelOption',3);
                    if strcmp(mode,'Cancel'),o=[];return;end
                    o.RefinementMode="inkprof";if startsWith(mode,'1.'),o.RefinementMode="argyll";end
                    o.Method="errors";[ok,why]=w.valid('feedback');
                    if ~ok,uialert(fig,"Complete current C3 feedback first: "+why,'Refinement');o=[];return;end
                end
            end
            if id=="refine"&&any(o.Method==["image","gamut"])
                reference=inkprof.internal.pendingVerification(w);
                o.IncludeC2=reference~="";o.C2Reference=reference;
                if o.Method=="image"&&w.valid('refine')&&isfield(w.State.steps.refine,'method')&&string(w.State.steps.refine.method)=="image"
                    choice=uiconfirm(fig,'Reuse your saved image-patch selection or select another image? Any current C2 patches without a saved measurement will be included automatically.', ...
                        'Image patches','Options',{'Use saved image patches','Choose another image','Cancel'},'CancelOption',3);
                    if strcmp(choice,'Cancel'),o=[];return;end
                    if strcmp(choice,'Use saved image patches'),o.ExistingProposal=w.output('refine','proposal');end
                end
            end
            if id=="review"
                m=w.output('measurement','measurement');inkprof.previewMeasurement(fileparts(m),jsondecode(fileread(m)));
            end
            a=inkprof.internal.withFocus(fig,@inputdlg,char(instruction(id)),'Record assessment',[4 65],{''});
            if isempty(a),o=[];return;end
            o.Notes=inkprof.internal.dialogText(a{1});o.Confirmed=strlength(strtrim(o.Notes))>0;
        elseif any(id==["export","numericalExport"])
            if id=="numericalExport"
                a=inkprof.internal.withFocus(fig,@inputdlg,{'Why are you ending this iteration without a separate verification print? State intended use.'},'Save measurement certificate',[4 70],{''});
                if isempty(a),o=[];return;end
                o.Notes=inkprof.internal.dialogText(a{1});
                if strlength(strtrim(o.Notes))==0,o=[];return;end
                answer=uiconfirm(fig,'Numeriskt kontrollerad; denna iteration är inte verifierad genom separat utskrift och mätning.','Confirm report scope', ...
                    'Options',{'Save with this statement','Cancel'},'DefaultOption',2,'CancelOption',2);
                if strcmp(answer,'Cancel'),o=[];return;end
                o.Confirmed=true;
            end
            message="The ICC profile already exists in this project:"+newline+w.output('profile','profile')+newline+newline+ ...
                "This step saves an approved delivery copy and creates the measurement certificate (PDF and HTML) inside the project."+newline+newline+ ...
                "You can also save copies elsewhere. The ICC, PDF certificate, HTML and supporting files are collected in one folder named after the PDF. Move or share that entire folder. The project keeps its own copies.";
            if id=="numericalExport"
                message="Save the current ICC and a measurement certificate (PDF and HTML) with the numerical-only verification scope. This does not approve print accuracy. Project copies are retained; external copies include all supporting files.";
            end
            choice='Also save copies elsewhere';
            if ~saveElsewhere
                choice=uiconfirm(fig,message,'Save profile and report', ...
                    'Options',{'Also save copies elsewhere','Save in project only','Cancel'},'DefaultOption',1,'CancelOption',3);
            end
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Save in project only'),return;end
            record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
            profileName=inkprof.internal.projectDeliveryProfileName(record);
            reportName=inkprof.internal.certificateDeliveryName(profileName,w.State.cycle,w.State.iterationId)+".pdf";
            destination=fullfile(string(java.lang.System.getProperty('user.home')),'Downloads');
            if ~isfolder(destination),destination=string(fileparts(w.Root));end
            [n,p]=inkprof.internal.withFocus(fig,@uiputfile,{'*.pdf','Report (*.pdf)';'*.html','Report (*.html)';'*.txt','Report as text (*.txt)'}, ...
                'Choose bundle name and location (ICC, PDF, HTML, JPG and supporting files)',fullfile(destination,reportName));
            if isequal(n,0),o=[];return;end
            o.ICCDestination=string(fullfile(p,profileName+".icc"));
            o.ReportDestination=string(fullfile(p,n));o.Overwrite=true;
        elseif id=="profile"
            choice=uiconfirm(fig,'Select a profiling workflow. Manual mode requires a completed B2 recipe.','Profiling', ...
                'Options',{'Automatic','Manual B3','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            o.Mode="automatic";if strcmp(choice,'Manual B3'),o.Mode="manual";end
            if o.Mode=="automatic"
                record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
                enabled=isfield(record.printing,'fwaCompensation')&&isequal(record.printing.fwaCompensation,true);
                default=2;if enabled,default=1;end
                choice=uiconfirm(fig,'Use FWA/OBA compensation to D50? The saved choice updates Project details. Requires native M0 spectra, a known instrument and measured paper white.','FWA / OBA', ...
                    'Options',{'Enable FWA','Disable FWA','Cancel'},'DefaultOption',default,'CancelOption',3);
                if strcmp(choice,'Cancel'),o=[];return;end
                o.FWACompensation=strcmp(choice,'Enable FWA');
                choice=uiconfirm(fig,'Is there a separate RoleFile defining training, development and verification patches?','Patch roles', ...
                    'Options',{'Select RoleFile','No separate role file','Cancel'},'CancelOption',3);
                if strcmp(choice,'Cancel'),o=[];return;end
                if strcmp(choice,'Select RoleFile'),o.RoleFile=pick('*.json','Select RoleFile');if o.RoleFile=="",o=[];return;end,end
            end
        end
        if any(id==["profile","refine","continue"])&&~(id=="refine"&&isfield(o,'Method')&&o.Method=="image")
            a=inkprof.internal.withFocus(fig,@inputdlg,{'MaxNewPatches','NormTarget','GrayWeight'},'Iteration parameters',1,{'100','1','2'});
            if isempty(a),o=[];return;end
            o.MaxNewPatches=str2double(a{1});o.NormTarget=str2double(a{2});o.GrayWeight=str2double(a{3});
        end
    end
    function file=pick(filter,label)
        [n,p]=inkprof.internal.withFocus(fig,@uigetfile,filter,label,char(w.Root));file="";if ~isequal(n,0),file=string(fullfile(p,n));end
    end
    function openLog(~,~)
        if isempty(w),return;end
        p=fullfile(w.Root,'result-log.txt');if isfile(p),edit(p);else,uialert(fig,'The log is created when the first operation runs.','Results log');end
    end
    function openReport(~,~)
        if isempty(w),return;end
        w.reload();id="export";
        if w.valid('numericalExport')&&(selected=="numericalExport"||~w.valid('export')),id="numericalExport";end
        [valid,reason]=w.valid(id);
        if ~valid,uialert(fig,char(reason),'Report is out of date');return;end
        web(char(w.output(id,'finalReport')),'-browser');
    end
    function showGamutView(~,~)
        if busy || isempty(w),return;end
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        busy=true;setappdata(fig,'InkProfRunning',true);
        busyGuard=onCleanup(@finishGamut); %#ok<NASGU>
        try
            w.reload();[ok,why]=w.valid('profile');
            assert(ok,'inkprof:GamutUnavailable','%s',why);
            [progressGuard,~]=inkprof.internal.calculationProgress("ICC gamut","Calculating the ICC gamut surface...",Parent=fig); %#ok<ASGLU>
            inkprof.showGamut(w.output('profile','profile'));
        catch err
            uialert(fig,err.message,'ICC gamut');
        end
    end
    function finishGamut()
        busy=false;
        if isgraphics(fig),setappdata(fig,'InkProfRunning',false);end
    end
    function show3D(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if isempty(w),return;end
        w.reload();[ok,why]=w.valid('c2');
        if ~ok,uialert(fig,char(why),'3D data unavailable');return;end
        inkprof.showVerificationLab(w.output('c2','reference'));
    end
    function history(~,~)
        focusGuard=inkprof.internal.restoreAppFocus(fig); %#ok<NASGU>
        if isempty(w),return;end
        w.reload();h=w.State.history;if isstruct(h),h=num2cell(h);end
        rows=cell(0,4);
        for k=1:numel(h)
            e=h{k};rows(end+1,:)={e.cycle,char(e.utc),char(e.step),char(e.status)}; %#ok<AGROW>
        end
        f=uifigure('Name','InkProf | Iteration history','Position',[120 100 1040 700]);
        grid=uigridlayout(f,[2 1]);grid.RowHeight={'1x','1x'};
        t=uitable(grid,'Data',rows,'ColumnName',{'Iteration','Time UTC','Step','Result'},'ColumnWidth',{80,180,180,'auto'});
        text=uitextarea(grid,'Editable','off');t.CellSelectionCallback=@showEvent;
        function showEvent(~,e)
            if ~isempty(e.Indices),text.Value=splitlines(string(jsonencode(h{e.Indices(1)},PrettyPrint=true)));end
        end
    end
    function openResult(~,~)
        if isempty(w)||busy,return;end
        s=w.State.steps.(selected);names=fieldnames(s.outputs);
        if isempty(names),return;end
        labels=names;
        deliveryStep=any(selected==["export","numericalExport"]);
        if deliveryStep
            labels(strcmp(names,'profile'))={'Save ICC and report copies...'};
            labels(strcmp(names,'finalReport'))={'Open HTML report'};
            labels(strcmp(names,'reportPDF'))={'Open PDF report'};
            labels(strcmp(names,'reportJSON'))={'Open report data (JSON)'};
            labels(strcmp(names,'reportText'))={'Open text report'};
            labels(strcmp(names,'delivery'))={'Open delivery receipt (saved locations)'};
        end
        dialogFocus=inkprof.internal.restoreAppFocus(fig);
        [ix,ok]=inkprof.internal.withFocus(fig,@listdlg,'ListString',labels,'SelectionMode','single','PromptString','Choose a result or save copies');
        clear dialogFocus
        if ~ok,return;end
        resultFocus=inkprof.internal.restoreAppFocus(fig,RestoreOnReturn=false); %#ok<NASGU>
        if deliveryStep&&strcmp(names{ix},'profile')
            run([],[],true);
        else
            open(w.output(selected,names{ix}));
        end
    end
    function closeApp(~,~)
        if busy
            uialert(fig,'An operation is still running. Wait for it to finish, or cancel it in its own dialog. Then close the app.','Operation in progress');return
        end
        if isempty(w),delete(fig);return;end
        try
            check=inkprof.verifyProject(w.Root);
            if check.passed
                record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
                message="Project data and workflow are saved on disk."+newline+ ...
                    "Integrity verified: "+check.checkedFiles+" files."+newline+ ...
                    "Last saved (UTC): "+string(record.updatedUTC)+newline+newline+ ...
                    "Project folder:"+newline+w.Root+newline+newline+ ...
                    "You can reopen this project and continue later. Close app does not quit MATLAB.";
                title='Project saved — safe to close';icon='success';
            else
                message="Saved project integrity could not be confirmed:"+newline+strjoin(check.issues,newline)+newline+newline+ ...
                    "Closing will not repair or remove any files. Keep the app open to investigate, or close anyway.";
                title='Check project before closing';icon='warning';
            end
            choice=uiconfirm(fig,message,title,'Options',{'Keep open','Close app'}, ...
                'DefaultOption',1,'CancelOption',1,'Icon',icon);
            if strcmp(choice,'Close app'),delete(fig);end
        catch err
            uialert(fig,"Could not confirm saved project state: "+string(err.message),'Close app');
        end
    end
end
function s=instruction(id)
s="This step runs in the selected project. Results and dependencies are saved in workflow.json.";
switch id
 case "render",s="Save TIFF16 in the project. Print the files separately, then return to the app for measurement.";
 case "c2",s="Save C2 as TIFF16. The ICC profile has already been applied once. Print separately without further colour conversion, then measure in the app.";
 case {"measurement","c2measurement","refinemeasurement"},s="When your separately printed sheet is ready, start instrument measurement here. The app uses the saved target TI2 and saves measurement results in the project.";
 case "numericalExport",s="Optional after step 8: save the current ICC and a measurement certificate without a new verification print. Your decision and the absence of separate print verification are recorded. This does not mark steps 9–14 complete.";
 case "export",s="This step requires print verification and approval for the current iteration. To finish without a separate verification print, use step 19. The ICC profile already exists in the project. This step saves the approved profile and creates its measurement certificate in the project. Optionally save additional copies elsewhere. The exported certificate and all supporting files are saved together in one report folder.";
 case "review",s="Review measurements, unusual rows and repeats. Record your assessment and any accepted remeasurements.";
 case "compare",s="Compare this ICC with the previous iteration on common RGB and Lab samples. Profile differences do not prove improved print accuracy; fresh independent print verification is still required.";
 case "approve",s="Record the intended use, quality requirements and accepted limitations. This is the user's decision after physical C2/C3 verification, not ISO certification.";
 case "refine",s="Add patches from an image, a saved gamut-area selection, or current verification errors. For gamut patches, first use View gamut → Select area → Review patches / create TIFF16, then choose From gamut selection here. Image and gamut refinement use the current checked ICC; error-driven refinement requires C3 feedback. Print the TIFF16 package saved by this step. Record why you are adding patches.";
 case "profile",s="Automatic iteration or manual B3. Manual B3 requires B2. A successful job produces a candidate, not an approval of print quality.";
 case "checks",s="Run numerical checks. Review the reports before printing; these checks do not replace C2/C3.";
 case "continue",s="Link refinement to previous inputs and patch roles. The next iteration requires new checks and new physical C2/C3 verification.";
end
end
