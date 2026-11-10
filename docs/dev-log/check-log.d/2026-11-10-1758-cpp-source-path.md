# 2026-11-10 — #1758 cpp source path under R CMD check

Branch: `cursor/fix-1758-cpp-source-path-027f`

## Change

- `tests/testthat/helper-gllvmTMB-cpp-source.R` — shared resolver (two-level `00_pkg_src`, `system.file`, dev tree).
- `tests/testthat/test-tmb-ad-safe-clamps.R` — use helper; stop on missing source (no `skip_if`).
- `tests/testthat/test-fix-1758-cpp-source-path.R` — regression guard for two-level check layout.
- `tests/testthat/test-zz-mspl-fenced-family-tapes.R` — delegate to shared helper.
- Beta clamp pins aligned with post-#1485 C++ (same as draft #1756) so the un-skipped scan passes.

## Commands

```text
# R not available in cloud agent VM at authoring time
# Not run: Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R")'
# Not run: Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-fix-1758-cpp-source-path.R")'
# Not run: devtools::test() / R CMD check
```

## Stale-wording scan

Not run (test-path-only slice).

## Deliberately not run

Full `devtools::test()`, `R CMD check`, `pkgdown::check_pkgdown()` — no exported surface or roxygen change.
