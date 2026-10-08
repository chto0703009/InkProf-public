% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function details=projectDetailsDialog(record)
%PROJECTDETAILSDIALOG Edit descriptive project metadata; cancel returns [].
arguments
 record (1,1) struct = struct
end
details=[];dismissed=false;
printing=struct;if isfield(record,'printing'),printing=record.printing;end
fig=uifigure('Name','InkProf | Project details','Position',[180 100 680 690], ...
 'WindowStyle','modal','Tag','projectDetailsDialog','CloseRequestFcn',@cancel);
cleanup=onCleanup(@()delete(fig));
outer=uigridlayout(fig,[3 1]);outer.RowHeight={'1x',75,36};
tabs=uitabgroup(outer);general=uitab(tabs,'Title','Project and materials');printingTab=uitab(tabs,'Title','Printing settings');profileTab=uitab(tabs,'Title','Profiling');
paperTab=uitab(tabs,'Title','Target paper');
g=uigridlayout(paperTab,[4 2]);g.ColumnWidth={230,'1x'};g.RowHeight={32,32,32,'1x'};
prefs=inkprof.internal.paperPreferences();if isfield(record,'paperLayout'),prefs=record.paperLayout;end
uilabel(g,'Text','Maximum measurement sweep (mm)');scanLimit=uieditfield(g,'numeric','Value',prefs.MaxScanMm,'Limits',[65 Inf]);
uilabel(g,'Text','Maximum target length (mm)');lengthLimit=uieditfield(g,'numeric','Value',prefs.MaxLengthMm,'Limits',[65 Inf]);
uilabel(g,'Text','Roll width (mm)');rollWidth=uieditfield(g,'numeric','Value',prefs.RollWidthMm,'Limits',[65 Inf]);
help=uilabel(g,'Text','Editable suggestions compare A5–A3+ sheets, cut pieces and roll feed for the actual patch count. These limits include margins. Changes apply to future targets; existing targets and measurements are preserved.','WordWrap','on');help.Layout.Column=[1 2];
g=uigridlayout(general,[10 2]);g.ColumnWidth={150,'1x'};g.RowHeight={32,32,32,32,32,32,32,40,90,'1x'};g.Padding=[20 16 20 16];
name=field('Project name','projectName',value(record,'name','New project'));
user=field('User','projectUser',value(record,'user',string(java.lang.System.getProperty('user.name'))));
printer=field('Printer','projectPrinter',value(printing,'printer','unknown'));
paper=field('Paper name','projectPaper',value(printing,'paper','unknown'));
uilabel(g,'Text','Paper finish');
items=["unknown","Glossy","Matte","Other"];
finish=value(printing,'paperSurface',value(printing,'finish','unknown'));if ~any(items==finish),items(end+1)=finish;end
surface=uidropdown(g,'Items',cellstr(items),'Value',char(finish),'Tag','projectFinish');
ink=field('Ink / ink set','projectInk',value(printing,'ink','unknown'));
uilabel(g,'Text','Ink type');
inkTypeValue=value(printing,'inkType','unknown');
inkTypes=["unknown","Dye","Pigment","Mixed","Other"];if ~any(inkTypes==inkTypeValue),inkTypes(end+1)=inkTypeValue;end
inkType=uidropdown(g,'Items',cellstr(inkTypes),'Value',char(inkTypeValue),'Tag','projectInkType');
inkType.Tooltip='Dye-based, pigment-based or a mixed ink set. Record the ink actually used; use Ink / ink set for product and channel details.';

uilabel(g,'Text','FWA / OBA');
fwa=uicheckbox(g,'Text','Compensate optical brighteners (D50)', ...
 'Value',isfield(printing,'fwaCompensation')&&isequal(printing.fwaCompensation,true),'Tag','projectFWA');
