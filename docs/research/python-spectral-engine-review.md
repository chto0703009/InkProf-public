# MATLAB Base, Python and spectral profiling in InkProf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-26. Status: review and recommended way forward; no new calculation engine is implemented by this document.

## Recommendation

Keep MATLAB Base as the user interface and project-leading layer. Use Python for new spectral calculations, model fitting and constrained numerical optimisation. Keep ArgyllCMS for instrument communication and as the first ICC profile engine and comparison reference. JSON remains the internal data model; TI1/TI2/TI3 are exchange formats.

The next concrete delivery should be a verifiable calculation chain from existing measured spectra to XYZ, Lab and comparisons. After that come ICC profiling and independent validation. An own spectral inverse model and optimisation under several light sources are later steps.

The choice of Python is motivated mainly by the availability of established numerical libraries without MATLAB add-ons. The change of language in itself improves neither measurement data nor grid distribution. Working MATLAB code does not need to be rewritten merely for uniformity.

## What already exists, and does it require MATLAB add-ons?

The local code review covered the MATLAB code, the Python start-up and the chartread bridge. `matlab.codetools.requiredFilesAndProducts` was run in R2025b Update 7 on 60 MATLAB files including setup. The analysis reported **only MATLAB** as a required product, with 60 dependency files identified. The report is stored locally in `work/review-python-20260926/matlab-dependencies.json`.

This is a static analysis, not proof of all dynamic run paths. The computer has several add-ons installed; an acceptance test on an installation with only Base remains. Nor does the analysis say anything about external Python or Argyll dependencies.

