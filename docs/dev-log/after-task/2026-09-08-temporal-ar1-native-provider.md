# After Task: Native temporal AR1 latent-score provider

**Branch**: `codex/temporal-ar1-plan-20260908`
**Date**: 2026-09-08
**Roles (engaged)**: Ada, Boole, Emmy, Gauss, Noether, Curie, Pat, Rose, Grace

## 1. Goal

Implement a native, rank-one temporal AR1 latent-score provider for complete
Gaussian longitudinal panels, including ordinary and replicated workflows,
long/wide syntax, fitted-object lifecycle support, documentation, and local
acceptance evidence. The work remains local only: no push, merge, release, or
general recovery or interval claim.

## 2. Implemented

`temporal_latent()` supplies one stationary unit-variance score process per
series, with `phi = (1 - 1e-6) tanh(theta_temporal_phi)`. Loadings carry the
process amplitude. For unreplicated panels, the likelihood integrates one
trait-specific total iid variance per occasion; for replicated panels it uses
the exact normalized marginal block `psi_j 11' + sigma_epsilon^2 I` while only
the scores persist through time. The public route accepts long
`0 + trait | series` syntax and compact wide `traits(...) ~ 1 +
temporal_latent(1 | series, ...)` syntax.

`extract_temporal()`, labelled `getLV()` scores, ordination labels,
training-data prediction, unconditional and conditional simulation, and public
call replay through `update()` are implemented. New-data prediction and the
iid profile/bootstrap/selection/interval routes refuse temporal fits before
entering unsupported algorithms.

## 4. Files Touched

**Provider and engine:** `R/temporal.R`, `R/gllvmTMB.R`, `R/traits-keyword.R`,
`R/fit-multi.R`, `src/gllvmTMB.cpp`, `NAMESPACE`.

**Lifecycle and guards:** `R/methods-gllvmTMB.R`, `R/extractors.R`,
`R/output-methods.R`, `R/bootstrap-lv-effects.R`, `R/bootstrap-sigma.R`,
`R/extract-repeatability.R`, `R/loading-ci-bootstrap.R`, `R/loading-ci.R`,
`R/loading-profile.R`, `R/ordination-uncertainty.R`, `R/phylo-signal-ci.R`,
`R/profile-derived.R`, `R/profile-targets.R`, `R/proportions-ci.R`,
`R/select-lv.R`, `R/z-confint-gllvmTMB.R`.

**Tests and retained evidence:** `tests/testthat/test-temporal-ar1-parser.R`,
`test-temporal-ar1-methods.R`, `test-temporal-ar1-oracles.R`,
`test-temporal-ar1-regressions.R`, `test-temporal-ar1-verify-runner.R`, and
`dev/temporal-ar1/` (runner, DGP, results, reviewer record, and acceptance
revision).

**Reader and status cascade:** `README.md`, `NEWS.md`, `_pkgdown.yml`,
`vignettes/articles/temporal-ar1.Rmd`, `vignettes/articles/api-keyword-grid.Rmd`,
`man/temporal_latent.Rd`, `man/extract_temporal.Rd`,
`man/update.gllvmTMB_multi.Rd`, `docs/design/01-formula-grammar.md`,
`03-likelihoods.md`, `04-random-effects.md`, `06-extractors-contract.md`,
`35-validation-debt-register.md`, and `docs/dev-log/known-limitations.md`.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the exact direct Gaussian marginal block for replicated
occasion variation rather than keep pair-trait `s_B` as TMB random effects.
**Rationale:** an independent dense oracle found the literal retained-effect
experiment inconsistent (near-zero Laplace objective where the dense NLL was
about 38). **Rejected alternative:** retaining `s_B`; it was removed.

**Decision:** record the user-approved, fixture-local G4 per-variance
median-relative-error ceiling of `0.36`. **Rationale:** the intact 12-series
fixture had one `0.355778405907` value after every numerical-health criterion
passed. **Rejected alternative:** silently changing a seed, model, or fixture;
the original `0.35` result and every retained row remain available. This is not
general recovery, calibration, precision, or coverage evidence.

## 5. Checks Run

- `NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R parser` →
  `TEMPORAL_PARSER_PASS`.
- `NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R oracle` →
  `TEMPORAL_ORACLE_PASS`.
- `NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R methods` →
  `TEMPORAL_METHODS_PASS`.
- `NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R recovery` →
  `TEMPORAL_RECOVERY_PASS` under the approved fixture-local revision.
- `NOT_CRAN=true Rscript --vanilla dev/temporal-ar1/verify.R regression` →
  `TEMPORAL_REGRESSION_PASS`, including `pkgdown::check_pkgdown()` and the
  temporal article render.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated the
  temporal Rd files; `tail -5` and `grep -c '^\\keyword'` checked both changed
  pages (zero keyword entries). The unrelated generated `sources = NULL` drift
  in `man/gllvm_julia_fit.Rd` was removed without changing its source.
