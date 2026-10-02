function tests=testTargets
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
testCase.TestData.root=root;
testCase.TestData.scratch=string(tempname);mkdir(testCase.TestData.scratch);
testCase.TestData.fixtures=fullfile(root,'tests','fixtures','i1profiler','chart-2033');
end
function teardownOnce(testCase)
rmdir(testCase.TestData.scratch,'s');
end
function testReferenceImports(tc)
base=tc.TestData.fixtures;
p=inkprof.importTarget(fullfile(base,'Chart 2033 Patches.pxf'));
t=inkprof.importTarget(fullfile(base,'Chart 2033 Patches.txf'));
c=inkprof.importTarget(fullfile(base,'Chart 2033 Patches.txt'),RGBScale=255);
verifySize(tc,p.rgbOriginal,[2033 3]);verifyEqual(tc,p.rgbOriginal,t.rgbOriginal);
verifyEqual(tc,p.ids,t.ids);verifyEqual(tc,p.rgbOriginal,floor(c.rgbOriginal));
verifyEqual(tc,size(unique(p.rgbOriginal,'rows'),1),2027);
verifyEqual(tc,t.sourceLayout.NumberPatchColumns,"30");
verifyError(tc,@()inkprof.importTarget(fullfile(base,'Chart 2033 Patches.txt')),'inkprof:Scale');
end
function testXmlSecurityAndMissingIds(tc)
file=fullfile(tc.TestData.scratch,'bad.pxf');
write(file,'<!DOCTYPE x [<!ENTITY x SYSTEM "file:///etc/passwd">]><x>&x;</x>');
verifyError(tc,@()inkprof.importTarget(file),'inkprof:XML');
raw=fileread(fullfile(tc.TestData.fixtures,'Chart 2033 Patches.pxf'));
raw=strrep(raw,'Id="c2"','Id="c1"');write(file,raw);
verifyError(tc,@()inkprof.importTarget(file),'inkprof:Identity');
end
function testCgatsRejectsMalformed(tc)
file=fullfile(tc.TestData.scratch,'bad.txt');
raw=fileread(fullfile(tc.TestData.fixtures,'Chart 2033 Patches.txt'));
write(file,strrep(raw,'NUMBER_OF_SETS'+string(char(9))+'2033','NUMBER_OF_SETS 2032'));
verifyError(tc,@()inkprof.importTarget(file,RGBScale=255),'inkprof:CGATS');
write(file,raw);verifyError(tc,@()inkprof.importTarget(file,RGBScale=100),'inkprof:Scale');
end
function testGeneratedAndRandomization(tc)
a=fullfile(tc.TestData.scratch,'generated');
m=inkprof.createTarget(a,PatchCount=40,GraySteps=5,DPI=100,Randomize=true,Seed=17);
verifyTrue(tc,m.compatibility.pixelChecksPassed);r=inkprof.verifyPackage(a);
verifyEqual(tc,r.sourcePatches,40);verifyGreaterThan(tc,r.paddingPatches,0);
verifyEqual(tc,r.maxTi2PixelErrorCodes,0);verifyLessThanOrEqual(tc,r.maxSourceQuantizationErrorCodes,.501);
b=fullfile(tc.TestData.scratch,'repeat');
inkprof.createTarget(b,Source=fullfile(a,'target.ti1'),DPI=100,Randomize=true,Seed=17);
la=jsondecode(fileread(fullfile(a,'layout.json')));lb=jsondecode(fileread(fullfile(b,'layout.json')));
verifyEqual(tc,string({la.patches.location}),string({lb.patches.location}));
verifyEqual(tc,string({la.patches.sampleId}),string({lb.patches.sampleId}));
verifyEqual(tc,vertcat(la.patches.rgb16),vertcat(lb.patches.rgb16));
c=fullfile(tc.TestData.scratch,'ordered');
inkprof.createTarget(c,Source=fullfile(a,'target.ti1'),DPI=100,Randomize=false);
lc=jsondecode(fileread(fullfile(c,'layout.json')));
verifyNotEqual(tc,string({la.patches.sampleId}),string({lc.patches.sampleId}));
verifyError(tc,@()inkprof.createTarget(a),'inkprof:Exists');
write(fullfile(a,'PRINTING.txt'),'modified');
verifyError(tc,@()inkprof.verifyPackage(a),'inkprof:Integrity');
end
function testImportedMultiPage(tc)
out=fullfile(tc.TestData.scratch,'imported spaces');
source=fullfile(tc.TestData.fixtures,'Chart 2033 Patches.txf');
m=inkprof.createTarget(out,Source=source,DPI=100,Randomize=true,Seed=31);
r=inkprof.verifyPackage(out);
verifyEqual(tc,r.sourcePatches,2033);verifyGreaterThan(tc,numel(r.pages),1);
verifyFalse(tc,m.compatibility.receiverLayoutVerified);
target=jsondecode(fileread(fullfile(out,'target.json')));
original=inkprof.importTarget(source);
verifyEqual(tc,target.rgbOriginal,original.rgbOriginal);
verifyEqual(tc,string(target.ids),original.ids);
verifyEqual(tc,inkprof.internal.sha256(fullfile(out,'source','original.txf')),original.sourceSHA256);
layout=jsondecode(fileread(fullfile(out,'layout.json')));
real=layout.patches(~[layout.patches.isPadding]);
verifyEqual(tc,sort(string({real.originalId})),sort(original.ids'));
relocated=fullfile(tc.TestData.scratch,'relocated');movefile(out,relocated);
verifyTrue(tc,inkprof.verifyPackage(relocated).passed);
end
function testFractionalCgatsAndQuotedPaths(tc)
source=fullfile(tc.TestData.scratch,"fractional 'quoted' $.txt");
text=sprintf(['CGATS.17\nNUMBER_OF_FIELDS 5\nBEGIN_DATA_FORMAT\n' ...
    'SAMPLE_ID SAMPLE_NAME RGB_R RGB_G RGB_B\nEND_DATA_FORMAT\n' ...
    'NUMBER_OF_SETS 3\nBEGIN_DATA\n' ...
    'id1 "First patch" 23.49 120.82 242.16\n' ...
    'id2 "Duplicate patch" 23.49 120.82 242.16\n' ...
    'id3 "Gray patch" 77.7777 77.7777 77.7777\nEND_DATA\n']);
write(source,text);out=fullfile(tc.TestData.scratch,"output 'quoted' $");
inkprof.createTarget(out,Source=source,RGBScale=255,DPI=100);
target=jsondecode(fileread(fullfile(out,'target.json')));
verifyEqual(tc,target.rgbOriginal(1,:),[23.49 120.82 242.16]);
verifyEqual(tc,string(target.names{1}),"First patch");
verifyTrue(tc,inkprof.verifyPackage(out).passed);
end
function testRelativePathsAfterCd(tc)
before=pwd;cleanup=onCleanup(@()cd(before));
cd(tc.TestData.scratch);
copyfile(fullfile(tc.TestData.fixtures,'Chart 2033 Patches.pxf'),'relative.pxf');
t=inkprof.importTarget('relative.pxf');
verifyEqual(tc,t.sourcePath,fullfile(tc.TestData.scratch,'relative.pxf'));
verifyEqual(tc,inkprof.internal.absolutePath('new-folder'),fullfile(tc.TestData.scratch,'new-folder'));
end
function testPortableCheckout(tc)
oldPath=path;oldFolder=pwd;cleanup=onCleanup(@()restore(oldPath,oldFolder));
destination=fullfile(tc.TestData.scratch,'moved checkout');mkdir(destination);
copyfile(fullfile(tc.TestData.root,'src'),fullfile(destination,'src'));
copyfile(fullfile(tc.TestData.root,'setupInkProf.m'),destination);
bin=inkprof.internal.argyllBin("");
rmpath(fullfile(tc.TestData.root,'src'));addpath(destination);
cd(tc.TestData.scratch);
p=setupInkProf(ArgyllBin=bin);
verifyEqual(tc,p.Root,destination);
verifyEqual(tc,p.Projects,fullfile(destination,'projects'));
verifyEqual(tc,string(which('inkprof.createTarget')),fullfile(destination,'src','+inkprof','createTarget.m'));
verifyTrue(tc,isfile(fullfile(destination,'local-config','settings.json')));
out=fullfile(p.Projects,'portable-test');
inkprof.createTarget(out,PatchCount=20,GraySteps=3,DPI=100);
verifyTrue(tc,inkprof.verifyPackage(out).passed);
end
function testTargetSizeLimits(tc)
verifyError(tc,@()inkprof.createTarget(fullfile(tc.TestData.scratch,"too-wide"),PaperSizeMm=[321 500]),'inkprof:Paper');
for sizeMm={[320 280],[300 500]}
    out=fullfile(tc.TestData.scratch,"limit-"+sizeMm{1}(1));
    inkprof.createTarget(out,PatchCount=40,GraySteps=3,DPI=100,PaperSizeMm=sizeMm{1});
    r=inkprof.verifyPackage(out);
    verifyEqual(tc,r.pages(1).sizeMm,sizeMm{1},'AbsTol',.26);
end
end
function testNamedPaperFormats(tc)
names=["A4-landscape","A3-portrait"];sizes=[297 210;297 420];
for k=1:2
    out=fullfile(tc.TestData.scratch,names(k));
    m=inkprof.createTarget(out,Paper=names(k),PatchCount=40,GraySteps=3,DPI=100);
    verifyEqual(tc,m.options.Paper,names(k));
    verifyEqual(tc,m.options.PaperSizeMm,sizes(k,:));
    r=inkprof.verifyPackage(out);
    verifyEqual(tc,r.pages(1).sizeMm,sizes(k,:),'AbsTol',.26);
    verifyTrue(tc,r.horizontalRowsVerified);
    pageFiles=dir(fullfile(out,'target*.tif'));pixels=imread(fullfile(pageFiles(1).folder,pageFiles(1).name));
    % Both side margins must carry the same number of gray label pixels.
    yy=ceil(25*100/25.4):floor((sizes(k,2)-25)*100/25.4);
    left=pixels(yy,1:ceil(12*100/25.4),1);
    right=pixels(yy,end-ceil(12*100/25.4)+1:end,1);
    verifyGreaterThan(tc,nnz(left==32768),0);verifyEqual(tc,nnz(right==32768),nnz(left==32768));
    layout=jsondecode(fileread(fullfile(out,'layout.json')));
    a=layout.patches(strcmp({layout.patches.strip},'1'));
    [~,idx]=sort([a.patchInStrip]);rA=reshape([a(idx).rectMm],4,[])';
    verifyEqual(tc,rA(:,2),repmat(rA(1,2),size(rA,1),1));
    verifyTrue(tc,all(diff(rA(:,1))>0));
    verifyEqual(tc,string(a(idx(1)).column),"A");
    verifyEqual(tc,string(a(idx(1)).coordinate),"A1");
    verifyEqual(tc,string(a(idx(1)).location),"1A");
    b=layout.patches(strcmp({layout.patches.strip},'2'));
    if ~isempty(b),verifyGreaterThan(tc,b(1).rectMm(2),rA(1,2));end
end
verifyError(tc,@()inkprof.createTarget(fullfile(tc.TestData.scratch,'conflict'), ...
    Paper="A4-landscape",PaperSizeMm=[210 297]),'inkprof:Paper');
verifyError(tc,@()inkprof.createTarget(fullfile(tc.TestData.scratch,'unknown'),Paper="A3-landscape"),'inkprof:Paper');
end
function restore(oldPath,oldFolder)
cd(oldFolder);path(oldPath);
end
function write(path,text)
fid=fopen(path,'w');c=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end

function testRejectCmykTarget(tc)
for ext=[".cgats",".ti1"]
    f=fullfile(tc.TestData.scratch,"cmyk"+ext);
    signature="CGATS.17";if ext==".ti1",signature="CTI1";end
    text=signature+newline+"COLOR_REP "+char(34)+"CMYK"+char(34)+newline+ ...
        "NUMBER_OF_FIELDS 5"+newline+"BEGIN_DATA_FORMAT"+newline+ ...
        "SAMPLE_ID CMYK_C CMYK_M CMYK_Y CMYK_K"+newline+"END_DATA_FORMAT"+newline+ ...
        "NUMBER_OF_SETS 1"+newline+"BEGIN_DATA"+newline+"1 0 0 0 0"+newline+"END_DATA"+newline;
    write(f,text);
    verifyError(tc,@()inkprof.importTarget(f),'inkprof:ColorFormat');
end
raw=fileread(fullfile(tc.TestData.fixtures,'Chart 2033 Patches.pxf'));
raw=strrep(raw,'ColorRGB','ColorCMYK');f=fullfile(tc.TestData.scratch,'cmyk.pxf');write(f,raw);
verifyError(tc,@()inkprof.importTarget(f),'inkprof:ColorFormat');
end
