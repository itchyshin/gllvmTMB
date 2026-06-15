# After Task: Julia Bridge CI Oracle Sync

Date: 2026-06-14

## Goal

Record the post-`19264a5` bridge evidence accurately: Gaussian profile and
bootstrap CI transport are now tested through the Julia bridge, while broader CI
coverage remains partial.

## Files Changed

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-14-julia-bridge-ci-oracle-sync.md`

## Checks Run

Previously run live bridge test, now recorded in the ledger:

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 53`, `FAIL 0`, `WARN 0`, `SKIP 0`.

Whitespace:

```sh
git diff --check
```

Result: clean.

## Evidence Boundary

The bridge now has live tests for:

- family mapping and unsupported-cell rejection;
- direct Julia bridge dispatch;
- Gaussian Wald CI equality to native Julia payloads;
- Gaussian profile and bootstrap CI transport through `confint()`.

This does not prove full R/TMB-vs-Julia statistical parity and does not promote
profile/bootstrap CIs across all families or structures.

## Rose Verdict

PASS WITH NOTES. The NEWS and check-log now match the live 53/53 bridge test.
Broader bridge parity, fixed-effect `X`, mixed families, missingness, and full
package checks remain queued.

## Next Command

```sh
git diff --check
```
