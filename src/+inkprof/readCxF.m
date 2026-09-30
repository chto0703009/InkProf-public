function [data,jsonFile]=readCxF(path,options)
%READCXF Validate CxF3 XSD and preserve colour data/specifications in JSON.
% XSD validation is not certification of all ISO 17972 CxF/X workflow rules.
arguments
 path (1,1) string = ""
 options.OutputFile (1,1) string = ""
 options.LayoutFile (1,1) string = ""
end
data=[];jsonFile="";
if path==""
 [f,p]=uigetfile({'*.cxf','CxF3 colour data';'*.*','All files'},'Select CxF3 file');if isequal(f,0),return;end;path=fullfile(p,f);
end
path=inkprof.internal.absolutePath(path);assert(isfile(path),'inkprof:Input','File does not exist.');
info=dir(path);assert(info.bytes<=64*1024*1024,'inkprof:CxF','CxF exceeds the 64 MiB limit.');
paths=inkprof.paths();schemaPath=fullfile(paths.Root,'schemas','cxf3','CxF3_Core.xsd');
w=string(tempname);mkdir(w);cleanup=onCleanup(@()rmdir(w,'s'));
% Snapshot first: schema validation and semantic decoding see identical bytes.
snapshot=fullfile(w,'source.cxf');copyfile(path,snapshot);
raw=fileread(snapshot);assert(isempty(regexpi(raw,'<!DOCTYPE|<!ENTITY','once')),'inkprof:CxF','DTD/entities are not accepted.');
try
 factory=javax.xml.parsers.DocumentBuilderFactory.newInstance();factory.setNamespaceAware(true);
 factory.setFeature('http://apache.org/xml/features/disallow-doctype-decl',true);
 factory.setFeature('http://xml.org/sax/features/external-general-entities',false);
 factory.setFeature('http://xml.org/sax/features/external-parameter-entities',false);
 doc=factory.newDocumentBuilder().parse(java.io.File(char(snapshot)));
 sf=javax.xml.validation.SchemaFactory.newInstance('http://www.w3.org/2001/XMLSchema');
 % MATLAB bundles Xerces versions without JAXP external-access properties.
 % Validate an entity-free DOM against the local self-contained schema only.
 schemaText=fileread(schemaPath);
 assert(isempty(regexp(schemaText,'<xs:(include|import|redefine)\b','once')), ...
     'inkprof:CxFSchema','External schema dependencies are not accepted.');
 sf.setFeature('http://javax.xml.XMLConstants/feature/secure-processing',true);
 schema=sf.newSchema(java.io.File(char(schemaPath)));validator=schema.newValidator();
 validator.validate(javax.xml.transform.dom.DOMSource(doc));
catch err
 error('inkprof:CxFSchema','CxF3 XML/schema validation failed: %s',err.message);
end
args=[snapshot,fullfile(w,'data.json')];
if options.LayoutFile~="",args=[args,"--layout",inkprof.internal.absolutePath(options.LayoutFile)];end
inkprof.runPython(fullfile(paths.Root,'exchange','read_cxf.py'),args);
data=jsondecode(fileread(fullfile(w,'data.json')));data.sourcePath=path;
assert(string(data.sourceSHA256)==inkprof.internal.sha256(path),'inkprof:Integrity','CxF changed during import.');
data.validation.xsdValidated=true;data.validation.schemaSHA256=inkprof.internal.sha256(schemaPath);
data.validation.schemaVersion="CxF3 core 3.0.018";
if options.OutputFile~=""
 jsonFile=inkprof.internal.absolutePath(options.OutputFile);
 assert(~isfile(jsonFile)&&~isfolder(jsonFile),'inkprof:Exists','Output already exists.');
 inkprof.internal.writeJson(jsonFile,data);
 inkprof.internal.recordProjectStep(jsonFile,"CxF3 import with XSD and semantic validation");
end
end
