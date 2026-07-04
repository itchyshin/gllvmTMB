# After Task: Julia Bridge Postfit Simulation Drift Closure

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Hopper / Fisher / Grace / Rose / Shannon`

## 1. Goal

Sync the R-side bridge drift contract after GLLVM.jl added native conditional
in-sample response simulation for Gaussian, Poisson, Binomial, NB2, Beta, and
Gamma.

## 2. Implemented

- Removed the obsolete `GJL-GATE-POSTFIT-SIMULATE-DRIFT` current gate.
- Removed the six non-ordinal `postfit_simulate` rows from the expected
  R-vs-Julia drift table.
- Updated the configured live bridge test so only two drift rows remain
  expected: Ordinal `ci_no_x_wald` and Ordinal `postfit_residuals`.
- Refreshed Mission Control to show 793/793 configured live assertions and a
  2-row registered drift probe with zero unregistered rows.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-postfit-simulation-drift-closure.md`

## 3a. Decisions and Rejected Alternatives

Decision: remove the simulator drift rows rather than leave them as historical
registered drift.

Rationale: the current local GLLVM.jl surface now advertises the same
non-ordinal conditional in-sample simulation boundary as the R ledger. Keeping
the old drift allowance would hide future regressions.

Rejected alternative: promote simulation to a broad parity claim. This slice
only admits retained/in-sample conditional response draws; newdata simulation,
unconditional redraws, Ordinal, masks, mixed-family, and source-specific rows
remain gated.

Confidence: high for the bridge truth table; no coverage or v1.0 completion
claim is made.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 362 assertions, 0 failures, and 13 expected
live-GLLVM-path skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 793 assertions, 0 failures, and 0 skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS'
pkgload::load_all(quiet = TRUE)
gllvmTMB:::gllvm_julia_setup()
engine_caps <- JuliaCall::julia_eval('GLLVM.bridge_capabilities()')
drift <- gllvmTMB:::.gllvm_julia_capability_drift(julia_caps = engine_caps)
print(drift[, c('family', 'capability', 'direction', 'status', 'gate_id')], row.names = FALSE)
cat('n=', nrow(drift), ' unregistered=', sum(drift$status == 'unregistered'), '\n')
RS
```

Outcome: 2 registered drift rows, 0 unregistered rows.

```sh
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
```

Outcome: both dashboard JSON files are valid.

## 5. Tests of the Tests

The live test now constructs the exact expected drift table. If any of the six
non-ordinal `postfit_simulate` rows reappear, the set-equality assertion fails.
If an unsupported new drift appears, `.gllvm_julia_capability_drift()` marks it
unregistered and the live test fails.

## 6. Consistency Audit

Searched the dashboard for current 8-row wording and the obsolete
`GJL-GATE-POSTFIT-SIMULATE-DRIFT` current gate. Current Mission Control rows now
state 2 registered live drift rows. Older after-task/check-log entries keep the
8-row and 9-row states as historical evidence from earlier checkpoints.

## 7. Roadmap Tick

No public roadmap row was promoted. This is a bridge-truth cleanup and local
v1.0-contract hardening slice.

## 7a. GitHub Issue Ledger

No issue was opened or closed. The work remains part of the local bridge
truth-lock around `gllvmTMB#488`.

## 8. What Did Not Go Smoothly

The configured test count remained 793/793 even though the drift table shrank
from 8 rows to 2. The compact drift printout is therefore the clearer evidence
artifact for Mission Control.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the slice scoped to truth-table cleanup. Hopper reconciled the R and
Julia capability ledgers. Fisher kept the simulation claim conditional and
in-sample only. Grace refreshed the dashboard and validation record. Rose kept
parity and source-specific claims blocked. Shannon kept the work local with no
push or PR.

## 10. Known Limitations And Next Actions

- Remaining live bridge drift: Ordinal Wald CI and Ordinal residual semantics.
- Still gated: newdata simulation, unconditional response simulation,
  non-Gaussian fixed-effect X, masks, mixed-family vectors/CIs,
  source-specific `lv`, Julia source-Psi parity, coverage calibration, and
  v1.0 parity completion.
