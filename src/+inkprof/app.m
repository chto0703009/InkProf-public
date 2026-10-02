function fig=app(projectFolder)
%APP Project workflow for the complete InkProf profiling chain.
% inkprof.app() or inkprof.app('/path/to/existing/project')
arguments
 projectFolder (1,1) string = ""
end
w=[];busy=false;selected="definition";defs=inkprof.internal.workflowSteps();
fig=uifigure('Name','InkProf | Projects and iterations','Position',[80 70 1220 810],'Tag','InkProfWorkflow');
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
reportButton=uibutton(bar,'Text','Open final report','Tag','openFinalReport','Enable','off','ButtonPushedFcn',@openReport);
labButton=uibutton(bar,'Text','View 3D','Tag','showProfile3D','Enable','off','ButtonPushedFcn',@show3D);
projectBar=uigridlayout(g,[1 2]);projectBar.ColumnWidth={'1x',140};projectBar.Padding=[0 0 0 0];
projectLabel=uilabel(projectBar,'Text','Create a new project or select an existing one.','WordWrap','on');
verifyButton=uibutton(projectBar,'Text','Verify project','Tag','verifyProject','Enable','off','ButtonPushedFcn',@verifyCurrentProject);
body=uigridlayout(g,[1 2]);body.ColumnWidth={490,'1x'};body.Padding=[0 0 0 0];
table=uitable(body,'ColumnName',{'Step','Status'},'ColumnWidth',{350,105},'ColumnEditable',false,'Tag','workflowSteps','CellSelectionCallback',@select);
right=uigridlayout(body,[6 1]);right.RowHeight={34,100,'1x',42,42,36};right.Padding=[10 0 0 0];
titleLabel=uilabel(right,'FontSize',18,'FontWeight','bold','Text','Workflow');
hint=uitextarea(right,'Editable','off','Value',{'Select a project.'});
details=uitextarea(right,'Editable','off','Tag','workflowDetails');
runButton=uibutton(right,'Text','Run selected step','Tag','runWorkflowStep','Enable','off','ButtonPushedFcn',@run);
uibutton(right,'Text','Open selected step results','ButtonPushedFcn',@openResult);
legal=uigridlayout(right,[1 2]);legal.Padding=[0 0 0 0];legal.ColumnWidth={'1x',170};
uilabel(legal,'Text','Results and progress are saved in the project.','WordWrap','on');
uibutton(legal,'Text','Licence and liability','Tag','licenseNotice','ButtonPushedFcn',@showLicense);
status=uilabel(g,'Text','Ready','WordWrap','on','Tag','workflowStatus');
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
    function loadProject(folder)
        check=inkprof.verifyProject(folder);
        if ~check.passed,uialert(fig,strjoin(check.issues,newline),'Project integrity check failed');return;end
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
        w=candidate;selected=string(w.State.currentStep);refresh();
    end
    function newProject(~,~)
        if busy,return;end
        paths=inkprof.paths();[n,p]=uiputfile('*','New project name',fullfile(paths.Projects,'New-paper'));
        if isequal(n,0),return;end
        try
            d=inkprof.projectDetailsDialog(struct('name',string(n)));if isempty(d),return;end
            folder=inkprof.createProject(string(fullfile(p,inkprof.internal.projectFolderName(d.Name))),Name=d.Name,User=d.User,Printing=d.Printing);loadProject(folder);
        catch err,uialert(fig,err.message,'Project');end
    end
    function editDetails(~,~)
        if isempty(w)||busy,return;end
        try
            record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
            d=inkprof.projectDetailsDialog(record);if isempty(d),return;end
            w.editDetails(d);refresh();
        catch err,uialert(fig,err.message,'Project details');end
    end
    function openProject(~,~)
        if busy,return;end
        paths=inkprof.paths();p=uigetdir(char(paths.Projects),'Select an existing InkProf project');
        if isequal(p,0),return;end
        try,loadProject(string(p));catch err,uialert(fig,err.message,'Project');end
    end
    function select(~,e)
        if isempty(e.Indices)||busy,return;end
        selected=string(defs(e.Indices(1),1).id);refresh();
    end
    function refresh()
        if isempty(w)||busy,return;end
        try
            w.reload();detailsButton.Enable='on';verifyButton.Enable='on';assessment=w.inspect();data=cell(numel(defs),2);
            for k=1:numel(defs)
                id=string(defs(k).id);valid=assessment.(id).valid;ready=assessment.(id).ready;
                s=string(w.State.steps.(id).status);
                if valid,s="Complete";elseif s=="completed",s="Out of date";elseif s=="running",s="Interrupted / running";elseif s=="failed",s="Failed";elseif ready,s="Ready";else,s="Locked";end
                data(k,:)={defs(k).label,char(s)};
            end
            reportButton.Enable=matlab.lang.OnOffSwitchState(assessment.export.valid&&isfield(w.State.steps.export.outputs,'finalReport'));
            labButton.Enable=matlab.lang.OnOffSwitchState(assessment.c2.valid);
            table.Data=data;index=find(string({defs.id})==selected);titleLabel.Text=defs(index).label;
            ok=assessment.(selected).ready;reason=assessment.(selected).reason;runButton.Enable=matlab.lang.OnOffSwitchState(ok);
            hint.Value=cellstr([reason;instruction(selected)]);
            step=w.State.steps.(selected);lines=["Iteration "+w.State.cycle;"Status: "+string(data{index,2});"";string(step.message);"";"Saved results:"];
            names=string(fieldnames(step.outputs));
            if isempty(names),lines(end+1)="No results yet.";end
            for name=names',lines=[lines;name+":";w.resolve(step.outputs.(name));""];end %#ok<AGROW>
            details.Value=cellstr(lines);
            record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
            projectLabel.Text=string(record.name)+" | "+string(record.printing.printer)+" | "+string(record.printing.paper)+newline+w.Root;
            heading.Text="InkProf | Iteration "+w.State.cycle;
            status.Text="Last active step: "+string(w.State.currentStep)+" | saved revision "+w.State.revision;
        catch err,status.Text=err.message;runButton.Enable='off';end
    end
    function run(~,~)
        if isempty(w)||busy,return;end
        try
            o=optionsFor(selected);if isempty(o),return;end
            busy=true;runButton.Enable='off';status.Text="Running: "+selected+". Complete or close the open dialog.";drawnow;
            w.run(selected,o);
            status.Text='Results saved. Project copies and selected save locations are listed in the results log.';
        catch err
            status.Text=err.message;
            if ~strcmp(err.identifier,'inkprof:Cancelled'),uialert(fig,err.message,'InkProf');end
        end
        busy=false;refresh();
    end
    function o=optionsFor(id)
        o=struct;
        if id=="definition"
            choice=uiconfirm(fig,'Create an RGB target or import an existing definition?','RGB target','Options',{'Create','Import','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Import')
                o.Source=pick('*.ti1;*.pxf;*.txf;*.cxf;*.txt;*.cgats','Select RGB definition');
                if o.Source=="",o=[];return;end
                [~,~,ext]=fileparts(o.Source);
                if any(lower(ext)==[".txt",".cgats"])
                    a=inputdlg('RGB scale (1, 100 or 255)','RGB scale',1,{'100'});if isempty(a),o=[];return;end;o.RGBScale=str2double(a{1});
                end
            end
        elseif id=="render"
            choice=uiconfirm(fig,'Render a new target or use an existing TIFF16 package?','Print target', ...
                'Options',{'Render new','Select existing','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Select existing'),o.Source=pick('target.ti2','Select TI2 in an existing print package');if o.Source=="",o=[];end,end
        elseif any(id==["measurement","c2measurement","refinemeasurement"])
            choice=uiconfirm(fig,'Measure with an instrument or select JSON / TI3 / MXF?','Measurement','Options',{'Measure','Select saved file','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            if strcmp(choice,'Select saved file'),o.Source=pick('*.json;*.ti3;*.mxf','Select accepted measurement revision');if o.Source=="",o=[];end,end
        elseif any(id==["review","approve","refine"])
            if id=="review"
                m=w.output('measurement','measurement');inkprof.previewMeasurement(fileparts(m),jsondecode(fileread(m)));
            end
            a=inputdlg(char(instruction(id)),'Record assessment',[4 65],{''});
            if isempty(a),o=[];return;end
            o.Notes=string(a{1});o.Confirmed=strlength(strtrim(o.Notes))>0;
        elseif id=="export"
            [n,p]=uiputfile({'*.icc','ICC profile (*.icc)';'*.icm','ICC profile (*.icm)'},'Save final ICC profile',fullfile(w.Root,'profile.icc'));
            if isequal(n,0),o=[];return;end
            o.ICCDestination=string(fullfile(p,n));
            [n,p]=uiputfile({'*.pdf','Final report (*.pdf)';'*.html','Final report (*.html)';'*.txt','Final report as text (*.txt)'}, ...
                'Save PDF and HTML with the same name',fullfile(p,'final-report.pdf'));
            if isequal(n,0),o=[];return;end
            o.ReportDestination=string(fullfile(p,n));o.Overwrite=true;
        elseif id=="profile"
            choice=uiconfirm(fig,'Select a profiling workflow. Manual mode requires a completed B2 recipe.','Profiling', ...
                'Options',{'Automatic','Manual B3','Cancel'},'CancelOption',3);
            if strcmp(choice,'Cancel'),o=[];return;end
            o.Mode="automatic";if strcmp(choice,'Manual B3'),o.Mode="manual";end
            if o.Mode=="automatic"
                choice=uiconfirm(fig,'Is there a separate RoleFile defining training, development and verification patches?','Patch roles', ...
                    'Options',{'Select RoleFile','No separate role file','Cancel'},'CancelOption',3);
                if strcmp(choice,'Cancel'),o=[];return;end
                if strcmp(choice,'Select RoleFile'),o.RoleFile=pick('*.json','Select RoleFile');if o.RoleFile=="",o=[];return;end,end
            end
        end
        if any(id==["profile","refine","continue"])
            a=inputdlg({'MaxNewPatches','NormTarget','GrayWeight'},'Iteration parameters',1,{'100','1','2'});
            if isempty(a),o=[];return;end
            o.MaxNewPatches=str2double(a{1});o.NormTarget=str2double(a{2});o.GrayWeight=str2double(a{3});
        end
    end
    function file=pick(filter,label)
        [n,p]=uigetfile(filter,label,char(w.Root));file="";if ~isequal(n,0),file=string(fullfile(p,n));end
    end
    function openLog(~,~)
        if isempty(w),return;end
        p=fullfile(w.Root,'result-log.txt');if isfile(p),edit(p);else,uialert(fig,'The log is created when the first operation runs.','Results log');end
    end
    function openReport(~,~)
        if isempty(w),return;end
        w.reload();[valid,reason]=w.valid('export');
        if ~valid,uialert(fig,char(reason),'Final report is out of date');return;end
        web(char(w.output('export','finalReport')),'-browser');
    end
    function show3D(~,~)
        if isempty(w),return;end
        w.reload();[ok,why]=w.valid('c2');
        if ~ok,uialert(fig,char(why),'3D data unavailable');return;end
        inkprof.showVerificationLab(w.output('c2','reference'));
    end
    function history(~,~)
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
        if isempty(w),return;end
        s=w.State.steps.(selected);names=fieldnames(s.outputs);
        if isempty(names),return;end
        [ix,ok]=listdlg('ListString',names,'SelectionMode','single','PromptString','Open results');
        if ok,open(w.output(selected,names{ix}));end
    end
    function closeApp(~,~)
        if busy,uialert(fig,'Complete or cancel the current dialog before closing the app.','Operation in progress');else,delete(fig);end
    end
end
function s=instruction(id)
s="This step runs in the selected project. Results and dependencies are saved in workflow.json.";
switch id
 case "render",s="Save TIFF16 in the project. Print the files separately, then return to the app for measurement.";
 case "c2",s="Save C2 as TIFF16. The ICC profile has already been applied once. Print separately without further colour conversion, then measure in the app.";
 case {"measurement","c2measurement","refinemeasurement"},s="When your separately printed sheet is ready, start instrument measurement here. The app uses the saved target TI2 and saves measurement results in the project.";
 case "export",s="Choose separate filenames and save locations for the ICC profile and final report. The project keeps its own copies. The HTML report assets folder is saved alongside the report.";
 case "review",s="Review measurements, unusual rows and repeats. Record your assessment and any accepted remeasurements.";
 case "approve",s="Record the intended use, quality requirements and accepted limitations. This is the user's decision after physical C2/C3 verification, not ISO certification.";
 case "refine",s="Review measurement errors and repeat variation first. Document why additional patches are needed.";
 case "profile",s="Automatic iteration or manual B3. Manual B3 requires B2. A successful job produces a candidate, not an approval of print quality.";
 case "checks",s="Run numerical checks. Review the reports before printing; these checks do not replace C2/C3.";
 case "continue",s="Link refinement to previous inputs and patch roles. The next iteration requires new checks and new physical C2/C3 verification.";
end
end
