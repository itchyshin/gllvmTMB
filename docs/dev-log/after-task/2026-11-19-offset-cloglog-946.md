# After-task: admit `binomial(cloglog)` offsets (#946)

## Scope

Widen the `gll_prepare_offset()` gate so family 1 / link 2 (binomial cloglog) accepts
a nonzero offset outside the integrated two-source contract. Logit and probit remain
refused. Design 01 §Offsets and regression tests updated.

## Outcome

- `R/offset.R`: gate on `family_id == 1 & link_id == 2` without `allow_isdm_cloglog`.
- `R/fit-multi.R`: drop the ISDM-only flag at the call site.
- Tests: three new cases in `test-offset-support.R`; `test-isdm-public-door.R` adjusted.
- Docs: `docs/design/01-formula-grammar.md`, `NEWS.md`.

## Checks

```sh
export R_LIBS_USER=~/R/library
Rscript -e 'pkgload::load_all(); testthat::test_dir("tests/testthat", filter="offset-support")'
Rscript -e 'pkgload::load_all(); testthat::test_dir("tests/testthat", filter="isdm-public-door")'
```

Before: 5080 `test_that` blocks repo-wide on `main`; offset suite 15 blocks.
After: 5083 `test_that` blocks (+3); offset suite 18 blocks. Local runs: offset-support PASS (1 skip glmmTMB); isdm-public-door PASS.

## Follow-up

None for this slice; integrated-model offset behaviour unchanged aside from no longer
requiring the contract flag at the parser.