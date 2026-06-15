# After Task: Julia Bridge Capability Ledger

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Hopper / Rose / Pat`

## 1. Goal

Expose the current R-side `engine = "julia"` admission ledger so users and tests
can see which bridge cells are routed, partial, or still planned before JuliaCall
setup.

## 2. Implemented

- Added `gllvm_julia_capabilities()`.
- The table reports `family`, `fit_no_x`, `fixed_effect_X`,
  `missing_response`, `cbind_binomial`, `status`, and `notes`.
- The table is tied to the same constants used by the R bridge guards.
- The mixed-family vector row is visible as `planned` because the paired
  GLLVM.jl checkout has a route, but the R-side metadata, labels, parity, and
  CI/status rows are not validated yet.
- Added the helper and existing Julia-bridge topics to a dedicated pkgdown
  reference section.

## 3. Files Changed

- `R/julia-bridge.R`
- `NAMESPACE`
- `man/gllvm_julia_capabilities.Rd`
- `_pkgdown.yml`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-capability-ledger.md`

## 3a. Decisions And Rejected Alternatives

Decision: make mixed-family visible as `planned`, not silently omitted. Rejected
alternative: routing mixed-family through R now, because the R fit object still
needs stable family metadata, labels, parity checks, CI-status behaviour, and
post-fit method coverage.

## 4. Checks Run

- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`:
  completed successfully.
- `Rscript -e 'devtools::document()'`:
  completed; emitted pre-existing unresolved-link warnings outside this slice
  and generated unrelated Rd link churn that was restored before commit.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `141 pass`, `14 skip`, `0 fail`, `0 warn` in `2.1s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`:
  `340 pass`, `0 fail`, `0 warn`, `0 skip` in `53.7s`.
- `Rscript -e 'pkgdown::check_pkgdown()'`:
  first reported four existing missing Julia-bridge topics; after adding the
  Julia bridge reference section, rerun returned `No problems found`.

## 5. Tests Of The Tests

The new test checks the table column contract, verifies admitted rows match the
R bridge constants, verifies cbind-binomial is binomial-only, and verifies the
mixed-family vector route is explicitly `planned`.

## 6. Consistency Audit

NEWS states that `gllvm_julia_capabilities()` is a pre-JuliaCall R-side
admission ledger, not proof that every paired checkout can run every row.
Pkgdown now has a dedicated Julia bridge reference section, so exported
bridge topics are discoverable.

## 7. Roadmap Tick

This advances the R-first bridge governance layer. It does not add a new model
cell; it gives the next mixed-family and mask+X implementation slices a concrete
R target and an auditable status row.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the bridge gate-vs-engine drift phase and should be cross-linked to the
gllvmTMB #488 follow-up before a public PR.

## 8. What Did Not Go Smoothly

The first pkgdown check revealed existing missing reference-index entries for
Julia-bridge topics. That was useful signal, so the slice added a dedicated
reference section instead of treating the helper alone as complete.

## 9. Team Learning

Rose/Hopper: a capability table is only useful when it includes planned and
unsupported rows, not just the happy path.

## 10. Known Limitations And Next Actions

`gllvm_julia_capabilities()` reports the R-side bridge ledger only. It does not
query the paired Julia checkout at runtime and does not prove R/TMB-vs-Julia
statistical parity. Next slices should either wire the mixed-family vector row
or add an automated gate comparing this R ledger to the GLLVM.jl bridge matrix.

## 11. Rose Verdict

Rose: PASS WITH NOTES — the admission ledger is visible and tested; it remains a
static R-side table until a cross-repo drift CI is added.
