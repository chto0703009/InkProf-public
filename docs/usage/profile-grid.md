# C1 – RGB grid, inverse, gray ramp and CMM comparison

> InkProf 1.0.0-rc.2, version marking updated 2026-10-08. See the [current app workflow](workflow-v1.0.md) for the complete 19-step process. Dated experiments and legacy examples below retain their original scope.

```matlab
[gridReport, gridFile] = inkprof.checkProfileGrid(jobFolder);
```

The default grid is 9×9×9 = 729 RGB points; `GridLevels` can be set from 3 to 25. The window shows statistics, the equal-RGB gray ramp, and the RGB channels obtained from neutral Lab through the inverse. `ShowDialog=false` is supported. Results are saved in the job's `checks/<UUID>` folder as JSON and Markdown, and the manifest is updated.

## Roundtrip

The computation uses `xicclu -ir -pl` without black point compensation. Forward goes through A2B; backward goes through the stored B2A table (`-fb`), not through numerical inversion of A2B (`-fif`).

RGB → Lab → RGB → Lab is checked with ΔE00 and with RGB error in percentage points. The number of RGB values outside the cube is reported without clipping them first. Non-finite values and a wrong number of tool results are rejected.

## Transitions and ramps

- **Transitions:** 27 lines (three axes, with the other channels at 0, 0.5 and 1), 257 samples each. The Lab76 norm of the second difference is reported. Values above 1 Lab unit are diagnostic candidates, not a general acceptance limit.
- **Gray ramp:** 257 equal-RGB values. Decreases in L* larger than 0.001 are counted.
- **Neutral Lab ramp:** a separate ramp tests the inverse from the profile's black L* up to 100. The neutral points are not guaranteed to be in gamut.

## CMM comparison

Pillow/LittleCMS is compared with Argyll, forward and backward, at the same quantized inputs, with relative colorimetric intent and BPC off.

The RGB/Lab interface is 8-bit. NumPy's representation of Pillow LAB has signed, byte-wrapped a/b channels; this is handled explicitly and tested against Pillow pixels. The result is a limited CMM check, not floating-point precision or broad compatibility certification.

## Interpretation

- A synthetic grid is separate from the measurement points, but it is not an independent measured control.
- A large RGB roundtrip deviation can be caused by non-uniqueness, gamut limits or approximation in the inverse. It must not be dismissed as harmless without further review.
- The distance between neighbouring points is a gradient, not automatically a discontinuity.
- A finite number of samples cannot prove smoothness everywhere.
- Equal RGB is not a requirement for neutral Lab on an uncorrected printer.

## Testing

Seven automatic tests cover tool output, errors, non-finite values, grid size and Lab encoding. The current 575-patch profile has been run through the MATLAB window.

A first internal trial had the wrong Lab encoding in the CMM comparison. That report is marked `invalid-cmm-comparison` and must not be used. Corrected reports are generated with the current code.

[Argyll xicclu](https://www.argyllcms.com/doc/xicclu.html) documents the difference between the backward table and the inverted forward table, and relative versus absolute colorimetric. Profile quality in real printing still needs to be verified with new measurements.
