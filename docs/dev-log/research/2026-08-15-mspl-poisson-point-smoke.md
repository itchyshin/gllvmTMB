# Poisson multi-seed LA-ML vs LA-MSPL point smoke (ordinary cells)

**Status:** local multi-seed point smoke. **Not a covered campaign.**
No SE / sandwich / profile / `confint`. Registry stays **`planned`**.
This note does **not** flip `admitted`. Failure-inclusive denominators.

**Tree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` on
`cursor/mspl-poisson-point-smoke` from `origin/main` @ `fa3c92a9`.
Script: `dev/mspl-poisson-multiseed-point-smoke.R`. Machine TSV
(committed):
`docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.tsv`.
RDS: `/tmp/mspl-poisson-multiseed-point-smoke.rds`.
Log: `/tmp/mspl-poisson-multiseed-point-smoke.log`.

**Recipe:** same public door as
`tests/testthat/test-mspl-poisson-public-door.R`. `n_site = 24`,
3 traits, `latent(..., unique = FALSE)`, `poisson(link = "log")`,
`n_init = 1`, `init_jitter = 0`, `se = FALSE`,
`OMP_NUM_THREADS = 1`. Arms ML and MSPL share identical data per
seed. Shared \(\Sigma\) compared via
`extract_Sigma(..., part = "shared")` relative Frobenius vs true
\(G=\Lambda_{\mathrm{DGP}}\Lambda_{\mathrm{DGP}}^\top\).

**DGP cells.** Healthy intercepts \(\beta=(0.40,0.10,0.60)\)
(mean \(y\) ≈ 1.5–2.4). Sparse intercepts
\(\beta=(-1.80,-1.20,-2.00)\) (mean \(y\) ≈ 0.17–0.33; zero
fraction ≈ 0.74–0.83). Loadings match the Gaussian point-grid
\(\Lambda\). No offset. No uniqueness \(\Psi\).

**Grid:** cells `{healthy, sparse}` × `q ∈ {1,2}` × 8 seeds
`160901:160908` × 2 arms = **64 arm-rows**. Probe pair projected
3.3 min; realised grid wall **5.7 s** on this Mac after
`load_all`. No shrink. No Totoro.

## Failure-inclusive summary (N = all attempted arms)

| cell | q | arm | N | conv0 | finite | err | runaway | med relF vs G | med max\|Λ\| | med min β | med wall s | MSPL closer to G |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| healthy | 1 | ML | 8 | 8 | 8 | 0 | 0 | 0.450 | 0.861 | 0.001 | 0.05 | — |
| healthy | 1 | MSPL | 8 | 8 | 8 | 0 | 0 | 0.401 | 0.789 | 0.036 | 0.11 | **5/8** |
| healthy | 2 | ML | 8 | 8 | 8 | 0 | 0 | 0.494 | 0.884 | 0.101 | 0.07 | — |
| healthy | 2 | MSPL | 8 | 8 | 8 | 0 | 0 | 0.551 | 0.821 | 0.152 | 0.13 | 4/8 |
| sparse | 1 | ML | 8 | 8 | 8 | 0 | 0 | 2.467 | 1.518 | −2.813 | 0.04 | — |
| sparse | 1 | MSPL | 8 | 8 | 8 | 0 | 0 | 0.945 | 0.925 | −1.976 | 0.09 | **7/8** |
| sparse | 2 | ML | 8 | 8 | 8 | 0 | 0 | 3.049 | 2.095 | −3.586 | 0.06 | — |
| sparse | 2 | MSPL | 8 | 8 | 8 | 0 | 0 | 0.936 | 0.874 | −2.140 | 0.11 | **8/8** |

All 64 arms: `conv = 0`, finite objective/par, zero thrown errors.
MSPL registry on every MSPL row: `planned` / `phase4_prep` /
`poisson:log:ordinary:q{1,2}`. Zero `admitted` rows. Runaway
threshold was \(\max|\Lambda|\ge 15\); none fired.

Paired median rel Frobenius MSPL vs ML ≈ 0.13 on healthy cells and
≈ 0.71–0.87 on sparse cells (arms disagree; they are not
bit-identical). Soft rate remains the unpinned Poisson `c = 1`.

## Looked better / worse / similar (multi-seed, still not covered)

- **Healthy q=1:** MSPL modestly closer to true \(G\) on 5/8 seeds;
  slightly smaller med \(\max|\Lambda|\). Call **similar-to-modestly
  closer for MSPL**. No healthy-regime harm on this DGP.
- **Healthy q=2:** split 4/8; med relF slightly favours ML
  (0.494 vs 0.551). Call **similar / no MSPL win**.
- **Sparse q=1 and q=2:** ML med relF vs \(G\) is 2.5–3.0, with two
  seeds at 15.3 and 18.2 and \(\max|\Lambda|\) 4.66 / 5.39. MSPL med
  relF is 0.94–0.95 and is closer on 15/16 sparse seeds. Intercepts
  stay less negative (med min \(\beta\) about −2 vs ML −2.8 to
  −3.6). That is an **anti-runaway observation on this sparse
  DGP**, not a covered recovery claim.

**Factor-death on the sparsest seeds.** Two MSPL arms collapsed
shared loadings to numerical zero
(\(\max|\Lambda|=1.78\times 10^{-6}\) on sparse q=1 seed 160904;
\(9.24\times 10^{-7}\) on sparse q=2 seed 160903). Both DGPs had
mean \(y\approx 0.17\)–\(0.18\) and zero fraction 0.833. RelF vs
\(G\) is then exactly 1 (null shared \(\Sigma\)). On seed 160904
ML’s relF 0.618 *beats* that collapsed MSPL. Finite-and-stationary
is not the same as a recovered factor. Programme constitution
Phase 4: *finite count fits alone do not pass.*

## Verdict

| Surface | Verdict | Why |
|---|---|---|
| Operational local point smoke (8 seeds, 64 arms, `se=FALSE`) | **PASS** | Every arm converged with a finite objective; registry stayed `planned`; no \(\max|\Lambda|\ge 15\) runaway; wall 5.7 s. |
| **Admit evidence** (Phase 4 exit + §8) | **FAIL** | Rate `c=1` is unpinned; Poisson loading atom under Laplace is OPEN; two sparse MSPL arms died to a null factor; no prediction / penalty-sensitivity / TMB-oracle packet; Shinichi gate has not authorised `planned` → `admitted`. |

**Headline for the parent:** `n=8`, **FAIL** for admit evidence,
path `docs/dev-log/research/2026-08-15-mspl-poisson-point-smoke.md`.

Do **not** flip evidence to `covered` or `admitted`. Do **not**
write NEWS. Do **not** claim SE. Totoro campaign remains gated.
Do **not** merge #972–#976 from this lane.

## Commands

```sh
cd /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NOT_CRAN=true
Rscript --vanilla dev/mspl-poisson-multiseed-point-smoke.R
# log: /tmp/mspl-poisson-multiseed-point-smoke.log
```
