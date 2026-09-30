function fig=showPrintResult(folder)
%SHOWPRINTRESULT Saved TIFF page count and first-page PNG preview.
arguments
    folder (1,1) string
end
m=jsondecode(fileread(fullfile(folder,'manifest.json')));
previews=inkprof.internal.previewFiles(m);
assert(~isempty(previews),'inkprof:Preview','No page previews in saved package.');
fig=uifigure('Name','InkProf – Saved TIFF16 target','Position',[160 100 800 680],'Tag','InkProfPrintResult','WindowStyle','alwaysontop','Visible','off');
fig.UserData=struct('folder',folder,'pageCount',numel(previews));
g=uigridlayout(fig,[5 1]);g.RowHeight={38,'1x',32,65,32};
uilabel(g,'Text',sprintf('Saved TIFF16 target — %d pages',numel(previews)), ...
    'FontSize',22,'FontWeight','bold','Tag','savedPageCount');
preview=uiimage(g,'ScaleMethod','fit');
pager=inkprof.internal.previewPager(g,preview);pager.setImages(cellstr(fullfile(folder,previews)));
uilabel(g,'Text',"PNG preview. Use the arrows to change page. Print the TIFF files at 100%."+newline+folder,'WordWrap','on');
uibutton(g,'Text','Close','ButtonPushedFcn',@(~,~)delete(fig));
fig.Visible='on';drawnow;focus(fig);
end
