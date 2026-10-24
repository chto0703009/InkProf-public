% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
classdef MeasurementDialog < handle
    % Modal, event-driven chartread UI. Instrument keys remain manual.
    properties (SetAccess=private)
        Figure
        Result = []
        Folder
        Failure = ""
    end
    properties (Access=private)
        Session
        Starting = false
        PollTimer
        Status
        Hint
        Log
        Buttons
        Buffer = ""
        Transcript = ""
        State
        LoadedPage = 1
        PageProgressOffset = 0
        Calibrating = false
        Saving = false
        Closing = false
        Ended = false
        FollowReread = false
        NavigationOffset = 0
        NextPass = NaN
        ResumeMessage = ""
        PauseRequested = false
        Pausing = false
        Resume = false
        ConfirmedPasses = []
        ChartHash
    end
    methods
        function obj=MeasurementDialog(folder,options)
            arguments
                folder (1,1) string = ""
                options.Source (1,1) string = ""
                options.ShowPreview (1,1) logical = true
                options.RowContext (1,1) struct = struct
                options.ArgyllBin (1,1) string = ""
                options.PythonExecutable (1,1) string = ""
                options.PairedWarningDeltaE (1,1) double {mustBePositive,mustBeFinite} = 1
                options.ScanTolerance (1,1) double {mustBePositive,mustBeFinite} = 1
                options.ScanMode (1,1) string {mustBeMember(options.ScanMode,["","single","alternating","paired"])} = ""
                options.Direction (1,1) string {mustBeMember(options.Direction,["auto","forward","both"])} = "both"
                options.Condition (1,1) string {mustBeMember(options.Condition,["M0","default"])} = "M0"
                options.Port (1,1) double {mustBeInteger,mustBeNonnegative} = 0
            end
            if options.ScanMode==""
                options.ScanMode="alternating";
                if options.Direction=="forward",options.ScanMode="single";end
            end
            obj.Folder=folder;
            if folder~=""
                obj.Folder=inkprof.internal.absolutePath(folder);
                assert(~isfile(fullfile(obj.Folder,'chart.ti3'))||isfile(fullfile(obj.Folder,'measurement-checkpoint.json')), ...
                    'inkprof:Exists','Use a new session; existing results are preserved.');
            end
            obj.State=inkprof.internal.chartPrompt("");
            try
                obj.build();
                obj.Figure.UserData=options;
                if folder~=""&&isfile(fullfile(obj.Folder,'measurement-checkpoint.json'))
                    checkpoint=inkprof.internal.measurementCheckpoint(obj.Folder);
                    settings=jsondecode(fileread(fullfile(obj.Folder,'measurement-settings.json')));
                    obj.Resume=true;options.ScanMode=string(settings.scanMode);options.ScanTolerance=settings.scanTolerance;
                    options.Condition=string(settings.requestedCondition);options.Port=settings.port;
                    obj.Figure.UserData=options;
                    obj.ConfirmedPasses=false(1,checkpoint.totalPasses);obj.ConfirmedPasses(checkpoint.confirmedPasses)=true;
                    obj.Status.Text='Saved partial measurement - ready to resume';
                    chart=jsondecode(fileread(fullfile(obj.Folder,'chart.json')));plan=struct;
                    if options.ScanMode=="paired",plan=jsondecode(fileread(fullfile(obj.Folder,'paired-plan.json')));end
                    obj.ResumeMessage=inkprof.internal.measurementResumeMessage(chart,checkpoint,plan);
                    obj.Hint.Text=obj.ResumeMessage+" New or replaced pages require a new session and fresh RGB checks.";
                    button=findobj(obj.Figure,'Tag','begin');button.Text='Resume measurement';
                end
                target=findobj(obj.Figure,'Tag','targetFile');
                target.Value=options.Source;
                if folder~=""&&isfile(fullfile(obj.Folder,'chart.json'))
                    data=jsondecode(fileread(fullfile(obj.Folder,'chart.json')));
                    target.Value=string(data.sourcePath);target.Editable='off';
                    set(findobj(obj.Figure,'Tag','browse'),'Enable','off');
                    set(findobj(obj.Figure,'Tag','browse'),'Text','Target locked','Tooltip', ...
                        'This measurement uses its prepared target. Close and choose the matching print in the workflow to change it.');
                    if ~obj.Resume
                        obj.Status.Text='Review the selected print before measuring';
                        obj.Hint.Text='Check the target type, saved time and page count above. Use Target details for the full path and page preview. For another print, close and select its matching target in the workflow first.';
                    end
                end
                obj.updateTargetInfo();
                set(findobj(obj.Figure,'Tag','direction'),'Value',options.ScanMode);
                set(findobj(obj.Figure,'Tag','tolerance'),'Value',options.ScanTolerance);
                set(findobj(obj.Figure,'Tag','port'),'Value',options.Port);
                set(findobj(obj.Figure,'Tag','condition'),'Value',options.Condition);
                if obj.Resume
                    for tag=["direction","tolerance","port","condition"],set(findobj(obj.Figure,'Tag',tag),'Enable','off');end
                end
                if ~isempty(fieldnames(options.RowContext))
                    for tag=["direction","tolerance","port","condition"],set(findobj(obj.Figure,'Tag',tag),'Enable','off');end
                    obj.Status.Text=sprintf('Remeasure page %d · Row %s',options.RowContext.page,options.RowContext.row);
                    obj.Hint.Text='Place the SAME printed page in the guide. Only the selected row will be read, using the original scan settings.';
                end
            catch err
                delete(obj);rethrow(err);
            end
        end
        function delete(obj)
            obj.Closing=true;
            if ~isempty(obj.PollTimer)&&isvalid(obj.PollTimer)
                stop(obj.PollTimer);delete(obj.PollTimer);
            end
            if ~isempty(obj.Session)&&isvalid(obj.Session),delete(obj.Session);end
            if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end
        end
    end
    methods (Access=private)
        function build(obj)
            obj.Figure=uifigure('Name','InkProf – Measure chart','Position',[160 40 930 880], ...
                'WindowStyle','modal','Color',[.96 .97 .98],'CloseRequestFcn',@(~,~)obj.close());
            grid=uigridlayout(obj.Figure,[12 1]);
            grid.RowHeight={35,32,85,62,48,34,36,58,85,22,'1x',24};grid.Padding=[22 18 22 18];grid.RowSpacing=10;
            uilabel(grid,'Text','InkProf  |  Strip measurement','FontSize',23,'FontWeight','bold','FontColor',[.1 .22 .3]);
            files=uigridlayout(grid,[1 3]);files.ColumnWidth={70,'1x',125};files.Padding=[0 0 0 0];
            uilabel(files,'Text','Chart (TI2)');
            uieditfield(files,'text','Tag','targetFile','Placeholder','Select the TI2 file for the printed chart', ...
                'ValueChangedFcn',@(~,~)obj.updateTargetInfo());
            uibutton(files,'Text','Choose chart…','Tag','browse','ButtonPushedFcn',@(~,~)obj.browse());
            identity=uigridlayout(grid,[1 2]);identity.ColumnWidth={'1x',125};identity.Padding=[0 0 0 0];
            uitextarea(identity,'Editable','off','Tag','targetSummary','Value',{'No target selected.'});
            uibutton(identity,'Text','Target details…','Tag','targetDetails','ButtonPushedFcn',@(~,~)obj.targetDetails());
            settings=uigridlayout(grid,[2 3]);settings.RowHeight={22,30};settings.ColumnWidth={'2x','1x','1x'};settings.Padding=[0 0 0 0];
            uilabel(settings,'Text','Scan mode');uilabel(settings,'Text','Scan tolerance');uilabel(settings,'Text','Instrument port (0 = default)');
            uidropdown(settings,'Tag','direction','Items',{'1. Single direction','2. Alternate rows','3. Forward + reverse average'}, ...
                'ItemsData',{'single','alternating','paired'},'Value','alternating');
            uieditfield(settings,'numeric','Tag','tolerance','Limits',[0 Inf],'LowerLimitInclusive','off','Value',1);
            uieditfield(settings,'numeric','Tag','port','Limits',[0 Inf],'RoundFractionalValues','on','Value',0);
            conditionBar=uigridlayout(grid,[1 3]);conditionBar.ColumnWidth={90,270,'1x'};conditionBar.Padding=[0 0 0 0];
            uilabel(conditionBar,'Text','Measurement condition','WordWrap','on');
            uidropdown(conditionBar,'Tag','condition','Items',{'M0 – i1Pro 2 without UV filter','Instrument default – unspecified'}, ...
                'ItemsData',{'M0','default'},'Value','M0');
            uilabel(conditionBar,'Text','M1/M2 are not directly available for i1Pro 2 in Argyll. FWA processing is a separate step.','WordWrap','on','FontSize',11);
            actions=uigridlayout(grid,[1 4]);actions.ColumnWidth={'1x','1x','1x','1x'};actions.Padding=[0 0 0 0];
            uibutton(actions,'Text','Start measurement','Tag','begin','BackgroundColor',[.12 .35 .48], ...
                'FontColor',[1 1 1],'ButtonPushedFcn',@(~,~)obj.begin());
            uibutton(actions,'Text','Resume saved session…','Tag','resumeSession','ButtonPushedFcn',@(~,~)obj.openCheckpoint());
            uibutton(actions,'Text','Open results folder','Tag','openFolder','Enable','off','ButtonPushedFcn',@(~,~)obj.openFolder());
            uibutton(actions,'Text','Close / cancel','ButtonPushedFcn',@(~,~)obj.close());
            obj.Status=uilabel(grid,'Text','Select chart and measurement settings' ,'FontSize',19,'FontWeight','bold');
            obj.Hint=uilabel(grid,'Text','Select the TI2 file for your print. Choose one scan per row, alternate rows, or two scans of each row with averaging. Then start the measurement.','WordWrap','on','FontSize',14);
            controls=uigridlayout(grid,[3 3]);controls.RowHeight={'1x','1x','1x'};controls.Padding=[0 0 0 0];
            labels=["Calibrate","Page loaded","Reread / retry","Accept reading", ...
                "Previous row","Next row","Next unread","Save and finish","Save completed rows / pause"];
            names=["calibrate","pageLoaded","retry","accept","back","forward","unread","save","pause"];
            obj.Buttons=struct;
            for k=1:numel(names)
                action=names(k);
                obj.Buttons.(action)=uibutton(controls,'Text',labels(k),'Tag',action, ...
                    'Enable','off','ButtonPushedFcn',@(~,~)obj.act(action));
            end
            obj.Buttons.pageLoaded.Visible='off';
            uilabel(grid,'Text','Instrument messages – updated automatically','FontWeight','bold');
            obj.Log=uitextarea(grid,'Editable','off','Tag','measurementLog','FontName','Monospaced','FontSize',11,'Value',{'The instrument starts only when you select Start measurement.'});
            uilabel(grid,'Text','A new measurement folder is created when you start.','Tag','folderLabel','FontSize',10,'FontColor',[.4 .4 .4]);
        end
        function browse(obj)
            paths=inkprof.paths();
            [name,folder]=inkprof.internal.withFocus(obj.Figure,@uigetfile,{'*.ti2','Argyll chart definition (*.ti2)'},'Choose chart file',char(paths.Projects));
            if isequal(name,0),return;end
            set(findobj(obj.Figure,'Tag','targetFile'),'Value',fullfile(folder,name));
            obj.updateTargetInfo();
        end
        function updateTargetInfo(obj)
            target=findobj(obj.Figure,'Tag','targetFile');target.Tooltip=target.Value;
            locked=string(target.Editable)=="off";
            try,lines=inkprof.internal.measurementTargetInfo(string(target.Value),locked);
            catch err,lines=["TI2: "+string(target.Value);"Target details could not be read: "+string(err.message)];end
            % Put identifying facts before the long path in the compact view.
            lines=lines(:);if numel(lines)>1,lines=[lines(2:end);lines(1)];end
            set(findobj(obj.Figure,'Tag','targetSummary'),'Value',cellstr(lines));
        end
        function targetDetails(obj)
            obj.updateTargetInfo();source=string(findobj(obj.Figure,'Tag','targetFile').Value);
            f=uifigure('Name','InkProf - Selected measurement target','Position',[200 120 800 520], ...
                'WindowStyle','modal','Tag','InkProfMeasurementTargetDetails');
            g=uigridlayout(f,[3 1]);g.RowHeight={30,'1x',35};
            uilabel(g,'Text','Match this target to the footer on your printed sheet','FontWeight','bold');
            uitextarea(g,'Editable','off','Value',findobj(obj.Figure,'Tag','targetSummary').Value);
            buttons=uigridlayout(g,[1 2]);buttons.Padding=[0 0 0 0];
            uibutton(buttons,'Text','Preview printed pages…','ButtonPushedFcn',@(~,~)preview());
            uibutton(buttons,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
            function preview()
                try
                    p=inkprof.showPrintResult(fileparts(source));p.WindowStyle='modal';
                catch err,uialert(f,err.message,'Target preview');end
            end
        end
        function openCheckpoint(obj)
            if obj.Starting||~isempty(obj.Session)||obj.Closing,return;end
            previous=uigetdir(char(fileparts(obj.Folder)),'Select a saved partial measurement session');
            if isequal(previous,0),return;end
            try
                checkpoint=inkprof.internal.measurementCheckpoint(string(previous)); %#ok<NASGU>
                chart=jsondecode(fileread(fullfile(previous,'chart.json')));
                source=string(findobj(obj.Figure,'Tag','targetFile').Value);
                if source~=""&&isfile(source)
                    assert(inkprof.internal.sha256(source)==string(chart.sourceSHA256),'inkprof:Identity','Checkpoint belongs to another target.');
                end
                options=obj.Figure.UserData;
                next=inkprof.MeasurementDialog(string(previous),ArgyllBin=options.ArgyllBin, ...
                    PythonExecutable=options.PythonExecutable,ShowPreview=options.ShowPreview);
                waitfor(next.Figure);obj.Result=next.Result;obj.Failure=next.Failure;obj.Folder=next.Folder;
                if ~isempty(obj.Result),obj.Ended=true;obj.disable();obj.Status.Text='Resumed measurement saved';end
                if isempty(obj.Result)&&isfile(fullfile(obj.Folder,'measurement-checkpoint.json'))
                    obj.Ended=true;obj.disable();obj.Status.Text='Partial measurement saved';
                end
            catch err,uialert(obj.Figure,err.message,'Resume measurement');end
        end
        function progress=progress(obj)
            data=obj.Figure.UserData;total=sum(data.physicalChart.passesInStrips);
            if isfield(data,'pairedPlan'),total=numel(data.pairedPlan.passes);end
            progress=inkprof.internal.measurementProgress(obj.Transcript,total);
            if numel(obj.ConfirmedPasses)==total,progress.confirmed=progress.confirmed|obj.ConfirmedPasses;end
            progress.count=sum(progress.confirmed);progress.missing=find(~progress.confirmed);
        end
        function begin(obj)
            if obj.Starting||~isempty(obj.Session)||obj.Ended||obj.Closing,return;end
            % Runtime checks yield to MATLAB callbacks. Guard before any yield
            % so queued clicks cannot launch a second bridge for this folder.
            obj.Starting=true;
            startCleanup=onCleanup(@()obj.finishStarting()); %#ok<NASGU>
            set(findobj(obj.Figure,'Tag','begin'),'Enable','off');
            try
                obj.Status.Text='Preparing measurement…';
                obj.Hint.Text='Checking chart coordinates and scan mode. Please wait.';drawnow limitrate nocallbacks;
                options=obj.Figure.UserData;
                if obj.Resume
                    choice=uiconfirm(obj.Figure, ...
                        obj.ResumeMessage+newline+newline+'Resume only on the SAME physical printed sheets used for the saved measurement. If you printed the target again or replaced any page, cancel and start a new measurement session with new RGB checks. The target checksum identifies the chart data, not the physical sheets.', ...
                        'Confirm same printed sheets','Options',{'Resume same printed sheets','Cancel'}, ...
                        'DefaultOption',2,'CancelOption',2);
                    if ~strcmp(choice,'Resume same printed sheets')
                        error('inkprof:Cancelled','Resume cancelled. For new or replaced sheets, start a new measurement session and measure RGB controls again.');
                    end
                end
                tolerance=findobj(obj.Figure,'Tag','tolerance').Value;
                port=findobj(obj.Figure,'Tag','port').Value;
                scanMode=string(findobj(obj.Figure,'Tag','direction').Value);
                direction="both";if scanMode~="alternating",direction="forward";end
                validateattributes(tolerance,{'double'},{'scalar','finite','positive'});
                validateattributes(port,{'double'},{'scalar','finite','integer','nonnegative'});
                if obj.Folder==""
                    paths=inkprof.paths();
                    source=string(findobj(obj.Figure,'Tag','targetFile').Value);
                    projectRoot=inkprof.internal.findProject(source);
                    base=paths.Projects;if projectRoot~="",base=fullfile(projectRoot,'measurements');end
                    obj.Folder=fullfile(base,"matning-dialog-"+string(datetime('now','Format','yyyyMMdd-HHmmss-SSS')));
                end
                if ~isfile(fullfile(obj.Folder,'chart.json'))
                    source=string(findobj(obj.Figure,'Tag','targetFile').Value);
                    inkprof.prepareChart(source,obj.Folder);
                end
                obj.ChartHash=inkprof.internal.sha256(fullfile(obj.Folder,'chart.json'));
                for tag=["targetFile","browse","direction","tolerance","port","condition","begin","resumeSession"]
                    set(findobj(obj.Figure,'Tag',tag),'Enable','off');
                end
                settings=struct('schemaVersion',1,'documentType',"inkprof.measurement-settings", ...
                    'chartJSONSHA256',obj.ChartHash,'requestedCondition',string(findobj(obj.Figure,'Tag','condition').Value), ...
                    'conditionMethod',"instrument native mode; no -F override; no FWA computation", ...
                    'scanMode',scanMode,'direction',direction,'scanTolerance',tolerance,'port',port);
                if ~obj.Resume,inkprof.internal.writeJson(fullfile(obj.Folder,'measurement-settings.json'),settings);end
                runtimeFolder=obj.Folder;
                data=obj.Figure.UserData;data.scanMode=scanMode;
                if scanMode=="paired"
                    if isfile(fullfile(obj.Folder,'paired-plan.json'))
                        data.pairedPlan=jsondecode(fileread(fullfile(obj.Folder,'paired-plan.json')));
                    else,data.pairedPlan=inkprof.internal.preparePairedChart(obj.Folder);end
                    runtimeFolder=fullfile(obj.Folder,'paired');
                    settings.chartJSONSHA256=inkprof.internal.sha256(fullfile(runtimeFolder,'chart.json'));
                    inkprof.internal.writeJson(fullfile(runtimeFolder,'measurement-settings.json'),settings);
                end
                data.runtimeFolder=runtimeFolder;
                data.physicalChart=jsondecode(fileread(fullfile(obj.Folder,'chart.json')));
                obj.Figure.UserData=data;
                if isfield(data.physicalChart,'printControls')&&~obj.Resume
                    obj.Status.Text='Checking separate RGB print controls before chart measurement…';
                    obj.Figure.WindowStyle='normal';
                    reused=false;
                    choice=uiconfirm(obj.Figure, ...
                        'For a new print, measure RGB controls on every page. For the SAME previously checked physical print, you may reuse its approved RGB checks. Do not reuse after changing print settings or replacing pages.', ...
                        'RGB print controls','Options',{'Measure RGB controls','Reuse checks for same print','Cancel'},'CancelOption',3);
                    if strcmp(choice,'Cancel'),error('inkprof:Cancelled','Measurement start cancelled.');end
                    if strcmp(choice,'Reuse checks for same print')
                        previous=uigetdir(char(fileparts(obj.Folder)),'Select the previous measurement session folder');
                        if isequal(previous,0),error('inkprof:Cancelled','No previous RGB check selected.');end
                        inkprof.internal.reusePrintControls(string(previous),obj.Folder);reused=true;
                    end
                    if ~reused
                        inkprof.measurePrintControls(obj.Folder,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable,Port=port);
                    end
                    obj.Figure.WindowStyle='modal';
                    inkprof.internal.requirePrintControls(obj.Folder);
                end
                if obj.Resume
                    checkpoint=inkprof.internal.measurementCheckpoint(obj.Folder);
                    inkprof.internal.requirePrintControls(obj.Folder);
                    raw=fullfile(runtimeFolder,'chart.ti3');
                    if isfile(raw)
                        copyfile(raw,fullfile(runtimeFolder,"before-checkpoint-restore-"+string(java.util.UUID.randomUUID())+".ti3"));
                    end
                    copyfile(fullfile(runtimeFolder,string(checkpoint.snapshot)),raw);
                end
                inkprof.internal.recordProjectStep(obj.Folder,"measurement-settings-saved");
                obj.Session=inkprof.ChartReadSession(runtimeFolder,ArgyllBin=options.ArgyllBin, ...
                    PythonExecutable=options.PythonExecutable,ScanTolerance=tolerance, ...
                    Direction=direction,Port=port,Resume=obj.Resume);
                set(findobj(obj.Figure,'Tag','openFolder'),'Enable','on');
                label=findobj(obj.Figure,'Tag','folderLabel');label.Text=obj.Folder;label.Tooltip=obj.Folder;
                obj.Status.Text='Starting instrument…';obj.Hint.Text='Wait for the calibration prompt.';
                if obj.Resume,obj.Hint.Text=obj.ResumeMessage;end
                obj.PollTimer=timer('ExecutionMode','fixedSpacing','Period',0.2,'BusyMode','drop', ...
                    'TimerFcn',@(~,~)obj.tick(),'ErrorFcn',@(~,~)obj.fail("Automatic updates stopped."));
                start(obj.PollTimer);
            catch err
                obj.Figure.WindowStyle='modal';
                if isempty(obj.Session)
                    obj.Status.Text='Check chart and settings';obj.Hint.Text=string(err.message);
                    for tag=["targetFile","browse","direction","tolerance","port","condition","begin","resumeSession"]
                        set(findobj(obj.Figure,'Tag',tag),'Enable','on');
                    end
                    if obj.Resume||~isempty(fieldnames(options.RowContext))
                        for tag=["direction","tolerance","port","condition"],set(findobj(obj.Figure,'Tag',tag),'Enable','off');end
                    end
                    if isfile(fullfile(obj.Folder,'chart.json'))
                        set(findobj(obj.Figure,'Tag','targetFile'),'Enable','off');
                        set(findobj(obj.Figure,'Tag','browse'),'Enable','off');
                    end
                else,obj.fail(string(err.message));end
                obj.Log.Value=cellstr(splitlines("Measurement could not start: "+string(err.message)));
                fprintf(2,'InkProf: measurement could not start: %s\n',err.message);
                uialert(obj.Figure,string(err.message),'Measurement could not start');
            end
        end
        function finishStarting(obj)
            if isvalid(obj),obj.Starting=false;end
        end
        function openFolder(obj)
            if ~isfolder(obj.Folder),return;end
            if ismac
                inkprof.internal.runTool('/usr/bin/open',string(obj.Folder),obj.Folder,15);
            elseif isunix
                inkprof.internal.runTool('xdg-open',string(obj.Folder),obj.Folder,15);
            else,winopen(char(obj.Folder));end
        end
        function tick(obj)
            if obj.Closing||obj.Ended||isempty(obj.Session),return;end
            try
                events=obj.Session.poll(0,false);
                for k=1:numel(events)
                    event=events{k};
                    if isfield(event,'text')
                        obj.Buffer=obj.Buffer+string(event.text);
                        obj.Transcript=obj.Transcript+string(event.text);
                        data=obj.Figure.UserData;
                        plan=struct;if isfield(data,'pairedPlan'),plan=data.pairedPlan;end
                        lines=splitlines(inkprof.internal.measurementLog(obj.Transcript,data.physicalChart,plan));
                        obj.Log.Value=cellstr(lines(max(1,end-180):end));
                        scroll(obj.Log,'bottom');
                    end
                    if isfield(event,'event')&&string(event.event)=="error"
                        obj.fail(string(event.message));return;
                    end
                    if isfield(event,'event')&&string(event.event)=="exited"
                        obj.finish(event);return;
                    end
                end
                data=obj.Figure.UserData;
                plan=struct;if isfield(data,'pairedPlan'),plan=data.pairedPlan;end
                [scannedPage,obj.PageProgressOffset]=inkprof.internal.completedScanPage( ...
                    obj.Transcript,obj.PageProgressOffset,data.physicalChart,plan);
                if ~isempty(scannedPage),obj.LoadedPage=scannedPage;end
                if obj.PauseRequested
                    obj.State=inkprof.internal.chartPrompt(obj.Buffer);
                    if obj.State.kind=="row",obj.savePause();else,obj.render();end
                    return;
                end
                [scanned,obj.NavigationOffset]=inkprof.internal.lastConfirmedPass(obj.Transcript,obj.NavigationOffset);
                if isfinite(scanned)&&obj.FollowReread
                    total=sum(data.physicalChart.passesInStrips);
                    if ~isempty(fieldnames(plan)),total=numel(plan.passes);end
                    obj.FollowReread=false;
                    if scanned<total,obj.NextPass=scanned+1;end
                end
                obj.State=inkprof.internal.chartPrompt(obj.Buffer);
                if isfinite(obj.NextPass)&&obj.State.kind=="row"
                    if obj.State.row==obj.NextPass
                        obj.NextPass=NaN;
                    else
                        key='f';if obj.State.row>obj.NextPass,key='b';end
                        obj.Session.sendKey(key);obj.Buffer="";
                        obj.State=inkprof.internal.chartPrompt("");
                    end
                end
                if obj.Resume&&obj.State.kind=="row"
                    progress=obj.progress();
                    if ~isempty(progress.missing)
                        obj.NextPass=progress.missing(1);obj.Resume=false;
                        if obj.State.row~=obj.NextPass
                            key='f';if obj.State.row>obj.NextPass,key='b';end
                            obj.Session.sendKey(key);obj.Buffer="";obj.State=inkprof.internal.chartPrompt("");
                        else,obj.NextPass=NaN;end
                    else,obj.Resume=false;end
                end
                obj.render();
                if ~obj.Session.isRunning()
                    % Drain any final JSON-lines on the next timer callback.
                    if isempty(events),obj.fail("The measurement process ended without a final message. See the log.");end
                end
            catch err
                obj.fail(string(err.message));
            end
        end
        function savePause(obj)
            obj.PauseRequested=false;obj.Pausing=true;obj.Saving=true;
            obj.Session.sendKey('d');obj.Buffer="";obj.State=inkprof.internal.chartPrompt("");obj.render();
        end
        function disable(obj)
            names=fieldnames(obj.Buttons);
            for k=1:numel(names),obj.Buttons.(names{k}).Enable='off';end
        end
        function render(obj)
            obj.disable();
            obj.Buttons.calibrate.Text='Calibrate';
            obj.Buttons.pageLoaded.Visible='off';
            data=obj.Figure.UserData;
            if ~isempty(obj.Session)&&~obj.Saving&&~obj.PauseRequested&&isfield(data,'physicalChart')
                progress=obj.progress();keep=inkprof.internal.completedMeasurementRows(progress.confirmed,data.scanMode=="paired");
                if any(keep),obj.Buttons.pause.Enable='on';end
            end
            if isfield(data,'scanMode')&&data.scanMode=="paired"
                obj.Buttons.back.Text='Previous scan';obj.Buttons.forward.Text='Next scan';
                obj.Buttons.unread.Text='Next unread scan';
            end
            if obj.State.kind~="busy",obj.Calibrating=false;end
            switch obj.State.kind
                case "calibration"
                    obj.Status.Text='Calibrate the instrument';
                    obj.Hint.Text='Place the instrument on its white reference. Select Calibrate and wait for the next instruction.';
                    obj.Buttons.calibrate.Enable='on';
                case "calibrationRetry"
                    obj.Status.Text='Calibration failed';
                    obj.Hint.Text='Place the instrument firmly on its own reflective white reference. Select Retry calibration. You can repeat this if calibration fails again; no restart is needed.';
                    obj.Buttons.calibrate.Text='Retry calibration';
                    obj.Buttons.calibrate.Enable='on';
                case "row"
                    data=obj.Figure.UserData;
                    plan=struct;if isfield(data,'pairedPlan'),plan=data.pairedPlan;end
                    pageInfo=inkprof.internal.measurementPage(data.physicalChart,obj.State.row,plan);
                    directionLabel="FORWARD";phaseLabel="";
                    if isfield(data,'scanMode')&&data.scanMode=="paired"
                        pass=data.pairedPlan.passes(obj.State.row);
                        directionLabel=upper(string(pass.expectedDirection));phaseLabel=string(sprintf(' (%d/2)',pass.phase));
                        obj.Status.Text=sprintf('Page %d · Row %s · %s scan%s',pass.page,string(pass.physicalRow),directionLabel,phaseLabel);
                    elseif isfield(data,'scanMode')
                        directionLabel="FORWARD";
                        if data.scanMode=="alternating"&&mod(obj.State.row,2)==0,directionLabel="REVERSE";end
                        obj.Status.Text=sprintf('Page %d/%d · Row %s · %s scan',pageInfo.page,pageInfo.totalPages,pageInfo.row,directionLabel);
                    else,obj.Status.Text=sprintf('Ready for row %d',obj.State.row);end
                    if ~isempty(fieldnames(data.RowContext))
                        context=data.RowContext;
                        if data.scanMode=="alternating",directionLabel=upper(string(context.expectedDirection));end
                        obj.Status.Text=sprintf('Page %d/%d · Row %s · %s scan%s',context.page,context.totalPages,context.row,directionLabel,phaseLabel);
                    end
                    obj.Hint.Text='FORWARD = left to right; REVERSE = right to left on the printed chart. Follow the displayed direction after Previous/Next too; rereading replaces the selected pass.';
                    if isfield(data,'scanMode')&&data.scanMode=="alternating"
                        obj.Hint.Text=obj.Hint.Text+" Automatic direction detection can be ambiguous on non-randomized charts. Use Single direction if uncertain.";
                    end
                    if isfield(data,'scanMode')&&data.scanMode=="paired"
                        obj.Hint.Text='Scan the SAME physical row twice: forward, then reverse. Move to the next printed row only when its number appears. Both readings will be saved and averaged.';
                    end
                    obj.Hint.Text="Press and hold the button on the i1 Pro 2 to scan; start and finish on white paper. "+string(obj.Hint.Text);
                    if ~isempty(fieldnames(data.RowContext))
                        obj.Hint.Text=sprintf('Use printed page %d, row %s. ',data.RowContext.page,data.RowContext.row)+string(obj.Hint.Text);
                    end
                    totalPasses=sum(data.physicalChart.passesInStrips);
                    if ~isempty(fieldnames(plan)),totalPasses=numel(plan.passes);end
                    progress=obj.progress();
                    if ~obj.State.allRead
                        obj.Hint.Text=string(obj.Hint.Text)+sprintf(' Instrument-confirmed scans: %d/%d. ',progress.count,progress.total);
                        if ~progress.confirmed(obj.State.row)
                            obj.Hint.Text=string(obj.Hint.Text)+"The indicated scan is still unread. Wait for 'Strip read OK'; Next unread changes the selection and does not accept a scan.";
                        end
                    end
                    if obj.State.allRead
                        obj.Status.Text=obj.Status.Text+" · ALL ROWS READ";
                        obj.Hint.Text='Select Save and finish. You can also return to a row and reread it before saving.';
                    end
                    for name=["back","forward","unread"],obj.Buttons.(name).Enable='on';end
                    if obj.State.allRead,obj.Buttons.save.Enable='on';end
                    wholeRows=any(inkprof.internal.completedMeasurementRows(progress.confirmed,data.scanMode=="paired"));
                    if wholeRows,obj.Buttons.pause.Enable='on';end
                    if ~obj.State.allRead && pageInfo.page~=obj.LoadedPage
                        obj.disable();
                        if wholeRows,obj.Buttons.pause.Enable='on';end
                        obj.Status.Text=sprintf('Change to page %d of %d · Row %s · %s scan%s',pageInfo.page,pageInfo.totalPages,pageInfo.row,directionLabel,phaseLabel);
                        obj.Hint.Text=sprintf('Place printed page %d in the guide. The next printed row is %s (row %d on this page). Select Page loaded, or scan the indicated row using the i1 Pro 2 button after changing the sheet. A successful scan also confirms the page change.',pageInfo.page,pageInfo.row,pageInfo.rowOnPage);
                        obj.Buttons.pageLoaded.Visible='on';obj.Buttons.pageLoaded.Enable='on';
                    end
                case "retry"
                    obj.Status.Text='Scan could not be read';
                    obj.Hint.Text='See the error in the log. Select Reread / retry and wait for the row prompt before scanning again.';
                    obj.Buttons.retry.Enable='on';
                case "unexpected"
                    obj.Status.Text='Unexpected colour response';
                    obj.Hint.Text='Check that you scanned the correct row. Rereading is recommended. Accept only if you intend to keep the unexpected reading.';
                    obj.Buttons.retry.Enable='on';obj.Buttons.accept.Enable='on';
                otherwise
                    if obj.Calibrating
                        obj.Status.Text='Calibrating instrument…';
                        obj.Hint.Text='Keep the instrument on its white reference. Wait for calibration to finish; do not click again.';
                        return;
                    end
                    if obj.Saving,obj.Status.Text='Saving measurement…';else,obj.Status.Text='Instrument is working…';end
                    obj.Hint.Text='Wait for the next instruction. No additional keypress is needed.';
            end
            if obj.Resume&&any(obj.State.kind==["calibration","calibrationRetry"])
                obj.Hint.Text=string(obj.Hint.Text)+" "+obj.ResumeMessage;
            end
        end
        function act(obj,action)
            % Refresh immediately before sending: do not act on stale prompts.
            obj.tick();if obj.Ended||obj.Closing,return;end
            if ~strcmp(obj.Buttons.(action).Enable,'on'),return;end
            if action=="pause"
                progress=obj.progress();data=obj.Figure.UserData;
                keep=inkprof.internal.completedMeasurementRows(progress.confirmed,data.scanMode=="paired");
                % If a reread is in flight, discard that physical row too.
                if obj.State.kind~="row"
                    tokens=regexp(char(obj.Transcript),'Ready to read strip pass\s+(\d+)','tokens');
                    if ~isempty(tokens)
                        pass=str2double(tokens{end}{1});
                        if data.scanMode=="paired",pass=2*ceil(pass/2)-1;keep(pass:pass+1)=false;
                        else,keep(pass)=false;end
                    end
                end
                if ~any(keep),obj.Hint.Text='No earlier complete rows to save yet.';return;end
                obj.ConfirmedPasses=keep;obj.PauseRequested=true;
                if obj.State.kind=="row",obj.savePause();else
                    obj.render();obj.Hint.Text='Save requested. Waiting for the instrument row prompt; the current row will not be included.';
                end
                return;
            end
            if action=="pageLoaded" && obj.State.kind=="row"
                data=obj.Figure.UserData;plan=struct;
                if isfield(data,'pairedPlan'),plan=data.pairedPlan;end
                pageInfo=inkprof.internal.measurementPage(data.physicalChart,obj.State.row,plan);
                if pageInfo.page~=obj.LoadedPage
                    obj.LoadedPage=pageInfo.page;obj.render();
                end
                return; % Page confirmation must never trigger a reading.
            end
            if action=="accept"
                choice=uiconfirm(obj.Figure,'Keep the reading despite the instrument warning?', ...
                    'Accept unexpected reading','Options',{'Reread','Accept'},'DefaultOption',1,'CancelOption',1);
                if strcmp(choice,'Reread'),action="retry";end
                expected="unexpected";obj.tick();
                if obj.Ended||obj.State.kind~=expected,return;end
            end
            if any(action==["back","forward","unread"])
                obj.NextPass=NaN;obj.FollowReread=any(action==["back","forward"]);
            end
            switch action
                case {"calibrate","retry"},key=' ';
                case "accept",key=char(13);
                case "back",key='b';
                case "forward",key='f';
                case "unread",key='n';
                case "save",key='d';obj.Saving=true;
            end
            try
                obj.Session.sendKey(key);obj.Calibrating=(action=="calibrate");obj.Buffer="";obj.State=inkprof.internal.chartPrompt("");obj.render();

            catch err,obj.fail(string(err.message));end
        end
        function finish(obj,event)
            obj.Ended=true;obj.disable();stop(obj.PollTimer);
            if event.exitCode~=0||~event.ti3Exists||~obj.Saving
                obj.Status.Text='Measurement ended without automatic import';
                obj.Hint.Text='No successful save was recorded. Previous measurements are unchanged. See the log.';return;
            end
            if obj.Pausing
                try
                    checkpoint=inkprof.internal.measurementCheckpoint(obj.Folder,obj.ConfirmedPasses);
                    obj.Status.Text='Completed rows saved - measurement paused';
                    obj.Hint.Text="Resume this session later using Resume saved session. Folder: "+obj.Folder;
                    obj.Result=[]; % A checkpoint never completes a workflow measurement step.
                    obj.Figure.WindowStyle='normal';
                    set(findobj(obj.Figure,'Tag','openFolder'),'Enable','on');
                    inkprof.internal.recordProjectStep(obj.Folder,"measurement-checkpoint-saved");
                catch err,obj.fail("Could not save checkpoint: "+string(err.message));end
                return;
            end
            try
                obj.Status.Text='Saving and checking measurement…';
                calculation=inkprof.internal.calculationProgress("Saving measurement","Importing readings, checking row identities and averaging paired scans.",Parent=obj.Figure);
                assert(inkprof.internal.sha256(fullfile(obj.Folder,'chart.json'))==obj.ChartHash, ...
                    'inkprof:Integrity','The chart definition changed during measurement.');
                data=obj.Figure.UserData;
                if isfield(data,'scanMode')&&data.scanMode=="paired"
                    raw=inkprof.importChartMeasurement(data.runtimeFolder);
                    obj.Result=inkprof.internal.averagePairedMeasurement(obj.Folder,raw,data.PairedWarningDeltaE);
                else,obj.Result=inkprof.importChartMeasurement(obj.Folder);end
                checkpointFile=fullfile(obj.Folder,'measurement-checkpoint.json');
                if obj.Result.complete&&isfile(checkpointFile)
                    movefile(checkpointFile,fullfile(obj.Folder,"completed-checkpoint-"+string(java.util.UUID.randomUUID())+".json"));
                end
                if obj.Result.complete,obj.Status.Text='Saved – all source patches imported';
                else,obj.Status.Text='Saved – incomplete measurement';end
                obj.Hint.Text='Results are saved in the project folder and available in dialog.Result. Complete means all patches are present, not that colour accuracy is verified. You can close this window.';
                clear calculation;
            catch err,clear calculation;obj.fail("Could not import the saved file: "+string(err.message));return;end
            % Visualization failure must never reclassify a successfully saved measurement.
            try
                obj.Figure.WindowStyle='normal';
                if data.ShowPreview,inkprof.previewMeasurement(obj.Folder,obj.Result);end
            catch err
                obj.Hint.Text="The measurement is saved, but the result chart could not be displayed: "+string(err.message);
            end
        end
        function fail(obj,message)
            obj.Ended=true;obj.disable();
            if ~isempty(obj.PollTimer)&&isvalid(obj.PollTimer),stop(obj.PollTimer);end
            if ~isempty(obj.Session)&&isvalid(obj.Session),delete(obj.Session);end
            obj.Status.Text='Measurement needs attention';obj.Hint.Text=message;
        end
        function close(obj)
            if ~obj.Ended&&~isempty(obj.Session)
                choice=uiconfirm(obj.Figure,'Cancel measurement? Unsaved readings may be lost.', ...
                    'Close measurement','Options',{'Continue measuring','Cancel measurement'},'DefaultOption',1,'CancelOption',1);
                if ~strcmp(choice,'Cancel measurement'),return;end
            end
            % Keep Result accessible in the controller after closing its window.
            obj.Closing=true;
            if ~isempty(obj.PollTimer)&&isvalid(obj.PollTimer),stop(obj.PollTimer);delete(obj.PollTimer);end
            if ~isempty(obj.Session)&&isvalid(obj.Session),delete(obj.Session);end
            delete(obj.Figure);
        end
    end
end
