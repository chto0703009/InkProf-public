# 008 – Patch definition, print layout and measurement results

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-26. Status: decided specification. The decision describes the desired behaviour; format support and physical compatibility must be verified separately.

## Basic principle

InkProf sets the standard for targets that InkProf creates. At the same time, InkProf must be able to analyse measurement results from other print and measurement programs. A patch definition, a physical print layout and a measurement result are three different kinds of information.

## Format support and preserving the original layout

InkProf is to handle all formats included in the project's format specification, according to what each file actually contains: patch definition, print layout, measurement data or a combination. This includes, among others, PXF, TXF, MXF/CMXF, TI1/TI2/TI3, relevant CGATS variants and TIFF-based targets. InkProf's own print standard is not a condition for import or analysis. The goal of format support does not mean that every adapter or dialect is already implemented and verified.

On import, the original file and its description of how the target looked at measurement time are to be preserved, where the information exists:

- patch identities, control values and channel description,
- order, page/row/column division and coordinates,
- patch size, orientation, padding and markers.

Measurements are to remain linked to this original layout. Missing or contradictory information is to be reported; it must not be silently replaced with InkProf's default values.

## Importing patch definitions and creating new prints

Import and re-layout are separate operations. Importing a supported PXF, TXF, TI1 or CGATS definition is to preserve the available original information in internal JSON and in the archived source file. The import must not in itself change the order, add contrast markers or reinterpret an already measured target as a new InkProf layout.

When the user chooses to create a new RGB target from the definition, InkProf may create its own layout according to the [print standard](../usage/target-print-standard.md). The new layout is to be a separate version with a traceable link to the original's patch identities and RGB values. The original layout and earlier measurements are to be preserved.

If the patches are randomized (scrambled), the exact permutation's mapping between identity, row, column and page is to be carried in JSON and in the relevant measurement files, for example TI2. Repeated RGB values must not be used as the only identity key. The current RGB restriction for creating new targets must not be used to silently discard channels or metadata in imported documents; colour models that a given analysis does not yet support are to be reported explicitly.

## Contrast markers for row measurement

Contrast markers are to be the default in new InkProf targets intended for row measurement, even if the later measurement program is i1Profiler. They are to be described as part of the layout and be compatible with the chosen instrument's measurement files. They are separators, not source patches or colour samples for the profile computation. Padding is a separate category.

Support for contrast fields in one print format does not automatically mean support for the same layout in another measurement program. Every adapter must verify the recipient's interpretation of the layout. In the Argyll workflow, TIFF and TI2 are to be generated as one coherent package with the same spacer settings; arbitrary colour fields must not be added to the image afterwards.

## Importing measurement results

A supported MXF is to be importable into the internal measurement model and analysable in the same principled way as TI3 or other supported measurement data. This does not require that the print was created by InkProf or contained contrast markers: the measurement has already been made.

The import is to check and preserve:

- Patch identity and an unambiguous link to the RGB control values; page and position when needed for the identification.
- Spectra, wavelengths, units and scale, without silent replacement with XYZ/Lab only.
- Measurement conditions such as M0/M1/M2, instrument and available measurement geometry. Different conditions are kept apart; unknown information stays unknown.
- The original file, its origin, missing or duplicated measurements, and any limitation in the format adapter.

If the patch link cannot be established, this is to be reported; values must not be silently assigned to patches by an assumed order. The MXF file extension alone is not a promise of support for every variant. The quality of the analysis also depends on the quality of the measurement, not only on the file being readable.

## TIFF images and physical row measurement

A TIFF image describes image pixels and can contain resolution and other metadata, but it is not automatically a complete patch definition or measurement file. InkProf is to read the available information and link the image to its associated definition where one exists. Patch identities, measurement conditions or spectral data must not be invented from the image. If image-based patch identification is needed, it is to be reported as derived and verified against the definition or the user's information.

The practical readability limitation that has been observed concerns the instrument's row measurement of a printed target, not a general limitation on importing external file formats. Similar neighbouring patches can make boundaries hard to identify. Scrambling can reduce the risk by changing the neighbourhood, but randomization does not guarantee sufficient contrast between every pair. Contrast markers are kept as support in new InkProf targets for row measurement.

Scrambling or added contrast markers require a new physical print and matching layout and measurement files. They must not be used to change, after the fact, the definition of an existing sheet or its measurements. Already printed external targets are to be handled according to their actual layout. If row measurement of such a sheet is problematic, it can be measured in the original program and the result imported, or replaced by a separate new print from the same patch definition.

## Experience from the i1Pro 2 test

The session `matning-A4-20260926-123236` covered 143 source patches and four padding fields in seven rows, with contrast markers. All rows were accepted and all source patches could be imported. The user explained the re-sweep of the first row by the sheet sitting too far to the right in the sled; this is not to be reported as an error in patch recognition.

Centring is needed in practice for room to start and finish the sweep on paper. The contrast markers are also kept because the user has experience of similar reading problems in i1Profiler. The test shows one working case, not a general guarantee or isolated proof of the effect of each layout change.

## Implementation status and acceptance

RGB patch import, Argyll contrast fields and TI3 import exist. A general MXF adapter and recipient verification are not to be considered finished merely because individual MXF files have been analysed with helper scripts.

At the time of this decision, `createTarget` still defaults to `SpacerMode="auto"`; the contrast test uses `SpacerMode="colored"` explicitly. The fixed 29 × 20 template has no contrast fields. Making contrast markers the default in all row-measurement layouts remains to be done according to this specification.

Acceptance requires verified TIFF/layout/patch mapping and physical row measurement of the chosen workflow. Measurement import requires verification against real format variants and preserved data and metadata. These checks are to be reported separately.
