# Design 118 B1 -- calibration-campaign harness

`docs/design/118-mspl-interval-calibration-protocol.md` s2 (calibrator), s3
(interval construction), s5 (grid, hold-outs, reps, gates), s6.2 (reduced
budget), s7.2 (profile bracket widening). Fence line 2 is **F-AMD**
(attractor-proximity), per the s8 deviations ledger (DEV-3) and
`docs/dev-log/2026-08-15-b1-launch-spec.md` -- the s_j probe is still
computed and recorded on every coordinate, but only for Design 117 s6.1
reporting, not refusal.

**Post-review revision:** the first commit of this harness was reviewed
pre-launch and REFUSED; see the deviations ledger lines in the after-task
report for the two blockers (storage contract, bootstrap triplication) and
seven fixes this revision addresses. Everything below describes the
revised harness.

## Files

- `lib-b1-calibration.R` -- pure functions: the full s5 grid (132 cells: 88
  calibration + 44 hold-out, each row flagged train/holdout), the DGP
  (continuous prevalence, variable n_site/n_trait/q), the fence (screen +
  F-AMD + fail-closed root-NA), the per-outer-dataset pipeline
  (`b1_run_outer()`: fit -> fence -> widened penalised-profile interval ->
  ONE shared 1-in-3 bootstrap fallback across all 3 targets -> per-target
  summary rows PLUS the raw profile-trace and bootstrap-replicate sidecar
  rows the s3.4 storage contract requires). Reuses
  `inst/sim/b0-fence-roc/lib-b0-fence-roc.R`'s attractor-root, label,
  probe, screen, and control functions directly -- **source that file
  first** (see below). `b1_run_outer()` returns a LIST
  (`list(rows=, profile_trace=, bootstrap_replicates=)`), not a bare
  data.frame.
- `run-b1-shard.R` -- CLI shard runner. `--task-id N` OR
  `--cell-id BNNN --shard-id N`; `--print-map` prints the full task-id ->
  (cell, shard) mapping (for `sbatch --array` sizing). Writes THREE files
  per shard: the main per-coordinate CSV under `shards/`, and two sidecars
  under `sidecars/` (`<cell_id>-shard-<NNN>-profile-trace.csv`,
  `...-bootstrap-replicates.csv`), all published atomically via a `.tmp`
  tempfile + rename (never `.csv`, so a killed mid-write task cannot leave
  a partial file the consolidator would ingest as a shard).
- `consolidate-b1.R` -- STRICT shard-name glob
  (`^B[0-9]{3}-shard-[0-9]{3}\.csv$`); asserts every expected shard is
  present with its expected row count before computing anything (exits
  nonzero on any MISSING/SHORT shard, named). Per-(cell, target) profile
  coverage (Wilson 90% CI, the s2.5 three-way PASS/FAIL/INDETERMINATE
  verdict + one-shot escalation rule, escalation compared in REP units).
  **Freeze discipline:** the default run shows TRAINING cells only and the
  calibrator-input export filters to `split == "train"`; pass `--holdout`
  (after actually freezing the calibrator map, s5.2/s5.7) to also print
  the hold-out table and the G1/G2 gate verdicts. Pass `--expect-full` to
  assert the ENTIRE registered 132-cell grid is present (vs. the default,
  which checks completeness only for cells actually found under `shards/`
  -- smoke-friendly).
- `sbatch-b1.sh` -- DRAC job-array **template**. Not runnable as committed
  (array bounds and `/project` paths are left as required parameters) and
  not wired into any launch path. **The orchestrator submits, not this
  harness.** `--time` is PROVISIONAL (see "Timing" below) pending a
  Totoro-measured re-calibration.

## Storage-format decision (Design 118 s3.4)

