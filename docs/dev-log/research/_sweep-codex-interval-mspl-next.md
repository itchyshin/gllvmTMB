# Teacher extract — Codex LA-MSPL interval lane (PROTECTED)

**Date:** 2026-08-15
**Platform:** Cursor Models bar
**Writer workspace:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`
**Source:** `git -C` only. This checkout did **not** switch to
`codex/lane-b-mspl-interval-feasibility`. `R/mspl.R` was **not** copied.

**Source worktree:** `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`
**Branch / HEAD:** `codex/lane-b-mspl-interval-feasibility` @
`e91c7b7ce7c6f526eeccc0eb2fe518a4d4b6da20`
(`docs: hand off MSPL interval feasibility to Claude`, 2026-08-15).
Handover text still names science tip `701821219f73c3373ce97a19cb2492a3f94cf546`;
`e91c7b7c` is that commit plus the Claude handoff file.

**Audience:** the Poisson SE designer. Binary interval evidence is a
**teacher**, not a transferable calibrated method.

**Absorb rule:** none. Do not merge this branch, do not import helpers, do
not enable `vcov()` / `confint()` / `sdreport()` for MSPL from this note.

**Brain:** `search_notes` over all projects returned no dedicated lane-b
interval note. Vault hits were older drmTMB / VA / structured-RE interval
probes. Treat the Codex worktree as ground truth. Any brain-only claim
below would be **UNVERIFIED**; none is used as load-bearing.

---

## One-line verdict

Finite binary MSPL intervals can be *built* after `se = FALSE` fits; they
are **not** calibrated, and the public SE door stays closed. Poisson SE
inherits the *discipline*, not the numbers.

---

## How this extract was made

```sh
git worktree list   # found ~/.codex/worktrees/8e9d/gllvmTMB
git -C /Users/z3437171/.codex/worktrees/8e9d/gllvmTMB status --short --branch
git -C /Users/z3437171/.codex/worktrees/8e9d/gllvmTMB log --oneline -30
```

Read-only files cited below live in that worktree. A sibling Claude tree
`/private/tmp/gllvmtmb-mspl-interval-calibration`
(`claude/mspl-interval-calibration`) exists and was **not** used.

---

## 1. `se = FALSE` versus `se = TRUE`

MSPL never takes the public TMB `sdreport()` path.

In `R/fit-multi.R` around the `sd_rep` assignment (Codex HEAD `e91c7b7c`),
`estimator == "mspl"` sets `sd_rep <- NULL` and writes
`sdreport_error = "LA-MSPL is an experimental point estimator; standard
errors are withheld until repeated-sampling calibration"`. The
`control$se` branch is reached only for non-MSPL fits. So
`gllvmTMBcontrol(se = TRUE)` on an MSPL fit does **not** produce SEs.

Every private interval runner therefore fitted with `se = FALSE`:

- `inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R`
- `inst/sim/lane-b-uncertainty/run-mspl-interval-feasibility.R`
- `inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R`
  (`375b19ca`, 2026-08-14)
- `inst/sim/lane-b-uncertainty/run-mspl-bootstrap-inversion-pilot.R`
- `tests/testthat/test-mspl-api.R`

After the point exists, private helpers invert a **numerical outer Hessian**
(`stats::optimHess` on `fit$tmb_obj`) or walk a penalised profile. That is
not `TMB::sdreport()`, not `standard_errors()`, and not `vcov()`.

Public refusals remain at `vcov()`, `confint()`, `profile_targets()`,
`tmbprofile_wrapper()`, `bootstrap_Sigma()`, `standard_errors()`,
`getREsd()`, and `getLV(se = TRUE)` via
`.gllvmTMB_mspl_assert_inference()` in `R/mspl.R`
(`e91c7b7c`; also `R/vcov-coef.R`, `R/z-confint-gllvmTMB.R`,
`R/standard-errors.R`).

**Teacher for Poisson SE.** Do not “just flip `se = TRUE`” after a Poisson
tape. The fit layer withholds `sdreport()` for the estimator class. A
Poisson SE lane must name a *new* private construction and a new ADEMP
gate. `se = FALSE` is the honest point-estimate door; it is also the door
the binary campaign actually used.

