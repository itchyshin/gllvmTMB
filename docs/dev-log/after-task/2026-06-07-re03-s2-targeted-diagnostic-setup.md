# After-Task: RE-03 s2 targeted diagnostic setup

## Scope

Inspect the completed dep-slope run 33 artifact, keep it out of the RE-03
evidence ledger if it is only `s = 1`, stop the broad scheduled dep-slope
campaign, and prepare the next manual `s = 2` diagnostic dispatch for weak
families.

This phase changes workflow scheduling only. It does not change package code,
tests, likelihoods, formula grammar, public examples, roxygen, Rd files,
NEWS, vignettes, README, or the validation-debt register.

## Files Touched

- `.github/workflows/dep-slope-identifiability-sweep.yaml`
  - Removes the cron schedule and leaves `workflow_dispatch` in place.
  - Updates the workflow comment to say future evidence collection should use
    targeted manual dispatches.
- `docs/dev-log/check-log.md`
  - Records the run-33 artifact readout, the `s2` store status, and the
    manual-dispatch decision.
- `docs/dev-log/after-task/2026-06-07-re03-s2-targeted-diagnostic-setup.md`
  - This report.

## Evidence

- Dep-slope run 33:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27087974761>
- Result-store tip after run 33:
  `a3183af dep-slope campaign: accumulate seeds (run 33)`
- Downloaded artifact:
  `/tmp/gllvmtmb-depslope-run27087974761/dep-slope-campaign-run-33/`
- Result-store archive:
  `/tmp/gllvmtmb-depslope-results-a3183af/`

Run 33 has 2,625 rows and every row is `n_slope = 1`. It is scheduled/default
single-slope evidence and does not change RE-03.

The dedicated `dep-slope-sweep-s2-accumulated.csv` store has 99 rows. The
current weak-family baseline is:

| family | n_sp | PD | strict | loose |
|---|---:|---:|---:|---:|
| Beta | 600 | 11/12 | 9/12 | 11/12 |
| nbinom2 | 600 | 11/12 | 9/12 | 11/12 |
| ordinal_probit | 600 | 9/12 | 7/12 | 8/12 |
| Beta | 1200 | 6/6 | 4/6 | 6/6 |
| nbinom2 | 1200 | 5/6 | 3/6 | 5/6 |
| ordinal_probit | 1200 | 5/6 | 4/6 | 4/6 |

## Local Verification

- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/dep-slope-identifiability-sweep.yaml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `rg -n "schedule:|cron:|broad scheduled|workflow_dispatch|s_grid|dep-slope-sweep-s2|GLLVMTMB_SWEEP_X_SD_GRID|GLLVMTMB_SWEEP_SLOPE_SCALE_GRID" .github/workflows/dep-slope-identifiability-sweep.yaml docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> no cron schedule remains; manual dispatch and diagnostic grid knobs are
  still wired.
- `git diff --check`
  -> clean.

## Interpretation

The broad scheduled campaign has served its purpose for single-slope
identifiability, but it is not the right lane for RE-03. Future evidence should
be named manual dispatches against the dedicated `s2` store, with explicit
DGP axes.

The next manual dispatch should start small enough to fit inside the 120-minute
workflow timeout:

```sh
gh workflow run dep-slope-identifiability-sweep.yaml \
  --repo itchyshin/gllvmTMB \
  --ref main \
  -f families=nbinom2,ordinal_probit \
  -f s_grid=2 \
  -f n_grid=600,1200 \
  -f seeds_per_run=1 \
  -f n_rep=20 \
  -f x_sd_grid=1,1.5 \
  -f slope_scale_grid=1,1.25 \
  -f end_date=2026-06-08
```

No validation-debt row moves. RE-03 remains `partial`, and the public
non-Gaussian `phylo_dep(..., s >= 2)` guard stays in place.

## Definition of Done Accounting

1. **Implementation.** Workflow schedule changed; no package code changed.
2. **Simulation recovery test.** Not applicable to this setup phase; the
   following manual dispatch is the evidence-producing simulation.
3. **Documentation.** Dev-log and after-task report added. No public docs
   changed.
4. **Runnable user-facing example.** Not applicable.
5. **Check-log entry.** Added with exact commands and artifact paths.
6. **Review pass.** Simulation-check lens applied: `s = 1` scheduled evidence
   is kept separate from RE-03 `s = 2` evidence, and fit health / strict /
   loose recovery are not conflated. Grace-style workflow risk check applied
   via YAML parsing and dispatch-input grep. No Boole/Gauss/Noether gate is
   triggered because formula grammar, likelihood, and TMB code are untouched.
