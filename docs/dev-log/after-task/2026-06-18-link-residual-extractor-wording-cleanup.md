# Link-Residual Extractor Wording Cleanup

Date: 2026-06-18 23:32 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Close the narrow extractor wording gap left after the public `unique()`
cleanup. Generated help still described `link_residual = "none"` and related
derived quantities as "latent + unique" or "latent+unique-implied" targets,
which made compatibility syntax sound like the ordinary user-facing model.

## Files Touched

- `R/extract-sigma.R`
- `R/extract-correlations.R`
- `R/bootstrap-sigma.R`
- `R/extract-sigma-table.R`
- `R/extract-omega.R`
- `R/extractors.R`
- `R/profile-derived.R`
- `R/extract-repeatability.R`
- `R/gllvmTMB.R`
- `R/z-confint-gllvmTMB.R`
- regenerated `man/bootstrap_Sigma.Rd`
- regenerated `man/confint.gllvmTMB_multi.Rd`
- regenerated `man/extract_Sigma.Rd`
- regenerated `man/extract_Sigma_table.Rd`
- regenerated `man/extract_Omega.Rd`
- regenerated `man/extract_communality.Rd`
- regenerated `man/extract_correlations.Rd`
- regenerated `man/extract_phylo_signal.Rd`
- regenerated `man/gllvmTMBcontrol.Rd`
- regenerated `man/profile_ci_phylo_signal.Rd`
- `docs/design/06-extractors-contract.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- Reworded `link_residual = "none"` documentation to say it returns the
  fitted model covariance without link-residual additions, with
  `Lambda Lambda^T + Psi` named only as the decomposition target where present.
- Removed generated-help wording that made `latent + unique` sound like the
  ordinary extractor scale.
- Updated derived phylogenetic-signal wording from species-level
  `latent + unique` to a species-level latent decomposition with Psi.
- Updated a repeatability Wald diagnostic to suggest ordinary `latent()` or
  standalone `indep()`, rather than presenting `unique()` as the repair path.
- Updated reduced-rank start-method wording so the independent warm start is
  described as a diagonal GLMM/GLLVM, not a user-facing `unique()`-only recipe.

## Checks

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  regenerated the affected Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-correlations|bootstrap-Sigma|extract-sigma-table|link-residual|confint|extract-repeatability|extractors", reporter = "summary")'`
  completed successfully; expected heavy recovery fixtures were skipped by the
  normal `GLLVMTMB_HEAVY_TESTS` gate.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Stale phrase scans returned no hits for:
  - `latent+unique-implied`
  - `fitted latent + unique`
  - `full latent + unique Sigma`
  - `latent + unique covariance`
  - `latent + unique Sigma`
- `git diff --check` passed.

## Still Not Claimed

- No `unique()` keyword removal.
- No rename of `part = "unique"` or extractor return fields.
- No source-specific or `kernel_*()` latent-Psi fold.
- No Paper 2 multi-kernel explicit-Psi support.
- No bridge completion, release readiness, or scientific coverage completion.
