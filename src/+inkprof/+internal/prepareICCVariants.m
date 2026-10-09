% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function prepareICCVariants(w,folder)
% Keep the checked profile and record selected delivery variants separately.
source=fullfile(folder,'profile.icc');
record=jsondecode(fileread(fullfile(w.Root,'inkprof-project.json')));
versions="v2";
if isfield(record.printing,'profileOutputVersions'),versions=string(record.printing.profileOutputVersions);end
if w.mode()=="verification"
 versions="original";
end
assert(any(versions==["v2","v4","both","original"]),'inkprof:ICCVersion','Unsupported ICC output choice.');
manifest=struct('documentType',"inkprof.icc-delivery-variants",'selection',versions, ...
 'checkedSHA256',inkprof.internal.sha256(source),'primaryFile',"profile.icc",'secondaryFile',"", ...
 'note',"Certificate refers to the checked ICC. v4.4 preserves colorimetric tables but changes perceptual/saturation mapping; check its prints in the intended application.");
if any(versions==["v4","both"])
 paths=inkprof.paths();
 builtFolder=fileparts(w.output('profile','profile'));
 built=fullfile(builtFolder,'profile-v4.icc');evidence=fullfile(builtFolder,'conversion-v4.json');
 if isfile(built)&&isfile(evidence)
  saved=jsondecode(fileread(evidence));
  assert(string(saved.inputSHA256)==manifest.checkedSHA256&& ...
   inkprof.internal.sha256(built)==string(saved.outputSHA256),'inkprof:Integrity','Built v4 copy or conversion evidence has changed.');
  copyfile(built,fullfile(folder,'profile-v4.icc'));copyfile(evidence,fullfile(folder,'conversion-v4.json'));
 else
  inkprof.runPython(fullfile(paths.Root,'profiles','icc_v2_to_v4.py'), ...
   [source,fullfile(folder,'profile-v4.icc'),"--report",fullfile(folder,'conversion-v4.json')],RequiredModules="numpy");
 end
 conversion=jsondecode(fileread(fullfile(folder,'conversion-v4.json')));
 assert(isempty(conversion.problems),'inkprof:ICCVersion','ICC v4.4 structural checks failed.');
 manifest.v4SHA256=inkprof.internal.sha256(fullfile(folder,'profile-v4.icc'));
 if versions=="v4",manifest.primaryFile="profile-v4.icc";else,manifest.secondaryFile="profile-v4.icc";end
end
inkprof.internal.writeJson(fullfile(folder,'icc-variants.json'),manifest);
end