help=uilabel(g,'Text','Can be changed after measurement or profiling. Requires native M0 spectra, a known instrument and a paper-white patch. Simulates D50 illumination; does not turn the measurement into a certified M1 measurement. Rebuild the profile and repeat validation after changing this option.','WordWrap','on');help.Layout.Column=[1 2];
g=uigridlayout(printingTab,[10 2]);g.ColumnWidth={150,'1x'};g.RowHeight={32,32,32,32,32,32,32,32,80,'1x'};g.Padding=[20 16 20 16];
media=field('Driver media setting','projectMedia',value(printing,'media','unknown'));
printPath=field('Printing application','projectPrintPath',value(printing,'printPath','unknown'));
driver=field('Driver / RIP','projectDriver',value(printing,'driver','unknown'));
quality=field('Print quality','projectQuality',value(printing,'quality','unknown'));
colour=field('Colour management','projectColourManagement',value(printing,'colorManagement','unknown'));
drying=field('Drying time (hours)','projectDryingHours',value(printing,'dryingHours','unknown'));
uilabel(g,'Text','Printer coating');
coatingValue=value(printing,'printerCoating','unknown');
coatingItems=["unknown","off","on","automatic"];if ~any(coatingItems==coatingValue),coatingItems(end+1)=coatingValue;end
coating=uidropdown(g,'Items',cellstr(coatingItems),'Value',char(coatingValue),'Tag','projectPrinterCoating');
coating.Tooltip='Clear coating applied by the printer, such as Chroma Optimizer or Gloss Optimizer. Separate from the paper finish. Match the setting used for the measured targets.';
coatingDetails=field('Coating settings','projectCoatingSettings',value(printing,'coatingSettings','unknown'));
coatingDetails.Tooltip='Coating product, mode, coverage or amount. Record the actual driver setting, including Auto if used.';

