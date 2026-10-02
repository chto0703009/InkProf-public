function evidence=numericalDecisionEvidence(w,folder,digest)
% Decision support only; differing training meshes are not equal test sets.
evidence=struct('purpose',"decision-support-only",'printAccuracyImprovement',"not-assessed", ...
 'trainingFit',struct,'comparison',struct);
current=jsondecode(fileread(w.output('checks','fit')));
if isfield(current,'summary'),evidence.trainingFit.current=current.summary;end
entries=w.State.history;if ~iscell(entries),entries=num2cell(entries);end
for k=numel(entries):-1:1
 e=entries{k};
 if string(e.step)~="cycle"||string(e.status)~="archived"||e.cycle~=w.State.cycle-1,continue;end
 if ~isfield(e.details.checks.outputs,'fit'),break;end
 s=e.details.checks;if string(s.status)~="completed",break;end
 relative=string(s.outputs.fit);path=w.resolve(relative);
 artifacts=reshape(s.artifacts,1,[]);match=find(string({artifacts.path})==relative,1);
 if isempty(match)||~isfile(path)||inkprof.internal.sha256(path)~=string(artifacts(match).sha256)
  evidence.trainingFit.previousStatus="unavailable-or-changed";break
 end
 old=jsondecode(fileread(path));
 if isfield(old,'summary')
  copyfile(path,fullfile(folder,'previous-fit.json'));
  evidence.trainingFit.previous=old.summary;
  evidence.trainingFit.previousSource=struct('file',"previous-fit.json",'sha256',inkprof.internal.sha256(path));
 end
 break
end
if isfield(evidence.trainingFit,'previous')&&isfield(evidence.trainingFit,'current')
 for metric=["mean","p95","max"]
  if isfield(evidence.trainingFit.previous,metric)&&isfield(evidence.trainingFit.current,metric)
   evidence.trainingFit.changeCurrentMinusPrevious.(metric)=evidence.trainingFit.current.(metric)-evidence.trainingFit.previous.(metric);
  end
 end
end
evidence.trainingFit.caveat="Anpassningsfel mot respektive iterations profilunderlag. Mätpunkter och antal kan skilja sig; detta är inte en jämförelse på ett gemensamt oberoende utskriftsprov.";
if w.valid('compare')
 data=jsondecode(fileread(w.output('compare','comparison')));
 assert(string(data.profileSHA256.current)==digest,'inkprof:Integrity','Comparison refers to another current ICC.');
 evidence.comparison=struct('previousIteration',data.previousIteration,'currentIteration',data.currentIteration, ...
  'profileSHA256',data.profileSHA256,'settings',data.settings,'sameRGBDeltaE00',data.sameRGBDeltaE00, ...
  'sameLabRGBChangePercentagePoints',data.sameLabRGBChangePercentagePoints);
end
end
