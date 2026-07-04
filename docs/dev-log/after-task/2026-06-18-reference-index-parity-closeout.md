# After-task report: export / pkgdown reference parity closeout

Date: 2026-06-18 22:22 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed the broader Rose export/reference parity warning found during
the coevolution/unique pre-publish audit. The fix keeps first-stop reference
navigation honest: public exports are indexed, while exported S3 printer
registrations that are not standalone help aliases are explicitly
`@keywords internal`.

## Files touched

- `_pkgdown.yml`
- `R/check-consistency.R`
- `R/check-identifiability.R`
- `R/confint-inspect.R`
- `R/coverage-study.R`
- `man/confint_inspect.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-reference-index-parity-closeout.md`

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  passed with `No problems found.`
- Corrected Rose export/reference parity script over `R/*.R` and
  `_pkgdown.yml` returned `PUBLIC_EXPORTS 151` and
  `MISSING_PUBLIC_EXPORTS 0`.
- `git diff --check` passed.

## Not claimed

- No release readiness.
- No full `devtools::check()`.
- No bridge completion.
- No scientific coverage completion.
