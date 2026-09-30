function out=workflowTiffOutputs(target)
% Expose every TIFF page as a deliverable, retaining TI2 for instrument input.
folder=fileparts(target);listing=[dir(fullfile(folder,'*.tif'));dir(fullfile(folder,'*.tiff'))];
assert(~isempty(listing),'inkprof:Workflow','Det sparade målet saknar TIFF16-filer.');
[~,order]=sort(string({listing.name}));listing=listing(order);
out=struct;
for k=1:numel(listing),out.("TIFF16_sida_"+k)=string(fullfile(listing(k).folder,listing(k).name));end
out.target=target;
end