---

## 2. Sandwich versus profile versus Hessian

Three **different objectives**, not three views of one matrix.
Source map:
`docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-private-uncertainty-method-map.md`
(`108815f4`).

Let \(Q_P(\theta)=\mathrm{NLL}_{LA}(\theta)+P_{\mathrm{MSPL}}(\theta)\) be
the active penalised outer objective on `fit$tmb_obj`
(`estimator_id = 1`). Let \(Q_0\) be the penalty-off Laplace NLL on the
provenance tape (`estimator_id = 2`). Never optimise \(Q_0\). Never treat
the MSPL point as ML.

| Route | Object | What it did | Private result | Public |
| --- | --- | --- | --- | --- |
| Penalised Hessian | Numerical \(\nabla^2 Q_P(\hat\theta)\) via `optimHess` | Private band \(\hat\beta_j\pm 1.96\,SE_H\) | Available as a diagnostic; low-prevalence cloglog **mean-SE / empirical-SD 1.07–1.35** | blocked |
| Paper-style Wald | \(\nabla^2 Q_0(\hat\theta_{\mathrm{MSPL}})\), no optimisation | Sterzinger–Kosmidis (2023) curvature at the penalised point | Endpoint map 21/36 finite; 15/36 typed `likelihood_hessian_non_pd` (5 of 12 *fit-level* Hessians) | blocked (coverage 9/36 joint) |
| Penalised profile | Nuisance-reoptimised crossing of \(Q_P\{\beta_j,\hat\nu(\beta_j)\}-Q_P(\hat\theta)=\tfrac12\chi^2_{1,0.95}\) | Feasibility, then coverage | Endpoints 36/36 after bracket-first bisection; coverage **24/36** joint | blocked |
| Unconditional percentile bootstrap | Full penalised refit after redraw of \(q=1\) site effects + Bernoulli \(Y\) | Endpoint construction, then coverage | Endpoints 36/36; coverage **20/36** joint | blocked |
| Godambe / sandwich | Additive scores \(\nabla Q_P=\sum_s u_s\) | Feasibility audit only | Typed `score_decomposition_unavailable` (`5af1bc0f`) | never built |
| Delete-one-site jackknife | Site-deletion refits | Exploratory only | **WITHDRAWN** (`6a827ffd`); Shinichi rejected | do not revive |

### Sandwich blocker (estimator-level, not Bernoulli-only)

`.gllvmTMB_mspl_sandwich_feasibility()` (`R/mspl.R`; after-task
`docs/dev-log/after-task/2026-08-13-lane-b-mspl-sandwich-feasibility.md`,
commit `5af1bc0f`) records:

1. TMB’s outer gradient is **total-only**.
2. The Laplace log-determinant is added **outside**
   `joint_nll_penalized`.
3. Jeffreys and loading/covariance penalties use global \(N_{\mathrm{eff}}\)
   and \(X_{\mathrm{mspl}}\).

Rejected: assigning global penalties to sites ad hoc; using joint NLL as a
marginal score; using the penalty-off tape as a score; treating
delete-one-site as a Godambe score; widening Hessian bands.

A Poisson Jeffreys atom \(X_*^\top\operatorname{diag}(\mu)X_*\) is also
**global**. The sandwich hole is not cured by changing the family.

### Two Hessians (do not collapse the names)

1. **Penalised numerical Hessian** —
   `.gllvmTMB_mspl_penalized_hessian_diagnostic()` (`d0f57448` closeout).
   TMB’s analytic Hessian is unavailable with random effects (stage-A
   after-task
   `docs/dev-log/after-task/2026-08-13-lane-b-mspl-uncertainty-stage-a.md`).
   This is not `sdreport()`.
2. **Penalty-off likelihood Hessian** —
   `.gllvmTMB_mspl_likelihood_hessian_diagnostic()`. Evaluated only at
   \(\hat\theta_{\mathrm{MSPL}}\). Non-PD, nonfinite, rank-deficient, or
   step-sensitive Hessians stay typed blockers. No pseudoinverse, no
   eigenvalue clip, no nearest-PD, no substitution of the penalised
   Hessian (`e2055c7b`, `108815f4`).

