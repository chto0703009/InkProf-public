# Instrument connection at startup

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

InkProf starts ArgyllCMS chartread to connect to and initialise the spectrometer. Calibration on the instrument’s own white reference remains a separate user action.

If chartread exits with “Initialising instrument failed” and “Communications failure” before any interaction, calibration prompt or saved result, InkProf now reconnects automatically, up to three attempts in total, with a two-second pause between attempts. The previous process must have exited before another starts. Each attempt keeps its own transcript and run JSON, including its attempt number.

This is a fresh ArgyllCMS connection, not a hardware reset or a verified equivalent of i1Profiler’s reset command. InkProf does not automatically press calibration or measurement keys. Calibration failures and failures during scanning are not automatically restarted. Existing measurement results, including resumed sessions, are not replaced by this recovery path.

Closing a chart measurement controller also waits briefly for its bridge to terminate chartread and release the instrument. If startup still fails after three attempts, close the measurement window and other instrument applications, reconnect the instrument’s USB cable, and start again. Do not interrupt an active measurement to do this.

The recovery is tested using a simulated child process that fails twice before connecting, repeated failures, and a failure after a calibration prompt. Successful first-start recovery with the physical instrument still needs to be checked by the user.

ArgyllCMS documents initial calibration separately from connection: [chartread documentation](https://www.argyllcms.com/doc/chartread.html).
