# After task — M1 public-boundary repair and arc-loop checkpoint

**Branch:** `codex/gllvmtmb-060-m1-baseline-20260720`
**Draft PR:** #778
**Date:** 2026-07-21
**Roles engaged:** Ada, Noether, Rose, Grace, Boole, Pat

## 1. Goal

Repair the four release-blocking public-boundary discrepancies found by fresh
adversarial review of the M1 candidate, verify the changed behavior narrowly,
and leave a durable L2 arc-loop checkpoint for sequential continuation in
Claude Code. This is a bounded repair receipt, not an M1 close or a 0.6
readiness claim.

## 2. Implemented

- Moved public nonlinear `method = "profile"` withdrawal ahead of fit,
  Julia, tier, link-residual, and secondary-argument validation. Retained the
  internal research prototype tests without advertising a public route.
- Restricted `extract_cross_correlations()` to the ordinary unit/B tier and
  made unsupported tiers fail with typed guidance.
- Made ordinal-probit `link_residual = "auto"` fail before covariance
  extraction, preventing a second unit residual from being added to the
  already fixed ordinal-probit residual.
- Made repeatability default to Wald, documented the implemented
  full-covariance estimand, kept profile withdrawn, and added typed validation
  for malformed bootstrap point and bound objects.
- Gave binomial, multinomial, and combined auto-Psi notices distinct
  once-per-session frequency identifiers and truthful compositions.
- Reconciled FAM-20/FAM-20A/FAM-20B prose. Fitted phylogenetic covariance now
  uses `part = "shared", link_residual = "none"`; the default total extraction
  is separately described as adding the fixed softmax residual matrix.
- Reworked the cross-family article to identify FAM-20B as a partial
  ordinary-unit route, expose the intentional ordinal-auto refusal, use a
  non-ordinal subset for the safe summary, and keep fitted `Psi` distinct from
  fixed `R_link`.
- Regenerated the two affected Rd topics and added the durable `LOOP/` goal,
  ledger, decision queue, frozen ultra-plan, and checkpoint needed for a
  Claude Code L2 arc-loop handover.

## 3a. Decisions and Rejected Alternatives

**Decision:** the bounded repair is focused PASS, while M1 remains **IN
PROGRESS**. **Rationale:** 117 focused expectations pass and the exact generated
example runs, but the repaired head has not passed the complete non-heavy,
touched-heavy, article-render, pkgdown, source-tarball, exact-SHA platform, or
fresh D-43 gates. **Rejected:** inheriting predecessor platform receipts as
exact-head evidence; silently falling back from profile to Wald; accepting
ordinal `auto`; treating default total phylogenetic multinomial covariance as
the fitted covariance; or entering Design 86 before M1 closes.

Design 85 remains a landed NO-GO. The maintainer's intention to attempt EVA in
0.6 is reconciled through a new, separately approved Design 86 only after M1,
under Design 72's fixed-rank-first sequential gates. Laplace-only 0.6 remains
the automatic fallback.

## 4. Files Touched

Implementation and generated help:

- `R/extract-correlations.R`
- `R/extract-repeatability.R`
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `man/extract_cross_correlations.Rd`
- `man/extract_repeatability.Rd`

Tests:

- `tests/testthat/test-cross-family-intervals.R`
- `tests/testthat/test-cross-family-multinomial.R`
- `tests/testthat/test-link-residual-multinomial.R`
- `tests/testthat/test-profile-ci.R`

Public and design surfaces:

- `NEWS.md`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/cross-family-correlations.Rmd`
- `vignettes/articles/multinomial.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `docs/design/02-family-registry.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/83-multinomial-response-family.md`
- `docs/design/84-phylogenetic-multinomial-tier2.md`

Durable control and receipts:

- `LOOP/GOAL.md`
- `LOOP/arcs.md`
- `LOOP/checkpoint.md`
- `LOOP/decision-queue.md`
- `LOOP/ultra-plan.md`
- `docs/dev-log/recovery-checkpoints/2026-07-21-044609-codex-m1-profile-boundary-repair-checkpoint.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-21-m1-public-boundary-repair.md`

No C++, TMB likelihood, NAMESPACE, dependency, formula grammar, family
registration, workflow, version, tag, or release artefact changed.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` — PASS; only
  `man/extract_cross_correlations.Rd` and `man/extract_repeatability.Rd`
  changed as expected.
- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS= OPENBLAS_NUM_THREADS=1
  OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e
  'devtools::test(filter =
  "cross-family-intervals|cross-family-multinomial|link-residual-multinomial|profile-ci",
  stop_on_failure = TRUE)'` — PASS in 470.6 seconds: 117 pass, 0 fail,
  0 warning, and 11 declared heavy skips.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  pkgload::run_example("man/extract_cross_correlations.Rd",
  run_dontrun = TRUE, quiet = TRUE)'` — PASS.
