% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
classdef RunProgress < handle
    % Own resources independently of the workflow callback's local workspace.
    properties
        Watch = []
        Progress = []
        Finished = false
    end
    properties (Access=private)
        Release
        Released = false
    end
    methods
        function obj=RunProgress(release)
            obj.Release=release;
        end
        function cleanup=guard(obj)
            % Capture the owner here, outside the exiting run workspace.
            cleanup=onCleanup(@()obj.finish());
        end
        function stop(obj)
            if ~isempty(obj.Watch)&&isvalid(obj.Watch)
                stop(obj.Watch);delete(obj.Watch);
            end
            obj.Watch=[];
            if ~isempty(obj.Progress)&&isvalid(obj.Progress),close(obj.Progress);end
            obj.Progress=[];
        end
        function finish(obj)
            obj.stop();
            if ~obj.Released
                obj.Released=true;
                release=obj.Release;obj.Release=[];
                release(obj.Finished);
            end
        end
    end
end