MATLAB Base already has [Delaunay triangulation](https://www.mathworks.com/help/matlab/ref/delaunaytriangulation.html), [scattered interpolation](https://www.mathworks.com/help/matlab/ref/scatteredinterpolant.html), linear algebra and [fminsearch](https://www.mathworks.com/help/matlab/ref/fminsearch.html). The latter searches for a local minimum without explicit constraints. [lsqnonlin](https://www.mathworks.com/help/optim/ug/lsqnonlin.html), by contrast, belongs to the Optimization Toolbox. Spectral integration does not in itself require an add-on; it can be expressed with ordinary matrices.

The current Python bridge uses the standard library. InkProf already has selection of Python per computer, checking of the runtime environment and invocation as a separate process. This is a suitable foundation to build on.

## Critical review of the submitted text

The text identifies the value of keeping spectra, but the code examples are not production-ready. The following needs to be corrected before they can be used as a model.

| Claim or construction | Assessment and consequence |
|---|---|
| ICC/LittleCMS is insufficient for the whole workflow | They do not replace spectral analysis, but remain relevant for ordinary ICC-based colour conversion. Spectral analysis and ICC delivery can coexist. |
| Spectrum → XYZ → sRGB gives the printer's RGB | sRGB is a defined colour space, not Canon's device RGB. Printer values require a printer profile or a measured inverse model. |
| D50 XYZ is passed to standard calls for sRGB | The white point must be specified and chromatic adaptation handled. The standard calls must not be assumed to understand that the input refers to D50. |
| A spectral value at 500 nm is used as the Lab white point | Wrong kind of quantity. The Lab conversion needs the white point's chromaticity, not the light source's power at a single wavelength. |
| Lab under several light sources is computed with a standard white point | Each calculation needs an explicit and consistent reference white point. Otherwise even ΔE becomes misleading. |
| Four random ink curves are summed linearly | This is not a calibrated model for overprint. Zero ink gives black in the example, not paper; increased positive weights make it lighter. The clipping also creates artificial plateaus. |
| CMYK weights are optimised for Canon | InkProf controls RGB in the current workflow. The internal ink channels are not accessible through this interface. |
| The same RGB reference defines the original under all lights | Three colour coordinates do not determine a unique reflectance spectrum. A reference spectrum or an explicit assumption is required. |
| A weighted sum of ΔE is called SMI and gives a guarantee | It is a chosen optimisation measure, not thereby a verified standardised metamerism index. Local optimisation guarantees neither a global optimum nor a physical print result. |
| F11 represents LED lighting | F11 refers to a fluorescent standard illuminant. Real LED lighting must be described by a suitable or measured spectral distribution. |

Colour states that [`XYZ_to_Lab`](https://colour.readthedocs.io/en/develop/generated/colour.XYZ_to_Lab.html) takes the white point as xy or xyY and normally uses D65. [`sRGB_to_XYZ`](https://colour.readthedocs.io/en/develop/generated/colour.sRGB_to_XYZ.html) and [`XYZ_to_sRGB`](https://colour.readthedocs.io/en/develop/generated/colour.XYZ_to_sRGB.html) require that the chosen white point and adaptation are understood. A variable called `cmyk_profiles` does not become CMYK or an ICC profile by containing sRGB numbers.

Colour's documentation illuminant table uses the key [`FL11`](https://colour.readthedocs.io/en/v0.3.16_b/generated/colour.SDS_ILLUMINANTS.html), not the example's `F11`. Keys and API must be checked against the version that is actually pinned and tested.

## The correct mathematical starting point

For a non-fluorescent reflectance sample r and a light source E, relative colorimetry is computed discretely as

```text
k = 100 / sum(E_i * ybar_i * delta_lambda_i)
X = k * sum(r_i * E_i * xbar_i * delta_lambda_i)
Y = k * sum(r_i * E_i * ybar_i * delta_lambda_i)
Z = k * sum(r_i * E_i * zbar_i * delta_lambda_i)
```

A perfect diffuse reflector gets Y=100. The reference white point is computed with r=1 on the same wavelength basis. Library calls that use XYZ on the 0–1 scale must be given corresponding scaling. This is relative colorimetry; it is not automatically absolute luminance or a complete description of colour appearance.

Wavelength range, interpolation method and extrapolation must be documented. 400–700 nm and 380–730 nm must not be treated as identical complete spectra. [`sd_to_XYZ`](https://colour.readthedocs.io/en/develop/generated/colour.sd_to_XYZ.html) offers different calculation methods and normalisations; we need to choose and test an explicit convention.

Optical brighteners make relighting more complicated: the measured spectral response may depend on the UV content of the measurement light. M0/M1/M2 must be preserved and must not be mixed as equivalent samples. A simple reflectance integral must not be promised as an exact prediction for arbitrary illumination on fluorescent paper.

## The model for our RGB printer

The relevant forward model is

```text
u = (R, G, B), 0 <= u_j <= 1
F(u; paper, print mode, driver settings) = measured spectral response
```

It covers the whole locked print chain. The number of cartridges does not give a corresponding number of controllable variables. Start with an empirical RGB model from measurements. Spectra can be modelled directly or through a low-dimensional basis, for example SVD/PCA with Base or NumPy. The choice of model, number of components and regularisation should be decided with separate validation. Constraints on reconstructed spectra must take into account whether the data contains fluorescence; blind clipping to 0–1 is not a universal solution.

A later inverse can search for RGB that minimises colour error under one or more specified lights, with RGB bounds and regularisation. For a known reflectance original, both samples can be computed under the same light and compared. If the original is only RGB, the task must instead be formulated as a chosen colour reproduction target; its true metamerism is unknown.

With three control variables we cannot promise independent control of the colour under several lights. An improvement under one light may worsen another. Improvement must therefore be reported per light source and verified with new prints.

Local Taylor expansion with an approximated Jacobian is a reasonable numerical method. Combine it with bounded steps, scaling and regularisation when the inverse is ill-conditioned. Fast convergence does not prove that the model is correct. SciPy's [`least_squares`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html) offers bounds, numerical Jacobians and robust loss functions. The function needs a residual vector; a weighted sum of ΔE should not be treated without thought as the same least-squares problem. Neither an approved solver status nor a low training deviation replaces physical validation.

## Division of work

| Part | Recommended responsibility |
|---|---|
| Windows, file selection, preview and presentation | MATLAB Base; English texts |
| Existing definition, layout and TIFF16 | Keep the working implementation |
| Instrument and strip reading | Argyll chartread via InkProf's own Python bridge |
| Spectral colorimetry and ΔE00 | Python, NumPy and Colour Science, with reference samples |
| Model fitting and constrained inverse | Python/SciPy when validated data exists |
| ICC generation and profile lookup | Argyll colprof and xicclu as the first engine |
| Data, identities and traceability | Versioned JSON; format adapters at import/export |

An ordinary ICC profile uses a colorimetric PCS. This means that the profile's standard transform does not preserve the whole spectrum, not that the measurements' spectra need to be discarded. ICC describes [XYZ/Lab-based PCS and spectral extensions](https://www.color.org/iccmax/connection1/); [iccMAX](https://www.color.org/iccmax/) has spectral capabilities. iccMAX should not be introduced as a requirement before support in the print chain and the need have been shown.

[Argyll colprof](https://www.argyllcms.com/doc/colprof.html) is the first profile reference. [profcheck](https://www.argyllcms.com/doc/profcheck.html) can compare a profile and TI3, including CIEDE2000 with `-k`. We need to distinguish the profile's forward-model error from a real check print through the profile: the latter tests also the inverse, rendering intent and the actual print chain.

## Portable Python and data contract

Reuse separate processes and the existing path configuration. MATLAB sends a versioned JSON job and receives a result file, status and log back. Do not use machine-bound Python paths in the saved project definition. Relative resources, program configuration and source data should be kept apart. Write results atomically and preserve input unchanged.

Keep the working measurement bridge without new heavy dependencies. Put the analysis packages in a separately defined and tested dependency group. Pin Python and package versions only after testing on supported computers; InkProf's current minimum version is not automatically sufficient for new libraries. Colour's reviewed [development metadata](https://github.com/colour-science/colour/blob/develop/pyproject.toml) states Python >=3.11,<3.15 for 0.4.7. This is not a notice to install the development branch or a claim that it has been tested in InkProf.

JSON needs to carry patch ID, device RGB and scale, physical position and page number, raw spectrum with wavelengths/units, instrument/measurement conditions, repeats, source file and hash. Derived results are stored separately with light source, observer, white point, scaling, integration method, program versions and source reference. Model results should additionally have training/validation roles, parameters, residuals and convergence status. The existing targetInfo should be reused, not duplicated with diverging metadata.

## Implementation and acceptance

1. **Establish the colorimetry contract.** Inventory real JSON/TI3/MXF spectral data and identify missing metadata. Preserve unknown fields as unknown; do not guess M-mode, scale or illumination.
2. **Build Python analysis as the first new engine.** Read an existing measurement and give traceable XYZ/Lab. Test white/black/neutral, percent versus 0–1, different spectral ranges, erroneous data and published ΔE00 reference cases. Compare with Argyll when the conditions are really the same; explain method differences before accepting tolerances.
3. **Build the ICC baseline.** Create TI3 from validated internal data, generate an RGB profile with Argyll and report ΔE00 on separate check patches. Then test a physical print with the profile. Grey scale, maximum and percentiles are reported together with the mean error.
4. **Build an empirical model and feedback.** Compare simple models before adding complexity. Densify areas with demonstrated model error and insufficient support, according to the plan for error-driven densification. Use repeats to separate measurement noise from model error. When check samples are used to choose the next grid, new untouched final checks are needed.
5. **Try multi-light optimisation.** Only when a reference spectrum or a defined colour reproduction target exists. Report trade-offs, sensitivity and real measurement verification; do not call an own measure a standardised metamerism index.

Geometric distance in RGB is a coverage measure. ΔE00 after measurement is a colour error. Uncertainty in a model is a third measure. They need separate names and fields, even if they are later combined to choose new patches.

## Scope of this review

Official documentation has been reviewed for MathWorks, SciPy, Colour Science, ICC and ArgyllCMS. The submitted code has been reviewed as a proposal, not approved by running it. No new Python packages have been installed, no physical measurement has been run and no spectral optimisation engine has been added. The recommendation supplements the project plan; it does not replace existing working measurement and target flows.
