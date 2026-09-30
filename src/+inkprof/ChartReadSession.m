classdef ChartReadSession < handle
    % Nonblocking JSON-lines controller; raw prompts remain authoritative.
    properties (SetAccess=private)
        Folder
    end
    properties (Access=private)
        Process
        Reader
        Writer
    end
    methods
        function obj=ChartReadSession(folder,options)
            arguments
                folder (1,1) string
                options.ArgyllBin (1,1) string = ""
                options.PythonExecutable (1,1) string = ""
                options.ScanTolerance (1,1) double {mustBePositive,mustBeFinite} = 1
                options.Direction (1,1) string {mustBeMember(options.Direction,["auto","forward","both"])} = "auto"
                options.Resume (1,1) logical = false
                options.Port (1,1) double {mustBeInteger,mustBeNonnegative} = 0
            end
            assert(isunix,'inkprof:Platform','Interactive measurement currently supports macOS/Linux.');
            obj.Folder=inkprof.internal.absolutePath(folder);
            assert(isfile(fullfile(folder,'chart.json')),'inkprof:Input','Prepare a JSON chart first.');
            bin=inkprof.internal.argyllBin(options.ArgyllBin);exe=fullfile(bin,'chartread');
            assert(isfile(exe),'inkprof:Input','chartread is missing from the Argyll directory.');
            runtime=inkprof.checkPython(PythonExecutable=options.PythonExecutable);
            paths=inkprof.paths();script=fullfile(paths.Root,'bridge','chartread_bridge.py');
            argv=java.util.ArrayList();
            args=[runtime.executable,"-u",script,obj.Folder,exe, ...
                "--scan-tolerance",compose("%.17g",options.ScanTolerance),"--direction",options.Direction];
            if options.Resume,args(end+1)="--resume";end
            if options.Port>0,args=[args,"--port",string(options.Port)];end
            for arg=reshape(args,1,[]),argv.add(java.lang.String(char(arg)));end
            % The bridge takes a session lock before adapting JSON to TI2.
            builder=java.lang.ProcessBuilder(argv);builder.redirectErrorStream(true);
            obj.Process=builder.start();
            obj.Reader=java.io.BufferedReader(java.io.InputStreamReader(obj.Process.getInputStream(),'UTF-8'));
            obj.Writer=java.io.OutputStreamWriter(obj.Process.getOutputStream(),'UTF-8');
        end
        function events=poll(obj,waitSeconds,echo)
            % Optional bounded wait avoids polling before startup produces output.
            if nargin<2,waitSeconds=0;end
            if nargin<3,echo=true;end
            validateattributes(echo,{'logical'},{'scalar'});
            validateattributes(waitSeconds,{'numeric'},{'scalar','real','finite','nonnegative','<=',60});
            started=tic;
            while ~obj.Reader.ready() && obj.isRunning() && toc(started)<waitSeconds
                pause(.05);
            end
            events={};
            while obj.Reader.ready()
                line=obj.Reader.readLine();if isempty(line),break;end
                try,event=jsondecode(char(line));catch,event=struct('event','diagnostic','text',char(line));end
                events{end+1}=event; %#ok<AGROW>
                if echo && isfield(event,'text'),fprintf('%s',event.text);end
                if echo && isfield(event,'message'),fprintf('%s\n',event.message);end
                if echo && isfield(event,'event') && string(event.event)=="started"
                    fprintf('chartread har startat. Kör s.poll(10) för nästa dialog.\n');
                elseif echo && isfield(event,'event') && string(event.event)=="exited"
                    fprintf('chartread avslutades med kod %d. TI3 finns: %d.\n',event.exitCode,event.ti3Exists);
                end
            end
        end
        function yes=isRunning(obj)
            yes=~isempty(obj.Process)&&obj.Process.isAlive();
        end
        function sendKey(obj,key)
            key=char(key);assert(numel(key)==1,'inkprof:Input','Send exactly one key; char(13) for Return.');
            assert(obj.isRunning(),'inkprof:Session','Measurement process is not running.');
            obj.Writer.write([jsonencode(struct('command','key','text',key)),newline]);obj.Writer.flush();
        end
        function stop(obj)
            if obj.isRunning()
                obj.Writer.write([jsonencode(struct('command','stop')),newline]);obj.Writer.flush();
            end
        end
        function delete(obj)
            % Closing the controller pipe makes the bridge terminate its child.
            if ~isempty(obj.Writer),try,obj.Writer.close();catch,end,end
        end
    end
end
