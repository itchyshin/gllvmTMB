# After-task report: gllvmTMB top-level indep help cleanup

Date: 2026-06-18 21:35 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Update the top-level `gllvmTMB()` help so ordinary no-prefix diagonal examples
and grouping-slot argument docs teach `indep()` first, with `unique()` retained
as legacy compatibility syntax.

## Files touched

- `R/gllvmTMB.R`
- `man/gllvmTMB.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The quartet overview now says ordinary `latent()` carries Psi by default and
  standalone diagonal code should use `indep()`.
- The `unit_obs` argument now names `indep(0 + trait | unit_obs)` for the W-tier
  diagonal and treats `unique()` as compatibility syntax.
- The `cluster2` argument now names `indep(0 + trait | <cluster2 col>)` for the
  second diagonal grouping and treats `unique()` as compatibility syntax.

## Definition-of-done accounting

1. Implementation: documentation wording only; no parser or model behavior
   changed and nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: roxygen source and generated Rd updated.
4. Runnable example: not changed in this slice.
5. Check-log: `docs/dev-log/check-log.md` has the 21:35 MDT entry with exact
   commands and outcomes.
6. Review pass: lifecycle wording consistency only; no likelihood, parser, or
   formula semantics changed.

## Validation

- `R/gllvmTMB.R` parsed.
- `devtools::document(quiet = TRUE)` regenerated `man/gllvmTMB.Rd`.
- Focused parser / keyword-grid / `sigma_eps` / deprecation tests passed with
  expected INLA skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no old top-level ordinary `unique()` slot wording in
  the touched source/help files.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` cleanup remains ongoing.
