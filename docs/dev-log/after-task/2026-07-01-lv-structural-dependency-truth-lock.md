# After Task: LV structural dependency truth lock

## Goal

Make source guards, the mixed-family point boundary, and the R<->Julia bridge
matrix tell one conservative story before any further phylo Model A work.

## Implemented

Added the named `GJL-GATE-MIXED-COMPONENTS` bridge gate, kept mixed-family R
bridge admission to complete balanced Gaussian + Poisson + Binomial
point/postfit rows, and refreshed Mission Control to show source-specific phylo
`lv` parked for v1, mixed-family `X`/`X_lv`/masks/CIs blocked, and no active
compute.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-canonical-keywords.R`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`

## Checks Run

```sh
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
git diff --check -- R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json
Rscript -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
Rscript -e 'source("R/julia-bridge.R"); ...; cat("bridge-gate-smoke-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R")'
```

Results: JSON parsed, whitespace clean, `parse-ok`, and
`bridge-gate-smoke-ok`. The local R 4.5-linked TMB DLL was rebuilt against R 4.6
after the first `load_all()` segfault. Focused R tests then passed:
`test-julia-bridge.R` 380 pass / 14 expected live-Julia skips,
`test-ordinary-latent-random-regression.R` 23 pass / 7 CRAN skips,
`test-canonical-keywords.R` 46 pass / 10 optional-package skips, and
`test-stage37-mixed-family.R` 6 pass.

Julia handover focused tests also passed:

```text
test_bridge_capabilities.jl: 63/63
test_bridge_mixed.jl: 18/18
test_bridge_x.jl: 195/195
test_bridge_missing_mask.jl: 83/83
test_bridge_ci.jl: 64/64
```

## Claim Audit

Searched the touched R/dashboard surfaces for stale `ready to scale`, live
source-specific support promotion, `partial support`, active compute, and
mixed-family CI/`X_lv` overclaims. Hits were limited to negative guard wording
such as `no active compute` and `do not call source-specific phylo lv partial
support`.

## Local Toolchain Note

The first `devtools::load_all(quiet = TRUE)` probe aborted at
`dyn.load(dll_copy_file)` because the untracked local `src/gllvmTMB.so` was
linked to R 4.5 while active R was 4.6. The stale object/shared object were
moved to `/tmp/gllvmtmb-stale-r45-dll-20260701/`, then
`TMB::compile("src/gllvmTMB.cpp")` rebuilt the DLL against R 4.6. Direct
`dyn.load()` and `load_all()` passed after that.

## Not Run

No `R CMD check`, pkgdown, article render, Totoro/DRAC job, PR reopen, push,
API widening, R grammar exposure, or likelihood change.

## Rose Verdict

Rose verdict: PASS WITH NOTES -- truth-lock wording and guard behavior are
coherent; this remains a focused guard slice rather than a full package check.