uilabel(g,'Text','Printer settings','WordWrap','on');
settings=uitextarea(g,'Value',splitlines(value(printing,'settings','')),'Tag','projectSettings');
g=uigridlayout(profileTab,[10 2]);g.ColumnWidth={150,'1x'};g.RowHeight={32,32,32,32,32,32,32,32,100,'1x'};g.RowSpacing=5;g.Padding=[20 16 20 16];
profileName=field('Profile name','projectProfileName',value(printing,'profileName',value(record,'name','New project')));
profileDescription=field('Description','projectProfileDescription',value(printing,'profileDescription',value(record,'name','New project')));
uilabel(g,'Text','Colour data');profileMode=uidropdown(g,'Items',{'Spectra (D50 / 2 degrees)','Stored XYZ'},'ItemsData',{'spectral','storedXYZ'},'Value',char(value(printing,'profileDataMode','spectral')),'Tag','projectProfileDataMode');
uilabel(g,'Text','Inverse table (B2A)');profileQuality=uidropdown(g,'Items',{'High (denser)','Medium (baseline)'},'ItemsData',{'high','medium'},'Value',char(value(printing,'profileB2AQuality','high')),'Tag','projectProfileB2AQuality');
shadow=inkprof.internal.shadowSettings(printing);
uilabel(g,'Text','Matte shadows');shadowMode=uidropdown(g,'Items',{'Extra shadow detail for Matte','Standard distribution'},'ItemsData',{'auto-matte','standard'},'Value',char(shadow.mode),'Tag','projectShadowMode');
uilabel(g,'Text','Dark patch emphasis');shadowPatch=uieditfield(g,'numeric','Value',shadow.patchEmphasis,'Limits',[1 4],'Tag','projectShadowPatch');
uilabel(g,'Text','Shadow grid emphasis');shadowGrid=uieditfield(g,'numeric','Value',shadow.gridEmphasis,'Limits',[1 3],'Tag','projectShadowGrid');
uilabel(g,'Text','Extra iteration patches');shadowCount=uieditfield(g,'numeric','Value',shadow.extraPatches,'Limits',[0 256],'RoundFractionalValues','on','Tag','projectShadowCount');
profileHelp=uilabel(g,'Text','Matte shadows uses Argyll -V: more dark patches and denser modelling in shadows, with less emphasis on lighter regions. This is an InkProf trial strategy, not an Argyll matte preset or a guarantee of improvement. Applies to new targets and builds. Compare and print-verify the result. FWA requires Spectra.','WordWrap','on');profileHelp.Layout.Column=[1 2];
note=uilabel(outer,'Text','Renaming also changes the project folder name. Corrected printing details require rebuilding the profiling stages. Existing measurements are preserved. For a different printing setup, create a new project.','WordWrap','on');
buttons=uigridlayout(outer,[1 2]);buttons.Padding=[0 0 0 0];
uibutton(buttons,'Text','Cancel','Tag','cancelProjectDetails','ButtonPushedFcn',@cancel);
uibutton(buttons,'Text','Save','Tag','saveProjectDetails','ButtonPushedFcn',@save);
topGuard=inkprof.internal.lowerTopWindows(fig); %#ok<NASGU> keep the dialog above always-on-top windows
if ~dismissed,uiwait(fig);end
% Nested callbacks retain this workspace; release cleanup explicitly so the
% modal window closes before returning the saved details to the app.
clear cleanup
    function control=field(label,tag,initial)
        uilabel(g,'Text',label);
        control=uieditfield(g,'text','Value',char(initial),'Tag',tag);
    end
    function save(~,~)
        if strlength(strtrim(string(name.Value)))==0||strlength(strtrim(string(user.Value)))==0
            uialert(fig,'Enter a project name and user.','Project details');return
        end
        try,inkprof.internal.projectFolderName(string(name.Value));catch err,uialert(fig,err.message,'Project name');return;end
        if strlength(strtrim(string(profileName.Value)))==0||strlength(strtrim(string(profileDescription.Value)))==0
            uialert(fig,'Enter a profile name and description on the Profiling tab.','Project details');return
        end
        if fwa.Value&&strcmp(profileMode.Value,'storedXYZ')
            uialert(fig,'FWA requires Spectra on the Profiling tab.','Project details');return
        end
        updated=printing;
        updated.shadowMode=string(shadowMode.Value);updated.shadowPatchEmphasis=shadowPatch.Value;
        updated.shadowGridEmphasis=shadowGrid.Value;updated.shadowExtraPatches=shadowCount.Value;
        updated.profileName=strtrim(string(profileName.Value));updated.profileDescription=strtrim(string(profileDescription.Value));
        updated.profileDataMode=string(profileMode.Value);updated.profileB2AQuality=string(profileQuality.Value);
        updated.printer=string(printer.Value);updated.paper=string(paper.Value);
        updated.paperSurface=string(surface.Value);
        updated.fwaCompensation=logical(fwa.Value);
        if isfield(updated,'finish'),updated=rmfield(updated,'finish');end
        updated.ink=string(ink.Value);updated.inkType=string(inkType.Value);updated.media=string(media.Value);updated.printPath=string(printPath.Value);
        hours=strtrim(string(drying.Value));
        if hours~="unknown"&&(isnan(str2double(hours))||~isfinite(str2double(hours))||str2double(hours)<0)
            uialert(fig,'Enter a nonnegative drying time in hours, or unknown.','Project details');return
        end
        updated.printerCoating=string(coating.Value);updated.coatingSettings=strtrim(string(coatingDetails.Value));
        if updated.coatingSettings=="",updated.coatingSettings="unknown";end
        updated.dryingHours=hours;updated.driver=string(driver.Value);
        updated.quality=string(quality.Value);updated.colorManagement=string(colour.Value);
        updated.settings=strjoin(string(settings.Value),newline);updated.status="user recorded";
        details=struct('Name',strtrim(string(name.Value)),'User',strtrim(string(user.Value)),'Printing',updated);
        details.PaperLayout=struct('MaxScanMm',scanLimit.Value,'MaxLengthMm',lengthLimit.Value,'RollWidthMm',rollWidth.Value);
        dismissed=true;uiresume(fig);
    end
    function cancel(~,~)
        details=[];dismissed=true;uiresume(fig);
    end
end
function text=value(s,key,fallback)
text=string(fallback);
if isfield(s,key)&&strlength(string(s.(key)))>0,text=string(s.(key));end
end
