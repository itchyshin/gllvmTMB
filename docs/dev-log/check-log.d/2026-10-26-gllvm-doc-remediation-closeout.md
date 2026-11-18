## 2026-10-26: Julia bridge Wald CI status and full article build

Closed audit finding D010 by making non-finite interval bounds report
`ci_status = "unavailable"` with a diagnostic note, while preserving any
engine-provided explanation. Missing engine notes now receive the generic
non-finite-endpoint diagnostic. Added regression coverage and revised the
`gllvm_julia_fit()` Wald example to use a six-trait, one-LV fixture and assert
finite returned bounds. The example makes no interval-coverage claim.
`devtools::test(filter = "julia-bridge")` passed with no failures; expected
skips and two pre-existing deprecation warnings remain. `devtools::document()`
completed and the unrelated generated `tidy.gllvmTMB_multi.Rd` drift was
discarded. Exact-source `R CMD INSTALL` succeeded in an isolated temporary
library. The original two-trait/two-LV negative-control fit returned
`ci_status = "unavailable"`, a non-finite-endpoint note, and non-finite bounds.
The revised six-trait/one-LV example returned `ci_status = "available"` with
14/14 finite bounds. Shinichi authorized completing D010 as package maintainer.
The complete pkgdown article build finished, and
`pkgdown::check_pkgdown()` reported no problems. Pandoc emitted repeated
deprecated `--mathml` / `--mathjax` warnings. No deployment or merge.
