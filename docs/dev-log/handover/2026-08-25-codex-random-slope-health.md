# Codex handover — random-slope health, before promotion

**Date:** 2026-08-25 (MDT)  
**Receiving tool:** Codex  
**Worktree:** `/private/tmp/gllvmtmb-random-slope-health`  
**Branch:** `codex/random-slope-health` (clean branch from `origin/main` at
`482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`)

## Critical context

You are Codex, picking up a new, isolated diagnostic lane. The 0.7.1
trust-release candidate is finished and merged; preserve that release evidence.
This lane is **not** a continuation of the old dirty random-slope handover or
of any prior random-slope worktree.

Random slopes are not ready for a broad public claim. The retained 12-cell
release-first smoke has **7/12 healthy fits** and explicitly fails its
all-healthy smoke gate. It is valuable internal evidence, but it is not a
recovery, interval-calibration, or family-wide admission result. Do not
cherry-pick the seven healthy cells or turn this evidence into release prose.

The maintainer’s 2026-08-25 direction is to keep four linked gaps visible:

1. random-slope health and recovery;
2. interval coverage;
3. diagnostics; and
4. REML.

5. predictor-informed latent-score means, `latent(..., lv = ~ x1 + x2)`.

They are connected, but they are **not authorised as one large implementation
or compute campaign**. This lane begins with diagnosis and a narrow plan. A
later interval, diagnostics, or REML arc needs its own bounded objective and,
if it crosses the 30-minute estimate line, an estimate, pre-run, and explicit
approval before the full run.

## What was accomplished before this handover

- PR #1207 merged the 0.7.1 exact-byte release candidate. Its candidate source
  was `0f2cbe9a427734ad4f422ded7f9fb5c8c99c640a`; the merge on `main` is
  `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`. It has retained local artifact,
  full macOS/Ubuntu/Windows, pkgdown, and fresh-review evidence. No tag, CRAN
  submission, or announcement occurred.
- The post-candidate report is retained on
  `origin/codex/0701-trust-release-closeout` at
  `docs/dev-log/after-task/2026-08-25-0701-trust-release.md`. Its eventual
  shared `check-log.md` append remains coordinated with #1208; do not touch
  that shared log from this lane without a fresh lane preflight and a narrow
  lease.
- The earlier slope receipt is
  `docs/dev-log/after-task/2026-08-20-release-first-collaborator-slope-evidence.md`
  (commit `11b10de4`). It retains all 12 attempts: `n_healthy = 7`,
  `smoke_pass = FALSE`, p90 15.4482 seconds, and total 98.0146 seconds.
  It explicitly says not to launch Totoro or DRAC from this result.
- The current capability record is
  `docs/design/61-capability-status.md`. It says one structured slope has
  named covered cells, while lognormal/Student-t and some non-Gaussian or
  multi-slope routes remain partial; interval calibration is a separate open
  limitation. Do not collapse these row-level distinctions into “random slopes
  work”.

## Current working state

- **Working:** clean new worktree and branch, created from current `origin/main`.
  A narrow path lease protects this handover file only.
- **In progress:** none. No package code, tests, design docs, or campaign
  fixtures have been changed in this worktree.
- **Blocked deliberately:** no large simulation, Totoro/DRAC job, public claim,
  documentation promotion, formula-grammar change, likelihood change, or
  release action is authorised by this handover.

## Decisions and rationale

- **Fresh lane, fresh baseline.** The release candidate must stay auditable and
  old random-slope branches/worktrees are protected historical evidence.
- **Diagnose before repair.** “7/12 healthy” is a fit-health signal, not enough
  to infer the failure mechanism. First classify failures by family, covariance
  route, convergence, Hessian, boundary, and data/fixture conditions.
- **Intervals stay separate from point recovery.** The Mission Control surface
  records interval status as point-only/early. No coverage claim is earned
  until target-specific, retained denominator evidence exists.
- **Diagnostics and REML are dependency questions, not automatic add-ons.**
  Diagnostics may explain failures; REML may be relevant only for the named
  Gaussian target. Neither is a blanket fix for non-Gaussian random slopes.
- **MSPL remains parked experimental work.** Do not expand it from this lane.
- **`lv = ~ x1 + x2` has a narrow, separate boundary.** It is a mean model for
  ordinary unit-tier latent scores, not a random-slope term. Native TMB admits
  ordinary Gaussian and pure binomial logit/probit/cloglog only; native Poisson
  and other non-binomial families fail loudly. The Julia bridge has
  complete-response point-only routes for Gaussian, Poisson, NB2, Gamma, Beta,
  and standard-link binomial, with no fixed-effect RHS, response mask, or CI.
  `REML = TRUE` with `lv` is rejected. Do not make it part of this slope repair.

## Next immediate steps

1. Run `lane_preflight.sh` in this worktree and inspect the current coordination
   board before claiming any production path. Reconcile this handover against
   current `origin/main`; it is a dated state record, not permission to repeat
   earlier work.
