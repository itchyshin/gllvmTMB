# Recovery checkpoint — Cursor capability proof (2026-09-04)

**Lane:** twin step 5 — capability proof (load_all + one fit; accessor deferred)  
**Branch:** `cursor/lane-gllvm-twin-20260904`  
**HEAD:** `5784dab65` (`origin/main` ancestor: yes)  
**Worktree:** `/Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904`

## Environment

- `Sys.setenv(NOT_CRAN = "true")` before `devtools::load_all(".")`
- No `testthat` / no `skip_on_cran` path — direct `Rscript` object inspection
- Package version at compile: **0.7.1** (debug build)

## Commands

```sh
cd /Users/z3437171/local-scratch/lanes/gllvmTMB-gllvm-twin-20260904
/usr/bin/time -p Rscript --vanilla -e '<load_all + gllvmTMB_wide fit script>'
```

Fit call (after `load_all`): `suppressWarnings(gllvmTMB_wide(Y, d = 1))` with `Y` = 25×6 Gaussian matrix (same scale as `tests/testthat/test-gllvmTMB-wide.R` helper).

## Wall times (measured)

| Phase | Seconds |
|---|---|
| `devtools::load_all(".")` (TMB recompile + install) | **29.8** |
| One `gllvmTMB_wide` fit | **1.0** |
| Total `time -p` real | **31.3** |

DLL compile: **success** (`gllvmTMB.so` linked; `R CMD INSTALL` *DONE*).

## Fit object (object-level)

| Check | Value |
|---|---|
| `class(fit)` | `gllvmTMB_multi`, `gllvmTMB` |
| `fit$convergence` | **0** |
| `logLik(fit)` | **-187.002729883217** (finite) |
| `length(coef(fit))` | **6** |
| `fit$report` present | yes (list on fit object) |
| `report(fit, silent=TRUE)` via namespace | not used — `fit$report` populated on object |

## Deliberately not run

- Coverage harness / arcG Cell-1 grid cell (later slice)
- Latent-score accessor (G0: after this proof)
- `devtools::test()` / push

## Verdict

**PASS** — worktree loads, TMB DLL compiles, one real Laplace Gaussian wide fit completes with convergence 0.
