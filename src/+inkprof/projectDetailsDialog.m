function details=projectDetailsDialog(record)
%PROJECTDETAILSDIALOG Edit descriptive project metadata; cancel returns [].
arguments
 record (1,1) struct = struct
end
details=[];
printing=struct;if isfield(record,'printing'),printing=record.printing;end
fig=uifigure('Name','InkProf | Project details','Position',[180 100 680 690], ...
 'WindowStyle','modal','Tag','projectDetailsDialog','CloseRequestFcn',@cancel);
cleanup=onCleanup(@()delete(fig));
outer=uigridlayout(fig,[3 1]);outer.RowHeight={'1x',75,36};
tabs=uitabgroup(outer);general=uitab(tabs,'Title','Project and materials');printingTab=uitab(tabs,'Title','Printing settings');
g=uigridlayout(general,[7 2]);g.ColumnWidth={150,'1x'};g.RowHeight={32,32,32,32,32,32,'1x'};g.Padding=[20 16 20 16];
name=field('Project name','projectName',value(record,'name','New project'));
user=field('User','projectUser',value(record,'user',string(java.lang.System.getProperty('user.name'))));
printer=field('Printer','projectPrinter',value(printing,'printer','unknown'));
paper=field('Paper name','projectPaper',value(printing,'paper','unknown'));
uilabel(g,'Text','Paper finish');
items=["unknown","Glossy","Matte","Other"];
finish=value(printing,'paperSurface',value(printing,'finish','unknown'));if ~any(items==finish),items(end+1)=finish;end
surface=uidropdown(g,'Items',cellstr(items),'Value',char(finish),'Tag','projectFinish');
ink=field('Ink / ink set','projectInk',value(printing,'ink','unknown'));
g=uigridlayout(printingTab,[8 2]);g.ColumnWidth={150,'1x'};g.RowHeight={32,32,32,32,32,32,100,'1x'};g.Padding=[20 16 20 16];
media=field('Driver media setting','projectMedia',value(printing,'media','unknown'));
printPath=field('Printing application','projectPrintPath',value(printing,'printPath','unknown'));
driver=field('Driver / RIP','projectDriver',value(printing,'driver','unknown'));
quality=field('Print quality','projectQuality',value(printing,'quality','unknown'));
colour=field('Colour management','projectColourManagement',value(printing,'colorManagement','unknown'));
drying=field('Drying time (hours)','projectDryingHours',value(printing,'dryingHours','unknown'));
uilabel(g,'Text','Printer settings','WordWrap','on');
settings=uitextarea(g,'Value',splitlines(value(printing,'settings','')),'Tag','projectSettings');
note=uilabel(outer,'Text','Renaming also changes the project folder name. Corrected printing details require rebuilding the profiling stages. Existing measurements are preserved. For a different printing setup, create a new project.','WordWrap','on');
buttons=uigridlayout(outer,[1 2]);buttons.Padding=[0 0 0 0];
uibutton(buttons,'Text','Cancel','Tag','cancelProjectDetails','ButtonPushedFcn',@cancel);
uibutton(buttons,'Text','Save','Tag','saveProjectDetails','ButtonPushedFcn',@save);
uiwait(fig);
    function control=field(label,tag,initial)
        uilabel(g,'Text',label);
        control=uieditfield(g,'text','Value',char(initial),'Tag',tag);
    end
    function save(~,~)
        if strlength(strtrim(string(name.Value)))==0||strlength(strtrim(string(user.Value)))==0
            uialert(fig,'Enter a project name and user.','Project details');return
        end
        try,inkprof.internal.projectFolderName(string(name.Value));catch err,uialert(fig,err.message,'Project name');return;end
        updated=printing;
        updated.printer=string(printer.Value);updated.paper=string(paper.Value);
        updated.paperSurface=string(surface.Value);
        if isfield(updated,'finish'),updated=rmfield(updated,'finish');end
        updated.ink=string(ink.Value);updated.media=string(media.Value);updated.printPath=string(printPath.Value);
        hours=strtrim(string(drying.Value));
        if hours~="unknown"&&(isnan(str2double(hours))||~isfinite(str2double(hours))||str2double(hours)<0)
            uialert(fig,'Enter a nonnegative drying time in hours, or unknown.','Project details');return
        end
        updated.dryingHours=hours;updated.driver=string(driver.Value);
        updated.quality=string(quality.Value);updated.colorManagement=string(colour.Value);
        updated.settings=strjoin(string(settings.Value),newline);updated.status="user recorded";
        details=struct('Name',strtrim(string(name.Value)),'User',strtrim(string(user.Value)),'Printing',updated);
        uiresume(fig);
    end
    function cancel(~,~)
        details=[];uiresume(fig);
    end
end
function text=value(s,key,fallback)
text=string(fallback);
if isfield(s,key)&&strlength(string(s.(key)))>0,text=string(s.(key));end
end
