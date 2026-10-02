function text=dialogText(value)
%DIALOGTEXT Preserve multiline inputdlg responses as one scalar string.
% MATLAB may return a padded character matrix rather than a character row.
lines=strip(string(value),'right');
if isempty(lines),text="";else,text=strjoin(lines(:),newline);end
end
