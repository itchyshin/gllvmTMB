# After Task: Integrated-JSDM identifiability diagnostic

## 1. Goal

Run the approved, hypothesis-generating public-route sentinel experiment at
source `09eca7b1eb9018958bad367be824871161a60af1` and use its retained evidence
to distinguish response-replication, estimand, optimizer-basin,
optimizer-termination, and curvature explanations for the earlier integrated-
JSDM recovery failures. The experiment was diagnostic only: it could select a
follow-up investigation, but could not retune a gate or promote a capability.

## 2. Implemented

The lane now contains a checksum-bound runner, qualification receipt, frozen
seed and task plans, four-fit smoke bundle, 52-task experiment bundle,
independent summarizer, negative controls, deterministic tests, and three
terminal reviews. Totoro completed the smoke in 15 seconds and the experiment
in 33 seconds with at most 16 one-thread workers.

The exact diagnostic denominator is 52 planned, 52 started, and 52 terminal
worker records: 16 nonspatial and 36 spatial. All 52 fits returned; errors,
interruptions, unavailable dispositions, coordinator substitutions, and
replacement attempts are all zero. The smoke's four fits remain outside that
denominator.

All five preregistered screening signals are `FALSE`, so the frozen rule returns
`MIXED` (zero signals fired). Tripling independent response draws for the same
ecological realization improved full-surface nRMSE in 8/8 pairs (median
reduction 0.1283) and full-surface correlation in 8/8 (median increase 0.0795),
but species-1 `Psi` error improved in only 4/8 and its median change was -0.0355.
The estimand screen passed 0/8. Neither five-start `nlminb` nor BFGS
continuation passed its rescue rule in any of the eight eligible spatial
sentinels. Curvature attribution agreed on native and normalized scales, but
`theta_rr_spde_lv` dominated only 8/12 rather than the required 9/12;
`log_kappa_spde` dominated the four converged/non-PD sentinels.

## 3. Mathematical and estimand contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed. The scored nonspatial targets remained
the preregistered rotation-invariant decomposition

`eta_fixed = alpha + X beta`,
`eta_shared = eta_fixed + U Lambda'`,
`eta_full = eta_shared + E`, and
`Sigma = Lambda Lambda' + Psi`.

The `rep3` arm retained the baseline rows byte-for-byte and added two
independent observation-response streams conditional on the same ecological
realization. Spatial alternatives changed only the public optimizer controls;
they did not change the model, truth, scoring target, or thresholds.

## 3a. Decisions and Rejected Alternatives

- **Decision**: retain `MIXED` as the terminal zero-signal result.
  **Rationale**: all five frozen signals are false and all three terminal
  reviewers reproduced that result from the raw 52 attempts.
  **Rejected alternative**: lower a threshold or select the visually nearest
  mechanism; that would convert exploration into post-hoc gate tuning.
  **Confidence**: high.
- **Decision**: reject an optimizer or engine repair as the next action.
  **Rationale**: `nlminb5` and BFGS continuation passed 0/8 rescue comparisons;
  the curvature split is descriptive and not causal.
  **Rejected alternative**: change optimizer defaults or TMB code from this
  sentinel evidence.
  **Confidence**: high.
- **Decision**: prepare, but do not launch, a nonspatial-only paired multi-seed
  replication-discrimination experiment across the same eight cells, freezing
  shared/full surfaces and all three `Psi` components separately.
  **Rationale**: response replication improved shared/full surfaces in all
  pairs but did not consistently improve `Psi`; this is the narrow unresolved
  contrast on which Fisher and Rose agree.
  **Rejected alternative**: repeat spatial arms, add intervals, or widen to
  structured-source models.
  **Confidence**: medium; the new design still requires its own approval.

## 4. Files Touched

- `LOOP/`: immutable goal, approved Ultra Plan, arc checkpoints, and 14-gate
  Unlazy acceptance ledger.
- `dev/isdm-requalification/diagnostic-rescue/`: frozen contract, task/seed
  plans, public-route runner, diagnostics, source/install qualification,
  watchdog, reconciliation, independent summarizer, verifiers, and SHA-256
  harness manifest.
- `dev/isdm-requalification/diagnostic-rescue/evidence/`: two seed-selection
  files, a three-file qualification bundle plus manifest, 21 smoke payload
  files plus plan/qualification/projection/manifest, and 143 experiment payload
  files plus plan/qualification/independent summary/manifest. The experiment
  payload includes all 52 started and all 52 terminal attempt records.
