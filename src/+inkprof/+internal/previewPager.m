function pager=previewPager(parent,preview)
%PREVIEWPAGER Navigation below a preview; images may be arrays or file paths.
images={};current=0;
g=uigridlayout(parent,[1 5]);g.ColumnWidth={'1x',110,160,110,'1x'};g.Padding=[0 0 0 0];
previous=uibutton(g,'Text','◀ Previous','Enable','off','Tag','previewPrevious','ButtonPushedFcn',@(~,~)step(-1));previous.Layout.Column=2;
label=uilabel(g,'Text','Page — of —','HorizontalAlignment','center','Tag','previewPage');
next=uibutton(g,'Text','Next ▶','Enable','off','Tag','previewNext','ButtonPushedFcn',@(~,~)step(1));
pager=struct('grid',g,'setImages',@setImages,'refresh',@refresh);
    function setImages(values)
        images=values;current=min(1,numel(images));
        if current==0,preview.ImageSource=ones(1,1,3);else,preview.ImageSource=images{current};end
        refresh();
    end
    function step(delta)
        if isempty(images),return;end
        current=max(1,min(numel(images),current+delta));
        preview.ImageSource=images{current};refresh();
    end
    function refresh()
        previous.Enable='off';next.Enable='off';
        if isempty(images),label.Text='Page — of —';return;end
        label.Text=sprintf('Page %d of %d',current,numel(images));
        if current>1,previous.Enable='on';end
        if current<numel(images),next.Enable='on';end
    end
end
