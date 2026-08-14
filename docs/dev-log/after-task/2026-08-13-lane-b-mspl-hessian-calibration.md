# After Task: LA-MSPL private numerical-Hessian calibration

**Branch**: `codex/lane-b-mspl-interval-feasibility`  
**Date**: `2026-08-13`  
**Roles (engaged)**: Ada, Fisher, Curie, Rose

## 1. Goal

Assess the private active-penalised-objective numerical-Hessian candidate in
four fixed ordinary q = 1 complete-Bernoulli fixtures, retaining all failures,
without exposing any public MSPL uncertainty interface.

## 2. Implemented

The campaign runner now has a `hessian_only` mode, atomic target-level
receipts, fit-failure retention, manifest-grid validation, and a disjoint seed
offset for confirmation. A local and Totoro smoke passed. Totoro completed a
4 x 500 gate (2,000 receipts) and a disjoint 4 x 1,000 confirmation (4,000
receipts) after all 12 gate cells cleared the declared continuation rule.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed. The only assessed quantity is the
private diagnostic band \(\hat\beta_j \mathbin{\pm} 1.96\,SE_H\), where
\(SE_H\) is taken from the inverse numerical outer Hessian of penalised
`fit$tmb_obj`. It is not `sdreport()`, a sandwich covariance, a likelihood
interval, or a calibrated standard error.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the numerical-Hessian result as a private diagnostic but
block public SE/CI promotion. **Rationale:** low-prevalence cloglog has a
material mean-SE / empirical-SD mismatch. **Rejected:** activating `vcov()`,
`confint()`, profile, a Wald fallback, bootstrap, or a public confidence claim.

## 4. Files Touched

- `inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R`: private
  Hessian-only, receipt, summary, and seed-isolation contract.
- `tests/testthat/test-mspl-uncertainty-runner.R`: deterministic private-runner
  fence contract.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  plan-versus-actual record.
- `docs/dev-log/check-log.md`: command and evidence receipt.
- This report.

No README, NEWS, ROADMAP, validation-debt register, known-limitations page,
design document, vignette, generated Rd, or pkgdown artifact changed. MSPL-04
remains `blocked` in the validation-debt register.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl", stop_on_failure = TRUE)'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-mspl-uncertainty-runner.R", reporter = "summary")'
git diff --check
rg -n 'gllvmTMB_mspl_penalized_hessian_diagnostic|gllvmTMB_mspl_profile_threshold_diagnostic' NAMESPACE R tests/testthat
```

The focused MSPL suite had no failures, warnings, or skips; the runner contract
had five passing expectations. Local and Totoro four-cell one-replicate smokes
both produced twelve target rows with profile status `not_run`. Remote manifest
validation accepted exactly 2,000 and 4,000 raw receipts respectively.

## 6. Tests of the Tests

The runner test is a boundary-contract guard: it requires `hessian_only`,
`not_run` profile status, atomic rename, exact-grid rejection, and a typed
fit-error path. The 500-summary grid bug was caught by its own exact-manifest
validator before any numerical verdict; the repaired validator passed against
the completed local smoke and the two remote receipt sets.

## 7a. Issue Ledger

Open PRs #955--#960 were inspected before shared-log edits; none owns this
private campaign. No relevant open issue; no new issue created.

## 8. Consistency Audit

`rg -n 'gllvmTMB_mspl_penalized_hessian_diagnostic|gllvmTMB_mspl_profile_threshold_diagnostic' NAMESPACE R tests/testthat` found both helpers only in private R/test paths and no NAMESPACE export. `git diff --check` passed. The touched files contain no reader-facing capability claim, so the broader user-prose stale-wording sweep was not applicable.

**Roadmap tick**: N/A — this private blocked candidate does not advance a roadmap capability.

## 9. What Did Not Go Smoothly

The exact-source Totoro install initially remained compiling after the client
returned, so the first remote smoke correctly failed to load its Linux shared
object. Monitoring showed compilation was still active; once the shared object
appeared the smoke passed. The 500-summary validator then exposed a malformed
expected-grid constructor; no raw receipt was changed, and a zero-fit repair
validated the retained set before adjudication.

## 10. Known Residuals

The confirmation is restricted to four ordinary q = 1 deterministic fixtures.
No formal public-promotion calibration criterion was evaluated, and the
low-prevalence scale mismatch blocks a calibrated-SE claim.

## 11. Team Learning

**Fisher:** high availability and nominal-looking coverage do not establish
calibrated SEs. The low-prevalence cloglog mean-SE / empirical-SD ratio
(1.07--1.35) is the decisive scale warning.

**Curie:** receipt-level failure retention and a disjoint confirmation seed
stream are necessary; otherwise a fast campaign can look complete while
silently reusing draws or omitting failed fits.

**Rose:** a zero-fit manifest validator is a real evidence gate. The failed
first summary was correctly treated as a reporting defect, not as a campaign
result. Public MSPL inference stays fail-closed.

## 12. Cross-Product Coverage

Covered: the three baseline links plus low-prevalence standard cloglog, ordinary
complete Bernoulli q = 1, and all three fixed-effect coordinates. Not covered:
q = 2, spatial/phylogenetic structure, missing data, bootstrap, profile
calibration, or any public inference provider.

## 13. Next Actions

The confirmation is limited to four ordinary q = 1 deterministic fixtures. It
does not cover q = 2, spatial/phylogenetic structure, missing data, bootstrap,
or public inference. The profile candidate remains blocked by its separate
low-prevalence cloglog evidence. The numerical-Hessian candidate is retained
as a private diagnostic but blocked from public SE/CI promotion because its
low-prevalence cloglog scale mismatch is material. Any future remedy needs a
new estimator-specific design, not activation of `vcov()` or `confint()`.