- `git diff --check` → pass.
- `node /Users/z3437171/shinichi-brain/skills/unlazy/scripts/gate-check.mjs --root . --cwd . --reverify --approve .unlazy/temporal-ar1/GATES.md` → all seven temporal gates met; G0–G5 reran and matched their expected markers.
- A whole current-tree `devtools::check(args = "--no-manual")` previously ran
  23m47s with no temporal failure but could not become green because of
  unrelated Julia/Rd working-tree defects. Detached clean worktree commit
  `184aa685f` then ran the same check in 24m12.7s with 0 errors, 5 warnings,
  and 4 notes. It reproduced only the pre-existing `BIC` namespace,
  `gllvm_julia_fit.Rd`, and `anova.gllvmTMB_multi.Rd` warnings; it reported no
  temporal failure.

## 6. Tests of the Tests

The parser fixture covers malformed panels, gaps, missing values, duplicate
measurements, unsupported ranks, and conflicting providers (boundary/failure
paths). The oracle fixture compares the native objective and gradients to
independent dense Gaussian calculations (feature combination and independent
calculation). Lifecycle tests combine long/wide parsing, update replay,
simulation, prediction ordering, and early unsupported-method guards. The
verification-runner fixture demonstrates rejection of missing, all-skipped,
and deliberately failing fixtures.

## 8. Consistency Audit

- `rg -n "temporal_latent|temporal AR1" README.md NEWS.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/04-random-effects.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md vignettes/articles/temporal-ar1.Rmd man/temporal_latent.Rd man/extract_temporal.Rd` → supported surface, help, article, status register, and limitation are all present.
- `rg -n "currently red|fixture is still failing|TEMPORAL_RECOVERY_FAIL" README.md NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md vignettes/articles/temporal-ar1.Rmd man/temporal_latent.Rd man/extract_temporal.Rd || true` → no stale red-fixture claim.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/temporal.R vignettes/articles/temporal-ar1.Rmd README.md NEWS.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/04-random-effects.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md || true` → no legacy notation in the temporal surface.
- `rg -n "gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/temporal-ar1.Rmd README.md NEWS.md || true` → no deprecated helper appears in the temporal article; NEWS hits are unrelated compatibility records.

## 7. Roadmap Tick

N/A: no existing `ROADMAP.md` row described this new, deliberately partial
temporal provider.

## 7a. Issue Ledger

`gh pr list --state open --limit 20` was attempted for the required
shared-file pre-edit check but could not connect to `api.github.com`. No issue
was inspected, created, commented on, or closed; no issue is claimed as
relevant from this offline worktree.

## 9. What Did Not Go Smoothly

The first recovery aggregation incorrectly took the median of a per-seed
maximum rather than a per-variance median across seeds. The runner was
corrected, preserving every original row. Under the corrected statistic, one
value still exceeded `0.35`; optimizer and 24-series diagnostics did not
provide a defensible post-hoc substitute. The maintainer then explicitly
approved the documented fixture-local `0.36` revision.

## 11. Team Learning

**Ada:** integrated the sequential parser, likelihood, lifecycle, evidence,
and documentation work; the acceptance runner exposed an aggregation error that
ordinary passing unit tests would not have found.

**Boole and Emmy:** preserved public formula identity through wide rewriting,
private pair indexing, public labels, and update replay. The separate methods
fixture prevents the ledger from treating parser tests as lifecycle evidence.

**Gauss and Noether:** the independent dense covariance calculation rejected
the retained-`s_B` experiment and supported the normalized marginal replicated
likelihood now used by the engine.

**Curie and Fisher:** fixed seeds, direct DGP code, retained failures, and
per-variance aggregation keep the recovery result inspectable. The revision is
recorded as fixture-local rather than inflated into a general validation claim.

**Pat:** the review prompted public-label, long/wide update, training-order,
and unsupported-route checks.

**Rose and Grace:** cross-file scope reconciliation identified stale
red-fixture wording and separated the temporal local result from unrelated
whole-tree package-check failures.

## 10. Known Residuals

The provider is still `partial` in TEMP-AR1-01. It is Gaussian identity-link,
rank one, regular time, complete panels, one temporal provider, and
training-data-only prediction. Forecasting, new data, additional providers,
higher rank, slopes, irregular time, other families, profile/bootstrap/score
intervals, and general recovery or coverage claims remain out of scope. The
next meaningful evidence would be a separately designed and approved
recovery/calibration study, not another post-hoc adjustment to this fixture.


## 12. Cross-Product Coverage

This work covers the native Gaussian identity-link ML/Laplace temporal path,
ordinary and replicated complete regular panels, rank one, and one temporal
intercept block. It does NOT cover non-Gaussian families, REML, VA, AGHQ,
MSPL, missing responses, irregular time, forecasts or new data, temporal
slopes, higher rank, a second covariance provider, profile/bootstrap/selection
or interval routes, three-OS CI, merge, or release. The temporal guards reject
these combinations before iid algorithms can misinterpret the fitted object.
