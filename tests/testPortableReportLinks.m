% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function tests=testPortableReportLinks
tests=functiontests(localfunctions);
end
function testLocalLinksWithBothQuotes(t)
input="<a href='final-report.pdf'>PDF</a><a href=""measurement-appendix.pdf"">Appendix</a><img src='figure.png'><img src=""plot.png"">";
actual=inkprof.internal.portableReportLinks(input,"underlag");
verifyTrue(t,contains(actual,"href='underlag/final-report.pdf'"));
verifyTrue(t,contains(actual,"href=""underlag/measurement-appendix.pdf"""));
verifyTrue(t,contains(actual,"src='underlag/figure.png'"));
verifyTrue(t,contains(actual,"src=""underlag/plot.png"""));
end
function testExternalAndFragmentLinksArePreserved(t)
input="<a href='https://example.org'>Web</a><a href=""#section"">Anchor</a><img src='data:image/png;base64,AAAA'><a href='//example.org'>Web</a>";
verifyEqual(t,inkprof.internal.portableReportLinks(input,"underlag"),input);
end
