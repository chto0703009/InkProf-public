# Save and resume chart measurement

Available in v1.1.1, 2026-10-14. Real-instrument resume validation remains necessary.

During measurement, choose **Save completed rows / pause** at a row prompt. The button becomes available after a completed physical row. If selected during a scan, saving waits for the instrument to return to a row prompt and excludes the row in flight. With forward/reverse averaging, a row with only one completed scan is omitted from the checkpoint; resume reads that row again in both directions. You can also pause before loading the next page.

Wait for **Completed rows saved - measurement paused** before closing the window. Use **Open results folder** to locate the saved session. The raw readings are saved as an immutable checkpoint, with the chart, scan settings and checksums. This does not accept a measurement revision or complete the workflow step.

To continue, open the measurement routine for the same target and choose **Resume saved session…**. Select the saved measurement session folder containing `measurement-checkpoint.json`. The dialog shows the number of saved complete rows, the first unfinished page and printed row, and the required scan direction. In paired mode it explains that the row restarts forward and then reverse. Then choose **Resume measurement** and confirm **Resume same printed sheets**. The confirmation defaults to Cancel and explains that new or replaced sheets require a new session and fresh RGB checks. Calibrate when prompted, and scan the displayed page and row. The original scan mode, tolerance, condition and port are reused. Approved RGB controls from that session are retained for the same physical print.

InkProf resumes with Argyll's `chartread -r`. Previously saved scans remain present, and the selection moves to the first unread scan. In paired mode, continue to follow the displayed forward/reverse instructions. After all rows have been measured, choose **Save and finish** and review the resulting measurement revision as usual.

An unexpected interruption can lose scans taken since the last checkpoint. It does not invalidate the immutable snapshot of the last successful pause. Resume restores that checkpoint and retains a copy of the working TI3 before restoring it. Do not reuse checkpoints after changing the printed chart or replacing pages. A changed chart, settings or checkpoint snapshot is rejected.

For remeasurement of the same physical print in a new session, the RGB dialog also offers **Reuse checks for same print**. Select the earlier measurement session containing the approved control check. A new physical print requires fresh RGB controls on all pages.

Source: [ArgyllCMS chartread, partial saves and resume](https://www.argyllcms.com/doc/chartread.html).
