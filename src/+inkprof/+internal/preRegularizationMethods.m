% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function [ids,labels]=preRegularizationMethods()
%PREREGULARIZATIONMETHODS Selectable pre-regularization methods (recipe B2).
% "off" must stay first: it is the backward-compatible default.
% New methods are added here, in createProfileRecipe>preRegularizationPlan,
% in profiles/preregularize.py (settings) and in profiles/profile_job.py.
% The former InkProf grid regularization (axial/Hessian) has been removed.
ids=["off","argyll-colprof"];
labels=["Argyll only (raw measurements)","Argyll colprof pre-smoothing (experimental)"];
end
