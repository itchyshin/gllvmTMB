# After Task: Restore the qualified temporal OU--kernel cell

**Branch**: `codex/temporal-nuisance-information-20260912`
**Date**: `2026-09-13`
**Roles (engaged)**: Ada, Noether, Boole, Curie, Grace, Rose

## 1. Goal

Restore the one pre-contracted irregular-time source pair that was accidentally
blocked by a later broad parser guard: replicated Gaussian
`temporal_indep(..., structure = "ou") + kernel_indep()` with one fixed labelled
kernel. Preserve every other temporal source-pair and lifecycle refusal.

## 2. Implemented

The parser now admits precisely this independent-trait OU kernel cell. Its
public temporal state and kernel labels survive fitting, extraction, simulation,
long/wide rewriting, and update/refit. Forecast, profile, bootstrap, and
selection still reject before entering temporal-only algorithms.

## 3a. Decisions and Rejected Alternatives

**Decision:** restore only the named OU independent-kernel exception.
**Rationale:** a mathematical contract and independent dense-oracle test already
exist, and the active test verifies its own additive covariance, gradients,
simulation, lifecycle identity, and narrow refusal boundary. **Rejected:**
enabling AR1 kernel, OU phylogenetic/animal/spatial, dependent, latent, or
lifecycle routes through the common source-pair allowlist. **Confidence:** high
for this named local fitting route; no recovery, coverage, or cross-platform
claim.

## 4. Files Touched

- Parser and generated help: `R/temporal.R`, `man/temporal_latent.Rd`.
- Active evidence: `tests/testthat/test-temporal-program-ou-kernel.R`.
- Contract cascade: `docs/design/01-formula-grammar.md`,
  `docs/design/06-extractors-contract.md`,
  `docs/design/35-validation-debt-register.md`,
  `vignettes/articles/temporal-ar1.Rmd`, and
  `vignettes/articles/api-keyword-grid.Rmd`.
- Evidence: ignored `.unlazy/temporal-program/re-admit-ou-kernel-GATES.md`;
  `docs/dev-log/check-log.md` records execution.

## 5. Checks Run

- The restored OU-kernel active test first failed at the stale parser guard.
- The repaired focused test passed with no failures, errors, warnings, or
  skips.
- `Rscript --vanilla dev/temporal-program/verify-ou-kernel-retained.R` emitted
  `TEMPORAL_OU_KERNEL_RETAINED_FAILURE_PASS`.
- `devtools::document(quiet=TRUE)` and `pkgdown::check_pkgdown()` passed.
- Both affected articles rendered from an isolated installation of this exact
  checkout.
- The five-gate OU-kernel unlazy ledger reports all gates met.
- `git diff --check` is run before commit.

## 6. Tests of the Tests

The dense test independently constructs the full additive observation
covariance, checks normalized NLL and selected central outer gradients, and
rejects the incorrect product covariance. It also checks time shift/rescaling,
rate limits, simultaneous Monte Carlo moment bounds, long/wide parsing, and
the explicit early refusals. The retained-receipt verifier rejects a missing or
altered frozen recovery receipt before its failure marker is emitted.

## 7a. Issue Ledger

No issue was opened. The active acceptance ledger records a narrow local
re-admission; merge and release are outside this slice.

## 8. Consistency Audit

The parser, test, generated help, grammar, extractor contract, validation
register, temporal article, keyword grid, and acceptance ledger now name the
same one OU independent-kernel cell and the same refused routes.

## 9. What Did Not Go Smoothly

The retained test had fallen outside the active suite, letting a later parser
guard silently supersede it. Article rendering initially loaded an older
installed package without temporal exports; an isolated installation of the
current checkout distinguished that environment problem from a package defect.

## 10. Known Residuals

The frozen nine-cell recovery fixture remains failed at rate .25. This work
does not cover recovery, coverage, intervals, forecast, profile, bootstrap,
selection, AR1 kernel pairs, other OU source pairs, non-Gaussian responses,
new series, cross-platform verification, merge, or release.

## 11. Team Learning

**Noether:** an additive OU kernel covariance needs its own irregular-time
oracle; positive AR1 evidence does not transfer.

**Boole/Curie:** retained source-pair tests must be restored to the active suite
whenever the public parser changes.

**Grace/Rose:** article rendering must use an installation of the exact source
being checked; an older installed package is not valid package evidence.

## 12. Cross-Product Coverage

This slice covers independent-trait temporal OU plus one fixed labelled kernel,
replicated Gaussian data, irregular elapsed time, public labels, additive
likelihood, simulation, long/wide syntax, update/refit, and early lifecycle
refusals. It does not cover any temporal interaction model, source-specific
forecast or inference, recovery promotion, or publication gate.
