function fig=previewMeasurement(folder,result)
%PREVIEWMEASUREMENT Show target swatches and their saved measurement values.
% Colours are nominal device RGB previews, not a colourimetric rendering.
arguments
    folder (1,1) string
    result = []
end
folder=inkprof.internal.absolutePath(folder);
chart=jsondecode(fileread(fullfile(folder,'chart.json')));
measurementFile="";files=dir(fullfile(folder,'measurement-*.json'));
[~,order]=sort(string({files.name}));
for index=reshape(flip(order),1,[])
    path=fullfile(folder,files(index).name);saved=jsondecode(fileread(path));
    if ~isfield(saved,'documentType')||string(saved.documentType)~="inkprof.chart-measurement",continue;end
    if isempty(result),result=saved;measurementFile=path;break;end
    if isfield(result,'sourceTI3SHA256') && string(saved.sourceTI3SHA256)==string(result.sourceTI3SHA256) && string(saved.chartJSONSHA256)==string(result.chartJSONSHA256),measurementFile=path;break;end
end
assert(~isempty(result),'inkprof:Measurement','No saved measurement JSON found.');
selectedPatch=0;
assert(string(result.chartJSONSHA256)==inkprof.internal.sha256(fullfile(folder,'chart.json')), ...
    'inkprof:Integrity','Measurement belongs to a different chart definition.');
p=chart.patches;n=numel(p);rows=strings(n,1);columns=strings(n,1);columnIndex=zeros(n,1);
for k=1:n
    [rows(k),columns(k),columnIndex(k)]=inkprof.internal.decodeLocation(p(k).sampleLoc);
