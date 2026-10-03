function result=previousCertificate(w,folder)
% Preserve a verified earlier certificate as historical evidence, never approval.
result=struct;
entries=w.State.history;if ~iscell(entries),entries=num2cell(entries);end
for k=numel(entries):-1:1
 e=entries{k};
 if string(e.step)~="cycle"||string(e.status)~="archived"||e.cycle>=w.State.cycle,continue;end
 if ~isfield(e.details,'export'),continue;end
 s=e.details.export;
 if string(s.status)~="completed"||~isfield(s.outputs,'reportJSON'),continue;end
 for a=reshape(s.artifacts,1,[])
  if inkprof.internal.isFinderMetadata(a.path),continue;end
  file=w.resolve(a.path);
  assert(isfile(file)&&inkprof.internal.sha256(file)==string(a.sha256), ...
   'inkprof:Integrity','Historical certificate is missing or changed: %s',file);
 end
 source=w.resolve(s.outputs.reportJSON);old=jsondecode(fileread(source));
 assert(old.iteration==e.cycle,'inkprof:Integrity','Historical certificate iteration mismatch.');
 relative="previous-certificate";copyfile(fileparts(source),fullfile(folder,relative));
 result=struct('iteration',old.iteration,'file',relative+"/final-report.json", ...
  'html',relative+"/final-report.html",'pdf',relative+"/final-report.pdf", ...
  'sha256',inkprof.internal.sha256(source),'profileSHA256',old.profile.sha256, ...
  'scope',"Historiskt mätcertifikat. Resultaten gäller tidigare iteration och verifierar inte aktuell ICC.");
 return
end
end
