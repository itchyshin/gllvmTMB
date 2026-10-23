# arcG coverage campaign — results

Status: **Full 9×500 grid DONE** (2026-09-04, Totoro). Cell-1 local proof retained below.

Design: `coverage-design.md` · Harness: `coverage-harness.R` · Grid driver: `run_grid.R`

---

## Totoro grid (2026-09-04)

**HEAD:** `fc08d83f1` (lane `cursor/lane-gllvm-twin-20260904`).

**Compute:** Totoro via ControlMaster (D-64); `mc.cores=150` (D-143); wall **73.3 s**; serial-time sum **5752 s ≈ 1.60 core-h** (under D-139 **5.0 core-h** ceiling).

**Jobs:** 9 cells × 500 seeds = **4500** fits; **4500** RDS in `results/raw/`; **4500** rows in `results/summary/per_seed_summary.csv`.

### Pooled coverage (all unit×seed pairs)

| Nominal | Empirical |
|---|---|
| 90% | **0.634** |
| 95% | **0.695** |

### Per-cell mean coverage @90% / @95% (see `results/summary/per_cell_summary.csv`)

| cell | n_sites | d | frac conv | frac pdHess | cov90 | cov95 |
|---|---:|---:|---:|---:|---:|---:|
| cell01 | 40 | 1 | 1.000 | 1.000 | 0.614 | 0.685 |
| cell02 | 80 | 1 | 1.000 | 1.000 | 0.595 | 0.665 |
| cell03 | 160 | 1 | 1.000 | 1.000 | 0.583 | 0.655 |
| cell04 | 320 | 1 | 1.000 | 1.000 | 0.578 | 0.648 |
| cell05 | 40 | 2 | 0.978 | 0.674 | 0.735 | 0.778 |
| cell06 | 80 | 2 | 0.994 | 0.668 | 0.699 | 0.742 |
| cell07 | 160 | 2 | 0.996 | 0.663 | 0.687 | 0.727 |
| cell08 | 320 | 2 | 0.994 | 0.698 | 0.688 | 0.726 |
| cell09 | 80 | 2 (8 traits) | 1.000 | 0.992 | 0.614 | 0.691 |

Undercoverage vs nominal is **expected** for marginal Wald intervals (design §2); d=2 cells show lower pdHess rates — flag for inference review, not a harness failure.

**Artifacts:** `results/summary/*.csv`, `results/raw/*.rds`, `results/PROVENANCE.txt`, `results/totoro-run.log`.

---

## Cell-1 local proof (2026-09-04)

(Smallest cell machinery check — 3 seeds; see `cell-1-smoke-results.csv`.)

**Verdict:** PASS — real fits, dims, coverage machinery numeric.
