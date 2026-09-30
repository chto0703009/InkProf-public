function tests=testPairedMeasurement
tests=functiontests(localfunctions);
end
function testReverseMappingAndMean(tc)
exercise(tc,false);
end
function testRandomizedReverseMappingAndMean(tc)
exercise(tc,true);
end
function exercise(tc,randomize)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
pkg=fullfile(w,'target');inkprof.createTarget(pkg,PatchCount=20,GraySteps=3,DPI=100,Randomize=randomize,Seed=42);
folder=fullfile(w,'measurement');chart=inkprof.prepareChart(fullfile(pkg,'target.ti2'),folder);
originalHash=inkprof.internal.sha256(fullfile(folder,'source.ti2'));
plan=inkprof.internal.preparePairedChart(folder);steps=chart.stepsInPass;
coordinates=zeros(chart.patchCount,2);
for k=1:chart.patchCount
 [row,~,col]=inkprof.internal.decodeLocation(chart.patches(k).sampleLoc);coordinates(k,:)=[str2double(row),col];
end
[~,order]=sortrows(coordinates,[1 2]);
verifyEqual(tc,plan.originalChartIndex(1:steps),order(1:steps));
verifyEqual(tc,plan.originalChartIndex(steps+1:2*steps),flipud(order(1:steps)));
if randomize,verifyNotEqual(tc,order,(1:chart.patchCount)');end
verifyEqual(tc,plan.scanNumber(steps+1:2*steps),repmat(2,steps,1));
runtime=fullfile(folder,'paired');pairChart=jsondecode(fileread(fullfile(runtime,'chart.json')));
verifyEqual(tc,pairChart.sourcePatchCount,2*chart.sourcePatchCount);
p=pairChart.patches;real=find(~[p.isPadding]);
f=fopen(fullfile(runtime,'chart.ti3'),'w');
fprintf(f,'CTI3\nCOLOR_REP "RGB_XYZ"\nNUMBER_OF_FIELDS 10\nBEGIN_DATA_FORMAT\nSAMPLE_ID SAMPLE_LOC RGB_R RGB_G RGB_B XYZ_X XYZ_Y XYZ_Z SPEC_400 SPEC_500\nEND_DATA_FORMAT\nNUMBER_OF_SETS %d\nBEGIN_DATA\n',numel(real));
for index=reshape(real,1,[])
    original=plan.originalChartIndex(index);phase=plan.scanNumber(index);
    base=original/10;extra=2*(phase-1);
    fprintf(f,'%s "%s" %.12g %.12g %.12g %.12g %.12g %.12g %.12g %.12g\n', ...
       p(index).sampleId,p(index).sampleLoc,p(index).rgbPercent,base+extra,base+extra,base+extra,base+extra,base+extra);
end
fprintf(f,'END_DATA\n');fclose(f);
raw=inkprof.importChartMeasurement(runtime);result=inkprof.internal.averagePairedMeasurement(folder,raw);
verifyTrue(tc,result.complete);verifyEqual(tc,result.measuredSourcePatches,chart.sourcePatchCount);
physical=find(~[chart.patches.isPadding]);expected=physical(:)/10+1;
verifyEqual(tc,result.data.spectra,[expected expected],AbsTol=1e-9);
verifyEqual(tc,result.data.xyz,[expected expected expected],AbsTol=1e-9);
verifyEqual(tc,result.pairedReadings.spectralRmsDifference,repmat(2,numel(expected),1),AbsTol=1e-9);
verifyEqual(tc,string(result.data.locations),string({chart.patches(physical).sampleLoc})');
verifyEqual(tc,inkprof.internal.sha256(fullfile(folder,'source.ti2')),originalHash);
verifyTrue(tc,isfile(fullfile(runtime,'chart.ti3')));
raw.complete=false;verifyError(tc,@()inkprof.internal.averagePairedMeasurement(folder,raw),'inkprof:Measurement');
end
