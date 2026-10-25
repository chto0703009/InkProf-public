% Copyright (c) 2026 Christer Törnkvist.
% SPDX-License-Identifier: GPL-3.0-or-later
% InkProf is free software under GNU GPL version 3 or later.
% Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
function measurementStartTone()
% Short start cue matching SpectraLab: 1200 Hz for 120 ms.
% Audio availability must never block the measurement workflow.
try
    rate=16000;
    t=(0:round(.120*rate)-1)'/rate;
    signal=.45*sin(2*pi*1200*t);
    ramp=linspace(0,1,round(.010*rate))';
    signal(1:numel(ramp))=signal(1:numel(ramp)).*ramp;
    signal(end-numel(ramp)+1:end)=signal(end-numel(ramp)+1:end).*flipud(ramp);
    player=audioplayer(signal,rate);
    % Finish the brief cue before spotread can take over audio output.
    playblocking(player);
catch
    % Fall back to the system cue if MATLAB cannot open an audio player.
    try,beep;catch,end
end
end
