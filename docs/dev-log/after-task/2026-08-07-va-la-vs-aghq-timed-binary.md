# After-task — LA vs AGHQ(+ridge) binary timed (S1)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Fence / auto:** unchanged. Measurement only.

## Goal

Answer Shinichi: for binary, best accuracy (β and Σ) — AGHQ or Laplace? What is AGHQ’s time cost?

## Mathematical contract

No public API / likelihood / grammar / family change. Opt-in AGHQ remains `gllvmTMBcontrol(aghq = k)` with default ridge τ=2 on the AGHQ path; Laplace stays the shipped default.

## Outcome

- **Old estimands (latent SD, ρ, runaway):** AGHQ+ridge still wins vs shipped Laplace on the banked binomial Totoro grid (954-fit lineage; shipped-4 wall ~5–23×).
- **S1 abs β / Σ rf / pass_abs:** live probit n=400 p=8 q=2 (4 seeds, warm excluded): **Laplace better** on Σ rf (0.60 vs 0.95) and pass_abs (0.50 vs 0); β RMSE tied (~0.065). AGHQ+ridge **~67×** slower (207 s vs 3.1 s).
- **Recommendation:** LA as large-N binary baseline; AGHQ opt-in; **no default flip.** Geometry chosen: n=400 p=8 (not 500×20 — AGHQ too slow for that smoke).

## Files

- `docs/dev-log/audits/2026-08-07-va-la-vs-aghq-timed-binary.md`
- `lanes/va-s1-binomials/scripts/probe-la-vs-aghq-timed.R`
- `lanes/va-s1-binomials/scripts/launch-totoro-la-vs-aghq-timed.sh`
- `docs/dev-log/check-log.md` (this sitting)
- this after-task

## Checks

- Timed smoke: local sequential, `se=FALSE`, DLL warm outside timer; summary at `/private/tmp/va-s1-la-vs-aghq-timed-20260807/summary.csv`.
- Banked: `dev/aghq-evidence/20-shipped4-inc.csv`, `totoro-suite-inc.csv`, `decisions.md` 2026-07-28.
- No package tests re-run (docs + probe scripts only).

## Not done

- n=1000 / 500×20 AGHQ abs-Σ panel (optional; not required for the verdict above).
- AGHQ no-ridge split on S1 scorers; coverage/SE.

## Roles

- **Fisher:** estimand split (σ/ρ vs abs Σ) is the load-bearing distinction; do not cite “AGHQ best” without naming the scorer.
- **Curie:** warm-outside-timer + matched DGP; ratio ~67× is the S1-shaped cost, banked 5–23× is the older grid.
- **Rose:** naming Laplace / AGHQ / VA-GH — never “LA-GH”.
