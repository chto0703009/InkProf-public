function [row,column,index]=decodeLocation(location)
% Current Argyll locations are row-first (e.g. 12C); display address is C12.
parts=regexp(char(location),'^([0-9]+)([A-Z]+)$','tokens','once');
if ~isempty(parts)
    row=string(parts{1});column=string(parts{2});index=0;
    for ch=char(column),index=index*26+double(ch)-double('A')+1;end
else
    % Permit verification of older packages with lettered strips.
    parts=regexp(char(location),'^([A-Z]+)([0-9]+)$','tokens','once');
    assert(~isempty(parts),'inkprof:Layout','Unsupported SAMPLE_LOC indexing.');
    row=string(parts{1});column=string(parts{2});index=str2double(column);
end
end
