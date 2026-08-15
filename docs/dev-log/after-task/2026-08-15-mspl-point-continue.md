# After-task: MSPL point-continue (Gaussian multi-seed + Poisson Phase-4 prep)

**Date:** 2026-08-15  
**Lane:** `cursor/mspl-point-programme-continue`  
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**PR:** https://github.com/itchyshin/gllvmTMB/pull/971

```text
🎯 GOAL
Solo: Cursor
Deliverable: (A) multi-seed Gaussian LA-ML vs LA-MSPL point evidence; (B) Poisson Phase-4 prep; (C) handover + MC
HEADLINE: finish point-estimate MSPL arc for Gaussian depth + Poisson derivation without SE
DEFER: binary SE; Gaussian SE; NEWS covered; Totoro>30min; EVA; free-ε; Poisson admit
DISCIPLINE: se=FALSE; OMP=1; verify by logs; failure-inclusive; after-task+PRs+Melissa
```

## Outcome

**(A)** Local multi-seed ordinary Gaussian grid: healthy + near-Heywood ×
q=1/2 × 8 seeds × ML/MSPL = 64/64 finite conv0 (~17 s). Near-Heywood
q=1 uniqueness collapse (`min ψ < 0.1`) **4/8 ML vs 0/8 MSPL**. Does
**not** flip `oracle_local` → covered.

**(B)** Poisson Phase-4 prep: Sol-quality derivation note; pure-R
oracles E1–E7; registry `poisson:log:ordinary:q{1,2}` = `planned` /
`phase4_prep`. Prepare fence unchanged. **Not admitted.**

**(C)** Handover extended; Rose fences note; Mission Control NOW +
`mspl_by_family.poisson` → planned; LOOP frozen; Melissa plan-actual.

## Files

- `dev/mspl-gaussian-multiseed-point-grid.R`
- `docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-{evidence.md,grid.tsv}`
- `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`
- `docs/dev-log/research/2026-08-15-mspl-point-continue-rose-fences.md`
- `tests/testthat/test-mspl-poisson-phase4-oracles.R`
- `R/mspl-registry.R` + registry tests
- `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/`
- `docs/dev-log/handover/2026-08-15-cursor-handover.md`
- `docs/dev-log/plan-actual/2026-08-15-mspl-point-continue.md`

## Checks

```sh
OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla dev/mspl-gaussian-multiseed-point-grid.R
# 64/64 finite; log /tmp/mspl-gaussian-multiseed-point-grid.log
devtools::test(filter="mspl-registry|mspl-poisson-phase4|mspl-gaussian-fit-smoke|mspl-gaussian-heywood")
# PASS
```

## Non-claims / OPEN GATES

- No Gaussian/binary SE; no NEWS covered; no Totoro campaign.
- **OPEN GATE:** Poisson `planned` → `admitted` needs smoke + Shinichi.
- Binary SE remains Codex-protected.

## Definition of Done (this GOAL)

A+B+C landed on the branch/PR. Merge is human when CI green.
