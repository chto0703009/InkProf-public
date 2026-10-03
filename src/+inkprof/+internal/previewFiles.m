% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function files=previewFiles(manifest)
%PREVIEWFILES Root page PNGs in numeric page order.
files=string({manifest.files.name});files=files(endsWith(files,'-preview.png') & ~contains(files,'/'));
numbers=zeros(size(files));
for k=1:numel(files)
    token=regexp(files(k),'(\d+)-preview\.png$','tokens','once');
    if ~isempty(token),numbers(k)=str2double(token{1});end
end
[~,order]=sort(numbers);files=files(order);
end
