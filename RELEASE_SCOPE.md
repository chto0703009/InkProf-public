# Public release scope - v1.5.1

Release 1.5.1 (2026-11-13) is prepared for publication from the separate public repository. Private development history is not merged into it or rewritten.

Included: current MATLAB/Python source, synthetic tests, editable documentation and rebuilt 1.5.1 handbooks and MATLAB workflow guides, and the dated 1.4.2 presentations and technical descriptions. The future-opportunities PDF remains a proposal. Unmodified ArgyllCMS 3.5.0 macOS ARM/Intel distributions are included under third_party/argyll with full upstream licences, reference files and archive provenance. Corresponding source is available from the upstream locations recorded in THIRD_PARTY_NOTICES.md. These are separate programs under upstream terms, including AGPL-3.0.

Excluded: private projects, user measurements/ICC profiles, imported i1Profiler packages and real MXF fixtures, vendor screenshots, private historical datasets, local machine settings, virtual environments and caches. Upstream Argyll reference files and synthetic documentation examples retain their own recorded scope.

MATLAB requires its own installation. On macOS, Prepare can obtain private Python 3.13.6 without changing system Python; a separate exact interpreter is also accepted. Each program builds its own pinned .venv. Other operating systems require a compatible Argyll installation and their own validation. Native macOS discovery does not imply cross-platform instrument qualification.

Separately licensed resources include the unmodified CxF3 schema and font assets; see LICENSE_SCOPE.md, THIRD_PARTY_NOTICES.md and licenses/inventory.json. Existing user certificates and project evidence are not regenerated or included. Copy only reviewed paths between repositories; never merge private history into the public tree.
