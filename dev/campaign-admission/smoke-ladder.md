# Immutable-chunk smoke ladder

**Status:** contract for the Design 66 (`docs/design/66-capstone-power-study.md`)
compute-admission slice, `docs/design/124-campaign-admission.md`. Design 66's
D-50 supersession (lines ~37-45) requires "an immutable-chunk smoke ladder,
not the full grid" as the first compute step after admission. This document
defines that ladder generically, for any campaign `admit.sh` has ADMITTED.

Each rung must PASS before the next rung is attempted. A rung that fails is
a finding to fix, not a rung to skip. No rung here launches a DRAC array or
an unbounded Totoro campaign -- everything below is bounded and cheap
(consistent with D-139: state a time estimate, and only a run over ~30
minutes needs a pre-run test and explicit maintainer approval before the
full commitment -- rungs 1-3 exist precisely so that pre-run test has
concrete stages instead of being one big guess).

## Rung 1 -- local, 1 fit

**What:** run the admitted runner script locally (on the machine doing the
admission, not Totoro/DRAC) with its smoke-mode env var set so it truncates
its task list to exactly one row (see `dev/coxreid-ab/run-ab.R`'s
`GRID_SMOKE` for the pattern this generalises).

**Command shape:**
```
GRID_SMOKE=TRUE Rscript --vanilla <dest>/runner.R
```
(substitute the specific runner's own smoke-mode env var name -- `admit.sh`
only checks that SOME smoke contract exists, per `RESULT-SCHEMA.md`; it does
not standardise the env var's literal name across campaigns.)

**PASS criteria:**
- the script exits 0 and prints exactly one `[done]`-style completion line
  (or the runner's equivalent);
- the resulting row has `converged == TRUE` for at least a plausible arm
  (a smoke fit failing every arm on a trivial cell is itself a finding,
  not something to wave through);
- no unhandled R error, no silent 0-row exit;
- wall time is a sane fraction of a second-to-low-minutes, not a hang (a
  local smoke run is a floor check on plumbing, not a compute campaign).

**On failure:** fix the runner, do not proceed. Nothing above rung 1 is
worth a Totoro core until rung 1 passes.

## Rung 2 -- Totoro canary (1 seed x all cell-arms)

**What:** run the admitted runner's canary mode on Totoro -- the full grid
of cells and arms, but only seed index 1. This is the same task-count
shape as `dev/coxreid-ab/run-ab.R`'s `AB_MODE=canary` (8 cells x 2 arms x
1 seed = 16 rows).

**Command shape (via the campaign's own launcher, mirroring
`dev/coxreid-ab/launch-ab.sh`):**
```
<CAMPAIGN>_CONFIRM=yes <MODE_VAR>=canary <WORKERS_VAR>=<N<=150> \
  <dest>/launch-<campaign>.sh --mode=canary --launch
```
run directly ON Totoro, guarded the same way `launch-ab.sh` guards its own
launch: dry-run default, explicit confirm env var, hostname check, worker
cap 150 (D-143), `GITHUB_ACTIONS` unset (D-50).

**PASS criteria (inspect the output file by hand, do not just check the
exit code):**
- the result file is non-empty and has exactly one row per (cell, arm)
  combination -- no silently dropped tasks (the mirai `vapply(res,
  is.data.frame, ...)` failure mode documented in `dev/coxreid-ab/run-ab.R`'s
  THIRD correction is exactly what this check catches);
- every numeric outcome column is finite for every `converged == TRUE` row
  (no `NaN`/`Inf` leaking through);
- `n_attempted == n_rows_written` for the canary grid -- no row vanished;
- at least the historically-expected fraction of cells converge for a
  "should work" arm (a canary where every arm fails on every cell means
  the DGP or formula is broken, not that the estimator is being tested).

**On failure:** do not widen to rung 3. Diagnose from the 16-ish canary
rows, which are cheap to regenerate under a fresh campaign id.

## Rung 3 -- one bounded full chunk (one cell, all seeds)

**What:** run the FULL seed range for exactly ONE cell (all arms), still on
Totoro, still under the worker cap. This is the first rung that exercises
the campaign's real `n_sim`, but bounded to a single grid cell so a
miscalibrated `n_sim` or a slow cell is caught before it is multiplied
across the whole grid.

**PASS criteria:**
- the chunk file (`chunk-NNN.csv` under the campaign's immutable
  destination) is written once and is never overwritten by a second attempt
  (a rerun uses a new campaign id per `RESULT-SCHEMA.md`'s retry policy);
- `n_attempted` for the chunk equals the cell's full seed count -- no rows
  lost to a mirai wrapper-function bug or a worker crash;
- coverage/power/bias for this one cell, computed with the three-denominator
  convention (`RESULT-SCHEMA.md`), are in a plausible range given prior
  pilot evidence for a comparable cell (not necessarily inside the final
  target band -- that is what the full campaign exists to determine -- but
  not wildly divergent either, e.g. not 0% converged or >10x the expected
  wall time per fit);
- the observed per-fit wall time, extrapolated to the full grid x full
  `n_sim`, produces a compute-time estimate the maintainer can act on
  (D-139: state the estimate before committing to the full run).

**On failure:** the chunk is diagnostic evidence, not throwaway noise --
keep it, characterise why it failed, and do not launch the full campaign
until the cause is understood.

## After rung 3: the full campaign

The full campaign (all cells, all seeds) is admitted only after rung 3
PASSES **and** the maintainer gives an explicit D-139 go on the
extrapolated compute-time estimate. `admit.sh` does not grant this itself
-- it freezes the source/runner/destination so the full run, when
approved, launches against exactly what rungs 1-3 were validated against
(same commit, same runner checksum), not a tree that drifted underneath the
smoke ladder.