### Profile is not a likelihood-ratio CI

The crossing uses \(Q_P\), not \(Q_0\). Tests poison the penalty-off `fn`
so a silent tape swap cannot pass. Early cloglog walks reported
`optimizer_failed` even when the retained trace already held a finite
bracket; Arc 3 (`e2055c7b`) stopped at the first adjacent
inside/outside pair and bisected to width \(\le 1.25\times 10^{-4}\).
That repaired *construction*, not *coverage*.

---

## 3. What broke

Timeline on the Codex branch (selected commits):

| When | Commit | Break / close |
| --- | --- | --- |
| 2026-08-13 | stage-A / `d0f57448` | Analytic TMB Hessian unavailable; numerical \(SE_H\) admitted privately; low-prevalence cloglog scale mismatch blocks promotion |
| 2026-08-13 | `5af1bc0f` | Sandwich typed blocker |
| 2026-08-13 | regime map | 4/36 cloglog lower walks `optimizer_failed` on the *fixed* grid (later repaired as construction, not calibration) |
| 2026-08-13 | uncertainty pilot | Low-prevalence cloglog profile: nonavailability + poor unconditional coverage |
| 2026-08-14 | `6a827ffd` | Jackknife withdrawn |
| 2026-08-14 | `e2055c7b` / `108815f4` | Trio endpoints feasible (profile 36/36, bootstrap 36/36, Wald 21/36) |
| 2026-08-14/15 | coverage production (`8b23cfd2` source; after-task `2026-08-14-lane-b-mspl-coverage-calibration-production.md`) | **No method passed 36/36** |
| 2026-08-15 | inversion (`70182121`, `e91c7b7c`) | Constrained inversion not a repair; centred-pivot 1/36; do not spend the planned 2,102 core hours |

### Coverage campaign (immutable; compact Git artefacts)

`docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/`

- 1,200 shards; 12,000 outer fits; 6,000,000 bootstrap refits;
  108,000 endpoints; 1,159,993 profile-trace rows.
- Receipt SHA-256
  `8232f1a847e6bfeb4626e6b55d033496743aa0e373284ad30a6432aeac277ea1`.
- Gate: availability \(\ge 0.95\); unavailable = noncoverage; 90% Wilson
  coverage interval wholly inside \([0.92, 0.98]\). Wald uses conditional
  coverage given a PD penalty-off Hessian and \(\ge 500\) available
  intervals.

From `method-summary.tsv`:

| Route | Joint pass | Availability fail | Coverage fail |
| --- | ---: | ---: | ---: |
| Profile | 24 / 36 | 2 | 11 (25 coverage-pass; 24 joint) |
| Bootstrap | 20 / 36 | 0 | 16 |
| Wald | 9 / 36 | 0 (cell-level) | 27 |

Profile availability failures named in the handover (`e91c7b7c`):
`C003` target 3 (high-prevalence logit, 945/1,000) and `C010` target 1
(low-prevalence cloglog, 928/1,000), both below the 0.95 floor
(`gate-map-108.tsv`).

Worst case `C011` (high-prevalence cloglog, 1/9 joint pass in
`case-summary.tsv`):

- Profile targets 2 and 3 cover **1.000** (Wilson upper = 1, fails the
  0.98 ceiling — overcoverage).
- Bootstrap target 3 covers **0.01**. Target 2 covers 0.358. This is the
  “severe high-prevalence cloglog undercoverage” in the production
  after-task.

Wald retained **6,948** non-PD endpoint failures. Availability of a
finite \(SE\) is not a coverage pass: several Wald cells have
conditional coverage near 0.98 while unconditional coverage sits near
0.52–0.63 because half the Hessians are non-PD.

Bootstrap re-expressions of the same 6M refits did not repair the map
(percentile 20/36, basic 14, normal 15, BC-normal 17, non-accelerated BC
2). Constrained inversion at \(\pm 2\) / \(\pm 4\) rejected both
boundaries on only 6/36 and 9/36 sides; centred-pivot 1/36.

