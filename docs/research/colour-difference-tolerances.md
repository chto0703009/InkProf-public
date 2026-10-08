# Colour deviation, industry tolerances and acceptance in InkProf

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Added 2026-09-29 after the user's input and source checking. This is
background and support for the choice of acceptance criteria. No code limits are changed by
the document and earlier measurements receive no new approval status.

## Scope of the standard and which Delta E is meant

ISO 12647 is a series for process control in graphic production.
**ISO 12647-2:2013 applies to offset lithographic processes**, not to all printing
or to a general tolerance for every colour on an RGB-driven inkjet printer.
Digital contract proofs are covered by **ISO 12647-7**. Using an inkjet printer
for a proof does not in itself make the print standard-compliant.
[ISO's description of 12647-2](https://www.iso.org/standard/57833.html),
[Fogra on digital proofs](https://fogra.org/en/certification/prepress-technology).

ΔE is not an unambiguous formula. InkProf uses CIEDE2000, written **ΔE00**, for
its current colour error comparisons. The formula corrects for irregularities in CIELAB's
relationship to visual colour difference. It must not be confused with CIELAB 1976,
**ΔE*ab**. A tolerance figure must always be accompanied by the formula; a limit value
cannot be transferred between the formulas by merely changing the designation.
[CIE's description of CIEDE2000](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1).

CIEDE2000 is relevant for small colour differences, but the claim that it always
corresponds "best" to visual impression is too general. Sample size, surround and
viewing method matter. Assessment of colour patches and of whole images is
not the same task.
[CIE on small colour differences](https://www.cie.co.at/publications/validity-formulae-predicting-small-colour-differences),
[CIE on colour differences in images](https://www.cie.co.at/publications/methods-evaluating-colour-differences-images).

## Correction of the proposed industry limits

- **"5.0 is the official maximum limit and everything below is approved"** must not
  be used as a general rule. State the standard part, edition, formula, reference,
  patch group and whether the limit applies to mean, maximum or percentile.
- **"2–3 is standard at most print shops"** can be discussed as a
  practical contract or project target, but does not prove a universal requirement.
- **"At most 1.0 is required for digital proofs"** is not a general requirement in
  ISO 12647-7. Such a figure may be one's own stricter target for selected
  colours, with clearly stated measurement and assessment conditions.

A concrete example is *MediaStandard Print 2018* from Bundesverband Druck und Medien (bvdm), the German Printing and Media Industries Federation, table 30, printed
page 50. It summarises job-related digital proof control
with a media wedge based on ISO 12647-7:2016:

| Check | Stated tolerance, ΔE00 |
|---|---:|
| Mean over all colour fields of the media wedge | ≤ 2.5 |
| Maximum over all colour fields of the media wedge | ≤ 5.0 |
| Solids of the primary colours | ≤ 3.0 |
| Paper white | ≤ 3.0 |

There are further requirements. The table is **not a complete certification test**
and must not be transferred directly to InkProf's optional RGB targets. It shows why
neither "all proofs must be below 1" nor "all values below 5 are approved"
is a correct summary.
[Bundesverband Druck und Medien (bvdm), MediaStandard Print 2018, table 30](https://www.bvdm-online.de/fileadmin/user_upload/01_Global/Downloads_PDF_DOC/Downloads_Technik/MediaStandard_Print_2018.pdf#page=50).

The exact requirements for a formal standard claim need to be checked against the
chosen standard edition and its whole testing procedure. Here, public
standard descriptions and the industry organisation's published summary
have been used, not a complete clause review of the ISO standards.

## Approximate visual interpretation

The following retains the user's intervals as **pedagogical orientation**, not
as ISO limits or verified universal perception thresholds:

| ΔE00 | Cautious interpretation when comparing colour samples |
|---|---|
| < 1.0 | Very small difference; may still be visible under favourable comparison conditions. |
| 1.0–2.0 | Small difference that can be detected in side-by-side comparison. |
| > 2.0–3.5 | May be noticeable; acceptance depends on colour, subject and contract. |
| > 3.5–5.0 | May be clear, especially in sensitive neutral areas or reference colours. |
| > 5.0 | Should be examined specifically; the figure alone determines neither visual impression nor standard deviation. |

"Completely invisible" and "completely deviating colour" should be avoided as absolute conclusions.
Lightness, hue, area size, texture, gloss, surround, illumination and observer
affect the assessment. The sharp interval boundaries above are a way of
presenting orders of magnitude, not steps in human colour vision.

## Paper, measurement conditions and reference

Paper whiteness, optical brighteners, surface texture and gloss affect the measured and
perceived colour. Coated and uncoated paper have different conditions.
This does not mean that a chalk-white or glossy paper always gives the lowest error:
the reference must be relevant to the material and the printer's attainable
colour gamut. Substrate and process choices are part of the choice of production standard.
[ISO/TC 130's guidance on production standards](https://committee.iso.org/files/live/sites/tc130/files/Resources/Guidelines%20for%20using%20print%20production%20standards%20v2%20Jan%202024.pdf).

For InkProf, a comparison must therefore document reference, illuminant and
observer, M0/M1/M2, measurement geometry, substrate/backing, paper, drying time and
print settings to the extent they are known. Unknown information must be
marked as unknown. A ΔE00 in D50 does not by itself describe metamerism under
other light sources.

## Significance for InkProf's iteration and acceptance

Distinguish between four measures:

1. **Training error:** the model's fit to the samples used in profiling.
2. **Development error:** separate samples that influence model choice and new patches.
3. **Print error:** a new physical print compared against the intended colour reference.
4. **Regression:** the increase of an existing error when one candidate is compared with
   another candidate on the same samples.

`MaxPatchRegression=0.5` means, for example, a permitted **increase** of 0.5 ΔE00
in the patch's error. It is not an absolute colour tolerance of 0.5 and not an
ISO requirement. Nor is `NormTarget=1` a requirement for certified proofs.
InkProf's weighted RMS norm must not be equated with an arithmetic mean error.

In the test with 911 training patches, the high variants gave lower overall error but
were stopped by the regression rule. The industry's absolute tolerances do not
alone decide whether that rule should be changed. A useful future acceptance policy
should state separate targets for mean, P95, maximum, greyscale and important colours,
and permitted local regression. For each limit, patch group, colour formula,
reference and measurement conditions are needed. Measurement variation must be taken into account for small differences.

## Decided principle: final quality and iteration diagnostics

The user's clarification 2026-09-29: colour errors are to be put in relation to
the requirements for the final result, while even small changes are used to
understand how the iteration develops. These two uses need different
decision rules.

**Example: the same patch goes from 0.6 to 0.7 ΔE00 against the same reference.**
The final error is 0.7 and the increase is 0.1. If both values lie within the project's
accepted quality range, the increase is not in itself a problem in the final result.
It is to be logged as information about the direction of the iteration, but should not alone
stop a candidate that improves the whole. The increase in the reference error is not
the same as the colour distance between the two candidates' colours.

For future selection logic, the following direction applies:

- **Final quality:** assess the absolute error against agreed requirements for the relevant
  patch group, together with mean, P95 and maximum.
- **Iteration diagnostics:** preserve earlier error, new error and the change,
  even when both results are acceptable. Follow recurring deteriorations
  over several iterations and use them for analysis and prioritisation of new samples.
- **Decision:** small deteriorations within accepted quality are primarily diagnostics.
  Larger regressions and exceeded quality limits are to weigh more heavily in
  profile selection and be able to trigger review. An improved mean error must not hide
  unacceptable local errors.
- **Priorities:** greyscale and particularly important colours may have stricter
  absolute requirements and regression rules than other colours.
- **Measurement variation:** a change of 0.1 may lie within the variation, but must
  not automatically be dismissed as noise. The assessment requires repetitions or
  other documented uncertainty information.

This is a decided development principle, **not an already implemented change to
the selection algorithm**. The current `MaxPatchRegression` rule does not yet take into
account whether the patch's absolute final error lies within an accepted range.
The example 0.6 → 0.7 already passes the current regression limit of 0.5, but
the principle means that future rules are also to weigh in the absolute quality level.
No new general acceptance limits are established here.

This document introduces **no new automatic approval policy**. The choice of
project limits is to be presented as separate requirements unless it concerns a complete
test according to an explicitly chosen standard.

Related: [automatic profile iteration](../usage/automatic-profile-iteration.md),
[iteration strategy](../planning/profile-iteration-strategy.md).

Bundesverband Druck und Medien (bvdm) is the German Printing and Media Industries Federation and the publisher of *MediaStandard Print*. ISO stands for International Organization for Standardization. The industry publication summarises standard requirements; it does not replace the ISO standard itself.

See also [abbreviations and terms](../usage/abbreviations.md).
