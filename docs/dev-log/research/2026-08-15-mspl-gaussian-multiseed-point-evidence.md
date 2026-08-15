# Gaussian multi-seed LA-ML vs LA-MSPL point evidence (ordinary cells)

**Status:** local multi-seed point smoke that thickens beyond single-seed
`oracle_local`. **Not a covered campaign.** No SE / sandwich / profile /
`confint`. Uniqueness pick C remains pinned. Failure-inclusive
denominators.

**Tree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` on
`cursor/mspl-point-programme-continue`. Script:
`dev/mspl-gaussian-multiseed-point-grid.R`. Machine TSV (committed):
`docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-grid.tsv`.
RDS: `/tmp/mspl-gaussian-multiseed-point-grid.rds`.

**Recipe:** same DGP helpers as `test-mspl-gaussian-fit-smoke.R`.
`n_site = 40`, 3 traits, `latent(..., unique = TRUE)`, identity
Gaussian, `n_init = 1`, `init_jitter = 0`, `se = FALSE`,
`OMP_NUM_THREADS = 1`. Arms ML and MSPL share identical data per seed.
Shared \(\Sigma\) compared via `extract_Sigma(..., part = "shared")`
relative Frobenius vs true \(G=\Lambda_{\mathrm{DGP}}\Lambda_{\mathrm{DGP}}^\top\).

**Grid:** cells `{healthy, near_heywood}` × `q ∈ {1,2}` × 8 seeds
`160801:160808` × 2 arms = **64 arm-rows**. Wall ≈ 17 s on this Mac.

## Failure-inclusive summary (N = all attempted arms)

| cell | q | arm | N | conv0 | finite | err | med relF vs G | med max\|Λ\| | med min ψ | med wall s | MSPL closer to G |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| healthy | 1 | ML | 8 | 8 | 8 | 0 | 0.422 | 0.970 | 0.542 | 0.12 | — |
| healthy | 1 | MSPL | 8 | 8 | 8 | 0 | 0.388 | 0.882 | 0.619 | 0.13 | **6/8** |
| healthy | 2 | ML | 8 | 8 | 8 | 0 | 0.494 | 0.762 | 0.533 | 0.11 | — |
| healthy | 2 | MSPL | 8 | 8 | 8 | 0 | 0.525 | 0.753 | 0.568 | 0.17 | 3/8 |
| near_heywood | 1 | ML | 8 | 8 | 8 | 0 | 0.278 | 0.879 | 0.068 | 0.14 | — |
| near_heywood | 1 | MSPL | 8 | 8 | 8 | 0 | 0.365 | 0.818 | 0.414 | 0.13 | 2/8 |
| near_heywood | 2 | ML | 8 | 8 | 8 | 0 | 0.448 | 0.674 | 0.513 | 0.10 | — |
| near_heywood | 2 | MSPL | 8 | 8 | 8 | 0 | 0.523 | 0.734 | 0.590 | 0.18 | 3/8 |

All 64 arms: `conv = 0`, finite objective/par, zero thrown errors.
MSPL registry on every MSPL row: `admitted` / `oracle_local` /
`gaussian:identity:ordinary:q{1,2}`.

Paired median rel Frobenius MSPL vs ML ≈ 0.06–0.11 (arms disagree
mildly; they are not bit-identical).

## Looked better / worse / similar (multi-seed, still not covered)

- **Healthy q=1:** MSPL modestly closer to true \(G\) on 6/8 seeds;
  slightly smaller med \(\max|\Lambda|\); larger med min ψ. Call
  **similar-to-modestly-closer for MSPL on this healthy q=1 cell**.
- **Healthy q=2:** ML closer on 5/8; med relF slightly favours ML.
  Call **similar / no MSPL win**.
- **Near-Heywood q=1:** MSPL lifts med min ψ (0.068 → 0.414) — the
  soft Hirose atom is doing anti-collapse work — but ML’s med relF
  vs truth is *better* (0.28 vs 0.37). Call **different trade-off:
  MSPL interiors uniqueness; ML closer to G on this DGP**. Not a
  programme win for either estimand alone.
- **Near-Heywood q=2:** similar pattern; no clear MSPL recovery win.

Do **not** flip evidence to `covered`. Do **not** write NEWS. Do
**not** claim SE. Totoro campaign remains gated.

## Commands

```sh
cd /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NOT_CRAN=true
Rscript --vanilla dev/mspl-gaussian-multiseed-point-grid.R
# log: /tmp/mspl-gaussian-multiseed-point-grid.log
```
