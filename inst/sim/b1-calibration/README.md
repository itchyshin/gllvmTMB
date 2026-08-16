# Design 118 B1 -- calibration-campaign harness

`docs/design/118-mspl-interval-calibration-protocol.md` s2 (calibrator), s3
(interval construction), s5 (grid, hold-outs, reps, gates), s6.2 (reduced
budget). Fence line 2 is **F-AMD** (attractor-proximity), per the s8
deviations ledger (DEV-3) and `docs/dev-log/2026-08-15-b1-launch-spec.md` --
the s_j probe is still computed and recorded on every coordinate, but only
for Design 117 s6.1 reporting, not refusal.

## Files

- `lib-b1-calibration.R` -- pure functions: the full s5 grid (132 cells: 88
  calibration + 44 hold-out, each row flagged train/holdout), the DGP
  (continuous prevalence, variable n_site/n_trait/q), the fence (screen +
  F-AMD), the per-outer-dataset pipeline (`b1_run_outer()`: fit -> fence ->
  penalised-profile interval -> 1-in-3 bootstrap fallback -> one row per
  calibration target). Reuses `inst/sim/b0-fence-roc/lib-b0-fence-roc.R`'s
  attractor-root, label, probe, and screen functions directly -- **source
  that file first** (see below).
- `run-b1-shard.R` -- CLI shard runner. `--task-id N` OR
  `--cell-id BNNN --shard-id N`; `--print-map` prints the full task-id ->
  (cell, shard) mapping (for `sbatch --array` sizing).
- `consolidate-b1.R` -- per-cell profile coverage (Wilson 90% CI, the s2.5
  three-way PASS/FAIL/INDETERMINATE verdict + one-shot escalation rule),
  refusal rates, and a calibrator-input observables export. Train and
  hold-out cells are always reported in separate tables, never pooled.
- `sbatch-b1.sh` -- DRAC job-array **template**. Not runnable as committed
  (array bounds and `/project` paths are left as required parameters) and
  not wired into any launch path. **The orchestrator submits, not this
  harness.**

## Local smoke

```sh
export GLLVM_TMB_PILOT_SOURCE=true   # this checkout, not the installed library
OUT=/path/outside/repo/b1-calibration-smoke
/usr/local/bin/Rscript inst/sim/b1-calibration/run-b1-shard.R \
  --cell-id B009 --shard-id 1 --outer-per-shard 3 --bootstrap-reps 5 --out "$OUT"
/usr/local/bin/Rscript inst/sim/b1-calibration/run-b1-shard.R \
  --cell-id B091 --shard-id 1 --outer-per-shard 3 --bootstrap-reps 5 --out "$OUT"
/usr/local/bin/Rscript inst/sim/b1-calibration/consolidate-b1.R --out "$OUT"
```

B009 (C-core, logit, pi=0.97, n_site=12) reliably saturates at this small
n_site, exercising fence refusal; B091 (H1, probit, pi=0.50, n_site=24) is
well-identified, exercising the admitted profile/bootstrap path.
`--bootstrap-reps` defaults to the registered 500 in production; override it
for a fast local smoke.

## Full B1 (orchestrator's step, NOT run by this harness alone)

132 cells x 600 reps (base, before hold-out escalation), `--outer-per-shard
10` => 60 shards/cell => 7,920 array tasks. `Rscript run-b1-shard.R
--print-map | wc -l` gives the exact array size. Reduced budget (D2):
bootstrap on a deterministic 1-in-3 subset of datasets per bootstrap-bearing
cell (C-ID1/C-ID2 carry no bootstrap at all). On DRAC, `sbatch-b1.sh`
(filled in and reviewed by the orchestrator) -- never GitHub Actions
(D-50).

## Fresh-seeds discipline

`b1_seed_base = 218,000,000 + cell_index*1,000,000` (2026-08-15 launch
spec), disjoint from B0's `118,000,000 + case_number*1,000,000`
(~1.19e8-1.30e8) and the 2026-08-14 archive's
`1,900,000,000 + case_number*10,000,000` (~1.91e9-2.02e9). Bootstrap
resample seeds live in a `+500,000` offset band per outer dataset, disjoint
from any outer dataset's own plain seed.

## Interpretation note: H1's "3 probit q=2" cells

Design 118 s5.1 gives H1's cell count (18 = 15 + 3) but not which of C-q2's
two `n_site` values {24, 96} the 3 probit q=2 hold-out cells use. H1's
non-q2 part already drops the smallest C-core `n_site` (12), keeping
{24,48,96}; by the same exclude-the-smallest pattern this harness uses
`n_site = 96` for the 3 probit q=2 cells. Flagged here as a documented
interpretation, not a silent grid resize.
