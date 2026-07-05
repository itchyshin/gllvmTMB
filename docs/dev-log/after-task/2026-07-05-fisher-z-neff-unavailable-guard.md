# After Task: Fisher-z Effective-N Unavailable Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Curie / Grace / Rose`

## 1. Goal

Close issue #631 by removing the silent hard-coded effective sample size fallback
from `extract_correlations(method = "fisher-z")`. A tiny or unknown tier count
must not produce Fisher-z intervals as if 30 independent observations existed.

## 2. Implemented

- `.correlation_fisher_n_eff()` now returns `NA_integer_` with a classed warning
  when the automatic tier count is missing or below 4.
- `.correlation_fisher_rows()` keeps point correlations but returns
  `lower = NA`, `upper = NA`, and `method = "(unavailable)"` when the
  automatic effective sample size cannot support Fisher-z.
- Explicit user overrides remain accepted when `n_eff >= 4`; invalid explicit
  overrides still error.
- `extract_correlations()` roxygen and generated Rd now state that no arbitrary
  effective sample size is substituted.

## 3. Files Changed

- `R/extract-correlations.R`
- `tests/testthat/test-fisher-z-correlations.R`
- `man/extract_correlations.Rd`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-fisher-z-neff-unavailable-guard.md`

## 3a. Decisions and Rejected Alternatives

Decision: return unavailable intervals rather than warning while still computing
with a substitute value.

Rationale: the old behavior fabricated precision. An explicit `n_eff` remains
the caller-controlled route when they have a defensible effective sample size.

Rejected alternative: keep a fixed fallback such as 30 with a warning. That
would still make downstream plots and filters treat unsupported bounds as real
interval evidence.

Confidence: high for the local boundary behavior; this is not an empirical
coverage-calibration claim.

## 4. Checks Run

```sh
gh issue view 631 --json number,title,state,body,labels,url
Rscript --vanilla -e 'invisible(parse("R/extract-correlations.R")); invisible(parse("tests/testthat/test-fisher-z-correlations.R")); cat("parse-ok\n")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-fisher-z-correlations.R")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-covariance-tables.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-m1-4-extract-correlations-mixed-family.R")'
tail -5 man/extract_correlations.Rd && grep -c '^\\keyword' man/extract_correlations.Rd
rg -n "n_eff_used <- 30L|max\\(n_eff_used - 3L, 1L\\)|hard-coded 30|fabricat.*n_eff|magic 30" R tests/testthat man docs/design docs/dev-log/check-log.md docs/dev-log/after-task
git diff --check
```

Outcomes:

- Parse check: `parse-ok`.
- `test-fisher-z-correlations.R`: 31 pass, 0 fail, 0 skip under
  `NOT_CRAN=true`.
- `test-plot-covariance-tables.R`: 263 pass, 0 fail, 0 skip.
- `test-confint-derived.R`: 33 expected heavy skips in the default local run.
- `test-m1-4-extract-correlations-mixed-family.R`: 6 expected heavy skips in
  the default local run.
- Rd spot-check: no `\keyword{}` lines in `man/extract_correlations.Rd`.
- Stale fallback scan found no executable old fallback; the only hit was the
  new validation-register note documenting the removed `n_eff = 30` fallback.
- `git diff --check`: pass.

## 5. Tests of the Tests

Boundary case: the new test mutates a fit to `fit$n_sites <- 3L`, reproducing
the issue's unsupported automatic tier count and asserting unavailable bounds.

Acceptance case: the companion test sets the same tiny fitted count but passes
`n_eff = 4L`, proving the explicit minimum override remains live.

Failure-before-fix: before the code change, the first new test would have seen
finite Fisher-z bounds computed from the hard-coded fallback instead of
`method = "(unavailable)"`.

## 6. Consistency Audit

`rg -n "n_eff_used <- 30L|max\\(n_eff_used - 3L, 1L\\)|hard-coded 30|fabricat.*n_eff|magic 30" R tests/testthat man docs/design docs/dev-log/check-log.md docs/dev-log/after-task`

Verdict: pass. No executable fallback remains. The only hit is the intentional
validation-register note stating that the old fallback was removed.

## 7. Roadmap Tick

N/A. This is a robustness repair under validation rows `EXT-04` and `CI-09`, not
a new public capability.

## 7a. GitHub Issue Ledger

- #631 inspected and repaired locally.
- #654 inspected during the same issue sweep and found evidence-closed by the
  current code/tests: the heavy derived phylo CI audit passed 24 assertions
  under `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`, confirming finite
  `wald(numeric)` fallback bounds.

No GitHub issue was closed or commented from this local slice.

## 8. What Did Not Go Smoothly

The first heavy #654 audit run still skipped because `skip_on_cran()` also
required `NOT_CRAN=true`. Re-running with both `NOT_CRAN=true` and
`GLLVMTMB_HEAVY_TESTS=1` produced the actual evidence.

## 9. Team Learning

Ada: keep stale issue triage separate from code changes; #654 needed evidence,
not churn.

Fisher: an interval method must not silently invent information. If the
effective sample size is not defensible, the interval is unavailable.

Curie: paired boundary and acceptance tests made the guard precise without a new
large simulation.

Grace: roxygen regeneration and Rd spot-check were required because the help
contract changed.

Rose: the validation register now distinguishes this as an interval-boundary
truth repair, not new calibration evidence.

## 10. Known Limitations And Next Actions

This does not calibrate Fisher-z coverage for complex latent, structured,
non-Gaussian, or mixed-family models. It only prevents one known precision
fabrication. Profile or bootstrap evidence remains the higher-confidence path
for final correlation intervals, and mixed-family / structured-tier profile and
bootstrap rows remain partial where the validation register says so.
