# After-Task Report: Kernel Separability Dimname Alignment

Date: 2026-07-04

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Close issue #686 by making `diagnose_kernel_separability()` compare fixed
kernels by level names when dimnames are present, not by raw matrix position.

## Files Changed

- `R/kernel-helpers.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `man/diagnose_kernel_separability.Rd`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-kernel-separability-dimname-alignment.md`

## What Changed

- Added a pure alignment helper for the pre-fit separability diagnostic.
- Named kernels are now reordered to the first kernel's level order before
  off-diagonal similarity is computed.
- Kernels with mismatched level sets, duplicated/missing names, or only one
  named dimension now fail loudly.
- Unnamed kernels keep the old positional comparison contract.

## Evidence

```sh
Rscript --vanilla -e 'invisible(parse("R/kernel-helpers.R")); cat("parse-ok\n")'
```

Result: parse passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-two-kernel.R", reporter = "summary")'
```

Result: focused coevolution tests passed. Heavy recovery cells skipped as
expected because `GLLVMTMB_HEAVY_TESTS` was not set.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE); cat("document-ok\n")'
```

Result: documentation regenerated `man/diagnose_kernel_separability.Rd`.

## Rose Verdict

OK. This is COE-04 diagnostic hardening only. It does not promote coevolution
recovery, interval calibration, in-engine rho estimation, or broader
non-Gaussian/mixed-family coverage.
