# PXF: i1Profiler Patch Sets

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: preliminary read/write contract for InkProf.

## Source-backed role

`.pxf` is used for i1Profiler's patch sets. [S5] The format is CxF3-based and contains device values, for example RGB or CMYK. [S4] See [common definition, sources and version limits](README.md).

## Proposed meaning in InkProf

A PXF is imported as a **target definition**, not as a measurement result. Patch identities, names, order, channel names, control values and encoding must be preserved. A patch set does not prove where the patches are located on an already printed sheet.

## Concrete reading map from reviewed code

ChromIQ's RGB export uses the following structure. It is a code observation, not a complete schema or a guarantee for all PXF files:

```text
CxF / Resources / ObjectCollection / Object
  @Id, @Name, @ObjectType
  DeviceColorValues / ColorRGB
    @ColorSpecification
    R, G, B
```

The XML namespace must be handled as described in the common description. Preserve the referenced colour specification even if its meaning is not fully interpreted. Device RGB must not automatically be treated as sRGB.

## Import requirements

- Identify the correct collection of target objects; do not mix in any measurement objects.
- Check channels and numerical values. Reject or mark a channel set that the importer does not yet support.
- Determine the encoding from the verified variant and available metadata. Do not scale by the highest patch value.
- Preserve repeated colours as separate patches and keep an explicit order map.

## Export requirements

- Generate object IDs and references without collisions.
- Choose the recipient's verified encoding and report rounding. ChromIQ's observed RGB export uses integers 0–255; this must not be generalised to all CxF3 files.
- Write only extensions that the exporter understands or can preserve with valid references.
- Do not create fake measurements to fill out a target definition.

## Interchange with Argyll

PXF and TI1 have corresponding target roles. The conversion must preserve the meaning of the device values, not just the numbers. For 0–255-encoded RGB, the conversion to TI1 percent is `100 × value / 255`; a different encoding requires a different conversion.

Layout, profiling settings and other private resources may lack an equivalent in TI1. Report losses and archive the original. The export must be checked in i1Profiler before it is called compatible.

## Verification cases

Test black, white, intermediate values, repeated RGB values and values that do not correspond to whole 8-bit steps. Check whether re-export changes precision or order. The exact mandatory PXF extensions for the user's version remain to be established from reference files.

## Practical review of i1Profiler 3.8.5

See the [verification report](ui-verification-3.8.5.md) for observed menu choices, the performed MXF import, spectral CGATS export and TIFF export. The report distinguishes performed tests from remaining format and layout verification.

## Export from TI1/TI2 in InkProf

```matlab
report = inkprof.exportPxfTarget(inputFile, outputFile);
```

`inputFile` is an RGB `.ti1` or `.ti2`; `outputFile` ends with `.pxf`.
The function uses the bundled, portable template
`resources/templates/rgb-patch-set.pxf`, built from the locally reviewed
`Chart 575 Patches.pxf`. The XML header, namespaces, colour specification and private
Prism structure are preserved. `Template=...` can specify another compatible PXF template.
`Name=...` sets description and title. Creator states InkProf.
(Note 2026-10-08: the bundled template has since been replaced by a minimal InkProf-authored XML scaffold without the copied Prism settings; see `resources/templates/rgb-patch-set.pxf`, THIRD_PARTY_NOTICES.md and [the TXF/PXF export guide](../../usage/i1profiler-txf-export.md).)

RGB is scaled from 0–100 to 0–255. The default mode `RGBEncoding="rgb8"` writes
integers and accepts only values within 0.00002 RGB code steps of the integer grid
(tolerance for TI1/TI2's decimal rounding). Other values are rejected.
`RGBEncoding="round8"` explicitly permits quantisation; `"float"` preserves
decimals but is experimental for the recipient. Patch order and repeated
colours are preserved. XML uses Target1/c1, Target2/c2, …; original names and
SAMPLE_ID are preserved in JSON with the same base name. Exported RGB values and
the maximum change are also saved there. TI2 padding is excluded
in accordance with InkProf's existing chart import. The remaining patches' original
coordinates are in the JSON. No new randomisation is done.

PXF is patch definitions, not measurement data or a copy of the TI2 print's layout.
The Prism template's private settings are compatibility default values, not
verified information about the source's print or profile. The JSON saves source hash,
template hash, export hash, targetInfo, mapping, removed padding count and
numerical re-read error. The project manifest is updated when the output is in
an InkProf project. Existing PXF/JSON files are never overwritten.

Automated tests cover TI1 with fractional and duplicated RGB, XML escaping,
TI2 with padding/coordinates, CMYK rejection and overwrite protection.
Recipient import of the RGB8 export from both TI1 and TI2 is user-verified
for the 575 example. Fractional RGB is still experimental.
See the [acceptance report](acceptance-20260927.md).

The first generated PXF candidate was rejected by i1Profiler with "can not load patch file set". V2 writes integer RGB, TargetN names and one field per XML line like the reference file, as well as WriteProtected=True and ScramblePatches=False as in ChromIQ. V2 was then accepted by the recipient. Which single change solved the earlier error has not been isolated.
