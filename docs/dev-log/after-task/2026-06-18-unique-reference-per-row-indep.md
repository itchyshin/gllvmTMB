# After-task report: unique reference per-row indep cleanup

Date: 2026-06-18 21:33 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Update the deprecated `unique()` reference page so its per-row residual section
points new users to `indep()` first and keeps `unique()` as compatibility
syntax.

## Files touched

- `R/unique-keyword.R`
- `man/diag_re.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The per-row `sigma_eps` auto-suppression section now recommends
  `indep(0 + trait | g)` for new code.
- Legacy `unique(0 + trait | g)` is still documented as accepted
  compatibility syntax.
- The family-aware section now describes a standalone diagonal tier rather
  than presenting ordinary `unique()` as the recommended spelling.

## Definition-of-done accounting

1. Implementation: documentation wording only; no parser or model behavior
   changed and nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: roxygen source and generated Rd updated.
4. Runnable example: unchanged; this page's runnable example already uses the
   default ordinary `latent()` pattern.
5. Check-log: `docs/dev-log/check-log.md` has the 21:33 MDT entry with exact
   commands and outcomes.
6. Review pass: lifecycle wording consistency only; no likelihood, parser, or
   formula semantics changed.

## Validation

- `R/unique-keyword.R` parsed.
- `devtools::document(quiet = TRUE)` regenerated `man/diag_re.Rd`.
- Focused parser / keyword-grid / `sigma_eps` / deprecation tests passed with
  expected INLA skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no old per-row `unique()` recommendation phrases in
  the touched source/help files.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` cleanup remains ongoing.