- `bash tools/check-actions-boundary.sh` — PASS; package checks and pkgdown
  remain the only Actions roles and no package-check artifact upload was added.
- `git diff --check` — PASS before this report.

Not yet run on the repaired head: complete non-heavy tests; the same touched
groups with `GLLVMTMB_HEAVY_TESTS=1`; execution of all four changed articles;
`pkgdown::check_pkgdown()`; a source-tarball `R CMD check --as-cran`; automatic
Ubuntu, manual three-OS, or Ubuntu-heavy workflows; and terminal D-43 review.

## 6. Tests of the Tests

The boundary tests deliberately combine `method = "profile"` with invalid
fit, level, link, and Julia inputs so that a wrong validation order cannot pass
accidentally. Cross-tier tests exercise ordinary unit/B acceptance and
unit-observation/phylogenetic rejection. A mock ordinal-probit family proves
that unsafe `auto` fails before covariance extraction. Bootstrap tests cover
empty lists, nonnumeric point estimates, missing components, and mismatched
bounds. Auto-Psi tests exercise binomial-only, multinomial-only, and combined
messages and frequency identifiers. The article's unsafe five-family ordinal
summary is retained as an intentional typed-refusal example, while a separate
four-family non-ordinal fit exercises the supported path.

## 7. Roadmap Tick

N/A for this bounded correction. It repairs public and design truth without
admitting a new capability. The live programme state is recorded in `LOOP/`
and Mission Control; the release roadmap must not be marked complete from this
focused receipt.

## 7a. Issue Ledger

Draft PR #778 remains the sole programme PR. No new issue was opened: the
corrections are exact-head M1 blockers already owned by that PR. Correlation
profile, BCa, structured redraw, plotting promotion, and wider CI promotions
remain cut or separately scoped; they were not pulled into this repair.

## 8. Consistency Audit

Noether independently reviewed validation precedence, mathematical estimands,
and typed failure boundaries. Rose independently reviewed NEWS, articles,
Design 84, FAM-20B scope, ordinal residual wording, and fitted-`Psi` versus
fixed-`R_link` terminology. Grace independently defined the smallest valid
post-repair qualification ladder and ruled predecessor SHA receipts historical
only. Ada reconciled their findings across code, tests, Rd, public prose,
design records, and the arc-loop checkpoint.

The package's six-part Definition of Done is not claimed for M1: implementation
is only on the draft branch; no new estimator required a new recovery campaign;
the changed help/example is present and focused-tested; this check-log entry is
present; and specialist review occurred, but merge, exact-head complete tests,
three-OS CI, Ubuntu-heavy CI, and terminal independent reviews remain open.

## 9. What Did Not Go Smoothly

The earlier M1 candidate accumulated green platform receipts before fresh
review found public API and claim-boundary defects. Those receipts remain
useful historical evidence but ceased to qualify the changed source. The
cross-family article also combined an ordinal-probit response with `auto`, so
the safety correction required separating the deliberate refusal from the
supported demonstration rather than weakening the new guard.

## 10. Known Residuals

M1 is not closed. Claude must next run the complete non-heavy suite, touched
heavy routes, all four changed articles, pkgdown, and a clean source-tarball
check; commit any required correction; then qualify one frozen exact SHA on
Ubuntu, macOS, Windows, and Ubuntu-heavy CI before three fresh D-43 reviews.
Any later source edit restarts the affected exact-head gates.

This work does not approve Design 86, implement EVA, launch Totoro or DRAC,
admit a public estimator, merge PR #778, freeze an API or candidate, version,
tag, submit, or support any release/readiness claim.

## 11. Team Learning

**Ada:** terminal review belongs before immutable platform ceremony as well as
after it; otherwise a truthful correction forces a costly but necessary new
exact-head cycle.

**Noether:** withdrawn methods must fail before every secondary validation and
model dispatch. Mathematical refusal order is part of the API contract.

**Rose:** “fitted covariance” and “default reported total covariance” require
separate calls and notation wherever fixed link residuals are available.

**Grace:** exact-SHA evidence does not survive source changes. The economical
path is focused proof, full local proof, frozen commit, then one platform cycle.

**Boole/Pat:** a safe public example should show the typed refusal and then the
supported recovery path; silently modifying the original fit would conceal the
boundary a user needs to understand.

## 12. Cross-Product Coverage

Covered here: public withdrawal precedence, ordinary-tier cross-family fences,
ordinal-auto safety, repeatability Wald/bootstrap contracts, multinomial
link-residual wording, and the corresponding focused R tests, Rd, NEWS,
articles, design records, and validation-register statements.

This bounded repair **does NOT cover** new estimators or families;
recovery/coverage calibration;
structured, mixed, missing-data, higher-rank, or universal EVA; full local or
platform qualification; RC/release ceremony; other repositories or products.