s3.4 requires, per replicate per target, "the full profile trace over
thresholds [0.354, 3.317]" and "the full bootstrap replicate vector
(B=500)" -- so a later calibrator-fitting step can re-evaluate coverage at
any alpha\* with **no refitting** (s2.4). The main per-coordinate CSV alone
cannot hold this (variable-length raw material per row), so it is split:

- **Main CSV** (`shards/<cell_id>-shard-<NNN>.csv`): one row per (outer
  dataset x calibration target), unchanged shape from before, but
  `profile_lower`/`profile_upper` are now a **derived diagnostic**
  (linearly interpolated from the stored trace at the nominal level, no
  second walk) rather than the profile construction's authoritative
  endpoints.
- **Profile-trace sidecar** (`sidecars/<cell_id>-shard-<NNN>-profile-trace.csv`,
  long format, `b1_profile_trace_columns`): every grid + refinement point
  from a SINGLE widened walk per (outer, target) at
  `level = 0.99` (threshold 3.317, s3.4's outer bound) with
  `max_widen_rounds` opted in (s7.2) so the walk reaches that far. Because
  the walk starts at the centre and grows outward, this one trace already
  spans everything from delta=0 up to (at least) 3.317 -- covering s3.4's
  whole registered range in one pass, not one walk per threshold.
  `b1_profile_trace_endpoint()` (pure function) linearly interpolates the
  target value at ANY threshold from these stored (target, delta) pairs.
- **Bootstrap-replicate sidecar**
  (`sidecars/<cell_id>-shard-<NNN>-bootstrap-replicates.csv`, long format,
  `b1_bootstrap_replicate_columns`): every usable replicate estimate (up
  to `bootstrap_reps`, registered 500), not just the two quantiles the
  main CSV's `bootstrap_lower`/`bootstrap_upper` diagnostic reports.

This is the "minimal sufficient statistics, flagged" option from the
pre-launch review's fix list, not literal per-alpha crossing pairs: a
single wide raw trace (rather than a pre-selected grid of levels) is what
lets the calibrator re-threshold at an arbitrary, not-yet-chosen alpha\*
without refitting, which is the actual requirement s2.4/s3.2 state.

## The profile bracket-search widen fix (Design 118 s7.2)

s7.2's "widen the ... bracket to thresholds [0.354, 3.317]" was ported
into `0d6de305` only as far as the two root-finder fixes; the walk's reach
stayed fixed at `step*max_steps`. `R/mspl.R`'s
`.gllvmTMB_mspl_profile_feasibility()` gained an opt-in
`max_widen_rounds` argument (default `0L`, byte-identical to the prior
behaviour for every caller that omits it -- see
`tests/testthat/test-mspl-api.R`'s widen test, added alongside the
existing s7.2 regression tests): when a grid-walk round finishes cleanly
but does not reach `threshold`, and the caller opted in, the walk
continues from the last known-good point with a 4x larger step instead of
reporting "truncated". `b1_run_outer()` calls with
`level = 0.99, max_widen_rounds = 3L, refinement_steps = 20L`.

## Local smoke

```sh
export GLLVM_TMB_PILOT_SOURCE=true   # this checkout, not the installed library
OUT=/path/outside/repo/b1-calibration-smoke
/usr/local/bin/Rscript inst/sim/b1-calibration/run-b1-shard.R \
  --cell-id B009 --shard-id 1 --outer-per-shard 3 --bootstrap-reps 5 --out "$OUT"
/usr/local/bin/Rscript inst/sim/b1-calibration/run-b1-shard.R \
  --cell-id B091 --shard-id 1 --outer-per-shard 3 --bootstrap-reps 5 --out "$OUT"
/usr/local/bin/Rscript inst/sim/b1-calibration/consolidate-b1.R \
  --out "$OUT" --outer-per-shard 3 --reps 3
```

B009 (C-core, logit, pi=0.97, n_site=12) reliably saturates at this small
n_site, exercising fence refusal; B091 (H1, probit, pi=0.50, n_site=24) is
well-identified, exercising the admitted profile/bootstrap path.
`--bootstrap-reps` defaults to the registered 500 in production; override
it for a fast local smoke. Pass `--reps` matching `--outer-per-shard` to
`consolidate-b1.R` for a smoke-scale completeness check (it otherwise
expects the registered 600 reps/cell).

## Timing (D-139) -- PROVISIONAL, local-only, EXTRAPOLATED

The Mac this harness was built on runs everything else too, so timing here
is deliberately minimal (one plain fit + a short bootstrap probe, both
`nice -19`, single-threaded) rather than a full worst-case shard. The
definitive `--time` calibration is a Totoro job, not a local one; see the
after-task report for the measured numbers and the PROVISIONAL value
`sbatch-b1.sh` carries until that lands.

## Full B1 (orchestrator's step, NOT run by this harness alone)

132 cells x 600 reps (base, before hold-out escalation), `--outer-per-shard
10` => 60 shards/cell => 7,920 array tasks. `Rscript run-b1-shard.R
--print-map | wc -l` gives the exact array size. Reduced budget (D2):
bootstrap on a deterministic 1-in-3 subset of datasets per bootstrap-bearing
cell (C-ID1/C-ID2 carry no bootstrap at all), ONE shared 500-refit
bootstrap cycle per outer dataset (not one per calibration target -- see
the after-task report's Blocker 2 fix). On DRAC, `sbatch-b1.sh` (filled in
and reviewed by the orchestrator) -- never GitHub Actions (D-50).

## Fresh-seeds discipline

`b1_seed_base = 218,000,000 + cell_index*1,000,000` (2026-08-15 launch
spec), disjoint from B0's `118,000,000 + case_number*1,000,000`
(~1.19e8-1.30e8) and the 2026-08-14 archive's
`1,900,000,000 + case_number*10,000,000` (~1.91e9-2.02e9). Bootstrap
resample seeds now live in a SEPARATE global family
(`400,000,000 + (cell_index-1)*1,002,000 + (outer_id-1)*501 + attempt_id`,
max 532,263,999 at the registered escalation cap), fixing a collision the
pre-launch review found in the old `seed_base`-relative scheme: it spilled
into the NEXT cell's outer-seed range once `outer_id` exceeded ~501,
invisible at the base n=600 (landed in an unused gap) but producing
189,000 duplicated seeds at the s2.5 escalation cap n=2000. See
`tests/testthat/test-b1-calibration.R`'s reps=2000 collision test.

## Interpretation notes (flagged for maintainer sign-off, not silent grid resizing)

- **H1's "3 probit q=2" cells:** Design 118 s5.1 gives the count
  (18 = 15 + 3) but not which of C-q2's two `n_site` values {24, 96} the
  probit hold-out mirror uses. H1's non-q2 part already drops the
  smallest C-core `n_site` (12), keeping {24,48,96}; by the same
  exclude-the-smallest pattern this harness uses `n_site = 96` for the 3
  probit q=2 cells.
- **C-core/C-ID's continuous-prevalence pi-triple** `{0.03, 0.50, 0.97}`
  used wherever s5.1 says "3 pi" without listing values, and **C-q2/C-ID's
  n_trait = 3** where s5.1 does not restate it -- both the only natural
  readings against C-core's own 5-value pi grid and 3-trait baseline.
- **Fence line 3 (probe non-convergence -> refuse) is dropped under
  F-AMD:** DEV-3 amends fence line 2 (the s_j threshold -> attractor
  proximity) but says nothing about line 3, which existed to protect the
  s_j-based refusal rule specifically. Since F-AMD's refusal is screen OR
  proximity OR root-NA -- never s_j -- a probe (Route A) non-convergence
  no longer gates anything; it is still recorded (`half_converged`,
  `double_converged`) for Design 117 s6.1 reporting. This harness does not
  reintroduce line 3 under F-AMD; flagged for the same sign-off as the
  grid interpretations above.
