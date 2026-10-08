% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
function s=regularizationReportSummary(w)
% Use the selected job's saved evidence, never the current dialog settings.
s=struct('summaryText',"Regularization: unavailable - no saved build recipe.");
job=w.output('profile','job');base=fileparts(job);file=fullfile(base,'recipe.json');
if ~isfile(file)
 s=appendGradientEvidence(s,base);return;
end
r=jsondecode(fileread(file));s.recipeSHA256=inkprof.internal.sha256(file);
s.jobSHA256=inkprof.internal.sha256(job);
s.parameters=struct;lines="Measurement-data regularization: Off (no preprocessing).";
if isfield(r.engine,'preRegularization')
 s.parameters=r.engine.preRegularization;pre=s.parameters;
 lines="Measurement-data regularization method: "+string(pre.method);
 for key="avgdev"
  if isfield(pre,key)
   value=pre.(key);if ischar(value)||isstring(value),value=string(value);else,value=string(jsonencode(value));end
   lines(end+1)=key+": "+value;
  end
 end
 if isfield(pre,'avgdev'),lines(end+1)="avgdev is assumed measurement/device noise in percent (preprocessing colprof -r).";end
end
if isfield(r,'patchCount'),lines(end+1)="Input patch count: "+r.patchCount;end
if isfield(r,'colorimetry')&&isfield(r.colorimetry,'mode'),lines(end+1)="Input data mode: "+string(r.colorimetry.mode);end
s.finalColprofArguments=r.engine.plannedArguments;
args=string(r.engine.plannedArguments);at=find(args=="-r",1);
if ~isempty(at)&&at<numel(args)
 lines(end+1)="Final ICC colprof -r (%): "+args(at+1);
else
 lines(end+1)="Final ICC colprof -r: Argyll default (not explicitly overridden).";
end
status=jsondecode(fileread(job));
if isfield(status,'renderingIntents')
 s.renderingIntents=status.renderingIntents;
 lines(end+1)="Delivered ICC rendering intents: perceptual (gamut-mapped B2A0), relative colorimetric (B2A1), absolute colorimetric (B2A1 plus media white).";
 lines(end+1)="Perceptual generic gamut compression (%): "+status.renderingIntents.compressionPercent;
end
if isfield(status,'preRegularization')
 s.result=status.preRegularization;a=s.result;
 if isfield(a,'summary')
  v=a.summary;lines(end+1)=sprintf('Model change versus raw measurements (Delta E00): mean %.3g, median %.3g, P95 %.3g, max %.3g.',v.mean,v.median,v.p95,v.max);
 end
elseif ~isempty(fieldnames(s.parameters))
 lines(end+1)="Regularization result: unavailable in saved job evidence.";
end
lines(end+1)="Raw measurements are preserved. Model change is not print accuracy or proof that visible banding is absent. Final-profile fit and print verification are reported separately.";
s.summaryText=join(lines,newline);
s=appendGradientEvidence(s,base);
end

function s=appendGradientEvidence(s,base)
profile=fullfile(base,'result','profile.icc');
if ~isfile(profile),return;end
digest=inkprof.internal.sha256(profile);
files=dir(fullfile(base,'checks','*','photo-gradients.json'));
[~,order]=sort([files.datenum],'descend');
for index=order
 file=fullfile(files(index).folder,files(index).name);
 try
  report=jsondecode(fileread(file));
  if string(report.profileSHA256)~=digest,continue;end
  s.photographicGradients=struct('reportSHA256',inkprof.internal.sha256(file),'report',report);
  rows=report.paths;floatRows=rows(string({rows.precision})=="float");
  valid=0;reversals=0;worst=0;
  for row=floatRows'
   m=row.metrics;
   if m.interiorTriples>=20 && ~isempty(m.interiorCurvatureP95)
    valid=valid+1;reversals=reversals+m.lightnessReversals;worst=max(worst,m.interiorCurvatureP95);
   end
  end
  text=["Photographic gradient diagnostic for this exact ICC (SHA-256 verified)."; ...
   string(report.method); ...
   "CMM: "+string(report.cmm.name)+" "+string(report.cmm.version)+"; samples per gradient: "+report.samples+"; tested paths and precision combinations: "+numel(rows)+"."; ...
   sprintf('Float paths with sufficient interior coverage: %d/%d; total L* reversals on those paths: %d; largest path curvature P95: %.1f.',valid,numel(floatRows),reversals,worst); ...
   "Curvature and reversal counts are numerical diagnostics, not perceptual acceptance thresholds. Quantization plateaus at 8/16 bit are recorded in the attached JSON evidence."; ...
   string(report.caveat)];
  s.summaryText=s.summaryText+newline+newline+join(text,newline);return;
 catch
  % An unreadable diagnostic must not become certificate evidence.
 end
end
s.summaryText=s.summaryText+newline+"Photographic gradient diagnostic: no readable saved report matching this ICC. Gradient smoothness has not been certified.";
end
