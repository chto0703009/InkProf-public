function previous=comparisonParent(state)
% Locate the preceding cycle's frozen profile, never a same-cycle rebuild.
previous=[];
if state.cycle<2,return;end
h=state.history;if iscell(h),entries=h;else,entries=num2cell(h);end
for k=numel(entries):-1:1
 e=entries{k};
 if string(e.step)=="cycle"&&string(e.status)=="archived"&&e.cycle==state.cycle-1
  previous=e.details.profile;return
 end
end
end
