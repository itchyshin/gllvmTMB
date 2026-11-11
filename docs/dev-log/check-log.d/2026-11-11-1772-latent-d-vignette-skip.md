# 2026-11-11 — #1772 latent-d teaching vignette skip under R CMD check

## Scope

`tests/testthat/helper-vignette-source.R`, `test-latent-d-identifiable-range-doc.R` (vignette `test_that` only), `test-fix-1772-latent-d-vignette-skip.R`, `NEWS.md`.

## Commands

```sh
git checkout -b cursor/fix-1772-latent-d-vignette-skip-e4ae
Rscript --vanilla -e 'devtools::test(filter = "fix-1772|latent-d-identifiable")'
Rscript --vanilla -e 'devtools::check(args = "--no-manual")'  # if environment permits
```

## Deliberately not run

- Full `devtools::test()` (CI verifier).
- `pkgdown::check_pkgdown()` (no user-facing doc change beyond NEWS).

## Stale-wording scans

Not applicable (test-only slice).
