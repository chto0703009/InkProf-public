% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testSpectralAnalysis
tests=functiontests(localfunctions);
end
function testMissingScale(tc)
verifyError(tc,@()inkprof.analyzeMeasurement("missing.json"),'inkprof:Scale');
end
function testPythonRoundTrip(tc)
python=string(getenv('INKPROF_TEST_PYTHON'));
assumeTrue(tc,python~="",'Set INKPROF_TEST_PYTHON for integration tests.');
w=string(tempname)+" space";mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
data=struct('ids',["white";"grey";"black"],'locations',["A1";"B1";"C1"], ...
    'rgbPercent',[100 100 100;50 50 50;0 0 0], ...
    'wavelengthNm',360:10:780,'spectra',[100*ones(1,43);50*ones(1,43);zeros(1,43)], ...
    'scales',struct('SpectralScale',NaN));
source=struct('schemaVersion',1,'documentType',"inkprof.chart-measurement", ...
    'measurementCondition',struct('reported',"M0"),'data',data);
p=fullfile(w,'measurement.json');inkprof.internal.writeJson(p,source);
before=inkprof.internal.sha256(p);
a=fullfile(w,'first.json');b=fullfile(w,'second.json');
r=inkprof.analyzeMeasurement(p,SpectralScale=100,PythonExecutable=python,OutputPath=a);
verifyEqual(tc,r.data.xyz100(:,2),[100;50;0],'AbsTol',1e-10);
verifyEqual(tc,r.data.lab(2,1),76.069261,'AbsTol',1e-5);
s=inkprof.analyzeMeasurement(p,SpectralScale=100,PythonExecutable=python,OutputPath=b,ReferenceAnalysis=a);
verifyEqual(tc,s.comparison.max,0);
verifyEqual(tc,inkprof.internal.sha256(p),before);
verifyError(tc,@()inkprof.analyzeMeasurement(p,SpectralScale=100,PythonExecutable=python,OutputPath=a),'inkprof:Analysis');
end
