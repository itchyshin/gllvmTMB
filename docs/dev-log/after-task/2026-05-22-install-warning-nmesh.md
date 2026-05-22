# After-task report: install warning n_mesh cleanup

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice removed the package-side `unused variable 'n_mesh'` compiler warning
without changing the TMB data interface or likelihood. It did not alter model
math, parameter transforms, spatial covariance construction, or R parser
behavior.

## What changed

- `src/gllvmTMB.cpp` now marks `n_mesh` as intentionally read with
  `(void)n_mesh;`.
- The `n_mesh` data field remains in the template so the R-side mesh data
  contract is unchanged.
- A brief Makevars/pragma experiment was discarded because source pragmas
  trigger an R CMD check warning and package flags landed before R's default
  `-Wall`.

## Validation

- `SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" R CMD INSTALL --preclean --library=/tmp/gllvmTMB-install-test-lib .`
  completed successfully. The `gllvmTMB.cpp:92` unused `n_mesh` warning no
  longer appeared.
- `Rscript --vanilla -e 'devtools::test(filter = "stage4-spde|spatial-mode-dispatch|spatial-orientation", stop_on_failure = TRUE)'`
  returned 42 passes, 0 failures, 0 warnings, 0 skips.
- `git diff --check` was clean before adding this report.
- Direct SDK check:
  `xcrun --show-sdk-version` still fails locally because
  `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` cannot be located.
  `SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" xcrun --show-sdk-version`
  succeeds and reports `26.4`.

## Review lenses

- Ada kept the patch to build-warning hygiene.
- Gauss/Noether: no likelihood, covariance, parameter transform, or
  objective-function algebra changed.
- Grace: local install still needs `SDKROOT` because CommandLineTools SDK
  lookup is broken on this machine; Eigen/R-header warnings are local
  toolchain/header warnings.
- Rose: source pragmas were rejected because R CMD check flags diagnostic
  pragmas as non-portable.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no estimator, likelihood, family, or
   formula grammar changed.
3. Documentation: after-task and check-log updated.
4. Runnable user-facing example: not applicable; this is build hygiene.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Gauss/Noether, Grace, and Rose lenses applied as above.

## Residual risk

- The local full `devtools::check(args = "--no-manual")` gate still fails
  without SDK/toolchain remediation because this machine's default `xcrun`
  SDK lookup is broken and R/TMB/Eigen headers emit compiler warnings under
  Apple clang 21.
