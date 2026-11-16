# Check-log: refuse singular AGHQ recovery steps (#1795)

**Goal:** Coverage shard 2/4 (run 43740016076, job 132890890900) failed
GOLDEN 2 at `tests/testthat/test-aghq-golden.R:215` because one k in
`c(1, 3, 5, 7, 9)` on the q = 2 fixture returned `opt$convergence != 0`.
Identify the k and the optimizer code, and stop cap-1 recovery from
certifying a singular-convergence step.

**Commands:**

Package built with covr's flags (`-O0 --coverage`, g++ 15.2.0) and
installed to `/tmp/gllvm-lib15`. The edited
`.gllvmTMB_aghq_recover_descent` was then `eval`'d into that namespace
(lines 12317–12383 of `R/fit-multi.R`) before the tests. The test file
itself was not edited.

```sh
# ladder diagnostics: each k's nlminb code, message, max |grad|, objective
# (script /tmp/aghq-golden-diag15.R against /tmp/gllvm-lib15)
Rscript --vanilla /tmp/aghq-golden-diag15.R

Rscript --vanilla -e '
.libPaths(c("/tmp/gllvm-lib15", .libPaths()))
Sys.setenv(NOT_CRAN = "true")
# unlockBinding + eval of the patched function, then:
testthat::test_dir("tests/testthat", filter = "^aghq-golden$",
                   reporter = "summary", stop_on_failure = FALSE)
testthat::test_dir("tests/testthat",
                   filter = "^aghq-multistart-convergence$",
                   reporter = "summary", stop_on_failure = FALSE)
'
```

**Results:**

CI ladder (the failure): only k = 3 is wrong. Objective 1.006476 against
brute-force nll 2.105188 (abs error 1.099), `convergence` 1. k = 1, 5, 7, 9
sit at 1.909543 with errors from 1e-9 down to 5e-14 and `convergence` 0.

Local `-O0 --coverage` before the guard, k = 3: the empirical-logit start
stalls at F = 1.88406537. Recovery then returns F = 1.00637865, finite-difference
gradient 5.94e-5 (under `aghq_grad_tol` 1e-4), `iterations` 1,
`opt$convergence` 1, message `singular convergence (7)`. A fresh adaptation
from that point scored 12.275 on this machine, so multi-start still kept the
Laplace start. On the coverage job the fresh adaptation reproduces ~1.006,
the run is marked converged, and 1.006 beats 1.909, so the singular step is
what the test sees.

After the guard, the same k = 3 recovery stays at the stall (F = 1.88406537,
gradient 0.0328, `iterations` 0) and is not marked converged. Multi-start
prints `objectives 1.9095, 1.8841 | converged TRUE, FALSE -> start 1`.
The golden ladder is then:

| k | convergence | message | objective | abs error |
| --- | --- | --- | --- | --- |
| 1 | 0 | relative convergence (4) | 1.909543 | 1.12e-9 |
| 3 | 0 | relative convergence (4) | 1.909543 | 2.93e-9 |
| 5 | 0 | relative convergence (4) | 1.909543 | 2.23e-10 |
| 7 | 0 | relative convergence (4) | 1.909543 | 1.71e-11 |
| 9 | 0 | relative convergence (4) | 1.909543 | 4.93e-14 |

`test_dir` filter `^aghq-golden$`: exit 0, summary reporter printed no
failure block. `test_dir` filter `^aghq-multistart-convergence$`: exit 0,
no failure block and no skip block (9 tests, including #1746 and both #843
cases), about 27 minutes on the `-O0 --coverage` build.

**Not run:** `devtools::test()` of the whole suite, a full
`covr::package_coverage()` shard, and three-OS `R CMD check`. Plain
R-CMD-check shards on this PR were already green before this change.

**Claim boundary:** No validation-debt row moves. No test expectation,
tolerance, skip, or `nocov` change. No public API, likelihood, grammar, or
family change. The guard only refuses a PORT singular-convergence step
inside cap-1 recovery. Iteration-limit steps still run; #1746 still recovers.
