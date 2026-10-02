function fig=renderTarget(source,options)
%RENDERTARGET Choose an RGB definition and generate a TIFF16 print package.
arguments
    source (1,1) string = ""
    options.OutputFolder (1,1) string = ""
end
paths=inkprof.paths();
fig=uifigure('Name','InkProf – Render TIFF16 target','Position',[100 100 1050 840],'WindowStyle','alwaysontop','Visible','off');
fig.UserData=struct('folder',"",'manifest',[],'busy',false,'cancelled',false,'pageCount',[]);
fig.CloseRequestFcn=@closeWindow;
g=uigridlayout(fig,[13 3]);g.ColumnWidth={180,'1x',170};
g.RowHeight={36,32,32,32,32,40,32,44,38,'1x',32,58,36};
h=uilabel(g,'Text','InkProf | TIFF16 print target','FontSize',22,'FontWeight','bold');h.Layout.Column=[1 3];
uilabel(g,'Text','Input patch definition');
input=uieditfield(g,'text','Value',char(source),'Tag','renderSource','ValueChangedFcn',@sourceChanged);
if options.OutputFolder~="",input.Editable='off';end
uibutton(g,'Text','Browse…','ButtonPushedFcn',@browse);
uilabel(g,'Text','Page size');
paper=uidropdown(g,'Items',{'A4 landscape','A4 portrait','A3 portrait','Custom'},'Value','A4 landscape','Tag','renderPaper','ValueChangedFcn',@paperChanged);
uibutton(g,'Text','Paper suggestions…','ButtonPushedFcn',@suggestPaper);
uilabel(g,'Text','Width / length (mm)');
sizes=uigridlayout(g,[1 2]);sizes.Padding=[0 0 0 0];
width=uieditfield(sizes,'numeric','Value',297,'Limits',[61 Inf],'Tag','renderWidth','ValueChangedFcn',@customSize);
height=uieditfield(sizes,'numeric','Value',210,'Limits',[61 Inf],'Tag','renderHeight','ValueChangedFcn',@customSize);
uilabel(g,'Text','Length is user-selected');
uilabel(g,'Text','Resolution (ppi / dpi)');
dpi=uieditfield(g,'numeric','Value',300,'Limits',[72 1200],'RoundFractionalValues','on','Tag','renderDPI','ValueChangedFcn',@changed);
scale=uidropdown(g,'Items',{'RGB: automatic','RGB values: 0–100','RGB values: 0–255','RGB values: 0–1'},'ItemsData',[NaN 100 255 1],'Tag','renderScale','ValueChangedFcn',@changed);
scale.Tooltip='Input number range, not colour space or TIFF bit depth. Keep automatic for known TI1/TI2/PXF/TXF formats. Generic files may require an explicit range.';
help=uilabel(g,'Text','RGB input range: leave Automatic for known formats. Other files may use 0–1, 0–100 or 0–255; choose their documented range. Output is always 16-bit RGB.', 'WordWrap','on');help.Layout.Column=[1 3];
uilabel(g,'Text','Patch order');
shuffle=uicheckbox(g,'Text','Randomize positions','Value',false,'Tag','renderShuffle','ValueChangedFcn',@changed);
seedGroup=uigridlayout(g,[1 2]);seedGroup.Padding=[0 0 0 0];seedGroup.ColumnWidth={75,'1x'};seedGroup.ColumnSpacing=5;
uilabel(seedGroup,'Text','Shuffle seed','FontSize',11);
seed=uieditfield(seedGroup,'numeric','Value',42,'Limits',[0 2147483647],'RoundFractionalValues','on','Tag','renderSeed','Tooltip','Used only with Randomize positions. The same seed reproduces the same patch order for the same target.','ValueChangedFcn',@changed);
uilabel(g,'Text','Output package name');
name=uieditfield(g,'text','Value','RGB-target','Tag','renderName','ValueChangedFcn',@changed);
button=uibutton(g,'Text','Generate and save…','Tag','renderSave','ButtonPushedFcn',@generate);
pageCount=uilabel(g,'Text','Pages: not calculated','FontWeight','bold','Tag','renderPageCount');pageCount.Layout.Column=[1 2];
uibutton(g,'Text','Calculate / preview','Tag','renderCalculate','ButtonPushedFcn',@calculate);
preview=uiimage(g,'ScaleMethod','fit','ImageSource',ones(1,1,3),'Tag','renderPreview');preview.Layout.Column=[1 3];
pager=inkprof.internal.previewPager(g,preview);pager.grid.Layout.Column=[1 3];
status=uilabel(g,'Text','Choose a definition, then click Calculate / preview to see the page count before saving. PNG is for preview only; print the TIFF files.', ...
    'WordWrap','on','Tag','renderStatus');status.Layout.Column=[1 3];
