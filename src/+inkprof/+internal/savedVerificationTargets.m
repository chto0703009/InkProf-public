% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function targets=savedVerificationTargets(w)
% List project-local targets made for the current ICC, without creating prints.
targets=struct('file',{},'label',{});
digest=inkprof.internal.sha256(w.output('profile','profile'));
listing=dir(fullfile(w.Root,'targets','*','verification.json'));
for f=reshape(listing,1,[])
 file=string(fullfile(f.folder,f.name));
 try
  r=jsondecode(fileread(file));
  if string(r.documentType)~="inkprof.verification-target"||string(r.printerProfile.sha256)~=digest,continue;end
  relative=string(r.printPackage.ti2);
  if relative~="print/target.ti2",continue;end
  target=fullfile(f.folder,relative);if ~isfile(target),continue;end
  [~,folder]=fileparts(f.folder);
  label=string(r.name)+" | "+numel(r.patches)+" patches | "+string(folder);
  targets(end+1)=struct('file',file,'label',label); %#ok<AGROW>
 catch
  % Incomplete packages cannot be offered for measurement.
 end
end
end
