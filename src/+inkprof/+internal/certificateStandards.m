function r=certificateStandards()
%CERTIFICATESTANDARDS Versioned, non-certifying bvdm/ISO reference.
p=inkprof.paths();
r=jsondecode(fileread(fullfile(p.Root,'resources','certificate-standards.json')));
end