cancel=uibutton(g,'Text','Cancel','Tag','renderCancel','ButtonPushedFcn',@closeWindow);cancel.Layout.Column=3;
if strlength(source)>0,sourceChanged([],[]);end
prefs=inkprof.internal.paperPreferences(inkprof.internal.findProject(string(input.Value)));
layoutChoice=struct('preferences',prefs);
fig.Visible='on';drawnow;focus(fig);
    function suggestPaper(~,~)
        try
            target=inkprof.importTarget(string(input.Value),RGBScale=scale.Value);
            project=inkprof.internal.findProject(string(input.Value));
            choice=inkprof.internal.paperLayoutDialog(numel(target.ids),project,string(input.Value),scale.Value);
            if isempty(choice),return;end
            layoutChoice=choice;width.Value=choice.paperSizeMm(1);height.Value=choice.paperSizeMm(2);paper.Value='Custom';changed([],[]);
        catch err,uialert(fig,err.message,'Paper suggestions');end
    end
    function changed(~,~)
        fig.UserData.pageCount=[];
        pageCount.Text='Pages: not calculated — click Calculate / preview';
        pager.setImages({});
        status.Text='Click Calculate / preview to see the exact page count and page 1 before saving.';
    end
    function sourceChanged(~,~)
        [~,stem]=fileparts(input.Value);
        if ~isempty(stem),name.Value=[stem '-TIFF16'];end
        changed([],[]);
    end
    function browse(~,~)
        if options.OutputFolder~="",return;end
        fig.WindowStyle='normal';restore=onCleanup(@restoreFocus);
        [file,folder]=uigetfile({'*.ti1;*.ti2;*.pxf;*.txf;*.cgats;*.txt;*.cxf','RGB patch definitions';'*.*','All files'},'Select RGB patch definition',char(paths.Projects));
        clear restore
        if isequal(file,0),return;end
        input.Value=fullfile(folder,file);sourceChanged([],[]);
    end
    function paperChanged(~,~)
        switch paper.Value
            case 'A4 landscape',v=[297 210];
            case 'A4 portrait',v=[210 297];
            case 'A3 portrait',v=[297 420];
            otherwise,changed([],[]);return;
        end
        width.Value=v(1);height.Value=v(2);changed([],[]);
    end
    function customSize(~,~)
        paper.Value='Custom';changed([],[]);
    end
    function calculate(~,~)
        if fig.UserData.busy,return;end
        temporary=string(tempname);cleanup=onCleanup(@()removeTemporary(temporary));
        controls=findall(fig,'-property','Enable');set(controls,'Enable','off');cancel.Enable='on';
        fig.UserData.busy=true;fig.UserData.cancelled=false;
        status.Text='Calculating the actual print layout and rendering a temporary preview…';drawnow;
        try
            assert(isfile(input.Value),'inkprof:Input','Select an existing RGB patch definition first.');
            m=inkprof.createTarget(temporary,Source=string(input.Value),RGBScale=scale.Value, ...
                PaperLayout=layoutChoice,PaperSizeMm=[width.Value height.Value],DPI=dpi.Value,SpacerMode="colored",Randomize=shuffle.Value,Seed=seed.Value,Continue=@keepGoing);
            previews=inkprof.internal.previewFiles(m);
            images=cell(1,numel(previews));
            for k=1:numel(previews),images{k}=imread(fullfile(temporary,previews(k)));end
            pager.setImages(images);
            fig.UserData.pageCount=m.pageCount;
            pageCount.Text=sprintf('Pages: %d | Use the arrows below the preview',m.pageCount);
            status.Text='Not saved. Page count uses the actual layout at your selected DPI. Temporary footer path is replaced with the final path when saving.';
        catch err
            if strcmp(err.identifier,'inkprof:Cancelled'),delete(fig);return;end
            pageCount.Text='Pages: calculation failed';fig.UserData.pageCount=[];
            status.Text=string(err.message);uialert(fig,err.message,'TIFF16 preview');
        end
        fig.UserData.busy=false;set(controls(isvalid(controls)),'Enable','on');pager.refresh();
    end
    function generate(~,~)
        if fig.UserData.busy,return;end
        try
            assert(isfile(input.Value),'inkprof:Input','Select an existing RGB patch definition first.');
            assert(~isempty(strtrim(name.Value)),'inkprof:Input','Enter an output package name.');
            % Validate before presenting the save dialog (including RGB scale).
            inkprof.importTarget(string(input.Value),RGBScale=scale.Value);
            suggested=regexprep(name.Value,'[\\/:*?"<>|]','-');
            fig.WindowStyle='normal';restore=onCleanup(@restoreFocus);
            base=paths.Projects;project=inkprof.internal.findProject(string(input.Value));
            if project~="",base=fullfile(project,'targets');end
            if options.OutputFolder==""
                [file,folder]=uiputfile({'*','Target package folder name'},'Save new TIFF16 package (choose a new name)',fullfile(base,suggested));
            else
                [folder,file]=fileparts(options.OutputFolder);
            end
            clear restore
            if isequal(file,0),return;end
            destination=fullfile(folder,file);
            controls=findall(fig,'-property','Enable');set(controls,'Enable','off');cancel.Enable='on';
            fig.UserData.busy=true;status.Text='Generating TIFF16 pages, matching TI2 and JSON; checking patch pixels…';drawnow;
            m=inkprof.createTarget(destination,Source=string(input.Value),RGBScale=scale.Value, ...
                PaperLayout=layoutChoice,PaperSizeMm=[width.Value height.Value],DPI=dpi.Value,SpacerMode="colored",Randomize=shuffle.Value,Seed=seed.Value,Continue=@keepGoing);
            resultWindow=inkprof.showPrintResult(destination);
            delete(fig);focus(resultWindow);return;
        catch err
            if strcmp(err.identifier,'inkprof:Cancelled'),delete(fig);return;end
            status.Text=string(err.message);uialert(fig,err.message,'TIFF16 target');
        end
        fig.UserData.busy=false;
        if exist('controls','var'),set(controls(isvalid(controls)),'Enable','on');end
        pager.refresh();
    end
    function restoreFocus()
        if isvalid(fig),fig.WindowStyle='alwaysontop';drawnow;focus(fig);end
    end
    function yes=keepGoing()
        drawnow;yes=~fig.UserData.cancelled;
    end
    function closeWindow(~,~)
        if fig.UserData.busy
            fig.UserData.cancelled=true;status.Text='Cancelling at the next safe checkpoint…';
        else
            delete(fig);
        end
    end
end

function removeTemporary(folder)
if isfolder(folder),rmdir(folder,'s');end
end
