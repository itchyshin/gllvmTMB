# After Task: Julia Bridge Non-Gaussian-X CI-Status Contract

## Goal

Harden the R-side `engine = "julia"` bridge contract for supported
non-Gaussian fixed-effect-X point-fit rows whose confidence intervals are still
not routed through Julia.

## Implemented

The bridge now reports method-specific unavailable CI-status strings for
non-Gaussian fixed-effect-X interval requests:
`wald_unavailable_non_gaussian_x`,
`profile_unavailable_non_gaussian_x`, and
`bootstrap_unavailable_non_gaussian_x`.

Complete non-Gaussian-X point-fit objects now cache
`ci_status = "ci_unavailable_non_gaussian_x"` and a matching `ci_note`.
`confint.gllvmTMB_julia()` preflights this unsupported cell before refitting,
even if a stale or synthetic object carries CI-looking fields.

The same pass broadened mixed-family unsupported-CI tests from Wald only to
Wald/profile/bootstrap, clarified the direct NA-without-mask error, and
time-scoped stale NB1 after-task notes that predated the later NB1 mask
admission.

## Mathematical Contract

No likelihood, objective, point estimate, or interval endpoint changed. This is
an R bridge status contract only: supported non-Gaussian-X point fits remain
valid point fits, while their interval route is explicitly unavailable.

## Files Changed

- `R/julia-bridge.R` - non-Gaussian-X CI-status helpers, direct fit guard,
  cached point-fit status, `confint()` preflight, and clarified NA-without-mask
  wording.
- `tests/testthat/test-julia-bridge.R` - pure-R unsupported-cell checks and live
  Poisson-X cached status/`confint()` checks.
- `man/gllvm_julia_fit.Rd`, `man/confint.gllvmTMB_julia.Rd` - regenerated bridge
  docs.
- `NEWS.md` - user-facing development note.
- `docs/dev-log/check-log.md` - evidence record.
- `docs/dev-log/coordination-board.md` plus two older NB1 after-task reports -
  stale-claim cleanup.

## Tests Added

Added pure-R tests for Poisson, Binomial, NB2, Beta, and Gamma fixed-effect-X
requests with `ci_method = "wald"`, `"profile"`, and `"bootstrap"`. NB1 was
deliberately excluded from that loop after the first test run confirmed NB1-X is
still rejected before the CI-status layer.

Added synthetic `confint()` tests proving non-Gaussian-X objects return the
method-specific unavailable status even if cached CI-looking fields are present.
Added live Poisson-X assertions that the fitted bridge object caches
`ci_unavailable_non_gaussian_x` and that all three `confint()` methods fail with
the matching status.

## Benchmark Numbers

N/A - no hot-path or Julia engine code changed.

## R-Parity Verdict

Bridge contract parity passed against the paired
`/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration` checkout. The slice
does not claim native TMB-vs-Julia numerical parity beyond the already routed
point-fit tests.

## Validation

- `Rscript -e 'devtools::document(roclets = "rd")'`
  - Passed with pre-existing unresolved-link roxygen warnings; unrelated
    generated Rd churn was reverted.
- `Rscript -e 'devtools::test(filter = "julia-bridge")'`
  - Final result: `FAIL 0 | WARN 0 | SKIP 18 | PASS 248`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'`
  - Final result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 599`.
- `Rscript -e 'devtools::test()'`
  - Final result: `FAIL 0 | WARN 3 | SKIP 724 | PASS 3018`.
- `git diff --check`
  - Clean.

## Rose Verdict

Rose verdict: PASS WITH NOTES - unsupported non-Gaussian-X interval cells now
have stable method-specific CI-status evidence. Interval endpoints remain
unsupported; NB1-X remains outside this status layer because NB1 fixed-effect-X
is not admitted yet.

## Remaining Risks

- Non-Gaussian fixed-effect-X Wald/profile/bootstrap endpoints are still
  unavailable.
- NB1 fixed-effect-X remains a separate admission gate.
- Mixed-family and masked-response interval endpoints remain unavailable.
- This does not replace the later need for native TMB-vs-Julia comparator
  parity on each admitted R bridge row.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```