end
rowNames=unique(rows,'stable');
if all(isfinite(str2double(rowNames))),[~,order]=sort(str2double(rowNames));rowNames=rowNames(order);end
[~,rowIndex]=ismember(rows,rowNames);
passes=double(chart.passesInStrips(:));
assert(sum(passes)==numel(rowNames),'inkprof:Layout','Page/row counts disagree.');
pageOfRow=repelem((1:numel(passes))',passes);
measured=zeros(n,1);
for k=1:numel(result.chartIndex)
    index=result.chartIndex(k);
    if index==0,continue;end
    assert(index>=1&&index<=n&&index==fix(index)&&measured(index)==0,'inkprof:Identity','Invalid measurement mapping.');
    measured(index)=k;
end
spotLab=nan(n,3);spotChange=nan(n,1);spotReplaced=false(n,1);
if isfield(result,'patchOverrides')
    for replacement=reshape(result.patchOverrides,1,[])
        i=find(string({p.sampleLoc})==string(replacement.sampleLoc));
        if ~isscalar(i),continue;end
        spotReplaced(i)=true;
        candidateFile=string(replacement.candidateFile);
        % Prefer project-local evidence after a directory move.
        if ~isfile(candidateFile)
            candidates=dir(fullfile(folder,'spot-rereads','*','candidate.json'));
            for entry=reshape(candidates,1,[])
                path=fullfile(entry.folder,entry.name);
                if inkprof.internal.sha256(path)==string(replacement.candidateSHA256),candidateFile=path;break;end
            end
        end
        if isfile(candidateFile)&&inkprof.internal.sha256(candidateFile)==string(replacement.candidateSHA256)
            candidateValue=jsondecode(fileread(candidateFile));spotLab(i,:)=reshape(candidateValue.lab,1,[]);
            comparisonFile=fullfile(fileparts(candidateFile),'comparison.json');
            if isfile(comparisonFile)
                compared=jsondecode(fileread(comparisonFile));
                if isfield(compared,'candidateSHA256')&&string(compared.candidateSHA256)==string(replacement.candidateSHA256)
                    spotChange(i)=compared.deltaE00;
                end
            end
        end
    end
end
fig=uifigure('Name','InkProf – Saved measurement','Position',[100 100 1180 720], ...
    'WindowStyle','modal','Color',[.96 .97 .98],'Tag','InkProfMeasurementResult');
fig.UserData=struct('folder',folder,'chartIndex',result.chartIndex);
grid=uigridlayout(fig,[6 1]);grid.RowHeight={35,32,'1x',48,125,36};grid.Padding=[18 14 18 14];
uilabel(grid,'Text',sprintf('Saved measurement – %d of %d source patches',result.measuredSourcePatches,result.expectedSourcePatches), ...
    'FontSize',21,'FontWeight','bold','FontColor',[.1 .22 .3]);
bar=uigridlayout(grid,[1 5]);bar.ColumnWidth={45,110,'1x',155,80};bar.Padding=[0 0 0 0];
uilabel(bar,'Text','Page');
pageChoice=uidropdown(bar,'Items',cellstr(string(1:numel(passes))),'Value','1','ValueChangedFcn',@(~,~)drawPage());
uilabel(bar,'Text','Click a patch to view its coordinate and measurement values.');
remeasure=uibutton(bar,'Text','Remeasure patch','Enable','off','Tag','remeasurePatch','ButtonPushedFcn',@openSpot);
uibutton(bar,'Text','Close','ButtonPushedFcn',@(~,~)delete(fig));
body=uigridlayout(grid,[1 2]);body.ColumnWidth={'1x',475};body.Padding=[0 0 0 0];
ax=uiaxes(body);ax.Toolbar.Visible='off';disableDefaultInteractivity(ax);
rankingPanel=uigridlayout(body,[2 1]);rankingPanel.RowHeight={76,'1x'};rankingPanel.Padding=[4 0 0 0];
rankingTitle=uilabel(rankingPanel,'Text','Forward/reverse differences unavailable.','WordWrap','on');
ranking=uitable(rankingPanel,'Data',cell(0,5),'ColumnName',{'Patch','Page','Scan ΔE00','Spot ΔE00','Status'}, ...
    'ColumnWidth',{50,45,90,90,155},'FontSize',11, ...
    'ColumnFormat',{'char','numeric','short','char','char'},'RowName',{},'ColumnEditable',false, ...
    'Tag','patchDeviationRanking','CellSelectionCallback',@selectRankedPatch);
rankedIndices=[];patchDelta=nan(n,1);
if isfield(result,'pairedReadings') && isfield(result.pairedReadings,'directionComparison')
    comparison=result.pairedReadings.directionComparison;
    if comparison.available && isfield(comparison,'patchDeltaE00')
        delta=double(comparison.patchDeltaE00(:));
        mapping=double(result.pairedReadings.originalChartIndex(:));
        assert(numel(delta)==numel(mapping),'inkprof:Identity','Paired difference mapping mismatch.');
        assert(all(mapping>=1 & mapping<=n & mapping==fix(mapping)) && numel(unique(mapping))==numel(mapping), ...
            'inkprof:Identity','Invalid paired patch mapping.');
        patchDelta(mapping)=delta;
        eligible=find(isfinite(patchDelta) & measured>0 & ~[p.isPadding]');
        [~,rankOrder]=sort(patchDelta(eligible),'descend');rankedIndices=eligible(rankOrder);
        tableData=cell(numel(rankedIndices),5);
        for rank=1:numel(rankedIndices)
            i=rankedIndices(rank);state="Within limit";
            if patchDelta(i)>comparison.threshold,state="Above limit";end
            if isfield(result,'patchOverrides') && any(string({result.patchOverrides.sampleLoc})==string(p(i).sampleLoc))
                state="Spot replaced";
            end
            change='—';if isfinite(spotChange(i)),change=sprintf('%.3f',spotChange(i));end
            tableData(rank,:)={char(columns(i)+rows(i)),pageOfRow(rowIndex(i)),round(patchDelta(i),3),change,char(state)};
        end
        ranking.Data=tableData;
        rankingTitle.Text=sprintf('Original scan differences, largest first. Limit: %.2f dE00. Spot change = new vs previous value.',comparison.threshold);
    end
end
valuesLabel=uilabel(grid,'Text','','FontSize',16,'FontWeight','bold', ...
    'WordWrap','on','Tag','patchValues');
info=uitextarea(grid,'Editable','off','FontName','Monospaced','Tag','patchDetails');
notice="Colours preview target RGB only. Padding is grey.";noticeColor=[.25 .25 .25];
if isfield(result,'pairedReadings')&&isfield(result.pairedReadings,'directionComparison')
 check=result.pairedReadings.directionComparison;
 if ~check.available
  notice="WARNING: Forward/reverse comparison could not be computed. Readings are saved.";noticeColor=[.7 .15 .05];
 elseif ~isempty(check.flaggedRows)
  warningRows=string({check.flaggedRows.row});
  notice=sprintf('WARNING: Forward/reverse difference exceeds %.2f dE00 on printed row(s): %s. Review or reread these rows.',check.threshold,strjoin(warningRows,', '));noticeColor=[.7 .15 .05];
 else
  notice=sprintf('Forward/reverse check: no row exceeds %.2f dE00 (maximum %.3f). Colours preview target RGB only.',check.threshold,check.maxDeltaE00);
 end
end
if any(spotReplaced)
    notice="Spot replacement saved: "+strjoin(columns(spotReplaced)+rows(spotReplaced),", ")+". Scan dE00 still describes the ORIGINAL sweeps. Spot change compares the replacement with the previous value. Swatch colours remain target RGB.";
    noticeColor=[.1 .3 .4];
end
if isfield(result,'rowDirectionCheck')
 check=result.rowDirectionCheck;
 if check.available && ~isempty(check.flaggedRows)
  notice=notice+" WARNING: Possible reversed patch order on row(s): "+strjoin(string({check.flaggedRows.row}),', ')+". Reread in Single direction. No values were reversed.";
  noticeColor=[.7 .15 .05];
 elseif ~check.available
  notice=notice+" Row direction check unavailable: "+string(check.reason);
 end
end
uilabel(grid,'Text',notice,'WordWrap','on','FontSize',11,'FontColor',noticeColor,'Tag','pairedWarning');
drawPage();
if ~isempty(rankedIndices),showRankedPatch(rankedIndices(1));end
    function selectRankedPatch(~,event)
        if isempty(event.Indices),return;end
        showRankedPatch(rankedIndices(event.Indices(1,1)));
    end
    function showRankedPatch(i)
        pageChoice.Value=char(string(pageOfRow(rowIndex(i))));
        drawPage();selectPatch(i);
    end
    function drawPage()
        page=str2double(pageChoice.Value);selected=find(pageOfRow(rowIndex)==page);
        firstRow=sum(passes(1:page-1));localRows=rowIndex-firstRow;cols=max(columnIndex(selected));
        cla(ax);hold(ax,'on');
        for i=reshape(selected,1,[])
            rgb=reshape(double(p(i).rgbPercent),1,[])/100;
            caption=columns(i)+rows(i);
            if p(i).isPadding,rgb=[.85 .85 .85];caption=caption+newline+"padding";
            elseif measured(i)==0,rgb=[1 .92 .92];caption=caption+newline+"missing";end
            edge=[.8 .8 .8];if measured(i)==0&&~p(i).isPadding,edge=[.8 0 0];end
            rectangle(ax,'Position',[columnIndex(i)-.5,localRows(i)-.5,1,1], ...
                'FaceColor',rgb,'EdgeColor',edge,'UserData',i,'Tag','measurementPatch','ButtonDownFcn',@(~,~)selectPatch(i));
            ink=[0 0 0];if dot(rgb,[.2126 .7152 .0722])<.48,ink=[1 1 1];end
            text(ax,columnIndex(i),localRows(i),caption,'HorizontalAlignment','center', ...
                'Color',ink,'FontSize',max(7,min(11,230/cols)),'Interpreter','none', ...
                'ButtonDownFcn',@(~,~)selectPatch(i));
        end
        hold(ax,'off');ax.YDir='reverse';ax.XLim=[.5 cols+.5];ax.YLim=[.5 passes(page)+.5];
        ax.DataAspectRatio=[1 1 1];ax.XTick=[];ax.YTick=[];ax.Box='off';
        title(ax,sprintf('Page %d of %d – letter = column, number = row',page,numel(passes)));
        selectPatch(selected(1));
    end
    function selectPatch(i)
        selectedPatch=i;remeasure.Enable='off';
        if strlength(measurementFile)>0 && measured(i)>0 && ~p(i).isPadding,remeasure.Enable='on';end
        delete(findall(ax,'Tag','patchSelectionContrast'));
        boxes=findall(ax,'Tag','measurementPatch');
        for box=reshape(boxes,1,[])
            box.LineWidth=.5;box.EdgeColor=[.8 .8 .8];
            patchIndex=box.UserData;
            if measured(patchIndex)==0&&~p(patchIndex).isPadding,box.EdgeColor=[.8 0 0];end
            if patchIndex==i
                [border,inner]=inkprof.internal.selectionBorder(box.FaceColor);
                box.LineWidth=3;box.EdgeColor=border;
                pos=box.Position;left=pos(1)+.06;right=pos(1)+pos(3)-.06;
                top=pos(2)+.06;bottom=pos(2)+pos(4)-.06;
                line(ax,[left right right left left],[top top bottom bottom top], ...
                    'Color',inner,'LineWidth',1.5,'HitTest','off','PickableParts','none','Tag','patchSelectionContrast');
            end
        end
        coordinate=columns(i)+rows(i);
        m=measured(i);
        if spotReplaced(i)&&all(isfinite(spotLab(i,:)))
            v=spotLab(i,:);
            valuesLabel.Text=sprintf('Patch %s | Accepted spot Lab: L* %.3f   a* %.3f   b* %.3f',coordinate,v(1),v(2),v(3));
        elseif ~p(i).isPadding && m>0 && isfield(result.data,'lab') && ...
                size(result.data.lab,1)>=m && size(result.data.lab,2)==3 && ...
                all(isfinite(result.data.lab(m,:)))
            v=result.data.lab(m,:);
            valuesLabel.Text=sprintf('Patch %s | Measured Lab: L* %.3f   a* %.3f   b* %.3f',coordinate,v(1),v(2),v(3));
        else
            v=double(p(i).rgbPercent);
            valuesLabel.Text=sprintf('Patch %s | Target RGB (%%): R %.3f   G %.3f   B %.3f — indication only',coordinate,v(1),v(2),v(3));
        end
        lines=["Patch "+coordinate+" | SAMPLE_LOC "+string(p(i).sampleLoc)+" | patch-ID "+string(p(i).sampleId); ...
            "Device RGB values (%): "+join(compose('%.5f',reshape(double(p(i).rgbPercent),1,[])),"  ")];
        if isfinite(patchDelta(i))
            lines(end+1)=sprintf('Original forward/reverse difference: %.4f dE00 (repeatability, not profile accuracy).',patchDelta(i));
        end
        if isfield(result,'measurementCondition')
            condition=result.measurementCondition;
            lines(end+1)="Measurement condition: requested "+string(condition.requested)+", interpreted "+string(condition.interpreted)+" (see metadata for evidence).";
        end
        if p(i).isPadding
            lines(end+1)="Padding patch, excluded from source patch measurement results.";
        elseif measured(i)==0
            lines(end+1)="No measurement is available for this patch.";
        else
            m=measured(i);
            overridden=isfield(result,'patchOverrides')&&any(string({result.patchOverrides.sampleLoc})==string(p(i).sampleLoc));
            if overridden
                lines(end+1)="Accepted spot replacement. Original paired readings and warnings remain historical evidence.";
                if isfinite(spotChange(i)),lines(end+1)=sprintf('Accepted spot versus previous value: %.4f dE00.',spotChange(i));end
            end
            if isfield(result,'pairedReadings') && ~overridden
                pair=find(result.pairedReadings.originalChartIndex==i);
                if isscalar(pair)
                    lines(end+1)="Mean of two readings. Spectral RMS difference: "+string(result.pairedReadings.spectralRmsDifference(pair))+" (TI3 spectral units).";
                end
            end
            lines(end+1)="A measurement is available and linked to this patch.";
            if ~isempty(result.data.xyz),lines(end+1)="Measured XYZ (TI3 scale): "+join(compose('%.5f',result.data.xyz(m,:)),"  ");end
            if ~isempty(result.data.lab),lines(end+1)="Measured Lab: "+join(compose('%.5f',result.data.lab(m,:)),"  ");end
            if ~isempty(result.data.spectra)
                waves=reshape(result.data.wavelengthNm,1,[]);values=result.data.spectra(m,:);
                lines(end+1)="Spectrum, wavelength nm : value (original TI3 scale):";
                for a=1:8:numel(waves)
                    ix=a:min(a+7,numel(waves));lines(end+1)=join(reshape(compose('%.0f: %.5f',waves(ix)',values(ix)'),1,[]),"   ");
                end
            end
        end
        info.Value=cellstr(lines);
    end
    function openSpot(~,~)
        try
            inkprof.remeasurePatch(measurementFile,columns(selectedPatch)+rows(selectedPatch),ParentPreview=fig);
        catch err,uialert(fig,err.message,'Cannot remeasure patch');end
    end

end
