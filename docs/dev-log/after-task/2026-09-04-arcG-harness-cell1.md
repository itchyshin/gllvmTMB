# After-task: arcG harness + Cell-1 local proof

**Date:** 2026-09-04  
**Lane:** gllvmTMB twin (`gllvmTMB-gllvm-twin-20260904`)  
**HEAD:** `afe161781`

## Scope

Wire arcG coverage harness to `extract_latent_scores()`; run Cell-1 local smoke (object-level proof). No Totoro dispatch.

## Outcome

- **Harness:** `dev/gapclose/arcG/coverage-harness.R` — grid defs, sign alignment, per-seed coverage via accessor + `ordination_uncertainty()`.
- **Cell-1 smoke:** `cell-1-smoke.R` — 3 seeds on smallest cell (`d=1, n_units=40, n_traits=4`).
- **Totoro prep:** `campaign.R` + `run-grid-totoro.sh` (prepared, not submitted).
- **Cell-1 verdict:** **PASS** (3/3 converged, pdHess, dims 40×1, finite coverage).

## Checks

```sh
NOT_CRAN=true Rscript dev/gapclose/arcG/cell-1-smoke.R
# Cell-1: PASS · wall 10.1s · mean cov90=0.642 cov95=0.708
```

## Files touched

- `dev/gapclose/arcG/coverage-harness.R` (new)
- `dev/gapclose/arcG/cell-1-smoke.R` (new)
- `dev/gapclose/arcG/campaign.R` (new)
- `dev/gapclose/arcG/run-grid-totoro.sh` (new, not executed)
- `dev/gapclose/arcG/coverage-results.md` (new)
- `dev/gapclose/arcG/cell-1-smoke-results.csv` (generated)

## Follow-up

- Parent: Totoro go for 9×500 grid via `run-grid-totoro.sh` (cm-totoro socket live).
- D-139 halt if measured fit cost > ~5 core-h.
