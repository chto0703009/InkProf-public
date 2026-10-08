# Remeasure one printed row

In the saved measurement overview, select a patch on the affected row and click **Remeasure row**. The new window lets you select **Page** and **Row**. The row number is the number printed on the sheet, rather than an index relative to the page.

**Measure selected row** prepares a separate one-row measurement session. Use the same original printed sheet, backing and instrument. The original scan mode, condition request, scan tolerance and port are retained:

- Single direction: one forward scan.
- Alternate rows: the forward/reverse instruction corresponds to the original row’s traversal position, even though the reread session contains only one row.
- Forward + reverse average: scan the same row forward and reverse. The two spectra and XYZ readings are averaged as in the initial measurement.

The measurement window displays the original page and row numbers and the current scan direction. Calibrate and measure using the usual controls and hardware button, then save. A table shows the change from the previous value for each patch, and the new forward/reverse maximum when available. These are change/repeatability diagnostics, not print accuracy.

**Accept row replacement** creates a new measurement JSON and TI3 in the original session, replacing only the selected row’s source patch values. Patch IDs, original locations, RGB, all other rows and the parent revision remain intact. The original chart, the one-row definition, both raw scans in paired mode, candidate and decision are retained in `row-rereads`. Incomplete rows or incompatible conditions, instrument identity, calibration standard or spectral bands are rejected.

Old forward/reverse statistics remain explicitly historical in the overview for replaced rows. New row statistics are stored with the row override. Accepted spot replacements on that row are superseded; their evidence remains in the previous revision. Discard/Close leaves the current measurement unchanged. Original scan settings, spectra and XYZ must be available to use this feature.
