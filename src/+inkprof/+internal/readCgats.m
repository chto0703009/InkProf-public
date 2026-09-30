function t=readCgats(path)
% Legacy first-table view. Full document API: inkprof.importCgats.
raw=fileread(path);tables=inkprof.internal.parseCgats(raw);first=tables(1);headers=struct;
for k=1:numel(first.metadata)
    v=first.metadata{k};headers.(matlab.lang.makeValidName(v(1)))=join(v(2:end)," ");
end
t=struct('signature',first.signature,'headers',headers,'fields',first.fields,'data',first.data,'rawText',raw);
end
