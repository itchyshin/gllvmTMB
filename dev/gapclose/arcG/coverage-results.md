# arcG coverage campaign — results stub

Status: **Cell-1 local proof DONE** (2026-09-04). Full 9×500 grid **NOT dispatched**.

Design: `coverage-design.md` · Harness: `coverage-harness.R` · Cell-1 smoke: `cell-1-smoke.R`

---

## Cell-1 local proof (2026-09-04)

**Cell definition:** smallest grid cell — `n_units=40`, `d=1`, `n_traits=4` (`cell01_d1_n40_t4`, grid id 1).

**HEAD:** `afe161781` (`extract_latent_scores()` landed).

**Command:**

```sh
cd /Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904
NOT_CRAN=true Rscript dev/gapclose/arcG/cell-1-smoke.R
```

**Environment:** `devtools::load_all(".")` (3.2 s compile/load); `NOT_CRAN=true`; `OPENBLAS_NUM_THREADS=1`.

**Seeds:** 501, 502, 503 (smoke subset; campaign uses 1:500).

### Object-level checks

| Check | Result |
|---|---|
| Real fit (not skip) | **PASS** — 3/3 seeds fitted |
| `fit$opt$convergence == 0` | **PASS** — 3/3 |
| `fit$sd_report$pdHess == TRUE` | **PASS** — 3/3 |
| `extract_latent_scores(fit)` dims | **PASS** — 40×1 all seeds |
| `extract_latent_scores(sim)` dims | **PASS** — 40×1 all seeds |
| `ordination_uncertainty()$se` dims | **PASS** — 40×1 all seeds |
| Coverage machinery numeric | **PASS** — finite cov90/cov95 per seed |

### Key numbers

| Metric | Value |
|---|---|
| Wall time (3 seeds) | **10.1 s** |
| Per-seed runtime | 0.45–7.24 s (contention-sensitive) |
| Mean empirical cov@90% | **0.642** (3-seed smoke mean) |
| Mean empirical cov@95% | **0.708** (3-seed smoke mean) |
| Cell-1 harness verdict | **PASS** |

Per-seed coverage (smoke — not campaign evidence):

| seed | cov@90% | cov@95% | runtime (s) |
|---|---|---|---|
| 501 | 0.325 | 0.425 | 1.35 |
| 502 | 0.750 | 0.825 | 7.24 |
| 503 | 0.850 | 0.875 | 0.45 |

**Note:** Undercoverage at 90%/95% on individual seeds is **expected** per design Section 2 (marginal Wald intervals for random effects); Cell-1 proof validates the **machinery**, not nominal calibration.

Raw CSV: `cell-1-smoke-results.csv`

---

## Full grid (NOT RUN)

9 cells × 500 seeds = 4,500 fits · ~5.0 core-h ceiling (§9a) · Totoro **NEXT** — see `run-grid-totoro.sh` (prepared, not submitted).
