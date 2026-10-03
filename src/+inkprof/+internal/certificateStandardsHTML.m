% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function text=certificateStandardsHTML(r,part)
%CERTIFICATESTANDARDSHTML Render the reference table or explanatory appendix.
c=r.sv;
if part=="table"
 text="<section class='standards-reference'><h2>"+esc(c.title)+"</h2><p>"+esc(c.caption)+"</p><table><tr>";
 for value=string(c.columns)',text=text+"<th>"+esc(value)+"</th>";end
 text=text+"</tr>";
 for k=1:size(c.rows,1)
  text=text+"<tr>";
  row=string(c.rows{k});
  for j=1:numel(row),text=text+"<td>"+esc(row(j))+"</td>";end
  text=text+"</tr>";
 end
 text=text+"</table></section>";
else
 text="<section class='reference-appendix' style='break-before:page'><h2>"+esc(c.appendixTitle)+"</h2>";
 for value=string(c.paragraphs)',text=text+"<p>"+esc(value)+"</p>";end
 text=text+"<p><a href='"+esc(r.sourceURL)+"'>MediaStandard Print 2018, tabell 30, sida 50</a></p></section>";
end
end
function value=esc(value)
value=replace(string(value),["&","<",">",string(char(34)),"'"],["&amp;","&lt;","&gt;","&quot;","&#39;"]);
end
