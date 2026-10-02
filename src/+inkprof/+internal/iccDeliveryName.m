function name=iccDeliveryName(projectName,date)
% Human-readable external filename; ICC contents remain byte-identical.
arguments
 projectName (1,1) string
 date (1,1) datetime = datetime('now')
end
date.Format='yyMMdd';
name=inkprof.internal.projectFolderName(projectName)+"_"+string(date)+".icc";
end
