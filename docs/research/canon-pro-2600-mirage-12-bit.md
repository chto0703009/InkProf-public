# Canon PRO-2600: 12-bit mode in Mirage

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Documented 2026-09-25. Source: screenshot provided by Christer in the planning conversation. The date refers to the documentation, not to a verified time of the screenshot's creation.

## Directly observed

- Program: Mirage Print; the version line shows Mirage Pro 2026.5.2 (Trial).
- Printer: `Canon PRO-2600 (LUCIA PRO II Ink)`.
- Paper: `Grafisk Handel Pro Luster 260 g`.
- Exact text of the quality field: **`High Quality (600x600 dpi, 12-bit)`**.
- `Finest Details` is selected; the Chroma Optimizer field shows `CO All`.

![Mirage showing 12-bit mode for Canon PRO-2600](assets/2026-09-25-mirage-pro-2600-12-bit.png)

## Interpretation and scope

The screenshot confirms that Mirage specifies 12 bits for the selected print mode. The statement does not refer to the designation "12 Color" or the number of cartridges. It replaces the earlier general uncertainty about whether Mirage specifies such a mode at all.

The screenshot does not establish where in the print chain quantisation takes place, what data format is transferred, or how the printer's internal ink dosing works. It does not prove 4 096 physically distinguishable levels per cartridge and must not be generalised to all quality modes or programs. 600x600 dpi is reproduced as the mode's designation, not as a claim about the print head's maximum resolution.

## Consequences for InkProf

- Keep `double` in calculations and the target of 16-bit TIFF and 16-bit ICC table values. Profile precision and the print mode's bit depth are different properties.
- Record program/version, printer, media setting, the full text of the quality mode, stated bit depth, Finest Details and Chroma Optimizer in the print recipe.
- Use the same print recipe for target printing and later profiled printing. Also record colour management settings; they are not visible in this image.
- State the level of evidence as "observed in the Mirage interface", not "verified internal printer bit depth".

## Traceability

The original image is preserved without image modifications in `assets/2026-09-25-mirage-pro-2600-12-bit.png`.

SHA-256: `491cca056f233c16c5fe550553f0989adedcfe2d69f64126598712fc227b5ca5`
