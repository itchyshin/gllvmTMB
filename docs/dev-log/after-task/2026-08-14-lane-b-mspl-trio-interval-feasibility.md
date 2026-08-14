# After Task: private LA-MSPL Wald/profile/bootstrap interval feasibility

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** 2026-08-14
**Roles engaged:** Ada, Curie, Fisher, Grace, Rose, Shannon

## 1. Goal

Restore the private Wald/profile/bootstrap trio for all 36 fixed-effect cells
in the selected deterministic ordinary `q = 1` complete-Bernoulli matrix:
four regimes x logit/probit/cloglog x three resolved `b_fix` targets. The task
was endpoint-construction feasibility only; it did not seek calibrated
standard errors, confidence intervals, or coverage.

## 2. Implemented

The private profile helper now retains earlier failed trial points, stops a side
at its first adjacent finite and converged inside/outside threshold bracket,
and performs at most 12 bisections to width `<= 1.25e-4`. It reoptimises every
nuisance coordinate on the active penalised `fit$tmb_obj`.

The new paper-style Wald diagnostic evaluates the full penalty-off approximate
Laplace NLL Hessian only at the penalised MSPL estimate. It checks two finite-
difference steps, full rank, positive definiteness, and a finite target
variance. It returns typed blockers and performs no optimisation, pseudoinverse,
eigenvalue clipping, nearest-PD repair, or penalised-Hessian substitution.

The new private bootstrap runner freezes 12 fixtures, deterministic seeds,
atomic 100-refit shards, complete provenance, and an exact 36,000-row target
grid. Each replicate confirms unconditional random-effect redraw, refits the
complete penalised MSPL procedure, and records all three fixed-effect targets.
The summariser retains every attempted row and requires at least 950 usable
refits, ordered type-7 percentile endpoints, and endpoint MCSEs no larger than
10% of interval width.

The active jackknife implementation, tests, runner route, and future campaign
recommendation were removed. Historical jackknife reports and the recovery
checkpoint are visibly marked `WITHDRAWN — exploratory route`.

## 3. Mathematical Contract

Let the active penalised outer objective be

\[
Q_P(\theta) = \operatorname{NLL}_{LA}(\theta) + P_{MSPL}(\theta),
\]

where `fit$tmb_obj` has `estimator_id = 1`. For fixed target `beta_j`, the
profile reoptimises nuisance coordinates `nu` and locates the fixed numerical
crossing

\[
Q_P\{\beta_j,\hat\nu(\beta_j)\} - Q_P(\hat\theta_{MSPL})
= \tfrac{1}{2}\chi^2_{1,0.95}.
\]

This is a penalised-objective diagnostic crossing, not a likelihood-ratio
confidence interval.

For the Wald route, let `Q_0` be the full penalty-off approximate Laplace NLL
on the provenance tape (`estimator_id = 2`). The diagnostic evaluates

\[
H_0 = \nabla^2 Q_0(\hat\theta_{MSPL}), \qquad
\widehat V_0 = H_0^{-1},
\]

only when `H_0` is finite, full-rank, positive definite, and step-stable. The
centre remains the penalised MSPL estimate; `Q_0` is never optimised.

For bootstrap replicate `b`, the runner unconditionally redraws the `q = 1`
site effects and Bernoulli responses and refits the complete MSPL procedure to
obtain `beta_hat_j^(b)` from estimator ID 1. The private endpoints are the
type-7 empirical 0.025 and 0.975 quantiles. This construction does not measure
their repeated-sampling coverage.

No public R API, likelihood implementation, formula grammar, response family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** preserve three distinct objective roles. **Rationale:** profiling
and bootstrap must follow the fitted penalised estimator, while the paper-style
Wald construction deliberately asks for penalty-off likelihood curvature at
that estimate. **Rejected:** treating all three routes as one objective,
optimising the penalty-off tape, or relabelling the centre as ML. **Confidence:**
high; objective IDs are asserted in source, tests, and raw receipts.

**Decision:** retain non-PD Wald Hessians as typed blockers. **Rationale:** any
pseudoinverse, eigenvalue clipping, nearest-PD repair, or penalised-Hessian
substitution would answer a different question. **Rejected:** numerical repair
and Wald substitution for profile/bootstrap failures. **Confidence:** high.

**Decision:** rerun scheduler failures only with the same manifest keys.
**Rationale:** pre-fit setup and shell failures created no statistical row.
**Rejected:** replacement replicate IDs or adaptive statistical retries.
**Confidence:** high; exact-key validation found one row for every frozen key.

## 4. Files Touched

Implementation and active tests:

- `R/mspl.R`
- `inst/sim/lane-b-uncertainty/run-mspl-interval-feasibility.R`
- `inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R`
- `tests/testthat/test-mspl-api.R`
- `tests/testthat/test-mspl-interval-runner.R`
- `tests/testthat/test-mspl-uncertainty-runner.R`

