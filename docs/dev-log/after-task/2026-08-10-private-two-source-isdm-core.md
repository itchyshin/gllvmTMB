# After Task: private two-source iSDM core and spatial-control ladder

**Branch**: `codex/isdm-package-core`
**Date**: `2026-08-10`
**Roles (engaged)**: Ada, Emmy, Gauss, Noether, Curie, Fisher, Rose, Maxwell

## 1. Goal

Implement a developer-only two-source relative-intensity route in `gllvmTMB`,
with a synthetic GBIF-only spatial-control ladder. This is package engineering
for the future Paper 2 vehicle, not an empirical analysis or a public API.

## 2. Implemented

The unexported `.gll_isdm_fit()` consumes a validated long observation contract:
GBIF rows use Poisson/log quadrature support; a branch-pure survey is either
Bernoulli/cloglog with known area or Poisson/log with known effort. Ecological
`X` is identical within a cell, while GBIF bias `B` is structural zero on survey
rows. The mixed PA route is admitted only through an exact source/family
contract; ordinary public calls keep the existing within-trait family guard.

The native template now emits a per-row, weighted observation NLL only for the
private diagnostic route. Fixed-vector PA and count tests hold all latent and
nuisance coordinates at zero, vary only GBIF bias columns, independently
reconstruct `eta = X_fix b_fix + offset`, and verify native objective
differences and row NLLs against the R oracle.

The synthetic spatial ladder tests no field, `spatial_indep(common = TRUE)`,
and `spatial_latent(d = 1)`. It fixes a guard bug: the common-variance
independent spelling can no longer coexist with the latent spatial term.

## Mathematical Contract

For row \(r\) of species \(j\) in cell \(i\), the private route uses
\(\eta_r = X_i^\top\beta_j + u_i^\top\lambda_j +
I_{\mathrm{GBIF},r}(\alpha_j + B_r^\top\delta_j) + \log s_r\).
GBIF and count-survey rows use \(Y_r \sim \mathrm{Poisson}(e^{\eta_r})\);
PA-survey rows use \(D_r \sim \mathrm{Bernoulli}(1-e^{-e^{\eta_r}})\).
The known \(s_r\) offset has coefficient one. This is a relative-intensity
model: it neither estimates absolute abundance/detection nor contains the
later distinct ecological and GBIF-bias spatial fields.

## 3. Files Changed

- Private iSDM: `R/isdm-contract.R`, `R/isdm-developer-fit.R`.
- Engine and routing: `R/fit-multi.R`, `R/offset.R`, `src/gllvmTMB.cpp`.
- Parser regression: `R/parse-multi-formula.R`.
- Tests: `tests/testthat/test-isdm-contract.R`,
  `tests/testthat/test-isdm-developer-fit.R`,
  `tests/testthat/test-isdm-spatial-control-ladder.R`,
  `tests/testthat/test-parse-multi-formula-long.R`, and
  `tests/testthat/_snaps/isdm-contract.md`.
- Design/closure: `docs/design/111-isdm-nonspatial-recovery-protocol.md`,
  this report, and `docs/dev-log/check-log.md`.

No README, NEWS, ROADMAP, vignette, generated Rd, NAMESPACE, or public API
file changed: this route remains developer-only.

## 3a. Decisions and Rejected Alternatives

**Decision:** PA and count surveys are separate branch-pure fits.
**Rationale:** adding both likelihoods for one survey event would double count
evidence; the current package route has one survey family selector.
**Rejected:** silently treating a count as PA, or adding a third survey family
without its own recovery gate.
**Confidence:** high; enforced by contract and regression test.

**Decision:** use existing spatial terms only as controls.
**Rationale:** `spatial_indep(common = TRUE)` is equal-variance independent
smoothing, whereas `spatial_latent(d = 1)` is a shared spatial axis. Neither
is the required ecology-plus-GBIF-bias two-field model.
**Confidence:** high; structural fixture and parser state are retained.

## 4. Checks Run

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); ... test-isdm-contract.R ... test-isdm-spatial-control-ladder.R ...'
# PASS: contract/oracle, PA/count private route, spatial ladder, parser,
# offset, family-boundary, scalar, and spatial-dispatch focused tests.

NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-isdm-developer-fit.R")'
# PASS: 35 assertions, including fixed-vector native objective / oracle parity
# for both PA and count branches.

Rscript --vanilla -e 'devtools::test(reporter = "summary", stop_on_failure = FALSE)'
# PASS: exit code 0. The ordinary suite completed with its declared gated
# skips and eight existing warnings; no failures were reported.

git diff --check
# PASS.
```

## 5. Tests of the Tests

The spatial mutual-exclusion test failed before its guard repair. Contract
tests exercise malformed source/branch/support, PA/count duplication,
mixed-branch rejection, and non-shared ecological `X`. The private route tests
combine mixed family, nonzero offsets, latent structure, and source-gated
covariates; forged marker input is rejected. The fixed-vector test requires a
nonzero GBIF eta/objective change and bitwise unchanged survey eta, preventing
a vacuous equality pass.

## 6. Consistency Audit

```sh
rg -n "gllvmTMB_internal_isdm|report_obs_nll|observation_nll|spatial_indep\\(|spatial_latent\\(" R src tests/testthat docs/design/111-isdm-nonspatial-recovery-protocol.md
# Verdict: private marker, report, ladder semantics, and tests are visible at
# every implemented surface; no public documentation advertises the route.

rg -n "GBIF|Artportalen|empirical|absolute intensity|spatial bias" README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design/111-isdm-nonspatial-recovery-protocol.md
# Verdict: only the private design protocol discusses GBIF; it explicitly
# excludes empirical data, absolute intensity, and two-field spatial claims.
```

## 7. Roadmap Tick

**Roadmap tick:** N/A. No public roadmap status changed for a private,
unvalidated developer route.

## 7a. GitHub Issue Ledger

Inspected open PR #952 (`feat: experimental binary LA-MSPL separation lane`);
it is unrelated. No relevant open issue was created or changed because this
private route is not yet an externally trackable capability.

## 8. What Did Not Go Smoothly

The first contract allowed mixed survey branches and the first marker check
was over-broad. Independent review caught both before close. R attribute
partial matching also made a report-only count marker look like the mixed
family marker; exact attribute lookup fixed it. The long internal formula
exposed a wrapped-`deparse()` parser warning, now protected by a small public
parser regression test.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss and Noether** found the branch-misrouting and marker-bypass risks, then
required a fixed-vector objective comparison rather than a finite-fit check.

**Fisher** kept the claim boundary clear: native row-kernel parity is not
recovery evidence; the current fixed-vector test is routing evidence only.

**Curie** supplied deterministic synthetic PA/count fixtures, malformed-input
tests, and the structural spatial ladder.

**Emmy** made the contract explicit before the helper assembled a formula,
which made source and event failures cheap to diagnose.

**Rose** preserved the dirty Paper-2 evidence worktree and enforced a clean
implementation boundary and private-only documentation.

## 10. Known Limitations And Next Actions

This is not a recovery pass, empirical fit, absolute-intensity estimator,
source-admission result, public feature, or two-field spatial iSDM. The full
local suite lacks a retained terminal completion receipt. The next approved
gate is a frozen known-truth nonspatial PA recovery campaign; count recovery
requires PA promotion. The later separate spatial arc must add distinct
ecological and GBIF-only spatial random blocks, projections, and parameters;
neither existing spatial keyword substitutes for it.
