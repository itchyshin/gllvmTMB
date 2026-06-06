# After Task: RE-03 s2 Diagnostic Scout Infrastructure

**Branch**: `codex/re03-s2-diagnostic-scout-2026-06-06`  
**Date**: `2026-06-06`  
**Roles (engaged)**: `Ada / Curie / Fisher / Jason / Rose / Grace`

## 1. Goal

Prepare the next RE-03 non-Gaussian `s = 2` evidence pass without advertising a
new capability. The prior accumulated sweep showed that `Beta`, `nbinom2`, and
`ordinal_probit` are not structural no-go cells, but the misses could not
separate fit-health failures from near-threshold recovery failures or DGP
sensitivity. This task adds the diagnostic fields and manual workflow knobs
needed for that separation.

## 2. Implemented

- The RE-03 sweep script now accepts comma-list grids for `n_rep`, slope
  covariate SD (`x_sd`), and a multiplicative scale on the true slope block of
  `Sigma_b`.
- Each result row now records the full `s = 2` slope-variance ratio vector
  (`slope_var_ratio_1` through `slope_var_ratio_4`), strict recovery
  (`[0.5, 2]`), loose recovery (`[0.4, 2.5]`), a failure reason, Sigma
  conditioning, eta range, response boundary rates, and basic fit diagnostics.
- Old accumulated store rows are upgraded in memory with default diagnostic
  axes (`n_rep = 10`, `x_sd = 1`, `slope_scale = 1`) and computed strict /
  loose recovery flags before aggregation.
- The manual GitHub Actions dispatch exposes `x_sd_grid` and
  `slope_scale_grid`; scheduled/default runs still use the old defaults.

No public R API, formula grammar, likelihood, family, NAMESPACE, generated Rd,
README, NEWS, vignette, or pkgdown navigation changed. The public non-Gaussian
`phylo_dep(..., s >= 2)` guard remains unchanged.

## 3. Files Changed

- `.github/workflows/dep-slope-identifiability-sweep.yaml` -- manual dispatch
  inputs and environment variables for diagnostic DGP grids.
- `docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R` --
  diagnostic axes, result schema, old-store migration, and grouped
  strict/loose recovery summaries.
- `docs/dev-log/check-log.md` -- command log and interpretation.
- `docs/dev-log/after-task/2026-06-06-re03-s2-diagnostic-scout.md` -- this
  report.

## 3a. Decisions and Rejected Alternatives

**Decision:** keep this as diagnostic infrastructure, not a guard-relaxation PR.  
**Rationale:** the current weak-family evidence is encouraging but still too
thin for admission, especially for `ordinal_probit`.
**Rejected alternative:** dispatch more blind seeds under the same DGP. That
would tighten Monte Carlo error but still would not explain whether the misses
come from fit health, threshold choice, covariate signal, or response-boundary
behaviour.

**Decision:** use `slope_scale` to scale only the slope rows/columns of the true
`Sigma_b`.  
**Rationale:** RE-03 is about the random-slope block; this keeps intercept
variation comparable while testing whether slope signal strength drives
recovery.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file = "docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R")); cat("r-parse-ok\n")'`
  -> `r-parse-ok`.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/dep-slope-identifiability-sweep.yaml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- `GLLVMTMB_SWEEP_FAMILIES=gaussian GLLVMTMB_SWEEP_SGRID=2 GLLVMTMB_SWEEP_NGRID=8 GLLVMTMB_SWEEP_SEEDS=999 GLLVMTMB_SWEEP_NREP=2 GLLVMTMB_SWEEP_X_SD_GRID=1 GLLVMTMB_SWEEP_SLOPE_SCALE_GRID=1 GLLVMTMB_SWEEP_OUT=/tmp/gllvmtmb-re03-diagnostic-smoke.csv Rscript --vanilla docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> full script path ran one intentionally tiny Gaussian `s = 2` cell and
  wrote a 38-column diagnostic CSV. The fit was non-PD, as expected for
  `n_sp = 8`, and exercised the failure path.
- `Rscript --vanilla -e 'x <- read.csv("/tmp/gllvmtmb-re03-diagnostic-smoke.csv"); cat(ncol(x), "columns\n"); print(names(x)); stopifnot(all(c("n_rep","x_sd","slope_scale","slope_var_ratio_4","sigma_condition","eta_min","response_boundary_frac","failure_reason","loose_recovered") %in% names(x))); cat("schema-ok\n")'`
  -> 38 columns; `schema-ok`.
- `git show origin/dep-slope-sweep-results:dep-slope-sweep-s2-accumulated.csv | sed -n '1,2p' > /tmp/gllvmtmb-old-s2-store-subset.csv && GLLVMTMB_SWEEP_FAMILIES=gaussian GLLVMTMB_SWEEP_SGRID=2 GLLVMTMB_SWEEP_NGRID=8 GLLVMTMB_SWEEP_SEEDS=1000 GLLVMTMB_SWEEP_NREP=2 GLLVMTMB_SWEEP_X_SD_GRID=1 GLLVMTMB_SWEEP_SLOPE_SCALE_GRID=1 GLLVMTMB_SWEEP_STORE=/tmp/gllvmtmb-old-s2-store-subset.csv GLLVMTMB_SWEEP_OUT=/tmp/gllvmtmb-re03-diagnostic-compat.csv Rscript --vanilla docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> old-schema row plus new row accumulated successfully.
- `Rscript --vanilla -e 'x <- read.csv("/tmp/gllvmtmb-re03-diagnostic-compat.csv"); stopifnot(nrow(x) == 2L, all(c("n_rep","x_sd","slope_scale","failure_reason","strict_recovered","loose_recovered") %in% names(x))); print(x[, c("family","n_rep","x_sd","slope_scale","strict_recovered","loose_recovered","failure_reason")], row.names=FALSE); cat("compat-schema-ok\n")'`
  -> old row defaulted to the baseline diagnostic axes and computed recovery
  flags; `compat-schema-ok`.
