% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function chainText=verificationChainSummaryText(d)
chainText="Chain diagnostics unavailable in this report.";
if ~isempty(d)
 chainText=string(sprintf('1. Desired Lab → ICC inverse → forward: mean %.1f, max %.1f dE00.',d.inverse.summary.mean,d.inverse.summary.max));
 if string(d.tiff.status)=="available"
  chainText=chainText+newline+sprintf('2. Saved RGB → TIFF pixels: %d mismatches / %d patches; maximum %d RGB16 codes.',d.tiff.mismatchCount,d.tiff.checkedCount,d.tiff.maxChannelCodeError);
 else,chainText=chainText+newline+"2. TIFF check unavailable: "+string(d.tiff.reason);end
 if string(d.print.status)=="available"
  chainText=chainText+newline+sprintf('3. TIFF RGB → ICC prediction vs measured print: mean %.1f, max %.1f dE00.',d.print.summary.mean,d.print.summary.max);
 else,chainText=chainText+newline+"3. TIFF-based print comparison unavailable.";end
end
end
