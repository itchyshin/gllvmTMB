# After Task: Ordinary `latent()` Psi Fold

**Date:** 2026-06-18 17:26 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Goal

Close the first real `unique()` follow-on slice after the coevolution model:
ordinary `latent()` should carry its diagonal Psi companion by default while
preserving the old no-residual subset and all compatibility `unique()` syntax.

## Implemented

- Added `residual = TRUE` to the ordinary `latent()` formula stub.
- Changed the ordinary parser rewrite so `latent(0 + trait | g, d = K)` emits
  `rr(0 + trait | g, d = K)` plus an internal
  `diag(0 + trait | g, .latent_psi = TRUE)` companion by default.
- Added `latent(..., residual = FALSE)` as the explicit no-residual subset; the
  parser requires `residual` to be literal `TRUE` or `FALSE`.
- Preserved explicit `latent() + unique()` compatibility syntax and fixed
  `common = TRUE` detection so an auto-emitted internal Psi term does not hide
  a later explicit compatibility `unique(common = TRUE)` term.
- Updated roxygen, generated Rd, NEWS, formula grammar, AGENTS/CLAUDE guidance,
  and the local mission-control dashboard.

## Mathematical Contract

The ordinary default now matches the standard factor-analysis decomposition:

```text
Sigma_g = Lambda Lambda^T + Psi
```

where `Psi` is the diagonal trait-unique variance matrix. The old
rotation-invariant / no-residual subset is still available as:

```r
latent(0 + trait | g, d = K, residual = FALSE)
```

No C++ likelihood path changed. The fold is R-parser plumbing that composes the
existing `rr` and diagonal covariance structures. Source-specific
`phylo_latent()`, `animal_latent()`, `spatial_latent()`, and `kernel_latent()`
do not auto-emit Psi in this slice.

## Files Changed

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `R/unique-keyword.R`
- `tests/testthat/test-unique-family-deprecation.R`
- `tests/testthat/test-stage2-rr-diag.R`
- `man/latent.Rd`
- `man/unique_keyword.Rd`
- `man/indep.Rd`
- `man/diag_re.Rd`
- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks Run

- Pre-edit lane check:
  - `gh pr list --state open` showed only draft PR #489.
  - `git log --all --oneline --since="6 hours ago"` showed the current
    coevolution stack on this branch.
  - `git diff --check` was clean before edits.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  regenerated `man/latent.Rd`, `man/unique_keyword.Rd`, `man/indep.Rd`, and
  `man/diag_re.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|stage2-rr-diag", reporter = "summary")'`
  passed; expected skips were three INLA skips and one glmmTMB non-PD Hessian
  skip.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|keyword-grid|brms-sugar|spatial-deprecation|spatial-orientation|kernel-equivalence|stage2-rr-diag", reporter = "summary")'`
  passed with the same expected skips.
- `Rscript --vanilla -e 'jsonlite::fromJSON("docs/dev-log/dashboard/status.json"); jsonlite::fromJSON("docs/dev-log/dashboard/sweep.json"); cat("json ok\n")'`
  parsed both dashboard JSON files.
- `tail -5 man/latent.Rd && grep -c '^\\keyword' man/latent.Rd`
  reported no runaway keyword block (`0` keywords).
- `tail -5 man/unique_keyword.Rd && grep -c '^\\keyword' man/unique_keyword.Rd`
  reported the expected single internal keyword.
- `tail -5 man/diag_re.Rd && grep -c '^\\keyword' man/diag_re.Rd`
  reported the expected single internal keyword.
- `tail -5 man/indep.Rd && grep -c '^\\keyword' man/indep.Rd`
  reported no runaway keyword block (`0` keywords).

## Tests Of The Tests

The new parser test is a feature-combination test: it checks the new default
fold, the `residual = FALSE` opt-out, and the absence of a leaked `residual`
argument in the generated `rr` term. The fit-equivalence test compares ordinary
`latent()` against the explicit compatibility spelling `latent() + unique()` on
the same Gaussian fixture and requires equal log likelihoods to `1e-8`.

## Consistency Audit

- `rg -n 'latent\(\) does not yet auto-emit Psi|latent-Psi fold lands|later latent-Psi fold|without unique.*LLt|only the latent-implied|no parser-wide deprecation|not latent-Psi auto-folding|does not yet auto' NEWS.md docs/dev-log/dashboard docs/design AGENTS.md CLAUDE.md R tests/testthat man vignettes`
  found no current stale claims after roxygen regeneration.
- `rg -n 'two `latent\(\) \+ unique\(\)` pairs|recommended.*latent\(\).*unique|Use `unique\(\)` paired with `latent\(\)`|latent-Psi auto-folding' R NEWS.md docs/dev-log/dashboard docs/design AGENTS.md CLAUDE.md`
  found no stale recommended ordinary `latent() + unique()` wording in the
  active source surfaces.

## Team Learning

Ada kept the fold ordinary-only because the source-specific and kernel
semantics still need a separate design decision. Boole's API concern is
addressed by making the opt-out explicit (`residual = FALSE`) instead of
changing the meaning of `d` or overloading `unique()`. Curie's test guard
checked both parser shape and fitted equivalence. Rose's status concern is
closed by updating NEWS, the formula grammar, AGENTS/CLAUDE, and the dashboard
while leaving earlier historical after-task notes unchanged.

## Status Inventory

`NEWS.md`, `docs/design/01-formula-grammar.md`, `AGENTS.md`, `CLAUDE.md`, and
the dashboard now say ordinary `latent()` carries Psi by default. Validation
anchors remain FG-04 / FG-06 for the ordinary latent/decomposition grammar and
FG-05 / FG-07 for compatibility diagonal syntax. COE-03 / COE-04 remain partial
and unchanged by this fold.

## Roadmap Tick

N/A. This closes an internal formula-grammar cleanup slice. It does not promote
coevolution scientific coverage or release readiness.

## GitHub Issue Ledger

No issue or PR was mutated. Draft PR #489 remains the open branch vehicle.

## Known Limitations

- No `unique()` API removal.
- No source-specific `phylo_latent()` / `animal_latent()` /
  `spatial_latent()` Psi fold.
- No `kernel_latent()` Psi fold; Paper 2 multi-kernel coevolution remains
  latent-only.
- No extractor contract change for `part = "unique"`.
- No `common =` replacement for users who still need explicit compatibility
  `unique(common = TRUE)`.
- No free-correlation reaction-norm redesign.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Actions

Proceed to the broader `unique()` deprecation plan after this stop: source-
specific folds, kernel compatibility strategy, extractor naming / `part =
"unique"`, `common =` migration, examples, and eventual removal are still
separate decisions.