2. Read the exact 12-cell receipt, the current capability table, the relevant
   validation-debt rows (`RE-02`, `RE-03`, `RE-12`, `RE-14`, `CI-08`, `CI-10`),
   and the existing slope test/fixture code. Build a prior-work matrix with a
   **CODE** row as well as documentation and evidence rows.
3. Write a fresh ultra-plan and acceptance ledger for one diagnosis arc. The
   first deliverable is a retained failure taxonomy plus a small known-DGP
   pre-run design, not a broad repair or a published capability.
4. Estimate the pre-run. If it is <=30 minutes, run it locally with retained
   results; if >30 minutes, present the estimate and pre-run plan to Shinichi
   for approval before running it. Pin `OPENBLAS_NUM_THREADS=1` for parallel
   work and measure both serial cost and realised parallel speedup.
5. Only after the diagnosis decide whether the next separate arc is (a)
   random-slope recovery, (b) diagnostics exposure/repair, (c) Gaussian-only
   REML target clarification, (d) target-specific interval calibration, or
   (e) an `lv` family-expansion design. Do not bundle them.

## Reader and claim boundary

The dashboard screenshot on 2026-08-25 correctly identifies the headline
gaps: interval coverage is the largest remaining task; random slopes are
unfinished/partial; diagnostics vary by family; REML is pilot/limited. These
are operational priorities, not a public release statement. Any new prose must
preserve the 0.7.1 fence: no claim that random slopes are broadly recovered,
calibrated, CRAN-ready, or released.

## Files created or modified by this handover

| Path | State | Notes |
|---|---|---|
| `docs/dev-log/handover/2026-08-25-codex-random-slope-health.md` | pending commit | This durable receiving brief only. |
| `/Users/z3437171/.codex/memories/extensions/ad_hoc/notes/20260825-gllvmtmb-random-slope-priorities.md` | local memory update | User-directed cross-session priority note; not part of this repository branch. |

No package-owned source, tests, NEWS, validation register, check log,
coordination board, or public article has been changed by this lane setup.

## Landing state

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `origin/main` at `482c9d37` (0.7.1 RC merge) | yes | yes | #1207 merged | LANDED |
| `origin/codex/0701-trust-release-closeout` | yes | yes | none | LANDED closeout report; later check-log coordination pending #1208 |
| `codex/random-slope-health` | no | no | none | CARRIED-OVER until this handover doc is committed and pushed |

## Gotchas and failed approaches

- The 7/12 smoke closes the remote-compute gate; it does not justify retrying
  only healthy families or a larger campaign.
- Search all of `R/`, `src/`, `tests/`, and `docs/` before declaring a gap.
  A documentation-only sweep has previously rebuilt functionality that already
  shipped.
- A green check from an earlier SHA is not candidate evidence. Bind every
  claim-bearing result to exact source bytes.
- Do not modify `docs/dev-log/check-log.md` casually: it is a shared,
  append-only multi-lane file and its 0.7.1 closeout append is already
  coordinated with #1208.
- Do not use GitHub Actions for a simulation/recovery/coverage campaign.
  Actions is for package checks/docs; campaign evidence belongs locally or on
  Totoro/DRAC under the compute rules.

## Mission Control summary

| Repo | Branch / baseline | CI / artifact state | What is true now | Plan by leverage |
|---|---|---|---|---|
| gllvmTMB | `codex/random-slope-health` from `origin/main` `482c9d37` | 0.7.1 exact RC validated; no tag/CRAN | Random slopes remain partial/internal; intervals point-only; diagnostics and REML not broad admissions | 1. diagnostic taxonomy + pre-run design; 2. choose one recovery/diagnostics/REML/interval arc; 3. only then run approved evidence |

## How to resume

From the new worktree:

```sh
cd /private/tmp/gllvmtmb-random-slope-health
bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"
git fetch origin && git status --short --branch && git log --oneline origin/main -5
export NOT_CRAN=true
```

Read in this order:

1. `AGENTS.md`;
2. this handover;
3. `docs/dev-log/handover/2026-07-25-active-lane-split.md`;
4. `docs/dev-log/after-task/2026-08-20-release-first-collaborator-slope-evidence.md`;
5. `docs/design/61-capability-status.md` and the named validation rows;
6. the current `R/`, `src/`, and `tests/testthat/` code identified by the
   prior-work sweep.

**Pasteable fresh-Codex prompt:**

> Rehydrate from `docs/dev-log/handover/2026-08-25-codex-random-slope-health.md`, then run the lane preflight, reconcile the handover with current `origin/main`, and continue only the diagnostic random-slope next steps. Do not run compute or promote a claim without the required estimate, ledger, and approval.

**Tool routing:** Codex owns any live R/TMB fits, package checks, rendering,
and approved simulation pre-run. Keep broad compute and public documentation
promotion out of scope until the diagnostic arc is approved and its evidence
is reviewed.
