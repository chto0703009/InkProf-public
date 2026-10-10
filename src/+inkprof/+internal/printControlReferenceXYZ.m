% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function xyz=printControlReferenceXYZ(readings)
% JSON vectors may decode as columns: average pages, never XYZ components.
xyz=struct;
for label=["R","G","B"]
 selected=readings(string({readings.label})==label);
 assert(~isempty(selected),'inkprof:PrintControlReference','Missing RGB reference reading.');
 values=zeros(numel(selected),3);
 for k=1:numel(selected)
  value=double(selected(k).xyz);
  assert(numel(value)==3&&all(isfinite(value(:))),'inkprof:PrintControlReference','Expected finite XYZ triples.');
  values(k,:)=reshape(value,1,3);
 end
 xyz.(label)=mean(values,1);
end
end
