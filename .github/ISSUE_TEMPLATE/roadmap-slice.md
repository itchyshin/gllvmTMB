---
name: Roadmap slice
about: A scoped roadmap slice (capability / validation / article / docs). See the capability board (#340).
title: "[track] <slice title>"
labels: ""
---

**Umbrella / part of:** #___
**Track label:** `random-slope` / `cluster2` / `missing-data` / `non-gaussian` / `simulation` / `CI` / `documentation` / `release` / `CRAN-ish`
**Backing design doc / register row:** (e.g. Design 35 `FAM-__`, Design 56 §__, Design 59 §__)

## Scope
What this slice delivers — one branch, one PR. Keep it narrow.

## Gating test
The test that proves it is done (recovery / known-answer / coverage + the tolerance). Tests are the binding contract.

## Stop boundary
What this slice explicitly does **not** do — the next slice picks it up. (drmTMB-style.)

## Definition of Done
- [ ] implementation
- [ ] tests pass (`devtools::test(filter = "<regex>")`)
- [ ] validation-debt register row updated (`docs/design/35-validation-debt-register.md`)
- [ ] docs / roxygen (and `_pkgdown.yml` if a new export)
- [ ] after-task report (`docs/dev-log/after-task/`)
- [ ] scope-honesty check — no overpromise vs the register

> Engine-lane slices (touch `fit-multi.R` / `brms-sugar.R` / `parse-multi-formula.R` / `src/gllvmTMB.cpp`) must be **serialized** — one engine PR in flight at a time; rebase on `main` before starting. Parallel-lane slices (articles, family-validation tests, sim, docs) run concurrently.
