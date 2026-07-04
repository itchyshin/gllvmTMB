# After-task report: kernel reference unique compatibility cleanup

Date: 2026-06-18 21:00 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by stopping the
`?kernel_latent` reference example from presenting `kernel_unique()` as the
main dense-kernel recipe.

## Files touched

- `R/kernel-keywords.R`
- `man/kernel_latent.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The kernel keyword prose now says new examples should use `kernel_latent()`
  for shared latent structure and `kernel_indep()` for standalone diagonal
  dense-kernel tiers.
- The `?kernel_latent` example now fits `kernel_latent()` alone and extracts
  the shared component with `extract_Sigma(..., part = "shared")`.
- `kernel_unique()` remains documented as soft-deprecated compatibility syntax
  and as the KER-02 equivalence-test path.

## Definition-of-done accounting

1. Implementation: reference/docs cleanup only on the local branch; not merged
   to `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: roxygen source and generated Rd updated.
4. Runnable example: the roxygen example now uses the preferred dense-kernel
   spelling.
5. Check-log: `docs/dev-log/check-log.md` has the 21:00 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood, parser, or exported API change. This was a
   lifecycle/reference consistency slice.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated
  `man/kernel_latent.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|kernel-equivalence|coevolution-two-kernel", reporter = "summary")'`
  passed with expected heavy skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` reported `No problems found.`
- Stale-reference scan found no `kernel_latent() + kernel_unique()` teaching
  example in `R/kernel-keywords.R` or `man/kernel_latent.Rd`.
- `git diff --check` was clean.

## Still open

- No keyword removal.
- No Paper 2 multi-kernel explicit Psi.
- No source-specific or kernel paired-Psi fold.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
