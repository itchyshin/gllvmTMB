# Check-log — Meuwissen-Luo F twin (#1322)

| Date | Slice | Command / evidence | Result |
|---|---|---|---|
| 2026-09-25 | Meuwissen-Luo F in `.gllvm_pedigree_precision` | `NOT_CRAN=true R_PROFILE_USER=/dev/null Rscript --no-init-file -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-pedigree-precision.R")'` | FAIL 0 / PASS 21 |
| 2026-09-25 | Sparse Ainv regression | same `load_all` + `test-pedigree-sparse-ainv.R` | FAIL 0 / PASS 9 |
| 2026-09-25 | Deliberately not run | full `devtools::test()` / Totoro n-ladder / speed receipt | D-50; identity gates only |

Lane: `cursor/meuwissen-twin-20260925` worktree `~/local-scratch/lanes/gllvmTMB-meuwissen-twin-20260925`. Issue #1322. Twin of drmTMB #1424. No public speed claim.
