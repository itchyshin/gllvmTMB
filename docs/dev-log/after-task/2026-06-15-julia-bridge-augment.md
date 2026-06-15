# After Task: Julia Bridge Augment Method

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Pat / Rose`

## 1. Goal

Add a broom-style `augment()` method for `gllvmTMB_julia` objects so R users can
inspect in-sample fitted values and residuals in row order.

## 2. Implemented

- Added `augment.gllvmTMB_julia()`.
- Re-exported `generics::augment`.
- Registered `S3method(augment, gllvmTMB_julia)`.
- Returned row identifiers plus `.observed`, `.fitted`, `.resid`, and `.status`.
- Preserved masked-response rows with `NA` observed/residual values and
  `.status = "masked"`.
- Rejected `newdata`, `type = "link"`, non-default `re_form`, and ordinal
  prediction payloads explicitly.
- Documented the method on the Julia-bridge methods help page and generated
  reexports page.

## 3. Files Changed

- `R/generics-imports.R`
- `R/julia-bridge.R`
- `NAMESPACE`
- `man/gllvmTMB_julia-methods.Rd`
- `man/reexports.Rd`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-augment.md`

## 3a. Decisions And Rejected Alternatives

Decision: keep `augment()` response-scale, in-sample, and conditional-only.
Rejected alternative: allowing `re_form = ~0`, because that would mix a
fixed-effects-only `.fitted` value with residuals computed from the conditional
prediction path unless a new residual definition was validated.

## 4. Checks Run

- `air format R/julia-bridge.R R/generics-imports.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::document()'`:
  completed; emitted pre-existing unresolved-link warnings outside this slice
  and generated unrelated Rd link churn that was restored before commit.
- `git diff --check`:
  completed with no whitespace errors.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `132 pass`, `14 skip`, `0 fail`, `0 warn` in `2.2s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `331 pass`, `0 fail`, `0 warn`, `0 skip` in `55.1s`.

## 5. Tests Of The Tests

The tests lock the synthetic no-Julia row contract, `data =` cbind path,
`newdata` rejection, `type = "link"` rejection, non-default `re_form` rejection,
masked-response status preservation, ordinal fail-loud behaviour, and live
Poisson Julia-engine row output.

## 6. Consistency Audit

NEWS now lists `augment()` among `gllvmTMB_julia` post-fit methods and states
that prediction, residual, and augmentation methods are in-sample only. The help
page documents that `augment()` only routes response-scale default-conditional
rows.

Scan run:
`rg -n "augment\\(|newdata augmentation|re_form = ~|ordinal predictions|AI-REML|non-Gaussian REML|REML" README.md NEWS.md R/julia-bridge.R docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-15-julia-bridge-augment.md`
-> expected hits only: the new augment boundaries, existing Gaussian-only REML
status rows, and AI-REML-as-future-Gaussian-design wording.

## 7. Roadmap Tick

This advances the R-first bridge surface before the next Julia engine slice. It
does not add Julia engine breadth, covariance payloads, CI endpoints, or
calibrated diagnostics.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the post-fit bridge-method row under the R-Julia contract phase and should be
reflected on the dashboard before the slice is called banked.

## 8. What Did Not Go Smoothly

The first draft accepted `re_form` in `augment()` but residuals were still
computed through `residuals()`, which always uses the default conditional
prediction path. Hopper and Rose caught the mismatch. The final method rejects
non-default `re_form` so `.fitted` and `.resid` share one prediction contract.

## 9. Team Learning

Hopper/Rose: broom-style API parity is only safe when the statistical semantics
are as explicit as the column contract.

## 10. Known Limitations And Next Actions

`augment()` does not support `newdata`, link-scale rows, fixed-effects-only
rows, ordinal probabilities, influence diagnostics, hat values, standard errors,
covariance payloads, or CI calibration. The next R-first bridge slices should
either fill a similarly small post-fit gap or start the bridge gate-vs-engine
guard so R rejections cannot drift behind Julia support.

## 11. Rose Verdict

Rose: PASS WITH NOTES — `augment()` is covered as a narrow in-sample row
diagnostic method; broader diagnostic, interval, and `newdata` claims remain
unsupported.
