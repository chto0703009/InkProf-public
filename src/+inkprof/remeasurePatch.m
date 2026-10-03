% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function fig=remeasurePatch(measurementFile,coordinate,options)
%REMEASUREPATCH Review a stationary i1 Pro 2 M0 reading before replacing a patch.
arguments
 measurementFile (1,1) string
 coordinate (1,1) string
 options.ArgyllBin (1,1) string = ""
 options.PythonExecutable (1,1) string = ""
 options.ParentPreview = []
end
measurementFile=inkprof.internal.absolutePath(measurementFile);
folder="";busy=false;activity="";activityStarted=tic;
session=[];candidate="";closed=false;decided=false;
fig=uifigure('Name','InkProf – Remeasure patch '+coordinate,'WindowStyle','modal','Position',[200 130 830 660],'Tag','InkProfSpotMeasurement');
g=uigridlayout(fig,[6 1]);g.RowHeight={40,85,70,'1x',85,48};
g.Padding=[16 16 16 16];g.RowSpacing=10;
uilabel(g,'Text','Remeasure patch '+upper(coordinate),'FontSize',22,'FontWeight','bold');
uilabel(g,'Text','Close other measurement sessions. Use the same print, backing and i1 Pro 2. Native M0 reflection only. Place the instrument stationary at the centre of the selected patch. Click Measure patch in this window; the instrument button is not needed. Do not swipe.','WordWrap','on');
status=uilabel(g,'Text','Press Start to connect and calibrate.','WordWrap','on','Tag','spotStatus');
log=uitextarea(g,'Editable','off','FontName','Monospaced','Value',{'The original measurement remains unchanged until you accept.'});
review=uitable(g,'Data',cell(0,4),'ColumnName',{'Value (D50 / 2° observer)','Previous measured value','New measured value','Change: new − previous'}, ...
    'ColumnWidth',{180,190,190,'auto'},'RowName',{},'ColumnEditable',false,'Visible','off','Tag','spotReviewValues');
review.Layout.Row=4;review.Layout.Column=1;
comparison=uilabel(g,'Text','','WordWrap','on','Tag','spotComparison','FontSize',14,'FontWeight','bold');
comparison.Layout.Row=5;comparison.Layout.Column=1;
bar=uigridlayout(g,[1 3]);bar.Layout.Row=6;bar.Layout.Column=1;bar.ColumnWidth={'1x','1x','1x'};
% Reserve the entire footer height for buttons, without nested default padding.
bar.Padding=[0 0 0 0];bar.RowHeight={'1x'};bar.ColumnSpacing=12;
action=uibutton(bar,'Text','Start spot measurement','ButtonPushedFcn',@trigger,'Tag','spotAction','Enable','off');
accept=uibutton(bar,'Text','Accept replacement','Enable','off','ButtonPushedFcn',@save,'Tag','spotAccept');
uibutton(bar,'Text','Discard / Close','ButtonPushedFcn',@closeDialog);
try
    preparation=inkprof.internal.calculationProgress("Preparing patch remeasurement", ...
        "Checking the saved measurement and locating patch "+upper(coordinate)+".",Parent=fig);
    folder=inkprof.preparePatchRemeasurement(measurementFile,coordinate);
    clear preparation;
catch err
    clear preparation;delete(fig);rethrow(err);
