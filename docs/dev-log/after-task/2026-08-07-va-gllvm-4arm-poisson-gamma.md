# After-task — gllvm 4-arm poisson/gamma comparator (Totoro)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Scope:** Resume aborted gllvm VA compare; deliver matched 4-arm known-truth
probe (gllvmTMB VA / LA + gllvm VA / LA) for poisson + gamma at `q∈{2,5}`.

## Outcome

- Consolidated probe on Totoro confirmation `022b4eab` checkout
  (`va-gllvm-h2h-4arm-022b4eab-20260807`), 8 seeds, 24 cores.
- Local copy under `/private/tmp/va-gllvm-h2h-4arm-20260807/totoro-results/`
  (D-50; raw CSVs not staged).
- Durable audit:
  `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md`
- Script retained:
  `lanes/va-s0b-exact/scripts/probe-gllvm-4arm.R`

### Headlines

- Poisson `q=2`: all four arms fail abs Σ together (~0.61–0.69) — shared regime.
- Poisson `q=5`: gllvmTMB VA strongest on Σ; gllvm VA weaker.
- Gamma: **gllvm LA is not hopeless on β/Σ** (8/8 finite; `q=5` pass_abs=1.0).
  Shape/φ for gllvm at `q=5` often explodes — not a matched estimand.
- S0b gamma “LA healthy 0/300” ≠ “Laplace cannot recover Σ” — that rate is
  **RETRACTED** (`laplace_health` FE+RE bug; FE-proxy ≈282/300 & ≈214/300).
  Gamma `(A) SCIENTIFIC_FAIL` = **VA reliability** under the recorded gate.

## Checks

```sh
# Local smoke (1 seed, 1 core, q=2 only)
PROBE_N_SEED=1 PILOT_CORES=1 PROBE_QS=2 \
  Rscript --vanilla /private/tmp/va-gllvm-h2h-4arm-20260807/probe-4arm.R
# EXIT 0; all four arms ok on poisson+gamma q=2

# Totoro full grid (8 seeds, q=2,5, 24 cores)
# EXIT 0; summary.md5 41bbe9f13ada77bb018a9d1152bfd954
```

Deliberately not run: fence edits, package tests, Arc-2 re-adjudication.

## Follow-up

- Optional: larger seed count if ranking gllvm vs gllvmTMB VA at poisson `q=5`.
- Keep shape/φ out of absolute-first pass/fail.
- Sibling gamma-LA n-ladder under `lanes/va-s0b-exact/results/` is separate.