Withdrawn historical records:

- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-jackknife-feasibility.md`
- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-jackknife-prerun.md`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-jackknife-admission.md`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-jackknife-calibration-prerun.md`
- `docs/dev-log/recovery-checkpoints/2026-08-14-213000-codex-mspl-jackknife-admission.md`

Arc 3 records:

- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-private-uncertainty-method-map.md`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-trio-interval-feasibility.md`
- `docs/dev-log/recovery-checkpoints/2026-08-14-075558-codex-mspl-trio-campaign.md`
- `docs/dev-log/check-log.md`
- this report

No README, NEWS, ROADMAP, known-limitations, validation-register, roxygen, Rd,
vignette, or pkgdown file changed because the work remains private and the
public `MSPL-04` inference status remains blocked.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl", stop_on_failure = TRUE)'
# PASS: 1,239 expectations, 0 failures, 0 warnings, 1 pre-existing skip;
# 142.7 seconds.

Rscript --vanilla inst/sim/lane-b-uncertainty/run-mspl-interval-feasibility.R \
  summarise --root /private/tmp/gllvmtmb-mspl-arc3-5598f9e4-consolidated
# PASS: raw_rows 36,000; summary_rows 36; finite_stable 36;
# public_fence unchanged.

git diff --check
# PASS at closeout.
```

The deterministic regression returned profile `matched/crossed/crossed/TRUE`
for all 36 targets. Wald returned 21 `ok` targets from seven fit-level Hessians
and 15 `likelihood_hessian_non_pd` targets from five fit-level Hessians.

The bootstrap campaign attempted exactly 12,000 refits and retained exactly
36,000 target rows. All rows were `status = "ok"`, convergence zero,
`estimator_id = 1`, finite, and `unconditional_redraw = TRUE`. Each target had
1,000 usable estimates. All 36 target summaries were `finite_stable`; the
largest endpoint-MCSE/width ratio was `0.080120592`.

Completed statistical task IDs were `19017652_1`--`19017652_10`,
`19017739_11`--`19017739_20`, and arrays `19017794`,
`19017801`--`19017809` for indices 21--120. All 120 tasks wrote exactly one
atomic shard.

Durable Rorqual hashes:

- manifest: `d9091022cb86b853672a93bc3960379096b464c0ef8e2717c7ffcf316c35c8e5`;
- raw archive: `5070f86e9f17e43bc1e9fa5b68cee6f24ea1f8e0c072a18b9f41ef8b548cd357`;
- summary: `fbca5b3ee66d6ab8c25cdd5ce766b46bf16afae46110220ba2699652cd7e9a1b`;
- failure table: `0b953a58a94937d8cb95cfce3bc4caf9e38c525c3982aa88ef11944679bdf17f`;
- receipt: `701e2e8206d5ab41ccff72ecae10ab680e6d635dfbe8f2c22b9f4df530306b6e`.

Deliberately not run: package-wide tests, `R CMD check`, pkgdown, CI, GitHub
Actions, public documentation, q = 2, structured effects, missing data,
coverage, calibrated-SE assessment, or public method activation.

## 6. Tests of the Tests

The profile regression is a failure-before-fix test: four cloglog sides
previously returned `optimizer_failed` even though their retained traces
contained adjacent finite, converged threshold brackets. The revised test
requires the bracket-first terminal rule and bounded refinement in all 36
cells.

The Wald map exercises a numerical boundary rather than only a happy path:
seven positive-definite fit-level Hessians must succeed, while five non-PD
Hessians must remain typed blockers. Tests poison or distinguish the wrong
objective tape so a penalised-Hessian substitution cannot pass unnoticed.

The bootstrap tests cover the exact 12-row manifest, seed mapping, atomic
shards, failure retention, estimator identity, and production cardinality. A
negative test flips one otherwise successful row to
`unconditional_redraw = FALSE` and requires validation to fail; this caught
and closed the statistical reviewer's load-bearing concern before compute.

## 7a. Issue Ledger

Open issue #345, the first-CRAN-readiness roadmap issue, was inspected through
`gh issue list --search MSPL`. It is not advanced by a private, fail-closed
endpoint-feasibility result. No issue was commented, closed, or created; the
arc's next scientific gate is recorded locally because no public capability
or release status changed.

## 8. Consistency Audit

```sh
rg -n -i 'jackknife|jack-knife' R tests/testthat inst/sim
# PASS: zero active-code matches.

git diff -- NAMESPACE
# PASS: no NAMESPACE change.

rg -n 'gllvmTMB_mspl_inference_abort|gllvmTMB_mspl_assert_inference|estimator = "mspl"|profile_targets|tmbprofile_wrapper|bootstrap_Sigma' \
  R/vcov-coef.R R/z-confint-gllvmTMB.R R/profile-targets.R R/profile-ci.R \
  R/bootstrap-sigma.R
