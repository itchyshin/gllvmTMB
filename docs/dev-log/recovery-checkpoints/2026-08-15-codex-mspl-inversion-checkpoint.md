# MSPL constrained-inversion pre-run checkpoint

**Lane:** `codex/lane-b-mspl-interval-feasibility`  
**Commit:** `069561fe6bb56cb4c20389e715ca1ea5196276fc`  
**Status:** private calibration pre-run in progress; public MSPL inference remains fail-closed.

## Completed locally

- Added the frozen constrained test-inversion runner, its production-shaped smoke,
  the Narval pre-run wrapper, and the strict 12-shard pre-run aggregator.
- `devtools::test(filter = "mspl-constrained-inversion-calibration",
  stop_on_failure = TRUE)` passed after the strict aggregator addition.
- The current worktree was clean immediately after commit `069561fe`.

## Current DRAC state

- Nibi has no usable existing ControlMaster socket, so no Nibi work has been submitted.
- Narval root: `/project/def-snakagaw/snakagaw/gllvmtmb-mspl-constrained-inversion-069561fe-r1`.
- Retained setup failure `1014873`: the job omitted the required
  `udunits/2.2.28,gdal/3.9.1,geos/3.12.0,proj/9.2.0` module set, so
  `units`, `sf`, and `fmesher` could not build.  It ran no simulation.
- Corrected source-identical native build `1015078` is queued on Narval with
  those modules and the same source archive, bundle, manifest, and launcher
  hashes.  Do not submit a pre-run shard until its receipt and runtime archive
  validate.

## Next safe action

Inspect Narval job `1015078`.  If it succeeds, validate its setup receipt and
runtime archive, then run `sbatch --test-only` followed by only the five Narval
pre-run indices (`7-10,12`) through `drac-prerun.sbatch`.  Preserve every
failure.  The 12-shard pre-run requires Nibi's seven assigned cases as well;
do not substitute clusters or change the frozen assignment without a new
immutable manifest.

## Deliberate non-runs

No full constrained-inversion campaign, public `confint()`/`vcov()` activation,
coverage claim, package-wide check, CI, or GitHub artifact work has been run.
