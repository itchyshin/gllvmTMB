# After Task: Julia Bridge Cbind-Binomial Contract

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Hopper / Fisher / Grace / Rose / Shannon`

## 1. Goal

Clean the local checkout for cloud-work readiness by closing the ordinary
binomial `cbind(successes, failures)` capability drift row in the R-to-GLLVM.jl
bridge, without widening any source-specific, mixed-family, mask, or fixed-X
claims beyond the current contract.

## 2. Implemented

- `gllvm_julia_capabilities()` now marks the binomial `cbind_binomial` row as
  admitted and describes the narrow contract: complete no-X binomial formula
  rows are marshalled as success counts plus trial-count `N`.
- The main `gllvmTMB(..., engine = "julia")` dispatcher now validates
  two-column binomial responses, rejects partial/non-finite/negative/non-integer
  counts, and pivots successes plus trials into the existing Julia bridge.
- Unsupported cbind combinations still fail loudly: non-binomial cbind,
  cbind plus weights, cbind plus fixed-effect X, masks, mixed-family vectors,
  and source-specific routes.
- Roxygen/Rd wording now states the current R bridge boundary: fixed-effect-X
  CI transport is Gaussian-only, and mask CI parity remains gated.
- Mission Control was refreshed to show the current live guard: 793/793
  configured bridge assertions, 8 registered drift rows, and 0 unregistered
  rows.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `man/gllvm_julia_fit.Rd`
- `man/gllvmTMB_julia-methods.Rd`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-cbind-binomial-contract.md`

## 3a. Decisions and Rejected Alternatives

Decision: route formula-level `cbind(successes, failures)` only for complete
no-X one-family binomial rows.

Rationale: direct Julia bridge trial-count support already exists through `N`,
but the R formula dispatcher needed explicit validation and pivoting. Admitting
only the no-X complete-response row closes the drift without implying broader
mask, X, mixed-family, or source-specific parity.

Rejected alternative: leave cbind as a registered Julia-broader drift row. That
would keep cloud work clean but would miss a small, defensible bridge closure.

Confidence: high for the bridge-transport contract; no coverage calibration or
full parity claim is made.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Final focused outcome after Roxygen/dashboard edits: passed with 362
assertions, 0 failures, and 13 expected live-GLLVM-path skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome before Roxygen/dashboard edits: passed with 793 assertions, 0 failures,
and 0 skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS'
pkgload::load_all(quiet = TRUE)
gllvmTMB:::gllvm_julia_setup()
engine_caps <- JuliaCall::julia_eval('GLLVM.bridge_capabilities()')
drift <- gllvmTMB:::.gllvm_julia_capability_drift(julia_caps = engine_caps)
print(drift[, c('family','capability','direction','status','gate_id')], row.names = FALSE)
cat('n=', nrow(drift), ' unregistered=', sum(drift$status == 'unregistered'), '\n')
RS
```

Outcome: 8 registered drift rows, 0 unregistered rows, and no remaining
`cbind_binomial` drift row.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: regenerated `man/gllvm_julia_fit.Rd` and
`man/gllvmTMB_julia-methods.Rd`; emitted the same unrelated unresolved-link
warnings.

## 5. Tests of the Tests

The new dispatch test proves that cbind binomial responses pass success counts
and a trial-count matrix to `gllvm_julia_fit()`. It also checks the important
negative combinations: cbind plus fixed-effect X remains `GJL-GATE-X-FAMILY`,
and non-binomial cbind remains `GJL-GATE-CBIND-BINOMIAL`.

## 6. Consistency Audit

Mission Control now says the current bridge guard is 8 registered live drift
rows and 0 unregistered rows. The dashboard continues to block R/Julia parity
completion, v1.0 completion, source-specific `lv`, mixed-family CIs, X/mask
parity, unique= Julia parity, coverage calibration, and active compute.

## 7. Roadmap Tick

No public roadmap row was promoted. This is a bridge drift reduction and local
cloud-readiness checkpoint.

## 7a. GitHub Issue Ledger

No issue was opened or closed.

## 8. What Did Not Go Smoothly

The Roxygen pass surfaced existing unresolved-link warnings in unrelated docs.
Those were left unchanged because they are outside this bridge slice.

## 9. Team Learning

Ada kept the slice focused on one bridge row and cloud readiness.
Hopper owned the R-to-Julia trial-count contract. Fisher checked that this is
transport only, not an inference or coverage claim. Grace kept validation and
Mission Control aligned. Rose kept unsupported surfaces gated. Shannon kept the
work local with explicit-file staging only.

## 10. Known Limitations And Next Actions

- No push, PR, or merge from this slice.
- No full `devtools::check()`.
- No source-specific `lv = ~ env` exposure.
- No mixed-family CI, fixed-X non-Gaussian, mask, or unique= Julia parity.
- Remaining live drift is registered and still needs separate v1.0 follow-up.