**Scope of the break.** Ordinary complete Bernoulli, \(q=1\), 24 sites,
3 traits, four named regimes, three links, three `b_fix` coordinates.
Not \(q=2\), not structured effects, not missing data, not loadings,
not Poisson.

---

## 4. What this can teach a Poisson SE lane

These are **discipline transfers**. They are not Poisson numbers.

1. **Keep `se = FALSE` until a named construction exists.** MSPL
   withholds `sdreport()` at the estimator, not at the family. A Poisson
   public door for the *point* (`#978` / planned registry) does not open
   SEs.

2. **Name the tape before naming the interval.** Profile and bootstrap
   must follow \(Q_P\) (`estimator_id = 1`). Wald-style curvature, if
   used at all, evaluates \(Q_0\) only at the penalised point. Poison
   the other tape in tests. Poisson will grow a new information atom;
   the same two-tape split still applies
   (`docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md` in
   *this* workspace: Poisson Jeffreys is \(\beta\)-dependent through
   \(\mu\), unlike Gaussian).

3. **Do not start with sandwich.** The missing object is an additive
   active-score decomposition of a Laplace-marginal TMB fit with global
   penalties. A Poisson \(W=\mathrm{diag}(\mu)\) atom does not create
   per-site scores. Handover `e91c7b7c` still says a standard
   Godambe route needs a *new estimator-level construction*.

4. **Do not revive jackknife** unless Shinichi reverses the recorded
   rejection.

5. **Feasibility is cheap; calibration is the gate.** Binary profile
   endpoints became 36/36 and still failed 12 cells. Poisson all-zero /
   near-zero traits are the analogue of low-prevalence cloglog: the
   Hessian can look PD and still be mis-scaled (binary warning:
   mean-SE / empirical-SD 1.07–1.35). The Poisson prep already says
   information size is \(\mathrm{tr}(W)=\sum\mu\), not row count.

6. **Retain non-PD Hessians.** Do not repair. Report availability and
   coverage as a conjunction. Conditional-on-PD coverage lied about
   Wald.

7. **High-prevalence cloglog bootstrap collapse (coverage 0.01) is a
   warning about one-sided / saturated mean regimes**, not a Poisson
   measurement. A Poisson SE design that skips all-zero *and*
   large-\(\mu\) cells will repeat this mistake.

8. **Do not promote a passing subset.** The frozen gate was 36/36. The
   53/108 joint-pass cells are not a public menu. Same rule if a
   Poisson pilot looks good on “healthy” counts only.

9. **New family = new ADEMP + G0.** The Codex handover’s owed next work
   is a *theory* lane for a non-jackknife pivot, not another binary
   array, and not a Poisson campaign. Binary evidence does not license
   Poisson `vcov()`.

10. **Keep the public fence.** `MSPL-04` stays `blocked` on that branch.
    This extract does not change the register.

---

## 5. Authoritative Codex files (read these, do not absorb code)

- `docs/dev-log/handover/2026-08-15-claude-handover-mspl-interval-feasibility.md` (`e91c7b7c`)
- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-coverage-calibration-production.md`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-private-uncertainty-method-map.md` (`108815f4`)
- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-trio-interval-feasibility.md`
- `docs/dev-log/after-task/2026-08-13-lane-b-mspl-sandwich-feasibility.md` (`5af1bc0f`)
- `docs/dev-log/after-task/2026-08-13-lane-b-mspl-hessian-calibration.md` (`d0f57448`)
- `docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/{README.md,method-summary.tsv,gate-map-108.tsv,case-summary.tsv}`

Raw shards under `/tmp/mspl-coverage-production-8b23cfd2-eqLdNa` and DRAC
`/project` are **outside Git**. If those trees are gone, row-level
re-aggregation is **UNVERIFIED**; the compact TSV/README hashes above
remain the committed verdict.

---

## 6. Explicitly not done

- No checkout of the protected branch in this worktree.
- No copy of `R/mspl.R`.
- No absorb of private helpers into the Cursor MSPL programme.
- No Poisson SE implementation, campaign, or public claim.
- No commit.
