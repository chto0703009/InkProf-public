function fig=app(projectFolder)
%APP Project workflow for the complete InkProf profiling chain.
% inkprof.app() or inkprof.app('/path/to/existing/project')
arguments
 projectFolder (1,1) string = ""
end
w=[];busy=false;selected="definition";defs=inkprof.internal.workflowSteps();
fig=uifigure('Name','InkProf | Projekt och iterationer','Position',[80 70 1220 810],'Tag','InkProfWorkflow');
fig.CloseRequestFcn=@closeApp;
g=uigridlayout(fig,[5 1]);g.RowHeight={42,40,48,'1x',42};g.Padding=[18 14 18 14];
heading=uilabel(g,'Text','InkProf | Projektbaserad profilering','FontSize',23,'FontWeight','bold');
bar=uigridlayout(g,[1 7]);bar.Padding=[0 0 0 0];bar.ColumnWidth={125,125,100,140,140,140,100};
uibutton(bar,'Text','Nytt projekt','Tag','newProject','ButtonPushedFcn',@newProject);
uibutton(bar,'Text','Öppna projekt','Tag','openProject','ButtonPushedFcn',@openProject);
uibutton(bar,'Text','Uppdatera','ButtonPushedFcn',@(~,~)refresh());
uibutton(bar,'Text','Öppna resultatlogg','Tag','openResultLog','ButtonPushedFcn',@openLog);
uibutton(bar,'Text','Iterationshistorik','Tag','iterationHistory','ButtonPushedFcn',@history);
reportButton=uibutton(bar,'Text','Öppna slutrapport','Tag','openFinalReport','Enable','off','ButtonPushedFcn',@openReport);
labButton=uibutton(bar,'Text','Visa 3D','Tag','showProfile3D','Enable','off','ButtonPushedFcn',@show3D);
projectLabel=uilabel(g,'Text','Skapa ett nytt projekt eller välj ett befintligt.','WordWrap','on');
body=uigridlayout(g,[1 2]);body.ColumnWidth={490,'1x'};body.Padding=[0 0 0 0];
table=uitable(body,'ColumnName',{'Steg','Status'},'ColumnWidth',{350,105},'ColumnEditable',false,'Tag','workflowSteps','CellSelectionCallback',@select);
right=uigridlayout(body,[6 1]);right.RowHeight={34,100,'1x',42,42,36};right.Padding=[10 0 0 0];
titleLabel=uilabel(right,'FontSize',18,'FontWeight','bold','Text','Arbetsgång');
hint=uitextarea(right,'Editable','off','Value',{'Välj ett projekt.'});
details=uitextarea(right,'Editable','off','Tag','workflowDetails');
runButton=uibutton(right,'Text','Utför valt steg','Tag','runWorkflowStep','Enable','off','ButtonPushedFcn',@run);
uibutton(right,'Text','Öppna resultat för valt steg','ButtonPushedFcn',@openResult);
legal=uigridlayout(right,[1 2]);legal.Padding=[0 0 0 0];legal.ColumnWidth={'1x',170};
uilabel(legal,'Text','Resultat och arbetsposition sparas i projektet.','WordWrap','on');
uibutton(legal,'Text','Licens och ansvar','Tag','licenseNotice','ButtonPushedFcn',@showLicense);
status=uilabel(g,'Text','Redo','WordWrap','on','Tag','workflowStatus');
if projectFolder~="",loadProject(projectFolder);end
    function showLicense(~,~)
        config=inkprof.paths();
        message=inkprof.internal.warrantyNotice()+newline+newline+ ...
            "InkProf: GNU GPL version 3 eller senare. Fullständig licens: "+ ...
            string(fullfile(config.Root,'LICENSE'))+newline+"https://www.gnu.org/licenses/gpl-3.0.html";
        uialert(fig,message,'Licens och ansvar','Icon','info');
    end
    function loadProject(folder)
        w=inkprof.ProjectWorkflow(folder);selected=string(w.State.currentStep);refresh();
    end
    function newProject(~,~)
        if busy,return;end
        paths=inkprof.paths();[n,p]=uiputfile('*','Nytt projektnamn',fullfile(paths.Projects,'Nytt-papper'));
        if isequal(n,0),return;end
        try,folder=inkprof.createProject(string(fullfile(p,n)),Name=string(n));loadProject(folder);
        catch err,uialert(fig,err.message,'Projekt');end
    end
    function openProject(~,~)
        if busy,return;end
        paths=inkprof.paths();p=uigetdir(char(paths.Projects),'Välj befintligt InkProf-projekt');
        if isequal(p,0),return;end
        try,loadProject(string(p));catch err,uialert(fig,err.message,'Projekt');end
    end
    function select(~,e)
        if isempty(e.Indices)||busy,return;end
        selected=string(defs(e.Indices(1),1).id);refresh();
    end
    function refresh()
        if isempty(w)||busy,return;end
        try
            w.reload();assessment=w.inspect();data=cell(numel(defs),2);
            for k=1:numel(defs)
                id=string(defs(k).id);valid=assessment.(id).valid;ready=assessment.(id).ready;
                s=string(w.State.steps.(id).status);
                if valid,s="Klart";elseif s=="completed",s="Inaktuellt";elseif s=="running",s="Avbrutet / pågår";elseif s=="failed",s="Fel";elseif ready,s="Redo";else,s="Låst";end
                data(k,:)={defs(k).label,char(s)};
            end
            reportButton.Enable=matlab.lang.OnOffSwitchState(assessment.export.valid&&isfield(w.State.steps.export.outputs,'finalReport'));
            labButton.Enable=matlab.lang.OnOffSwitchState(assessment.c2.valid);
            table.Data=data;index=find(string({defs.id})==selected);titleLabel.Text=defs(index).label;
            ok=assessment.(selected).ready;reason=assessment.(selected).reason;runButton.Enable=matlab.lang.OnOffSwitchState(ok);
            hint.Value=cellstr([reason;instruction(selected)]);
            step=w.State.steps.(selected);lines=["Iteration "+w.State.cycle;"Status: "+string(data{index,2});"";string(step.message);"";"Sparade resultat:"];
            names=string(fieldnames(step.outputs));
            if isempty(names),lines(end+1)="Inga resultat ännu.";end
            for name=names',lines=[lines;name+":";w.resolve(step.outputs.(name));""];end %#ok<AGROW>
            details.Value=cellstr(lines);
            projectLabel.Text=w.Root;heading.Text="InkProf | Iteration "+w.State.cycle;
            status.Text="Senast aktivt steg: "+string(w.State.currentStep)+" | sparad revision "+w.State.revision;
        catch err,status.Text=err.message;runButton.Enable='off';end
    end
    function run(~,~)
        if isempty(w)||busy,return;end
        try
            o=optionsFor(selected);if isempty(o),return;end
            busy=true;runButton.Enable='off';status.Text="Pågår: "+selected+". Slutför eller stäng den öppnade dialogen.";drawnow;
            w.run(selected,o);
            status.Text='Resultat sparat. Projektkopiorna och eventuella valda sparplatser finns i resultatloggen.';
        catch err
            status.Text=err.message;
            if ~strcmp(err.identifier,'inkprof:Cancelled'),uialert(fig,err.message,'InkProf');end
        end
        busy=false;refresh();
    end
    function o=optionsFor(id)
        o=struct;
        if id=="definition"
            choice=uiconfirm(fig,'Skapa RGB-mål eller importera en befintlig definition?','RGB-mål','Options',{'Skapa','Importera','Avbryt'},'CancelOption',3);
            if strcmp(choice,'Avbryt'),o=[];return;end
            if strcmp(choice,'Importera')
                o.Source=pick('*.ti1;*.pxf;*.txf;*.cxf;*.txt;*.cgats','Välj RGB-definition');
                if o.Source=="",o=[];return;end
                [~,~,ext]=fileparts(o.Source);
                if any(lower(ext)==[".txt",".cgats"])
                    a=inputdlg('RGB-skala (1, 100 eller 255)','RGB-skala',1,{'100'});if isempty(a),o=[];return;end;o.RGBScale=str2double(a{1});
                end
            end
        elseif id=="render"
            choice=uiconfirm(fig,'Rendera ett nytt mål eller använd ett befintligt TIFF16-paket?','Utskriftsmål', ...
                'Options',{'Rendera nytt','Välj befintligt','Avbryt'},'CancelOption',3);
            if strcmp(choice,'Avbryt'),o=[];return;end
            if strcmp(choice,'Välj befintligt'),o.Source=pick('target.ti2','Välj TI2 i befintligt utskriftspaket');if o.Source=="",o=[];end,end
        elseif any(id==["measurement","c2measurement","refinemeasurement"])
            choice=uiconfirm(fig,'Mät med instrument eller välj JSON / TI3 / MXF?','Mätning','Options',{'Mät','Välj sparad fil','Avbryt'},'CancelOption',3);
            if strcmp(choice,'Avbryt'),o=[];return;end
            if strcmp(choice,'Välj sparad fil'),o.Source=pick('*.json;*.ti3;*.mxf','Välj accepterad mätrevision');if o.Source=="",o=[];end,end
        elseif any(id==["review","approve","refine"])
            if id=="review"
                m=w.output('measurement','measurement');inkprof.previewMeasurement(fileparts(m),jsondecode(fileread(m)));
            end
            a=inputdlg(char(instruction(id)),'Dokumentera bedömning',[4 65],{''});
            if isempty(a),o=[];return;end
            o.Notes=string(a{1});o.Confirmed=strlength(strtrim(o.Notes))>0;
        elseif id=="export"
            a=inputdlg('Användare i rapportens sidfot','Rapportuppgifter',1,{char(java.lang.System.getProperty('user.name'))});
            if isempty(a),o=[];return;end
            o.ReportUser=string(a{1});
            [n,p]=uiputfile({'*.icc','ICC-profil (*.icc)';'*.icm','ICC-profil (*.icm)'},'Spara färdig ICC-profil',fullfile(w.Root,'profil.icc'));
            if isequal(n,0),o=[];return;end
            o.ICCDestination=string(fullfile(p,n));
            [n,p]=uiputfile({'*.pdf','Slutrapport (*.pdf)';'*.html','Slutrapport (*.html)';'*.txt','Slutrapport som text (*.txt)'}, ...
                'Spara PDF och HTML med samma namn',fullfile(p,'slutrapport.pdf'));
            if isequal(n,0),o=[];return;end
            o.ReportDestination=string(fullfile(p,n));o.Overwrite=true;
        elseif id=="profile"
            choice=uiconfirm(fig,'Välj profileringsväg. Manuell väg kräver ett färdigt B2-recept.','Profilering', ...
                'Options',{'Automatisk','Manuell B3','Avbryt'},'CancelOption',3);
            if strcmp(choice,'Avbryt'),o=[];return;end
            o.Mode="automatic";if strcmp(choice,'Manuell B3'),o.Mode="manual";end
            if o.Mode=="automatic"
                choice=uiconfirm(fig,'Finns en separat RoleFile som delar upp träning, utveckling och kontroll?','Patchroller', ...
                    'Options',{'Välj RoleFile','Ingen separat rollfil','Avbryt'},'CancelOption',3);
                if strcmp(choice,'Avbryt'),o=[];return;end
                if strcmp(choice,'Välj RoleFile'),o.RoleFile=pick('*.json','Välj RoleFile');if o.RoleFile=="",o=[];return;end,end
            end
        end
        if any(id==["profile","refine","continue"])
            a=inputdlg({'MaxNewPatches','NormTarget','GrayWeight'},'Iterationsparametrar',1,{'100','1','2'});
            if isempty(a),o=[];return;end
            o.MaxNewPatches=str2double(a{1});o.NormTarget=str2double(a{2});o.GrayWeight=str2double(a{3});
        end
    end
    function file=pick(filter,label)
        [n,p]=uigetfile(filter,label,char(w.Root));file="";if ~isequal(n,0),file=string(fullfile(p,n));end
    end
    function openLog(~,~)
        if isempty(w),return;end
        p=fullfile(w.Root,'result-log.txt');if isfile(p),edit(p);else,uialert(fig,'Loggen skapas när första operationen körs.','Resultatlogg');end
    end
    function openReport(~,~)
        if isempty(w),return;end
        w.reload();[valid,reason]=w.valid('export');
        if ~valid,uialert(fig,char(reason),'Slutrapporten är inte aktuell');return;end
        web(char(w.output('export','finalReport')),'-browser');
    end
    function show3D(~,~)
        if isempty(w),return;end
        w.reload();[ok,why]=w.valid('c2');
        if ~ok,uialert(fig,char(why),'3D-underlag saknas');return;end
        inkprof.showVerificationLab(w.output('c2','reference'));
    end
    function history(~,~)
        if isempty(w),return;end
        w.reload();h=w.State.history;if isstruct(h),h=num2cell(h);end
        rows=cell(0,4);
        for k=1:numel(h)
            e=h{k};rows(end+1,:)={e.cycle,char(e.utc),char(e.step),char(e.status)}; %#ok<AGROW>
        end
        f=uifigure('Name','InkProf | Iterationshistorik','Position',[120 100 1040 700]);
        grid=uigridlayout(f,[2 1]);grid.RowHeight={'1x','1x'};
        t=uitable(grid,'Data',rows,'ColumnName',{'Iteration','Tid UTC','Steg','Resultat'},'ColumnWidth',{80,180,180,'auto'});
        text=uitextarea(grid,'Editable','off');t.CellSelectionCallback=@showEvent;
        function showEvent(~,e)
            if ~isempty(e.Indices),text.Value=splitlines(string(jsonencode(h{e.Indices(1)},PrettyPrint=true)));end
        end
    end
    function openResult(~,~)
        if isempty(w),return;end
        s=w.State.steps.(selected);names=fieldnames(s.outputs);
        if isempty(names),return;end
        [ix,ok]=listdlg('ListString',names,'SelectionMode','single','PromptString','Öppna resultat');
        if ok,open(w.output(selected,names{ix}));end
    end
    function closeApp(~,~)
        if busy,uialert(fig,'Slutför eller avbryt pågående dialog innan appen stängs.','Operation pågår');else,delete(fig);end
    end