- `git diff --check`
  -> clean.

Not run: `devtools::test()`, `devtools::check()`, `devtools::document()`,
`pkgdown::check_pkgdown()`, or article builds. This slice touched a research
spike script and a manual workflow dispatch surface only; no package code,
roxygen, public examples, generated Rd, README, NEWS, or vignettes changed.

## 5. Tests of the Tests

No formal package tests were added. The smoke run is a boundary check: it uses a
deliberately underpowered Gaussian `s = 2` cell to verify the non-PD /
failure-reason path. The compatibility run exercises the old-store migration
path that the next remote diagnostic dispatch will need.

## 6. Consistency Audit

- `rg -n "GLLVMTMB_SWEEP_X_SD_GRID|GLLVMTMB_SWEEP_SLOPE_SCALE_GRID|x_sd_grid|slope_scale_grid|loose_recovered|failure_reason" .github/workflows/dep-slope-identifiability-sweep.yaml docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> found the intended workflow inputs/env vars, script env parsing, result
  flags, and old-store migration logic.
- `rg -n "s >= 2|s ≥ 2|two or more random slopes|RE-03|non-Gaussian" R/fit-multi.R docs/design/35-validation-debt-register.md NEWS.md tests/testthat/test-phylo-dep-slope-s2-gaussian.R docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> confirmed the RE-03 runtime guard and public `partial` / reserved wording
  remain in place.
- `rg -n "strict_recovered|loose_recovered|failure_reason|sigma_condition|response_boundary_frac|x_abs_cor_max" docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
  -> confirmed the new diagnostic fields are confined to the research spike
  script.

## 7. Roadmap Tick

N/A. RE-03 remains `partial`; no roadmap status changes.

## 7a. GitHub Issue Ledger

- Inspected issue `#341` and its post-`#456` RE-03 comments. No comment was
  posted in this slice.
- No new issue was created. The follow-up still belongs under `#341` until a
  diagnostic run produces an admission or a separately scoped blocker.

## 8. What Did Not Go Smoothly

The first workflow patch missed the exact `n_rep` description string and had
to be reapplied against the live YAML. The first script patch also left a
tabbed indentation artifact in the accumulation block; `nl` inspection caught
it before close-out.

## 9. Team Learning

**Ada:** The right next slice is infrastructure for diagnosis, not admission.
The current guard stays honest while the sweep gains enough metadata to decide
whether each family needs a different threshold, stronger DGP, or continued
reservation.

**Curie:** The next simulation should vary the covariate and slope-signal axes
instead of only adding seeds. The old-store compatibility check matters because
the next remote run will mix historical baseline rows with expanded-schema rows.

**Fisher:** Strict recovery and fit health are now recorded separately, with a
loose recovery screen added as a diagnostic, not as an admission rule. That
prevents a near-threshold row from being mistaken for the same problem as a
non-PD Hessian.

**Jason:** A cross-package comparator is unlikely to match this exact
`phylo_dep(..., s = 2)` likelihood surface. The useful scout here is internal:
same DGP, same engine path, richer diagnostics.

**Rose:** The capability boundary remains consistent across code and status
docs: no user-facing text now claims non-Gaussian `s >= 2` support.

**Grace:** Scheduled workflow behaviour is preserved. The new knobs are manual
dispatch inputs with defaults, so default campaign runs do not accidentally
become factorial diagnostic runs.

## 10. Known Limitations And Next Actions

- No full remote diagnostic run was dispatched in this slice.
- No family-specific admission threshold was ratified. The next pass should
  dispatch a narrow grid for `Beta`, `nbinom2`, and `ordinal_probit`, for
  example `s_grid = 2`, `n_grid = 600,1200`, `n_rep = 10,20`,
  `x_sd_grid = 1,1.5`, and `slope_scale_grid = 1,1.25`, with a small seed
  batch first to estimate runtime.
- Do not update `docs/design/35-validation-debt-register.md`, `NEWS.md`, or the
  runtime guard until a family clears a pre-agreed admission rule.
