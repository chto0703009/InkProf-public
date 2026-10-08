# 003 - Shared GPL licence for InkProf and Camera-41

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-25. Status: decided by the project owner and implemented.

## Background

The project owner decided that InkProf and Camera-41 should have the same GPL licence, to make reuse between the projects easier. When checked, Camera-41 v0.9.0-dev had no licence declaration, so there was no existing version statement to copy.

## Decision

Both projects' own code and documentation get the same licence: **GNU General Public License version 3 or later**, SPDX identifier `GPL-3.0-or-later`.

InkProf is to be presented explicitly as **open-source and free software**. The source code may be studied, changed and distributed under GPL-3.0-or-later. The trademark rules in decision 005 do not restrict these licence rights; they separate the project's own identity from factual references to compatible third-party products.

The full GPL v3 text is in each repository's `LICENSE`. The README states explicitly that a later version may be chosen, which distinguishes the choice from `GPL-3.0-only`.

## Scope

- Applies to the projects' own material where no other explicit licence or rights notice is given.
- Existing rights notices are to be preserved when code moves between the projects. The code's origin and version are to be documented.
- Third-party code, publications, external data and other separately licensed parts are not relicensed by this decision.
- MATLAB and other external dependencies keep their own terms. This decision is not an assessment of every possible combination or form of distribution.
- Statements in older plan versions that the licence choice was still open are historical and are superseded by this decision.

## Implemented

InkProf: `LICENSE`, the README and the foundation decision updated.

Camera-41: a corresponding `LICENSE` and README declaration added in the current working copy `Camera-41_v0.9.0-dev`. `.gitignore` now allows the licence file. Historical version folders have not been changed.

No third-party code was imported through the licence change.

## Source

The unchanged licence text was taken from [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.txt).

## Related decision

- [005 - Format- and operation-based names in the public API](005-format-based-public-api.md)

## Clarification 2026-09-26

The shared licence choice implies no runtime dependency on Camera-41 or SpectraLab. InkProf is installed and versioned independently, per [decision 007](007-independent-inkprof.md). Reused code requires a documented origin and preserved licence notices.

## Ongoing rights review 2026-09-27

The project owner requires that all other routines and dependencies are also handled with respect for copyright and correct attribution. [Third-party notices](../../THIRD_PARTY_NOTICES.md) and the [version/hash inventory](../../licenses/inventory.json) document the reviewed packages. New or adapted routines must have an identified origin, a checked licence and preserved copyright notices. A copyright notice does not replace permission or the obligation to provide source code. Uncertainties are to be documented and resolved before the relevant distribution.

The installed ArgyllCMS 3.5.0 states AGPLv3, not GPL alone. MATLAB remains a separate proprietary dependency. The concrete form of distribution has to be assessed; this notice gives no general guarantee of non-infringement.
