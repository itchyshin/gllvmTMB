# After Task: S4 public `phylo_dep` receipt runner

## 1. Goal

Add a write-once evidence runner for exactly the experimental post-fit Gaussian
`traits(trait_1, trait_2) ~ 1 + phylo_dep(1 | species, tree = tree)` Tree cell.

## 2. Change

`run-destination-b-s4-public-phylo-dep-isolated.R` executes only the generic
closure test and the seven-endpoint S4 test, checks exact public target order,
uses a predeclared `1e-4` endpoint ceiling, binds fixture/DLL/R/GLLVM/Julia
identity and hashes retained test/probe output, and creates output by link-only
write-once publication. The live test now supplies the seven endpoint pairs.

## 3. TDD evidence

Before implementation, the new focused test failed because the runner was
absent. After implementation it passed and exercises malformed/dangling target
payloads plus duplicate receipt output.

## 4. Checks

`devtools::test(filter = "destination-b-s4-public-phylo-dep-runner")` passed.
`devtools::test(filter = "julia-phylo-rr-bridge")` passed with five opt-in
live cases skipped, including this S4 case.

## 5. Live estimate

The earlier one-cell S4 paired run took 29.8 seconds; this live receipt is
estimated under 10 minutes, so no >30-minute approval is required.

## 6. Environment qualification

The runner requires `GLLVM_S4_JULIA_ENV` and runs an unsuppressed Julia CLI
probe requiring `LogExpFunctions.loglogistic` and `using GLLVM` without an
extension-load error. The previously documented repaired environment path
`/private/tmp/destination-b-juliacall-env-IVmUVo` is absent, so no live receipt
was produced and the S4 environment is not qualified.

## 7. Scope boundary

No C++ or R likelihood work, generic `engine = "julia"` admission, public
promotion, recovery/coverage claim, push, merge, or release occurred.

## 8. Rose review

Runner contract tests cover write-once output and target/order/dangling
rejection. A fresh environment and successful immutable live receipt remain
required before an evidence claim.

## 9. Files

The runner, its focused tests, the existing S4 live test receipt hook, this
report, and `check-log.md` are the only intended tracked changes.

## 10. Next action

Recreate or locate a clean isolated JuliaCall environment, set the five
required `GLLVM_S4_*` variables, commit this leaf so source snapshots are
clean, and run the one-cell command once to a new artifact path.

## 11. Status

Runner/test implementation is complete locally; successful immutable receipt
and environment qualification are blocked by the missing repaired environment.