- `dev/isdm-requalification/diagnostic-rescue/reviews/`: Curie, Gauss, and Rose
  plan reviews plus Fisher, Gauss, and Rose terminal reviews.
- `tests/testthat/test-isdm-diagnostic-*.R`: contract, diagnostic, receipt,
  runner, failure-path, corruption, signal, and portability tests.
- `docs/dev-log/check-log.md` and this report: protected closeout record.

No `R/`, `src/`, `man/`, `vignettes/`, `README.md`, `NEWS.md`, `ROADMAP.md`,
`docs/design/35-validation-debt-register.md`, `_pkgdown.yml`, `NAMESPACE`, or
package metadata file changed. The convention-change cascade is therefore not
applicable.

## 5. Checks Run

- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-source.R`
  — `DIAGNOSTIC_SOURCE_VERIFIED`; all 17 harness entries verified.
- `Rscript --vanilla -e 'devtools::test(filter = "isdm-diagnostic", stop_on_failure = TRUE)'`
  — 139 passed, 0 failed, 0 warned, 0 skipped after the portability repair.
- `python3 dev/isdm-requalification/diagnostic-rescue/watchdog-signal-test.py`
  — TERM, INT, and HUP process-group cleanup passed during pre-launch review.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R qualification`
  — `DIAGNOSTIC_REMOTE_QUALIFICATION_VERIFIED`.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R smoke`
  — `DIAGNOSTIC_SMOKE_VERIFIED`; projected experiment wall time 38.3 seconds.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R experiment`
  — `DIAGNOSTIC_52_ATTEMPTS_VERIFIED`.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-remote-receipt.R summary`
  — `DIAGNOSTIC_SUMMARY_VERIFIED`; pure-reader output identical to the retained
  summary.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-negative-control.R`
  — `DIAGNOSTIC_NEGATIVE_CONTROL_VERIFIED`.
- `Rscript --vanilla dev/isdm-requalification/diagnostic-rescue/verify-reviews.R terminal`
  — `DIAGNOSTIC_TERMINAL_REVIEWS_VERIFIED`.
- `git diff --check` — passed.
- `Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'` — final result
  is recorded in the adjacent check-log closeout entry.

Protected closeout used the fresh shared-doc lease
`codex:isdm-identifiability-diagnostic` after the coefficient lane released
the two named dev-log paths.

`devtools::document()`, article rendering, and pkgdown checks were deliberately
not run because no package code, roxygen, Rd, vignette, reader-facing prose, or
navigation changed. Three-OS CI remains required before merge because the
branch adds package tests; it is not used for simulation compute.

## 6. Tests of the Tests

The receipt tests exercise boundary and corruption paths: missing/duplicate
dispositions, extra or modified manifest members, malformed tri-state fit
entry, wrong source/plan identity, unavailable-reason mismatch, and deliberately
flipped target availability. The runner tests combine mixed Poisson-log and
Bernoulli-cloglog public-route fitting with source masking and rotation-
invariant surface/covariance scoring. The watchdog tests exercise interrupted
process groups and coordinator reconciliation.

The installed-manifest portability test satisfies failure-before-fix: remote
qualification first failed because `saveRDS()` bytes differed between Linux and
macOS. Its first repair then failed the new C-versus-UTF-8 regression because
ordinary `order()` followed `LC_COLLATE`. Canonical UTF-8 radix ordering now
passes under both collations and would catch either original defect.

## 7. Roadmap Tick

N/A. This hypothesis-generating diagnostic does not change a public capability
or `ROADMAP.md` status.

## 7a. Issue Ledger

Issue #941 (Integrated GLLVM) was inspected and remains open. This experiment
narrows its validation question but does not close the feature or justify a
public status change. Issues #1133 and #1176 remain separate prediction/article
follow-ups and were not changed. No issue is closed by this internal evidence.

## 8. Consistency Audit

- `git diff --name-only origin/main...HEAD | rg '^(R/|src/|NEWS.md|NAMESPACE|man/|vignettes/|_pkgdown.yml)'`
  — no matches; package/API/likelihood/docs surfaces are unchanged.
