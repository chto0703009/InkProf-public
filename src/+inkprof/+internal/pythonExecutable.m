% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function executable=pythonExecutable(requested,root,configured)
% Resolve a Python executable without running it or searching shell PATH.
if nargin<2,p=inkprof.paths();root=p.Root;configured=p.PythonConfigured;end
executable=string(requested);
if executable=="",executable=string(configured);end
if executable~=""
    % Relative configured paths are relative to the checkout, never pwd.
    f=java.io.File(char(executable));
    if ~f.isAbsolute(),executable=fullfile(root,executable);end
    % Keep the venv launcher path: resolving symlinks would select base Python.
    executable=string(java.io.File(char(executable)).toPath().normalize().toString());
    return
end
if ispc,candidate=fullfile(root,'.venv','Scripts','python.exe');
else,candidate=fullfile(root,'.venv','bin','python');end
if isfile(candidate),executable=candidate;end
end
