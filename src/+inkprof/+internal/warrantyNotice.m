% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=warrantyNotice(language)
arguments
 language (1,1) string = "sv"
end
%WARRANTYNOTICE Plain-language summary; the full GPL remains authoritative.
text="InkProf tillhandahålls i befintligt skick utan garantier. Användaren ansvarar för att kontrollera mätningar, ICC-profiler och utskriftsresultat före användning. I den utsträckning tillämplig lag tillåter ansvarar upphovsrättsinnehavaren inte för skador eller förluster som uppstår genom användningen. Se GNU GPL v3, avsnitt 15–17.";
if language=="en"
 text="InkProf is provided as is, without warranties. Users are responsible for checking measurements, ICC profiles and print results before use. To the extent permitted by applicable law, the copyright holder is not liable for damage or loss arising from use. See GNU GPL v3, sections 15-17.";
end
end
