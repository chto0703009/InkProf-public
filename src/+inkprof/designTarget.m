function fig=designTarget(options)
arguments
    options.OutputFile (1,1) string = ""
end
%DESIGNTARGET Interactive RGB grid refinement / Argyll target generation.
fig=uifigure('Name','InkProf – Design RGB target','Position',[80 60 1190 820], ...
    'Tag','InkProfTargetDesigner');
fig.UserData=struct('design',[],'saved',[],'busy',false,'cancelled',false,'closePending',false);
fig.CloseRequestFcn=@closeWindow;
root=uigridlayout(fig,[7 1]);root.RowHeight={32,136,36,'1x',85,68,35};root.Padding=[16 12 16 12];
uilabel(root,'Text','InkProf | RGB target design','FontSize',22,'FontWeight','bold');
settings=uigridlayout(root,[4 6]);settings.RowHeight={22,30,22,30};settings.Padding=[0 0 0 0];
labels=["Target name / file name","Method","Initial levels per axis","Maximum total patches","Extra gray levels","Control patches"];
for s=labels,uilabel(settings,'Text',s);end
name=uieditfield(settings,'text','Value','RGB-refined','Tag','designName','ValueChangedFcn',@invalidate);
method=uidropdown(settings,'Items',{'InkProf mesh refinement','Argyll OFPS'},'ItemsData',{'mesh','argyll'}, ...
    'Value','mesh','Tag','designMethod','ValueChangedFcn',@invalidate);
shadow=inkprof.internal.shadowSettings(struct);
project=inkprof.internal.findProject(options.OutputFile);
if project~="",record=jsondecode(fileread(fullfile(project,'inkprof-project.json')));shadow=inkprof.internal.shadowSettings(record.printing);end
if shadow.enabled,method.Value='argyll';method.Enable='off';method.Tooltip='Matte shadow emphasis from Project details uses Argyll OFPS.';end
levels=number('levels',5,2);limit=number('maxPoints',575,8);gray=number('graySteps',33,0);controls=number('controls',64,0);
labels=["Extra repeat patches","Max interior gap (0 = off)","Initial gap ratio (0 = off)","Interior placement","",""];
for s=labels,uilabel(settings,'Text',s);end
repeats=number('repeats',12,0);
edgeLimit=uieditfield(settings,'numeric','Value',0,'Limits',[0 Inf],'Tag','maxEdge','ValueChangedFcn',@invalidate);
gapRatio=uieditfield(settings,'numeric','Value',0,'Limits',[0 Inf],'Tag','gapRatio','ValueChangedFcn',@invalidate);
placement=uidropdown(settings,'Items',{'Centroids (default)','Sphere centers in tetrahedra','All interior sphere centers'}, ...
    'ItemsData',{'centroid','contained-circumcenter','circumcenter'},'Value','centroid','Tag','interiorPlacement','ValueChangedFcn',@invalidate);
for k=1:2,uilabel(settings,'Text','');end
actions=uigridlayout(root,[1 3]);actions.ColumnWidth={'1x','1x','1x'};actions.Padding=[0 0 0 0];
base=uibutton(actions,'Text','Preview initial grid','Tag','previewBase','ButtonPushedFcn',@(~,~)generate(false));
refine=uibutton(actions,'Text','Refine / generate','Tag','generate','ButtonPushedFcn',@(~,~)generate(true));
cancel=uibutton(actions,'Text','Stop generation','Tag','cancel','Enable','off','ButtonPushedFcn',@stopGeneration);
plots=uigridlayout(root,[1 2]);plots.ColumnWidth={'1x','1x'};plots.Padding=[0 0 0 0];
left=uigridlayout(plots,[2 1]);left.RowHeight={'1x',150};left.Padding=[0 0 0 0];
ax=uiaxes(left);xlabel(ax,'Edge rank (largest first)');ylabel(ax,'RGB distance, normalized 0–1 channels');
table=uitable(left,'Tag','edgeTable','ColumnName',{'Rank','Point 1','Point 2','RGB distance'},'ColumnEditable',false);
cube=uiaxes(plots);xlabel(cube,'R');ylabel(cube,'G');zlabel(cube,'B');view(cube,3);
status=uilabel(root,'Text','Preview the initial grid, inspect distances, then choose limits and refine.','WordWrap','on','Tag','designStatus');
saving=uigridlayout(root,[1 3]);saving.ColumnWidth={'1x',260,90};saving.Padding=[0 0 0 0];
saveHint=uilabel(saving,'Text','Not saved. Enter Target name / file name above, then generate and save. The save dialog lets you choose the folder and file name.', ...
    'WordWrap','on','Tag','saveHint');
