function proposals=planTargetPaper(count,options)
%PLANTARGETPAPER Conservative paper proposals; renderer confirms actual pages.
arguments
 count (1,1) double {mustBeInteger,mustBePositive}
 options.MaxScanMm double=[]
 options.MaxLengthMm double=[]
 options.RollWidthMm double=[]
end
prefs=inkprof.internal.paperPreferences();
for key=string(fieldnames(prefs))',if isempty(options.(key)),options.(key)=prefs.(key);end;validateattributes(options.(key),{'double'},{'scalar','finite','>=',65});end
% Standard i1 patch geometry: 10 mm scan + 1 mm spacer, 8 mm row.
% Reserve scan lead-in/out and furniture; never shrink patches to fit.
proposals=struct('kind',{},'description',{},'sizeMm',{},'estimatedPages',{}, ...
 'piecesPerSheet',{},'stockSheets',{},'usedAreaMm2',{},'stockAreaMm2',{},'rollFeedMm',{});
stock=[148 210;210 297;297 420;329 483];names=["A5","A4","A3","A3+"];
for s=1:4
 for cuts=[1 2 4]
  % Halve the longest dimension successively (includes half A3+).
  piece=stock(s,:);
  for c=1:log2(cuts),[~,j]=max(piece);piece(j)=piece(j)/2;end
  for rot=0:1
   dims=piece;if rot,dims=fliplr(dims);end
   add("Sheet",names(s)+" / "+cuts+" piece(s)",dims,cuts,prod(stock(s,:)),0);
  end
 end
end
% Both orientations: roll width may become the measurement length.
for lanes=1:max(1,ceil(options.RollWidthMm/148))
 for rot=0:1
  for feed=80:5:floor(max(options.MaxScanMm,options.MaxLengthMm))
   dims=[options.RollWidthMm/lanes feed];if rot,dims=fliplr(dims);end
   add("Roll","Roll "+options.RollWidthMm+" mm; feed "+feed+" mm; "+lanes+" cut piece(s) across",dims,lanes,options.RollWidthMm*feed,feed);
  end
 end
end
assert(~isempty(proposals),'inkprof:Paper','No format fits these measurement limits.');
[~,order]=sortrows([[proposals.usedAreaMm2]' [proposals.stockAreaMm2]'],[1 2]);proposals=proposals(order);
% Keep the best roll proposal and all feasible sheet choices.
roll=find(string({proposals.kind})=="Roll");if numel(roll)>1,proposals(roll(2:end))=[];end
 function add(kind,label,dims,pieces,stockArea,feed)
  if dims(1)>options.MaxScanMm||dims(2)>options.MaxLengthMm,return;end
  capacity=floor((dims(1)-55)/11)*floor((dims(2)-52)/8);
  if dims(1)<148||dims(2)<80||capacity<1,return;end
  pages=ceil(count/capacity);sheets=ceil(pages/pieces);
  proposals(end+1)=struct('kind',kind,'description',label,'sizeMm',dims, ...
   'estimatedPages',pages,'piecesPerSheet',pieces,'stockSheets',sheets, ...
   'usedAreaMm2',pages*prod(dims),'stockAreaMm2',sheets*stockArea,'rollFeedMm',feed*sheets);
 end
end