end
function s=instruction(id)
s="Steget arbetar i valt projekt. Resultat och beroenden sparas i workflow.json.";
switch id
 case "render",s="Spara TIFF16 i projektet. Du skriver ut filerna separat och återkommer till appen för mätning.";
 case "c2",s="Spara C2 som TIFF16. ICC är redan applicerad en gång. Skriv ut separat utan ytterligare färgomvandling, mät sedan i appen.";
 case {"measurement","c2measurement","refinemeasurement"},s="När ditt separat utskrivna ark är klart: starta instrumentmätningen här. Appen använder det sparade målets TI2 och sparar mätresultatet i projektet.";
 case "export",s="Välj filnamn och sparplats för ICC och slutrapport var för sig. Projektet behåller egna kopior. HTML-rapportens underlagsmapp sparas bredvid rapporten.";
 case "review",s="Granska mätning, avvikande rader och upprepningar. Ange bedömning och eventuella accepterade ommätningar.";
 case "approve",s="Ange avsedd användning, kvalitetskrav och accepterade begränsningar. Detta är användarens beslut efter fysisk C2/C3, inte ISO-certifiering.";
 case "refine",s="Granska mätfel och upprepningsvariation först. Dokumentera varför fler patchar behövs.";
 case "profile",s="Automatisk iteration eller manuell B3. Manuell B3 kräver B2. Ett lyckat jobb är en kandidat, inte godkänd utskriftskvalitet.";
 case "checks",s="Kör numeriska kontroller. Granska rapporterna före utskrift; kontrollerna ersätter inte C2/C3.";
 case "continue",s="Koppla komplettering till tidigare underlag och patchroller. Nästa iteration kräver nya kontroller och en ny fysisk C2/C3.";
end
end