- `rg -n 'MIXED|REPLICATION_SIGNAL|ESTIMAND_SIGNAL|BASIN_SIGNAL|TERMINATION_SIGNAL|CURVATURE_SIGNAL' LOOP dev/isdm-requalification/diagnostic-rescue`
  — the approved zero-or-multiple rule, implementation, tests, summary, and
  reviews use the same five labels and `MIXED` boundary.
- `rg -n 'interval|structured-source|threshold|promotion|replacement' LOOP/GOAL.md LOOP/ultra-plan.md dev/isdm-requalification/diagnostic-rescue/reviews/terminal-*.md`
  — only explicit deferrals, invariants, and no-promotion boundaries remain.
- `rg -n 'planned|started|terminal|worker|coordinator|fit_returned|unavailable' dev/isdm-requalification/diagnostic-rescue/reviews/terminal-*.md`
  — every review reports the same 52/52/52 worker denominator, zero coordinator
  substitutions, and zero unavailable records.

The broader package stale-wording scans were not run because this internal
diagnostic lane changes no reader-facing, design-status, roxygen, or formula
surface. Historical reports remain historical evidence and were not rewritten.

## 9. What Did Not Go Smoothly

The first qualified bundle exposed a platform-dependent hash of an R-serialized
data frame. The initial canonical-content repair still used locale-dependent
sorting; independent review caught the C-versus-UTF-8 difference before any
fit started. Both invalid qualification artifacts were abandoned, new isolated
libraries were installed, and the final qualification was rebuilt from the
re-frozen harness. No abandoned artifact entered the smoke or experiment.

The first Unlazy execution reached later gates before experiment evidence and
closeout files existed, so G8 onward recorded expected early failures. They
must be reverified against final evidence rather than treated as scientific
failures. The full package suite exceeded the ledger's original 120-second
per-gate timeout; it was rerun separately with an appropriate bound.

## 10. Known Residuals

This is a 52-fit sentinel, not a recovery or coverage campaign. Its selected
historical task identities are deliberately enriched for outcomes and cannot
estimate population prevalence. The observation-replication result is strong
within these eight pairs but does not establish recovery probability. The
curvature block split is descriptive, not proof of a parameterization defect.
The independent summarizer is commit-bound and was not part of the qualified
remote execution harness; its output was therefore independently reproduced
from raw attempts and protected by the experiment manifest.

Exactly one next action is earned: prepare a separately approved,
nonspatial-only paired multi-seed baseline-versus-rep3 discrimination design
across the same eight cells, with shared/full surface and each of the three
`Psi` contrasts reported separately. Do not launch it from this authority.
Spatial optimizer work, engine changes, intervals, structured-source models,
threshold changes, and public promotion remain deferred.

## 11. Team Learning

**Curie** checked the paired DGP and immutable denominators before launch. The
key lesson is to preserve the baseline rows exactly while adding response
streams; otherwise an apparent replication effect can be seed drift.

**Gauss** checked source, install, DLL, plan, and manifest binding. The remote
qualification failure showed that content receipts crossing operating systems
must hash a canonical byte representation, never language serialization or
locale-dependent order.

**Fisher** independently reproduced all five signals and prevented the strong
8/8 surface improvement from being misreported as a composite replication
signal when the preregistered `Psi` component failed.

**Rose** enforced the scope boundary: `MIXED` here means no signal fired, not
that several mechanisms were proved. Rose also restricted the next action to a
new approval packet and blocked intervals, structured sources, package changes,
and public promotion.

**Grace** contributes a remaining boundary: the qualification retained the
exact successful Ubuntu CI run at the execution source, but it is not itself a
three-OS certification of this dev/test branch. Branch CI must be green before
landing.

## 12. Cross-Product Coverage

Measured nonspatial cells crossed two/three sources, full/weak overlap, and
150/810 cells, with mixed Poisson-log and Bernoulli-cloglog observation laws,
ordinary rank-one latent structure, and baseline/three-response-stream arms.
Measured spatial sentinels crossed two/three sources, full/weak overlap, and
the three historical convergence/Hessian classes, with public default,
five-start `nlminb`, and BFGS-continuation arms.

This diagnostic does not cover intervals, structured-source latent terms,
SPDE slopes, phylogenetic/kernel prediction, richer source weights, absolute
abundance, occupancy, detectability, profile/bootstrap intervals, Julia, or
release readiness.

## 13. Next actions

Prepare the separately approved nonspatial paired multi-seed discrimination
packet named above. Do not start fits under this completed diagnostic's
authority.
