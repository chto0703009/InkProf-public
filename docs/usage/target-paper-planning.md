# Paper suggestions and measurement-sled limits

> v1.0.0 preparation (1.0.0-rc.1), reviewed 2026-10-03. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

InkProf proposes an editable target size from the actual number of source patches. Refinement counts include the new colours **and** repeated control patches. Patch size and contrast spacers are preserved; fewer patches can occupy a smaller piece of paper.

## Project settings

Open **Project details → Target paper**:

- **Maximum measurement sweep (mm)**: available horizontal travel, including the target margins.
- **Maximum target length (mm)**: the other measurement-piece dimension, including heading and footer.
- **Roll width (mm)**: physical width of your roll.

The initial 320 × 370 mm limits describe Christer's measurement sled, not a universal instrument limit. They can be increased or decreased. Defaults are read from `config/target-paper-defaults.json`. Each new project stores its own `paperLayout` object in `inkprof-project.json`, so the settings move with the project:

```json
"paperLayout": {
  "MaxScanMm": 320,
  "MaxLengthMm": 370,
  "RollWidthMm": 329
}
```

Older projects use the JSON defaults until their settings are saved. Saving target-paper preferences does not invalidate existing profiling or measurement results. A target package records the limits used when it was created; later preference changes do not retroactively change its verification criteria.

## Choosing a proposal

For a base target, open **Paper suggestions…** in the TIFF16 dialog. Workflow C2 and refinement-target generation also open the same suggestions dialog. The list compares:

- A5, A4, A3 and A3+ (329 × 483 mm), both orientations;
- whole, half and quarter sheets, including half A3+;
- roll pieces in both orientations, with feed length in 5 mm increments and, where useful, several pieces cut across the roll width.

Suggestions are ranked by the estimated total area of the measurement pieces, then the stock area required. The table distinguishes **used area**, **stock area**, **stock sheets / roll strips**, and **total roll feed**. Remaining cut pieces can be saved for later. Select a row and edit its sweep and length before accepting. Editing dimensions turns the selection into a custom format: the original proposal's stock calculation is then only a reference, not a revised cutting plan.

**Preview selected dimensions** renders a temporary target and shows the actual page count. The base-target dialog also has **Calculate / preview**. Final rendering always checks TIFF16 pixel values, patch identities, physical dimensions and layout. Suggestions estimate capacity from standard i1 geometry (10 mm patches along the sweep, 1 mm spacers and 8 mm row pitch), with room reserved for margins and headings. They are not a guarantee of the minimum possible paper consumption. Custom patch scales or spacers can change capacity.

A minimum suggested sweep of 148 mm and length of 80 mm leaves room for readable print furniture. This is a layout constraint, separate from the adjustable sled limits. Small targets use a stacked footer with the complete TIFF path, date and page number. Extremely long paths or custom dimensions can still require a larger target to keep text readable.

## Printing and traceability

Each TIFF represents one measurement piece. The app does not impose several TIFFs onto a larger sheet or roll automatically. Stock-use estimates for several pieces assume that you arrange them in your printing application, or cut the stock into the stated pieces. Keep the shown dimensions and print at **100%**, without fit-to-page. Account for the printer's own printable margins when arranging pieces.

`paper-layout.json` in the print package stores the source-patch count, selected proposal, edited dimensions, settings and actual page count. `target.json` and `manifest.json` record the physical dimensions and measurement limits; their package hashes protect the new files. The matching TI2 and layout JSON identify the exact page and position to measure.

When C2 already has a generated verification definition, InkProf creates a new layout from those frozen RGB/Lab values and updates only the placements and package references. It does not apply the ICC again. Existing target packages and measurements are retained.

After measurement, use [ICC comparison](profile-comparison.md) for numerical differences between iterations, and independent print verification to assess whether measured print accuracy improved.
