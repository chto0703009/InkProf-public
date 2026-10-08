# 006 - Earlier proposal for a boundary with SpectraLab

> Historical planning/research/decision record. The dated findings are preserved; use [the v1.0.0 documentation index](https://github.com/chto0703009/InkProf-public/blob/main/docs/README.md) for current usage and status.

Date: 2026-09-26. **Superseded by [decision 007: independent InkProf](007-independent-inkprof.md).**

The earlier proposal was to let SpectraLab handle spot measurement and re-reading through an adapter. The project owner chose instead to implement these functions in InkProf itself, so that the two projects stay independent. No SpectraLab adapter is to be implemented as a runtime dependency.

Experience from SpectraLab's session handling may still be used as background. Current responsibilities, revision requirements and verification status are described in decision 007 and in the [measurement guide](../usage/chart-measurement.md).
