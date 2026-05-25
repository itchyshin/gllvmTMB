# After Task: Identifiability diagnostics for #248

**Branch**: `codex/identifiability-diagnostics-248-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Fisher / Emmy / Grace / Rose`

## 1. Goal

Expose the latent-fit health signals requested by symbolizer issue #248
through an existing programmatic gllvmTMB diagnostic surface, so users can
inspect a fitted latent-variable model before comparing model structures.

## 2. Implemented

- Extended `check_gllvmTMB()` with additional machine-readable rows:
  `hessian_rank`, `rotation_convention_*`, `weak_axis_*`,
  `near_zero_psi_*`, `boundary_sigma_eps`, and
  `cross_loading_structure_*`.
- Kept the implementation inside `check_gllvmTMB()` rather than adding a
  new exported alias, because the package already has a stable exported
  diagnostic name and reference-index placement.
- Added a focused boundary test that mutates a fitted object to force weak
  axis, near-zero `psi`, and near-zero `sigma_eps` warnings without adding
  another expensive simulation-refit workflow.
- Updated NEWS, ROADMAP, and the validation-debt register row DIA-08.

## 3. Files Changed

Implementation:

- `R/diagnose.R`

Tests:

- `tests/testthat/test-sanity-multi.R`

Documentation and ledgers:

- `man/check_gllvmTMB.Rd`
- `NEWS.md`
- `ROADMAP.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-identifiability-diagnostics-248.md`

## 3a. Decisions and Rejected Alternatives

Decision: extend `check_gllvmTMB()` instead of adding `check_gllvm()`.

Rationale: `check_gllvmTMB()` is already exported, documented, listed in
pkgdown, and described as the machine-readable diagnostic table. Adding a
second exported function would increase API surface and reference-index
cascade work without giving symbolizer a stronger contract.

Rejected alternative: implement `check_gllvm()` as an alias. This can be
reconsidered if symbolizer needs a shorter cross-package naming convention.

Confidence: medium-high. The implementation satisfies the requested diagnostic
rows while staying inside the existing API.

## 4. Checks Run

Completed:

- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 26`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> loaded package and wrote `check_gllvmTMB.Rd`.
- `air format .`
  -> ran, but touched unrelated files; Ada restored all accidental changes
  outside the intended diagnostic files before continuing.
- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 26` after documentation and formatting.
- `docs/dev-log/recovery-checkpoints/2026-05-25-051340-ada-checkpoint.md`
  -> restart checkpoint after a broken-thread handoff.
- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 26` after restart.
- `tail -5 man/check_gllvmTMB.Rd`
  -> Rd ends after the example block.
- `grep -c '^\\keyword' man/check_gllvmTMB.Rd`
  -> `0`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Rose pre-publish scans for NEWS/roxygen/Rd/ROADMAP/register consistency
  -> PASS with expected false positives only from existing
  `gllvmTMB_wide()` soft-deprecation wording and source-code `gr(`.
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> completed in 13m 42.2s with `0 errors`, `1 warning`, and `4 notes`;
  returned nonzero because the local macOS install warning is treated as a
  check failure. The check did not report test failures.
- `R CMD INSTALL --preclean --library=/private/tmp/gllvmtmb-install-test-lib .`
  -> install succeeded and reproduced toolchain / upstream-header warnings:
  `xcrun --show-sdk-version` status 1 / `using SDK: NA`, Eigen unused-variable
  warnings, and `R_ext/Boolean.h` unknown warning group
  `-Wfixed-enum-extension`.

## 5. Tests of the Tests

The new boundary test satisfies the boundary-case rule: it forces a weak
latent axis, near-zero `psi`, and near-zero estimated `sigma_eps`, and then
checks that the table emits `WARN` rows for each condition.

The existing clean-fit test checks the neighbouring feature combination:
rank-2 latent + unique fit, restart provenance, Hessian rows, and rotation
advisory rows in one diagnostic table.

## 6. Consistency Audit

Rose PASS for the touched public/reference surfaces. NEWS, roxygen, generated
Rd, ROADMAP, and DIA-08 all describe the same scope: the new rows are
programmatic fitted-model diagnostics, not interval-calibration evidence or
proof that a selected latent rank is scientifically preferred. `check_gllvmTMB`
remains exported and listed in the pkgdown reference index.

Grace WARN on local full-check hygiene: the branch has no local test failures,
but `devtools::check(args = "--no-manual")` is not locally green on this macOS
toolchain because of the install warning. The remaining notes are environmental
or pre-existing package hygiene items, not new #248 diagnostics failures.

## 7. Roadmap Tick

`ROADMAP.md` now records #248 as implemented through `check_gllvmTMB()` and
moves the active queue to #228 predictive diagnostics.

## 7a. GitHub Issue Ledger

Relevant issue:

- #248: Programmatic identifiability diagnostics for latent-variable fits.

No issue comment has been posted yet; post the PR and CI evidence after the PR
is opened or merged.

## 8. What Did Not Go Smoothly

`air format .` was broader than useful for this slice and reformatted many
unrelated files. Ada restored those accidental edits and kept only the intended
diagnostic files.

## 9. Team Learning

Ada: kept the #248 implementation inside the existing diagnostic API and
preserved single-PR pacing.

Fisher: treated weak axes, Hessian rank, near-zero `psi`, and `sigma_eps`
boundary rows as diagnostic warnings, not proof of model invalidity.

Emmy: kept the returned object as the same stable six-column data frame so
downstream tools can consume it without a new class.

Grace: required regenerated Rd, focused tests, pkgdown checking, and CI before
merge.

Rose: required NEWS, ROADMAP, validation-debt register, roxygen, and generated
Rd to tell the same scope story.

## 10. Known Limitations And Next Actions

These checks are heuristics on a fitted object. They do not calibrate
intervals, choose latent rank, or replace `check_identifiability()` simulation
refits.

Next slice after this PR is #228 predictive diagnostics.
