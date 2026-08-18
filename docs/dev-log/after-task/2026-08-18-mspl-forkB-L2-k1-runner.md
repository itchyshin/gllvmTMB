# After-task — Design 125 fork B local-L2 K1 runner

**Date:** 2026-08-18
**Lane:** `cursor/mspl-forkB-L2-exec-20260818`
**Worktree:** `~/local-scratch/lanes/gllvmTMB-mspl-forkB-L2-goal` from `origin/main` @ `2a2a0450`

## Scope

K1 only: thin L2 runner that reuses `dev/mspl-forkB-l1-ademp.R`. No 50-rep
panel, no official L2 receipt, no Totoro.

## Outcome

`dev/mspl-forkB-l2-smoke.R` sources the L1 ADEMP harness, inherits official
Seed A (20260818 / `L1-anchor-n80-T8`, cov_eff **0.880**, #1128), remaps cell
status to `L2-RECORDED` (does not re-freeze L1's 0.80 Wilson rule), and
attaches Wilson + binomial MCSE. `--panel=k3` walks only the new grid cells.

## Checks

- `Rscript --vanilla -e 'parse("dev/mspl-forkB-l2-smoke.R")'` — 24 expressions.
- `Rscript --vanilla dev/mspl-forkB-l2-smoke.R --sourced` — exit 0, no fit.
- Seed A refuse (log, not exit code): `--seed_base=20260818 --n_rep=1 --no-write`
  stopped at `mspl_forkB_l2_guard_seed_a` with "inherited official L1 (cov_eff 0.880, #1128)"
  after `load_all()` of this checkout. No DGP / fit started.
- `git diff --stat -- dev/mspl-forkB-l1-ademp.R LOOP docs/dev-log/lanes/cursor-mspl-fork-B/`
  empty. Root `LOOP/` and closed g0_unlock untouched.
- Deliberately not run: K2 1-rep smokes as *this* sitting's claim, K3 panel,
  Totoro, `devtools::test`, public se, undraft #1077.

## Follow-up

K2a + K2b smoke-first on the exec branch. Do not start Totoro.

## Definition-of-done notes

Items 2–4 (simulation recovery, user example, pkgdown) N/A — internal runner,
no public capability. Rose fence: MSPL-04 stays `blocked`; #1077 stays draft;
no NEWS `covered`.
