# After Task: Phase 3 unified weights/data-shape implementation

## Goal

Implement the accepted Phase 3 contract from
`docs/design/02-data-shape-and-weights.md`: route `gllvmTMB()`,
`gllvmTMB_wide()`, and `traits(...)` through one shared weight-shape
normalisation helper, add paired tests for long/wide equivalence, and
update the reader-facing documentation for the three entry points.

## Implemented

Phase 3 now has a shared internal helper,
`normalise_weights()`, in `R/weights-shape.R`.

The helper accepts three response-shape modes:

- `long`: `weights` must be a numeric vector of length `nrow(data)`;
- `wide_matrix`: `weights` may be `NULL`, a scalar, a row vector of
  length `nrow(Y)`, or a matrix with `dim(Y)`;
- `wide_df`: `weights` may be `NULL` or a row vector of length
  `nrow(data)` for `traits(...)`.

The three public entry paths now call the helper before the engine
sees weights. `gllvmTMB_wide()` also now keeps `Y`, row-broadcast
weights, and site-level predictors aligned when `X` is supplied by
matching the already-pivoted long data back to `X` rows instead of
using `merge()` plus a later sort.

The morphometrics article now shows the main model three ways:
long-format `gllvmTMB()`, formula-wide `traits(...)`, and matrix-wide
`gllvmTMB_wide()`.

## Mathematical Contract

No likelihood, TMB parameterisation, family support, formula grammar,
NAMESPACE, or covariance keyword semantics changed.

The implemented change is at the R input-normalisation layer:
accepted weight shapes are validated once and converted to the
long-format per-observation vector before `gllvmTMB_multi_fit()`
builds engine inputs.

For matched long/wide Gaussian models, the Phase 3 paired tests compare
the engine fixed-effect matrix, trait levels, normalised `weights_i`,
family IDs, and the negative log-likelihood evaluated from the
engine's initial parameter vector.

The binomial `cbind(successes, failures)` versus
`weights = n_trials` contract remains in the long-format engine tests
(`test-lme4-style-weights.R` and `test-multi-trial-binomial.R`).
`gllvmTMB_wide()` does not gain a two-layer binomial response-array API
in this phase.

## Files Changed

- `R/weights-shape.R`: new shared weight-shape helper and validators.
- `R/gllvmTMB.R`: routes long-format weights through the helper and
  routes `traits(...)` weights through the rewritten long call.
- `R/gllvmTMB-wide.R`: removes local weight handling, calls the helper,
  and fixes `X` row alignment.
- `R/traits-keyword.R`: normalises row-broadcast wide-data-frame
  weights during the pivot pre-pass.
- `tests/testthat/test-weights-unified.R`: adds Phase 3 shape-layer
  tests and paired equivalence checks.
- `vignettes/articles/morphometrics.Rmd`: adds the three-way entry
  point bridge.
- `docs/design/02-data-shape-and-weights.md`: marks Phase 3
  implementation status and records the binomial wide-array boundary.
- `NEWS.md`: records the bug fix.
- Generated Rd: `man/gllvmTMB.Rd`, `man/gllvmTMB_wide.Rd`, and
  `man/traits.Rd` reflect the new cross-links.
- `docs/dev-log/check-log.md`: records the validation evidence.

## Checks Run

- Pre-edit lane check:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json ...` found
  PR #29, `agent/air-format-trial`, touching Air/CONTRIBUTING files
  and a separate after-task report. No implementation-file overlap with
  Phase 3.
- End-of-session Shannon check found PR #30,
  `agent/site-species-to-unit-trait`, touching `R/gllvmTMB-wide.R`,
  `man/gllvmTMB_wide.Rd`, `man/gllvmTMB-package.Rd`, and
  `man/make_mesh.Rd`, all of which overlap this branch. A coordination
  comment was posted on PR #30:
  https://github.com/itchyshin/gllvmTMB/pull/30#issuecomment-4430062907.
- Resume/integration check after PR #29 and PR #30 merged:
  `git fetch origin && git rebase origin/main` replayed the Phase 3
  commit cleanly onto `45eae2e` with no conflicts. The final branch
  diff no longer includes `man/gllvmTMB-package.Rd` or
  `man/make_mesh.Rd`, because PR #30 already brought those generated
  files into sync on `main`.
- Recent-log check:
  `git log --all --oneline --since="6 hours ago"` found `f79567b` and
  `4ab907b`, both in the Air-format lane.
- `Rscript --vanilla -e 'devtools::test(filter = "weights-unified")'`:
  PASS, 30 tests, 0 failures, 0 warnings, 0 skips, 2.4 s.
- Post-rebase rerun,
  `Rscript --vanilla -e 'devtools::test(filter = "weights-unified")'`:
  PASS, 30 tests, 0 failures, 0 warnings, 0 skips, 2.5 s.
- Post-rebase
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed with no additional file changes.
- Post-rebase `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`:
  PASS, "No problems found."
- `Rscript --vanilla -e 'devtools::test()'`: PASS, 1293 tests, 0
  failures, 6 warnings, 11 skips, 1426.7 s. Warnings were known
  legacy alias/deprecation warnings, not Phase 3 failures.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: completed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: PASS, "No
  problems found."
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics")'`:
  completed; only the pre-existing `../logo.png` pkgdown warning
  appeared.
