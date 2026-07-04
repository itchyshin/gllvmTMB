# After-task report: exported extractor help ordinary unique cleanup

Date: 2026-06-18 21:22 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by aligning exported
extractor examples, top-level residual documentation, and the fit-time
`sigma_eps` auto-suppression message with the default `latent()` / standalone
`indep()` convention.

## Files touched

- `R/gllvmTMB.R`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/extract-sigma-table.R`
- `R/extract-omega.R`
- `R/extract-repeatability.R`
- `R/brms-sugar.R`
- `man/gllvmTMB.Rd`
- `man/extract_Sigma.Rd`
- `man/extract_Sigma_table.Rd`
- `man/extract_residual_split.Rd`
- `man/extract_repeatability.Rd`
- `man/indep.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- `extract_Sigma()` and `extract_Sigma_table()` examples now use ordinary
  `latent()` alone for the default shared + diagonal-Psi covariance.
- `extract_residual_split()` uses `indep()` for the per-row OLRE diagonal.
- `extract_repeatability()` uses two default ordinary `latent()` tiers.
- `gllvmTMB()` residual docs and the runtime `sigma_eps` auto-suppression
  message now teach per-row `indep()` and mention ordinary `unique()` only as
  legacy compatibility spelling.
- The `indep()` example label now calls standalone `unique()` compatibility
  spelling rather than a new decomposition form.

## Definition-of-done accounting

1. Implementation: local documentation/diagnostic cleanup only; not merged to
   `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: roxygen sources and generated Rd files updated.
4. Runnable example: exported extractor examples now use preferred syntax.
5. Check-log: `docs/dev-log/check-log.md` has the 21:22 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood, parser behavior, or formula grammar behavior
   changed; this was a lifecycle/reference consistency slice.

## Validation

- All touched R files parsed.
- `devtools::document(quiet = TRUE)` regenerated the touched Rd files.
- Focused extractor/residual/deprecation tests passed with expected skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no remaining touched-surface copy-paste examples for
  ordinary `latent() + unique()` or per-row `unique()` as the first spelling.
- `git diff --check` was clean.

## Still open

- No keyword removal.
- No source-specific/kernel paired-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
