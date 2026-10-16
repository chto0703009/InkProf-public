% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function certificateMeasurementView(w,folder,includeVerification,scope)
% Use the current fit report: includes accumulated fitting data across iterations.
request=struct('profileSHA256',inkprof.internal.sha256(w.output('profile','profile')), ...
 'fit',"",'verification',"",'verificationReference',"",'scope',string(scope));
if w.mode()~="verification",request.fit=w.output('checks','fit');end
if includeVerification
 request.verification=w.output('c3','report');
 request.verificationReference=w.output('c2','reference');
end
requestFile=fullfile(folder,'measurement-view-request.json');
inkprof.internal.writeJson(requestFile,request);
cleanup=onCleanup(@()delete(requestFile)); %#ok<NASGU>
config=inkprof.paths();
inkprof.runPython(fullfile(config.Root,'analysis','certificate_measurements.py'), ...
 [requestFile,string(folder)],RequiredModules=["numpy","colour"],WorkingDirectory=config.Root);
end
