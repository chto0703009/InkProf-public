function config=argyllLocalConfig(config,requested,source,legacy)
% Keep only an explicit per-checkout override, never an autodetected path.
if requested=="auto" || (requested==""&&legacy&&source~="config")
 for key=["argyllBin","argyllBinSource"]
  if isfield(config,key),config=rmfield(config,key);end
 end
elseif requested~=""
 config.argyllBin=requested;config.argyllBinSource="explicit";
end
end