# PASS: public vcov/confint/profile/bootstrap refusal gates remain present.

rg -n 'gllvmTMB_mspl_(profile_feasibility|profile_threshold_diagnostic|likelihood_hessian_diagnostic)|unconditional_redraw|36,000' \
  NAMESPACE R/mspl.R \
  inst/sim/lane-b-uncertainty/run-mspl-interval-feasibility.R \
  tests/testthat/test-mspl-interval-runner.R
# PASS: dot-prefixed helpers, unconditional-redraw guard, negative test, and
# exact production-cardinality guard are present; no export was found.
```

The status inventory was inspected. README, NEWS, ROADMAP,
`docs/dev-log/known-limitations.md`, `_pkgdown.yml`, and the validation-debt
register require no change because no user-facing capability was promoted.
Historical jackknife records remain for provenance but carry visible
withdrawal banners. The current method map no longer recommends jackknife.

## Roadmap Tick

**Roadmap tick:** N/A. This private experimental result does not change a
public roadmap row or validation-debt status.

## 9. What Did Not Go Smoothly

The initial bootstrap aggregator counted `status = "ok"` rows as usable without
independently requiring `unconditional_redraw = TRUE`. Fisher's review found
the gap; `5598f9e4` added both the validator guard and a negative regression.

Fir and Rorqual project-library extraction hit file-count quota, Nibi's live
ControlMaster stopped returning remote commands, and a Fir-built dependency
library raised an illegal CPU instruction on Narval. The final Rorqual setup
used node-local libraries and exact-source compressed artifacts.

The first production array failed before fitting because R printed the shard
mapping without a trailing newline. Bash `read` assigned the values but
returned nonzero under `set -e`. A one-task trace proved the cause; adding the
newline allowed the same missing shard keys to run. No failed statistical draw
was replaced, because those scheduler attempts wrote no raw row.

## 10. Known Residuals

The result covers only four deterministic ordinary complete-Bernoulli `q = 1`
regimes. It does not cover repeated-sampling coverage, SE calibration, q = 2,
structured effects, missing data, multi-trial binomial data, offsets, fixed
coefficients, or arbitrary datasets. Five of 12 paper-style Wald fit-level
Hessians remain non-PD blockers.

The next scientifically distinct arc, if approved, is a repeated-sampling
coverage and calibration design for the already feasible profile and bootstrap
routes, with the Wald non-PD mechanism retained as a separate availability
outcome. It must begin with an ADEMP design and a measured pre-run; this arc
does not activate public `vcov()`, `confint()`, profile, bootstrap, or standard-
error methods.

## 11. Team Learning

**Ada:** kept the milestone at endpoint feasibility and rejected scope drift
into coverage, q = 2, structured effects, public methods, or numerical Wald
repair. The useful decomposition was objective-specific: profile/bootstrap on
ID 1, Wald curvature on ID 2 at the ID-1 estimate.

**Curie:** treated cases, seeds, attempts, and failures as an immutable grid.
The exact-key validator and no-replacement rule separated scheduler reruns from
statistical retries and made the 36,000-row receipt auditable.

**Fisher:** caught the missing unconditional-redraw condition before compute
and required the claim to remain endpoint construction rather than confidence-
interval calibration. Fisher also required the 21 Wald targets to be reported
as seven fit-level Hessian successes, not 21 independent Hessians. The final
read-only statistical gate passed with no P0/P1/P2 finding.

**Grace:** isolated three infrastructure mechanisms—quota, connection, and CPU
instruction compatibility—before spending more compute. Node-local libraries,
compressed provenance artifacts, right-sized five-minute tasks, and durable
Rorqual hashes made the final campaign reproducible without GitHub Actions.

**Rose:** the final mechanical audit passed every active public fence but found
that the method map and one recovery checkpoint still described jackknife as
active. Their explicit withdrawal markers resolved the warning; the repeat
audit passed.

**Shannon:** the pre-edit lane check found several other Codex worktrees but no
foreign platform owning this MSPL lane. Shared-file edits stayed within the
named worktree; GitHub PR lookup was unavailable and that limitation was
recorded rather than treated as proof of no overlap.

## 12. Cross-Product Coverage

Covered here: ordinary complete single-trial Bernoulli data, `q = 1`, zero
offsets, no fixed coefficients, baseline/low-prevalence/high-prevalence/
strong-signal regimes, logit/probit/cloglog, three resolved `b_fix` targets,
private profile/bootstrap endpoint construction, and typed paper-style Wald
availability.

This arc **does NOT cover** `q > 1`, spatial/phylogenetic/kernel/animal
structure, missing or
aggregated responses, multi-trial binomial data, offsets, fixed or tied
coefficients, non-Bernoulli families, arbitrary prevalence/signal/sample-size
regimes, SE calibration, nominal coverage, public inference providers, release
admission, or reader-facing documentation.
