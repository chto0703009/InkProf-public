function image=drawPrintFurniture(image,dpi,page,total,timestamp,filePath,summary,footerInsetMm)
%DRAWPRINTFURNITURE Standard heading, date, centred full TIFF path and page footer.
% Java2D is used only to rasterize text in the white margins. Device RGB
% patch pixels are never resampled or passed through a colour transform.
if nargin<7,summary="";end
if nargin<8,footerInsetMm=12;end
widthMm=size(image,2)/dpi*25.4;heightMm=size(image,1)/dpi*25.4;
image=textAt(image,"InkProf Quality Profiling RGB printer",[widthMm/2 9],dpi,20,"center",widthMm-16);
if widthMm<240
    if strlength(string(summary))>0
        image=textAt(image,string(summary),[widthMm/2 heightMm-19],dpi,7,"center",widthMm-16);
    end
    [lines,points,lineMm]=footerLines(string(filePath),widthMm-16,dpi,4,12);
    for k=1:numel(lines)
        image=textAt(image,lines(k),[widthMm/2 heightMm-11+(k-(numel(lines)+1)/2)*lineMm],dpi,points,"center",widthMm-16);
    end
    image=textAt(image,timestamp,[8 heightMm-3],dpi,7,"left");
    image=textAt(image,string(page)+" ("+total+")",[widthMm-8 heightMm-3],dpi,7,"right");
else
if strlength(string(summary))>0
    image=textAt(image,string(summary),[widthMm/2 heightMm-footerInsetMm-5.3],dpi,7,"center",widthMm-16);
end
image=textAt(image,timestamp,[8 heightMm-footerInsetMm],dpi,9,"left");
% Keep filename clear of date/time and page count; never silently clip it.
assert(strlength(string(filePath))>0,'inkprof:Label','A TIFF filename is required.');
[lines,points,lineMm]=footerLines(string(filePath),widthMm-110,dpi);
for k=1:numel(lines)
    y=heightMm-footerInsetMm+(k-(numel(lines)+1)/2)*lineMm;
    image=textAt(image,lines(k),[widthMm/2 y],dpi,points,"center",widthMm-110);
end
image=textAt(image,string(page)+" ("+total+")",[widthMm-8 heightMm-footerInsetMm],dpi,9,"right");
end
end

function image=textAt(image,text,position,dpi,points,alignment,maxWidthMm)
if nargin<7,maxWidthMm=inf;end
font=java.awt.Font('SansSerif',java.awt.Font.PLAIN,1).deriveFont(single(points*dpi/72));
probe=java.awt.image.BufferedImage(1,1,java.awt.image.BufferedImage.TYPE_INT_RGB);
g=probe.createGraphics();g.setFont(font);metrics=g.getFontMetrics();
while double(metrics.stringWidth(char(text)))+2>maxWidthMm*dpi/25.4 && points>6
    points=points-0.5;
    font=font.deriveFont(single(points*dpi/72));g.setFont(font);metrics=g.getFontMetrics();
end
assert(double(metrics.stringWidth(char(text)))+2<=maxWidthMm*dpi/25.4, ...
    'inkprof:Label','TIFF filename is too long for the centred footer; choose a shorter filename.');
w=double(metrics.stringWidth(char(text)))+2;h=double(metrics.getHeight());ascent=double(metrics.getAscent());g.dispose();
canvas=java.awt.image.BufferedImage(w,h,java.awt.image.BufferedImage.TYPE_INT_RGB);
g=canvas.createGraphics();g.setColor(java.awt.Color.WHITE);g.fillRect(0,0,w,h);
g.setColor(java.awt.Color.BLACK);g.setFont(font);g.drawString(char(text),1,ascent);g.dispose();
pixels=canvas.getRGB(0,0,w,h,[],0,w);mask=reshape(pixels,w,h)'~=-1;
x=round(position(1)*dpi/25.4)+1;y=round(position(2)*dpi/25.4-h/2)+1;
if alignment=="center",x=x-round(w/2);elseif alignment=="right",x=x-w;end
assert(x>=1&&y>=1&&x+w-1<=size(image,2)&&y+h-1<=size(image,1),'inkprof:Label','Print heading/footer does not fit.');
for c=1:3
 block=image(y:y+h-1,x:x+w-1,c);
 assert(all(block(mask)==65535),'inkprof:Label','Heading/footer overlaps existing target content.');
 block(mask)=0;image(y:y+h-1,x:x+w-1,c)=block;
end
end

function [lines,points,lineMm]=footerLines(path,maxWidthMm,dpi,maxLines,maxHeight)
% Wrap the complete path without ellipses in the reserved footer.
if nargin<4,maxLines=2;maxHeight=6.5;end
probe=java.awt.image.BufferedImage(1,1,java.awt.image.BufferedImage.TYPE_INT_RGB);
g=probe.createGraphics();cleanup=onCleanup(@()g.dispose());
for points=8:-0.5:6
    font=java.awt.Font('SansSerif',java.awt.Font.PLAIN,1).deriveFont(single(points*dpi/72));
    g.setFont(font);metrics=g.getFontMetrics();
    remaining=char(path);lines=strings(0,1);
    while ~isempty(remaining)
        count=0;
        while count<numel(remaining) && double(metrics.stringWidth(remaining(1:count+1)))+2<=maxWidthMm*dpi/25.4
            count=count+1;
        end
        assert(count>0,'inkprof:Label','No room for the TIFF path.');
        if count<numel(remaining)
            slash=find(remaining(1:count)=='/' | remaining(1:count)=='\',1,'last');
            if ~isempty(slash),count=slash;end
        end
        lines(end+1)=string(remaining(1:count));remaining=remaining(count+1:end);
    end
    lineMm=double(metrics.getHeight())/dpi*25.4;
    if numel(lines)<=maxLines && numel(lines)*lineMm<=maxHeight,return;end
end
error('inkprof:Label','Full TIFF path does not fit the footer; choose a shorter output path.');
end
