function f=showRefinementProposal(folder,options)
%SHOWREFINEMENTPROPOSAL Reopen a saved C3 proposal without regenerating files.
arguments
 folder (1,1) string = ""
 options.Visible (1,1) logical = true
end
f=[];
if folder==""
 paths=inkprof.paths();selected=uigetdir(paths.Projects,'Select saved refinement folder');
 if isequal(selected,0),return;end;folder=string(selected);
end
folder=inkprof.internal.absolutePath(folder);
proposal=jsondecode(fileread(fullfile(folder,'proposal.json')));
assert(string(proposal.documentType)=="inkprof.verification-refinement",'inkprof:Refinement','Expected a C3 refinement proposal.');
f=uifigure('Name','InkProf - C3 Jacobian refinement','Position',[100 100 1100 650],'WindowStyle','alwaysontop','Visible','off');
try
 g=uigridlayout(f,[4 1]);g.RowHeight={80,'1x',60,35};
 uilabel(g,'Text',sprintf('%s\n%d new RGB patches / %d maximum. %s. Proposals only; review print conditions.',proposal.name,numel(proposal.candidates),proposal.parameters.MaxNewPatches,proposal.stopReason),'WordWrap','on');
 rows=cell(numel(proposal.candidates),6);
 for k=1:numel(proposal.candidates)
  c=proposal.candidates(k);o=proposal.observations(c.observationIndex);
  rows(k,:)={char(join(string(o.coordinates(:)),', ')),double(c.rgbPercent(1)),double(c.rgbPercent(2)),double(c.rgbPercent(3)),double(c.score),char(string(c.direction))};
 end
 uitable(g,'Data',rows,'ColumnName',{'Source patches','R %','G %','B %','Priority','Sampling direction'},'ColumnWidth',{180,100,100,100,100,230},'RowName',{});
 uilabel(g,'Text',folder,'WordWrap','on');uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(f));
 if options.Visible,f.Visible='on';drawnow;focus(f);end
catch err
 delete(f);rethrow(err);
end
end
