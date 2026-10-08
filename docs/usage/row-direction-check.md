# Scan direction and row-order diagnostics

> InkProf 1.0.0-rc.3, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

The measurement dialog states FORWARD (left to right on the printed chart)
or REVERSE (right to left). The direction is recalculated from the selected
pass after Previous, Next and Next unread; navigation does not count as a
scan. Single direction uses chartread `-B`. Alternate rows uses automatic
bidirectional recognition (`-b`), which may be ambiguous on charts without
randomized patch positions. Paired mode retains its explicit forward/reverse
pass plan. The selected row and direction remain visible when all rows have
been read, so rereading remains possible.

Each newly imported measurement stores `rowDirectionCheck` in its JSON.
The Python diagnostic compares stored XYZ with approximate TI2 XYZ, using
the same D50 adaptation assumption as the existing target check. It compares
normal and reversed patch order within each complete physical row, sorted
by column coordinate rather than file order. Partial rows, including rows
with omitted padding, are excluded. Incomplete measurements or missing
reference/XYZ data produce an explicit unavailable result; analysis errors
do not prevent the measurement being saved.

A row is flagged only if mean forward error exceeds 10 ΔE00, reversing
reduces the mean by more than 5 ΔE00 and to less than half its former value.
These are conservative diagnostic thresholds, not profile acceptance limits.
The saved-measurement window lists suspected rows and recommends rereading
in Single direction. No spectra, XYZ, patch identities or order are changed.
TI2 estimates are not measured truth: false positives and missed reversals
remain possible. Older measurements are not rewritten retroactively.

Validation on the original 575-patch measurement dated 2026-09-27 flags
exactly rows 22 and 23, independently of the later MXF comparison. Synthetic
tests cover reversed rows, shuffled storage order, correct rows, symmetric
rows and missing columns. Hardware behaviour still needs a manual check.