- `_R_CHECK_SYSTEM_CLOCK_=FALSE Rscript --vanilla -e 'devtools::check(document = FALSE, manual = FALSE, args = "--no-tests", quiet = FALSE, error_on = "never")'`:
  0 errors, 1 warning, 1 note. The warning was the known Apple clang /
  R header warning from `R_ext/Boolean.h`; the note was the
  pre-existing duplicated `tidyselect` DESCRIPTION entry.
- `git diff --check`: PASS.
- Post-rebase `git diff --check origin/main..HEAD`: PASS.
- Post-rebase `air format --check .`: reported broad pre-existing
  formatting drift across many R and test files. The Air workflow added
  by PR #29 is explicitly advisory (`continue-on-error: true`) during
  the trial period, so this branch did not absorb a repository-wide
  format sweep.

## Tests Of The Tests

The new tests cover both acceptance and rejection:

- helper acceptance: row-broadcast wide weights and scalar wide weights
  with an `NA` response mask;
- helper rejection: matrix weights in the long API and per-cell weights
  in the `traits(...)` API;
- paired acceptance: no-weight long/matrix-wide equivalence,
  row-broadcast equivalence, per-cell equivalence, matrix-wide `X`
  alignment, and `traits(...)` round-trip equivalence.

The row-broadcast-with-`X` test is the regression test for the original
alignment bug: if `gllvmTMB_wide()` reorders rows after merging `X`, the
engine inputs and likelihood no longer match the long-format fit.

## Consistency Audit

Rose pre-publish scans covered the touched public surface:

- `rg -n "method *=|default|fisher-z|profile|wald|bootstrap" ...`
- `rg -n "latent|unique|indep|dep|phylo_|spatial_|meta_known_V|trio" ...`
- `rg -n "unit_obs|unit =|trait =|cluster =|tier =|level =|weights|normalise_weights|n_trials|cbind" ...`
- `rg -n "implementation will follow|will hold|follow-up PR|Phase 3 implementation should|should add|Codex's current|two-layer array|will be" ...`

No new contradiction was found in the touched Phase 3 public prose.
The design doc now explicitly says binomial two-layer wide response
arrays are not part of this phase.

## What Did Not Go Smoothly

The previous full test run was lost when the conversation compacted,
so the full `devtools::test()` evidence had to be rerun from scratch.

Before the final rebase, `devtools::document()` regenerated two stale
Rd files outside the Phase 3 roxygen blocks: `gllvmTMB-package.Rd` and
`make_mesh.Rd`. PR #30 absorbed that generated-doc sync on `main`, so
the final Phase 3 branch no longer carries those files.

## Team Learning

Phase 3 surfaced a useful boundary: weight-shape unification is not the
same as adding new response shapes. The long-format binomial
`cbind()`/`weights = n_trials` semantics are tested and preserved, but
wide binomial response arrays would be a separate API design.

Shannon note: PR #29 and PR #30 are now merged into `origin/main`.
This branch was rebased on top of them without conflicts and remains
focused on Phase 3.

## Known Limitations

- `traits(...)` still does not accept per-cell weight matrices. Use
  `gllvmTMB_wide()` for per-cell weights.
- `gllvmTMB_wide()` still does not accept two-layer binomial response
  arrays. Use long-format `cbind(successes, failures)` for multi-trial
  binomial and beta-binomial examples.
- The package still has the pre-existing duplicated `tidyselect` entry
  across DESCRIPTION fields, which produces the known R CMD check note.
- The local macOS toolchain still emits the known Apple clang warning
  from `R_ext/Boolean.h`.

## Next Actions

Review Phase 3 as its own pull request and let GitHub Actions report
the cross-platform integration result. If the maintainer wants
matrix-wide multi-trial binomial data later, start a new design note
for response-shape support rather than expanding this weights
normalisation patch.
