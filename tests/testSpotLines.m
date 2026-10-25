% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testSpotLines
tests=functiontests(localfunctions);
end
function testPartialLineDoesNotBlockCalibrationUI(tc)
writer=java.io.PipedWriter();pipe=java.io.PipedReader(writer);reader=java.io.BufferedReader(pipe);
cleanup=onCleanup(@()closePipes(reader,writer));
writer.write(java.lang.String('{"event":"state","kind":"cal'));writer.flush();
started=tic;[lines,pending]=inkprof.internal.readSpotLines(reader,'');
verifyLessThan(tc,toc(started),1);verifyEmpty(tc,lines);verifyNotEmpty(tc,pending);
writer.write(java.lang.String(['ibration"}' newline]));writer.flush();
[lines,pending]=inkprof.internal.readSpotLines(reader,pending);
verifyEmpty(tc,pending);verifyEqual(tc,numel(lines),1);
event=jsondecode(lines{1});verifyEqual(tc,string(event.kind),"calibration");
end
function testMultipleLinesAndUnfinishedTail(tc)
reader=java.io.BufferedReader(java.io.StringReader(['one' newline 'two' newline 'partial']));
cleanup=onCleanup(@()reader.close());[lines,pending]=inkprof.internal.readSpotLines(reader,'');
verifyEqual(tc,lines,{'one','two'});verifyEqual(tc,pending,'partial');
end
function closePipes(reader,writer)
writer.close();reader.close();
end
