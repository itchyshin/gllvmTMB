# Check-log: positional covstruct args (#1906)

## Commands

```sh
git diff --stat
rg -n "gllvmTMB_check_top_level_call_slots|1906" R/gllvmTMB.R tests/testthat/test-1906-positional-covstruct.R
```

## Deliberately not run

- Full `devtools::test()` / `R CMD check` (R toolchain unavailable on Cloud Agent VM; CI on push).