save=uibutton(saving,'Text','Save definition: TI1 + JSON…','Tag','saveDesign','Enable','off','ButtonPushedFcn',@saveDesign);
uibutton(saving,'Text','Cancel','Tag','designCancel','ButtonPushedFcn',@closeWindow);
uilabel(root,'Text','Distances describe device RGB geometry, not measured colour error. Save the RGB definition here; use the TIFF16 window for page layout and printing.','WordWrap','on');
    function h=number(tag,value,minimum)
        h=uieditfield(settings,'numeric','Value',value,'Limits',[minimum Inf],'RoundFractionalValues','on','Tag',tag,'ValueChangedFcn',@invalidate);
    end
    function invalidate(~,~)
        if ~isvalid(fig),return;end
        save.Enable='off';
        saveHint.Text='Settings changed. Generate again, then save the new target.';
        if ~fig.UserData.busy,status.Text='Settings changed. Generate again before saving.';end
        enabled='on';if string(method.Value)=="argyll",enabled='off';end
        if shadow.enabled,method.Enable='off';end
        placement.Enable=enabled;levels.Enable=enabled;edgeLimit.Enable=enabled;gapRatio.Enable=enabled;base.Enable=enabled;
    end
    function generate(doRefine)
        if fig.UserData.busy,return;end
        fig.UserData.busy=true;fig.UserData.cancelled=false;save.Enable='off';base.Enable='off';refine.Enable='off';cancel.Enable='on';
        % Freeze generation parameters while callbacks pump the UI.
        inputs={name,method,levels,limit,gray,controls,repeats,edgeLimit,gapRatio,placement};
        for k=1:numel(inputs),set(inputs{k},'Enable','off');end
        try
            d=inkprof.designRGBTarget(Name=string(name.Value),Method=string(method.Value),Levels=levels.Value, ...
                MaxPoints=limit.Value,GraySteps=gray.Value,ControlCount=controls.Value,RepeatCount=repeats.Value, ...
                MaxEdge=edgeLimit.Value,GapRatio=gapRatio.Value,InteriorPlacement=string(placement.Value),Refine=doRefine,ShadowEmphasis=1+double(shadow.enabled)*(shadow.patchEmphasis-1),Progress=@progress);
            fig.UserData.design=d;fig.UserData.saved=[];
            render(d);
            suggest=regexprep(char(d.name),'[^a-zA-Z0-9_-]','-');
            saveHint.Text=sprintf('Not saved. Suggested file: %s.ti1. Click Save definition to save TI1 and JSON. Open the TI1 separately in the TIFF16 window.',suggest);
            save.Enable='on';
        catch err
            status.Text=string(err.message);
            if ~strcmp(err.identifier,'inkprof:Cancelled'),uialert(fig,err.message,'Target generation');end
        end
        if fig.UserData.closePending,delete(fig);return;end
        fig.UserData.busy=false;cancel.Enable='off';refine.Enable='on';for k=1:numel(inputs),set(inputs{k},'Enable','on');end
        enabled='on';if string(method.Value)=="argyll",enabled='off';end
        if shadow.enabled,method.Enable='off';end
        placement.Enable=enabled;levels.Enable=enabled;edgeLimit.Enable=enabled;gapRatio.Enable=enabled;base.Enable=enabled;
    end
    function yes=progress(s)
        status.Text=sprintf('Generating: %d fitting points · refinement distance %.5f',s.count,s.maxEdge);
        drawnow;yes=~fig.UserData.cancelled;
    end
    function render(d)
        isInterior=string(d.options.Method)=="mesh" && string(d.options.Refinement)=="interior";
        cla(ax);plot(ax,d.initialRefinementDistances,'Color',[.65 .65 .65]);hold(ax,'on');
        plot(ax,d.sortedRefinementDistances,'Color',[.1 .4 .7],'LineWidth',1.4);
        if d.effectiveThreshold>0,yline(ax,d.effectiveThreshold,'--','Stop distance');end
        hold(ax,'off');legend(ax,{'Initial','Current'},'Location','northeast');
        if isInterior
            title(ax,'Interior candidate gaps (largest first)');
            ylabel(ax,'Candidate to nearest fitting point, RGB 0–1');xlabel(ax,'Candidate rank');
            table.ColumnName={'Rank','R','G','B','Nearest distance'};
            table.Data=[(1:numel(d.sortedRefinementDistances))',d.candidatePoints,d.sortedRefinementDistances];
        else
            title(ax,'Sorted mesh-edge distances');ylabel(ax,'RGB edge length');xlabel(ax,'Edge rank');
            table.ColumnName={'Rank','Point 1','Point 2','RGB distance'};
            table.Data=[(1:numel(d.sortedDistances))',d.sortedEdges,d.sortedDistances];
        end
        cla(cube);p=d.rgb(1:d.fitCount,:);scatter3(cube,p(:,1),p(:,2),p(:,3),18,p,'filled');
        xlim(cube,[0 1]);ylim(cube,[0 1]);zlim(cube,[0 1]);axis(cube,'equal');grid(cube,'on');view(cube,3);
        title(cube,'Fitting RGB points (nominal colours)');
        status.Text=sprintf(['%d total: %d fit + %d control + %d repeats. Stop: %s.\n' ...
            'Fit locations: %d interior / %d surface. Sampled coverage (33^3 probes): interior max %.5f, mean %.5f; surface max %.5f, mean %.5f.'], ...
            size(d.rgb,1),d.fitCount,d.controlCount,d.repeatCount,d.stopReason, ...
            d.coverage.interiorFitCount,d.coverage.boundaryFitCount,d.coverage.interior.max,d.coverage.interior.mean, ...
            d.coverage.surface.max,d.coverage.surface.mean);
    end
    function stopGeneration(~,~)
        fig.UserData.cancelled=true;
    end
    function saveDesign(~,~)
        if isempty(fig.UserData.design)||fig.UserData.busy,return;end
        p=inkprof.paths();suggest=regexprep(char(fig.UserData.design.name),'[^a-zA-Z0-9_-]','-');
        if options.OutputFile==""
            [file,folder]=uiputfile({'*.ti1','RGB patch definition (*.ti1)'},'Save RGB definition and JSON',fullfile(p.Projects,[suggest '.ti1']));
        else
            [folder,stem,ext]=fileparts(options.OutputFile);file=stem+ext;
        end
        if isequal(file,0),return;end
        save.Enable='off';refine.Enable='off';base.Enable='off';fig.UserData.busy=true;
        status.Text='Saving RGB definition and design metadata…';drawnow;
        if fig.UserData.closePending,delete(fig);return;end
        try
            saved=inkprof.saveRGBDefinition(fig.UserData.design,fullfile(folder,file));
            fprintf('InkProf: saved definition %s\nJSON: %s\n',saved.ti1,saved.json);
            delete(fig);return;
        catch err
            if strcmp(err.identifier,'inkprof:Cancelled'),delete(fig);return;end
            status.Text=string(err.message);uialert(fig,err.message,'Save target');
        end
        fig.UserData.busy=false;save.Enable='on';refine.Enable='on';
        if string(method.Value)=="mesh",base.Enable='on';end
    end
    function closeWindow(~,~)
        if fig.UserData.busy
            fig.UserData.cancelled=true;fig.UserData.closePending=true;status.Text='Cancelling at the next safe checkpoint…';
        else
            delete(fig);
        end
    end
end
