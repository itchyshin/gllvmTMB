# After Task: Julia Bridge Capability Checkpoint Cleanup

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Hopper / Fisher / Grace / Rose / Shannon`

## 1. Goal

Clear the local dirty `gllvmTMB` checkout for cloud-work readiness while preserving an honest R-to-Julia bridge contract. The immediate target was a local checkpoint commit, not a push, PR, merge, or new bridge feature.

## 2. Implemented

- Narrowed `gllvm_julia_capabilities()` to the live admitted one-family rows: Gaussian, Poisson, Binomial, NB2, Beta, Gamma, and Ordinal.
- Removed the advertised mixed-family vector row from the live R bridge ledger.
- Added/used a named `GJL-GATE-MASK` stop for response masks and kept non-Gaussian fixed-effect `X` behind `GJL-GATE-X-FAMILY`.
- Kept `nb1`, `ordinal_probit`, masks, non-Gaussian `X`, and mixed-family vectors as explicit follow-up/gated rows rather than bridge support.
- Regenerated `man/gllvm_julia_capabilities.Rd` to match the roxygen boundary.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_capabilities.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-capability-checkpoint.md`

## 3a. Decisions and Rejected Alternatives

Decision: checkpoint the narrow bridge truth rather than widening R claims to match stale tests.

Rationale: the local `GLLVM.jl` capability ledger does not currently support response masks, non-Gaussian fixed-effect `X`, mixed-family vectors, `nb1`, or `ordinal_probit` as admitted bridge rows. Advertising those rows from R would make Mission Control and cloud work less trustworthy.

Rejected alternative: re-enable the broad R ledger and leave live failures as Julia-only problems. That would overstate R parity.

Confidence: medium-high for the ledger cleanup; live parity remains a separate follow-up.

## 4. Checks Run

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 350 assertions, 0 failures, and 14 live-Julia skips.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: regenerated `man/gllvm_julia_capabilities.Rd`; reported existing unresolved-link warnings in unrelated roxygen topics.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: diagnostic only, not green: 503 passes and 25 failures. Failures remain in stale live-parity tests for gated rows and in older parity assumptions.

## 5. Tests of the Tests

The focused test file now checks that the capability ledger excludes mixed-family, `nb1`, and `ordinal_probit` admitted rows; response masks fail through `GJL-GATE-MASK`; and non-Gaussian fixed-effect `X` fails through `GJL-GATE-X-FAMILY`. This is a boundary-lock test change, not a new numerical-validation test.

## 6. Consistency Audit

```sh
rg -n "mixed-family vector route|response masks and masked no-X|nb1.*postfit|ordinal_probit.*postfit" R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvm_julia_capabilities.Rd
```

Verdict: one remaining hit in a dormant future mask-CI note branch inside `R/julia-bridge.R`. Current active capability notes and generated Rd wording say response masks are gated.

## 7. Roadmap Tick

No roadmap row changed. This is a local cloud-readiness checkpoint and bridge truth cleanup.

## 7a. GitHub Issue Ledger

No new issue created. Existing bridge rows continue to point at `gllvmTMB#488` in the gate registry.

## 8. What Did Not Go Smoothly

The optional live-Julia bridge tests are still ahead of the admitted contract. They assume support for rows that the current R ledger now correctly gates. A later live-parity sweep should either update those tests to skip/gate unsupported rows or implement the missing bridge features.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept this as a cleanup checkpoint, not a feature expansion.

Hopper aligned the R ledger with the local `GLLVM.jl` capability surface.

Fisher kept CI/mask/X wording scoped to admitted rows.

Grace recorded the exact validation commands and the live diagnostic failure.

Rose blocked overclaiming of mixed-family, `nb1`, `ordinal_probit`, masks, and non-Gaussian `X`.

Shannon kept this local: no push, PR, or merge was performed.

## 10. Known Limitations And Next Actions

- Live `GLLVM_JL_PATH` bridge tests are not green yet.
- Registered drift still needs a dedicated live-parity sweep, especially for retained-payload simulation and stale tests that assume old broad bridge rows.
- No cloud-visible push has happened from this checkpoint; a push requires explicit maintainer authorization.
