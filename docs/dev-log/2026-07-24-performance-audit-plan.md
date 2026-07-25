# gllvmTMB Performance Audit Plan

```text
GOAL: In this Codex session, establish whether gllvmTMB has a measured,
reproducible performance bottleneck relevant to Ayumi's two-level,
mixed-family BIRDBASE GLLVM workflow; deliver a benchmark receipt and a
focused C++/TMB review target. HEADLINE: improve elapsed time only when the
same numerical fit is retained. IN PARALLEL: source/workflow inventory and
benchmark-fixture design after the audit contract is fixed. DEFER: variational
approximation, likelihood reparameterisation, and any broad optimisation
rewrite. DISCIPLINE: use a toy smoke before any full fit; use Totoro for the
representative fit if required; retain all starts and convergence safeguards;
accept a patch only with numerical parity plus a measured speedup; close with
an after-task report.
```

## What is known

- Ayumi's public BIRDBASE issue records a 26-response, two-tier rank-2,
  mixed-family BFGS-polished fit in 1,206.57 seconds. Her broader campaign
  uses several model variants and five starts.
- `gllvmTMB_multi_fit()` currently executes `n_init` restarts serially. This
  is an immediate wall-clock candidate, but preserves its scientific purpose:
  selecting the best likelihood basin.
- Design 72 already tested a narrow VA-vs-Laplace feasibility prototype and
  parked further VA work. This audit does not reopen that estimator project.
- The working Claude checkout was dirty and active. This clean worktree was
  created from `origin/main`; no open PR existed at the pre-edit check.

## Audit contract

| Stage | Deliverable | Gate |
| --- | --- | --- |
| Baseline | One reproducible mixed-family two-tier fixture with `n_init = 1` and `n_init = 5` receipts | Same data, control settings, package revision, and thread count |
| Attribution | Time split for R setup, optimizer, and TMB objective/gradient work | Do not infer a C++ problem from total elapsed time |
| Review | A short list of measured C++/TMB hot paths | No generic rewrite or speculative micro-optimisation |
| Repair | One independent, minimal patch per proven bottleneck | Identical objective/gradient/report at controlled parameters plus benchmarked speedup |

## Deferred

- Running the full 5,397-species BIRDBASE analysis locally without Ayumi's
  data and environment.
- Reducing starts, changing the raw-gradient acceptance criterion, or changing
  the biological model merely to save runtime.
- VA/EVA or a new fitting engine.
