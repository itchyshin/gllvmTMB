# After-Task: RE-03 stronger-slope fixture repair

## Task Goal

Repair the RE-03 diagnostic harness so `slope_scale > 1` creates a valid
positive-definite truth covariance and can be used for the next targeted
`s = 2` weak-family run.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, README, NEWS, or pkgdown navigation change.

The diagnostic truth covariance is still
`Sigma_b = L L^T` for the full unstructured phylogenetic dep-slope block. For
sensitivity runs, a diagonal coordinate-scaling matrix `D` modifies the slope
coordinates only:

```text
Sigma_b(slope_scale) = D Sigma_b D
D[j, j] = slope_scale for slope-coordinate indices j
D[j, j] = 1 otherwise
```

The implementation now uses paired diagonal indices,
`D[cbind(idx, idx)] <- slope_scale`. The previous
`D[idx, idx] <- slope_scale` filled the whole slope-by-slope submatrix and made
`D` singular.

## Files Created Or Changed

- `docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  - Fixes the stronger-slope coordinate scaling.
  - Adds an early Cholesky check for every requested truth covariance.
  - Prints true slope variances for each requested `slope_scale`.
- `docs/dev-log/check-log.md`
  - Records the root cause, commands, and smoke result.
- `docs/dev-log/after-task/2026-06-08-re03-slope-scale-fixture-repair.md`
  - This report.

No package implementation, tests, public docs, roxygen, Rd, NEWS, README,
roadmap, or pkgdown navigation files changed.

## Checks Run

- `Rscript --vanilla - <<'RS' ... recreate .Sigma_b_true() with the old D[idx, idx] <- slope_scale assignment ... RS`
  -> reproduced the singular covariance at `s = 2`, `slope_scale = 1.25`.
- `Rscript --vanilla - <<'RS' ... use D[cbind(idx, idx)] <- slope_scale and check slope_scale in {1, 1.25, 1.5} ... RS`
  -> corrected covariance was positive definite for all three scales.
- `Rscript --vanilla -e 'invisible(parse(file = "docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R")); cat("r-parse-ok\n")'`
  -> `r-parse-ok`.
- `GLLVMTMB_SWEEP_FAMILIES=gaussian GLLVMTMB_SWEEP_SGRID=2 GLLVMTMB_SWEEP_NGRID=8 GLLVMTMB_SWEEP_SEEDS=9901 GLLVMTMB_SWEEP_NREP=2 GLLVMTMB_SWEEP_X_SD_GRID=1 GLLVMTMB_SWEEP_SLOPE_SCALE_GRID=1.25 GLLVMTMB_SWEEP_OUT=/tmp/gllvmtmb-re03-slope-scale-smoke.csv Rscript --vanilla docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> fixture and fit path executed; the tiny underpowered cell failed as
  `nonPD/nonconv`, not `not_fit`.

## Consistency Audit

The exact status scan remains:

```sh
rg -n "^\| RE-03\||RE-03" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md ROADMAP.md
```

Verdict: RE-03 still reads `partial`, and the non-Gaussian `s >= 2` public
guard remains reserved pending a corrected multi-seed diagnostic.

## Tests Of The Tests

No package test was added because this is a remote diagnostic harness, not an
exported package behavior. The harness now has its own pre-fit truth-covariance
Cholesky check, which would have stopped run 38 before spending time on eight
invalid stronger-slope cells.

## What Did Not Go Smoothly

While reproducing the bug, one accidental default sweep was started locally by
sourcing the whole script. It was identified as the Codex-owned `R --file=-`
process and terminated. No result from that partial default sweep is used as
evidence.

## Team Learning

- Ada: keep this as harness repair, not capability admission.
- Curie: DGP validity must be checked before using a grid axis as recovery
  evidence.
- Fisher: the corrected run must count only fitted rows; `not_fit` rows are
  fixture evidence, not model evidence.
- Rose: the root cause is now in the repo evidence trail before the corrected
  remote run is launched.

## Design-Doc Updates

None. `docs/design/35-validation-debt-register.md` remains unchanged because
no admission evidence moved yet.

## Pkgdown And Documentation Updates

None. No user-facing documentation changed.

## Roadmap Tick

N/A. No `ROADMAP.md` row status chip or progress bar changed.

## GitHub Issue Ledger

Issue #341 remains the RE-03 ledger. The next issue comment should be the
corrected remote run result after this fix is merged and dispatched.

## Definition Of Done Accounting

1. **Implementation.** Diagnostic harness repaired.
2. **Simulation recovery test.** The fix was smoke-tested on a tiny
   `s = 2`, `slope_scale = 1.25` cell; the evidence-producing run still needs
   remote dispatch.
3. **Documentation.** Check-log and after-task report updated.
4. **Runnable user-facing example.** Not applicable.
5. **Check-log entry.** Added with exact commands and outcomes.
6. **Review pass.** Curie/Fisher/Rose lenses applied. No Boole/Gauss/Noether
   gate is triggered because formula grammar, likelihood, and TMB code are
   untouched.

## Known Limitations And Next Actions

RE-03 remains `partial`. The public non-Gaussian
`phylo_dep(..., s >= 2)` guard stays in place.

Next action: merge this harness fix, then rerun the targeted weak-family
diagnostic for `nbinom2` and `ordinal_probit` with `slope_scale_grid=1,1.25`.