end
action.Enable='on';
fig.CloseRequestFcn=@closeDialog;fig.UserData=struct('attemptFolder',folder,'measurementFile',measurementFile);
poller=timer('ExecutionMode','fixedSpacing','Period',.15,'BusyMode','drop','TimerFcn',@poll);
fig.DeleteFcn=@cleanup;
    function trigger(~,~)
        if busy||closed||strcmp(action.Enable,'off'),return;end
        busy=true;
        try
            action.Enable='off';
            if isempty(session)
                status.Text='Checking Python and connecting to the instrument…';
                connection=inkprof.internal.calculationProgress("Connecting spectrometer", ...
                    "Checking Python and starting instrument communication. Please wait.",Parent=fig);
                session=inkprof.SpotReadSession(folder,ArgyllBin=options.ArgyllBin,PythonExecutable=options.PythonExecutable);
                clear connection;setActivity("Waiting for the instrument and its calibration instructions.");start(poller);
            else
                session.sendKey(' ');
                if strcmp(action.Text,'Measure patch')
                    setActivity("Measuring patch "+upper(coordinate)+". Keep the instrument still.");
                else
                    setActivity("Calibrating. Keep the instrument on its white reference.");
                end
            end
        catch err,clear connection;fail(err.message);end
        busy=false;
    end
    function setActivity(message)
        activity=message;activityStarted=tic;showActivity();
    end
    function showActivity()
        if strlength(activity)==0||~isgraphics(fig),return;end
        status.Text=activity+newline+sprintf('Working — elapsed %.0f seconds. Please wait.',toc(activityStarted));
        drawnow limitrate nocallbacks;
    end
    function poll(~,~)
        if busy||closed,return;end
        try
            showActivity();
            events=session.poll(0,false);
            for k=1:numel(events)
                e=events{k};
                switch string(e.event)
                    case 'output'
                        lines=[string(log.Value(:));splitlines(string(e.text))];log.Value=cellstr(lines(max(1,end-120):end));
                    case 'state'
                        switch string(e.kind)
                            case {'calibration','calibrationRetry'}
                                activity="";
                                status.Text='Place the instrument on its own white reference, then press Calibrate.';action.Text='Calibrate';action.Enable='on';
                            case {'ready','retry'}
                                activity="";
                                status.Text='Place the instrument still at the centre of patch '+upper(coordinate)+'. Click Measure patch in this window. Do not swipe or press the instrument button.';action.Text='Measure patch';action.Enable='on';
                            otherwise,action.Enable='off';
                        end
                    case 'candidate'
                        candidate=string(e.path);stop(poller);action.Enable='off';activity="";
                        busy=true;
                        calculation=inkprof.internal.calculationProgress("Comparing patch measurements", ...
                            "Calculating Lab and Delta E00, then saving the candidate for your review.",Parent=fig);
                        paths=inkprof.paths();comparisonFile=fullfile(folder,'comparison.json');
                        inkprof.runPython(fullfile(paths.Root,'analysis','spot_compare.py'),[measurementFile,candidate,comparisonFile], ...
                            PythonExecutable=options.PythonExecutable,RequiredModules=["numpy","colour"]);
                        v=jsondecode(fileread(comparisonFile));
                        previous=jsondecode(fileread(measurementFile));spot=jsondecode(fileread(candidate));
                        labels={'L*';'a*';'b*';'X';'Y';'Z'};
                        old=[v.previousLab(:);previous.data.xyz(spot.request.measurementIndex,:)'];
                        new=[v.newLab(:);spot.xyz(:)];
                        review.Data=[labels,num2cell(old),num2cell(new),cellstr(compose('%+.3f',new-old))];
                        log.Visible='off';review.Visible='on';
                        comparison.Text=sprintf('Patch %s — colour difference from previous measurement: %.3f dE00 (ΔE00).\nMeasured L*, a*, b* are colour coordinates, not changes. Change = new − previous.\nΔE00 summarises the colour difference; it is not profile accuracy.',upper(coordinate),v.deltaE00);
                        status.Text='Review the previous and new values below. Accept replaces only this patch; Discard keeps the previous value.';
                        accept.Text=sprintf('Accept %s (dE00 %.3f)',upper(coordinate),v.deltaE00);
                        inkprof.internal.recordProjectStep(folder,'Single-patch candidate awaiting review');
                        clear calculation;accept.Enable='on';
                    case 'error',fail(e.message);
                end
            end
            if ~session.isRunning()&&strlength(candidate)==0
                % Drain buffered output on the following timer tick before declaring failure.
                if isempty(events),fail('Instrument process ended without a candidate. Close and try again.');end
            end
        catch err,clear calculation;fail(err.message);end
        busy=false;
    end
    function fail(message)
        activity="";stop(poller);action.Enable='off';accept.Enable='off';status.Text='Measurement not accepted: '+string(message);
    end
    function save(~,~)
        if busy||closed||decided,return;end
        busy=true;
        try
            accept.Enable='off';
            saving=inkprof.internal.calculationProgress("Saving accepted patch", ...
                "Saving a new measurement revision and checking the updated rows. Please wait.",Parent=fig);
            [r,path]=inkprof.acceptPatchRemeasurement(measurementFile,candidate);
            decided=true;fig.UserData.savedMeasurement=path;
            refresh=inkprof.internal.calculationProgress("Updating measurement overview", ...
                "Preparing the colour patches and the newly saved measurement values.",Parent=fig);
            inkprof.previewMeasurement(fileparts(path),r);
            cleanup([],[]);
            clear refresh saving;
            if ~isempty(options.ParentPreview)&&isgraphics(options.ParentPreview),delete(options.ParentPreview);end
            delete(fig);
        catch err,clear refresh saving;fail(err.message);end
        busy=false;
    end
    function closeDialog(~,~)
        if busy||closed,return;end
        busy=true;
        closing=inkprof.internal.calculationProgress("Closing patch remeasurement", ...
            "Stopping instrument communication and recording the measurement decision.",Parent=fig); %#ok<NASGU>
        if ~decided
            inkprof.internal.writeJson(fullfile(folder,'decision.json'),struct('decision','discarded','parentMeasurementSHA256',inkprof.internal.sha256(measurementFile)));
            decided=true;
        end
        cleanup([],[]);
        clear closing;delete(fig);
    end
    function cleanup(~,~)
        if closed,return;end;closed=true;
        if ~decided
            inkprof.internal.writeJson(fullfile(folder,'decision.json'),struct('decision','discarded','parentMeasurementSHA256',inkprof.internal.sha256(measurementFile)));
            decided=true;
        end
        try,stop(poller);delete(poller);catch,end
        if ~isempty(session),try,session.stop();delete(session);catch,end,end
        inkprof.internal.recordProjectStep(folder,'Closed single-patch measurement attempt');
    end
end
