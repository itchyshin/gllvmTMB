# Deprecated Keyword Help Pointers

Date: 2026-07-04

## Goal

Close issue #662 by making deprecated formula-keyword warnings point to the
correct replacement help topic.

## Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-scan-deprecated-namespace.R`
- `docs/dev-log/check-log.md`

## What Changed

- Added a replacement-specific `see` field to the deprecated-keyword map.
- Updated `.gllvmTMB_warn_keyword_deprecated()` to use that pointer in the
  closing help line.
- Added a regression showing `phylo_rr()` now points to `?phylo_latent` and
  does not point to `?diag_re`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/brms-sugar.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-scan-deprecated-namespace.R", reporter = "summary")'
```

Focused scanner tests passed.

## Claim Boundary

This changes only the deprecation guidance message. It does not alter formula
grammar, canonical rewrites, model fitting, or keyword lifecycle state.

## Rose Verdict

OK. The warning now sends users to the right replacement documentation without
changing behavior.
