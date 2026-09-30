# Public release scope

The v0.9 public repository is a clean source snapshot with a new history. The private development history has not been published or rewritten.

Excluded from the public snapshot:

- Imported i1Profiler target/reference packages, real MXF examples and vendor-format measurement exports from the private fixtures.
- The 575-patch reference PXF/TIFF and root CGATS reference file.
- Vendor screenshots, raw research JSON/TI1 data and historical planning PDFs.
- Examples and tests requiring these excluded reference packages.
- Local projects, measurements, configuration, environments, secrets, binaries and caches.

Included test fixtures are the synthetic RGB reflectance MXF, synthetic CxF spectrum and fake instrument scripts. The CxF3 schema is an explicit exception to the third-party-resource exclusion: it is provided unmodified with its separate redistribution licence and provenance.

The four presentation/workflow PDFs contain InkProf-produced figures and text. Font notices for their embedded fonts are included under licenses/fonts. Research notes describe earlier experiments; the underlying private reference material is not included, and those notes are not a claim that every earlier test can be reproduced from this source snapshot.

Do not merge or push the private repository history into this public repository. Bring future changes across as reviewed source patches, preserving attribution and checking new data and dependencies.
