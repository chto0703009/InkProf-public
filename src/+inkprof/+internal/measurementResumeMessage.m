% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=measurementResumeMessage(chart,checkpoint,plan)
arguments
 chart (1,1) struct
 checkpoint (1,1) struct
 plan (1,1) struct = struct
end
confirmed=false(1,checkpoint.totalPasses);confirmed(checkpoint.confirmedPasses)=true;
paired=string(checkpoint.scanMode)=="paired";
count=sum(confirmed);if paired,count=count/2;end
missing=find(~confirmed,1);
if isempty(missing)
 text=sprintf('%d completed rows are saved. Calibrate if prompted, then choose Save and finish to complete and review the measurement.',count);return;
end
info=inkprof.internal.measurementPage(chart,missing,plan);
direction="FORWARD";
if string(checkpoint.scanMode)=="alternating"&&mod(missing,2)==0,direction="REVERSE";end
text=string(sprintf('%d completed rows are saved. Resume on page %d of %d, printed row %s (row %d on this page), %s scan. ', ...
 count,info.page,info.totalPages,info.row,info.rowOnPage,direction));
if paired
 text=text+"Read this row again in BOTH directions: forward first, then reverse. A previously unfinished row was not included in the saved checkpoint. ";
else
 text=text+"Read the first unfinished row again from its beginning. ";
end
text=text+"Use the same printed sheets and saved scan settings. Calibrate when prompted, then wait for the displayed row instruction before scanning. Saved RGB controls are retained.";
end
