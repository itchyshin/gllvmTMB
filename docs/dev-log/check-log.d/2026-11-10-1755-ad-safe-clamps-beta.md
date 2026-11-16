## 2026-11-10: #1755 — refresh Beta AD-safe-clamp source scan

Test-only slice; `src/` untouched.

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R")'
# before (main): [ FAIL 1 | PASS 10 ] — stale expect_match on removed y_safe clamp
# after (branch): [ FAIL 0 | PASS 13 ]
rg -n 'y_safe|tiny_y' src/gllvmTMB.cpp   # no matches
```
