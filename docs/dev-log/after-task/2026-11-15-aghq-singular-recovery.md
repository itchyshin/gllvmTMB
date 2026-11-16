# After Task: refuse singular AGHQ recovery steps

**Branch**: `cursor/fix-aghq-golden-integrate-f5ad`
**Date**: `2026-11-15`
**Roles (engaged)**: Gauss, Fisher, Curie, Grace

## 1. Goal

Coverage shard 2/4 failed GOLDEN 2 (`test-aghq-golden.R:215`) because the
q = 2 k ladder did not all report `opt$convergence == 0`. The plain
R-CMD-check shards pass. The job was to name the failing k and the
optimizer code, and to fix the fit only if the failure is a real bad
point rather than a harmless code at an already-converged optimum.

## 2. Implemented

`.gllvmTMB_aghq_recover_descent()` now breaks out of its line search when
`nlminb` stops with singular convergence (PORT code 7, R code 1, message
`singular convergence (7)`). Iteration-limit stops are still accepted.
The test file, its expectations, and its tolerances are unchanged.

On the q = 2 fixture the failing k is 3. The empirical-logit start stalls,
and the singular recovery step reports an honest objective near 1.006 with
a finite-difference gradient just under 1e-4. That certifies the start as
converged. Under covr the fresh adaptation reproduces that value, multi-start
prefers it to the Laplace start at 1.909543, and the stored `opt$convergence`
is 1. The landed point is 1.099 nll from the brute-force oracle. k = 1, 5,
7 and 9 were already at the oracle with convergence 0.

## 3. Files Changed

- `R/fit-multi.R` — singular-convergence break in
  `.gllvmTMB_aghq_recover_descent()`.
- `docs/dev-log/check-log.d/2026-11-15-aghq-singular-recovery.md`
- `docs/dev-log/after-task/2026-11-15-aghq-singular-recovery.md`

No README, NEWS, ROADMAP, design-doc, vignette, roxygen, or `man/*.Rd`
change. The test helper and the test file were not edited.

## 3a. Decisions and Rejected Alternatives

Decision: refuse the singular step, and leave the stall marked
not converged so the existing ranking keeps the stationary Laplace start.

Rationale: the 1.006 point is a different parameter value, not the shared
optimum with a noisy code. Its gradient is small only because the coarse
grid is flat there. Accepting the step is what makes multi-start select it.

Rejected: editing the golden expectation, forcing `opt$convergence <- 0`
while keeping the 1.006 point, and warm-starting the ladder in the test.
The first two hide a point 1.1 nll from the oracle. The ladder is built in
the test file, which this slice must not edit. Warm-starting would also
not stop recovery from certifying the singular step on a fresh k = 3 fit.

Confidence: high on the mechanism (the recovery objective 1.00637865 matches
the CI objective 1.006476, and the message is singular convergence). The
local `-O0` build did not itself select that point, because a fresh
adaptation from it scored 12.275 and lost the ranking. The coverage job is
the build that stays at 1.006.

## 4. Checks Run

Instrumented library: g++ 15.2.0, `-O0 --coverage`, install prefix
`/tmp/gllvm-lib15`. The patched function was loaded into that namespace
before each test.

- Golden file, `testthat::test_dir(..., filter = "^aghq-golden$")`: exit 0,
  no failure block. Printed q = 2 ladder, all five k at convergence 0 and
  objective 1.909543. Absolute errors 1.12e-9, 2.93e-9, 2.23e-10, 1.71e-11,
  4.93e-14.
- `testthat::test_dir(..., filter = "^aghq-multistart-convergence$")`:
  exit 0, no failure block, no skip block. Includes #1746 (cap-1 recovery
  still converges) and both #843 ranking tests. About 27 minutes.
- `git diff` is confined to `R/fit-multi.R` plus these two dev-log files.

Not run: the full package test suite, a full `covr::package_coverage()`
shard, `devtools::document()`, `pkgdown::check_pkgdown()`.

## 5. Tests of the Tests

No test was added or edited. The existing expectation
`all(ladder$convergence == 0L)` is the CI failure. #1746 still requires the
stop reason `^converged (cap-1 stall recovered` and a gradient under the
unchanged tolerances, so a guard that also dropped honest iteration-limit
steps would fail that test. It passed.

## 6. Consistency Audit

```sh
rg -n "singular convergence" R/fit-multi.R
```

One match, inside `.gllvmTMB_aghq_recover_descent()`. No user-facing string
changed. No stale-wording scan of README, NEWS, or articles: those files
were not touched.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

Inspected PR #1795 (https://github.com/itchyshin/gllvmTMB/pull/1795), which
is the coverage failure this slice is fixing. No issue was closed or opened.
The PR body was not edited.

## 8. What Did Not Go Smoothly

A local `-O0 --coverage` build, with both g++ 13 and g++ 15, did not
reproduce the CI selection. Recovery still computed F = 1.00637865 with a
sub-tolerance gradient and singular convergence, but the following
adaptation scored that start at 12.275, so the Laplace start won and every
k already had convergence 0. The CI print (objective 1.006476, convergence 1,
only at k = 3) is the same recovery value surviving the fresh adaptation.
Ubuntu 26.04's R / BLAS, which the coverage job uses, was not reproduced here.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Gauss: a singular PORT step is not a descent direction. The tilted
`nlminb` objective on that step was on the order of -3e9, while the honest
line search reported 1.006. The finite-difference gradient at that artefact
(5.9e-5) is what cleared `aghq_grad_tol`. Judging recovery by the honest
gradient alone will certify a point the quadratic model could not step in.

Fisher: convergence code 1 here is not "relative convergence with a tiny
gradient at the shared optimum." k = 1, 5, 7 and 9 share objective 1.909543.
k = 3's 1.006 is a different point, and the brute-force integral there is
2.105. Ranking on `(converged, objective)` then does the wrong thing,
because the artefact was labelled converged and had the lower objective.

Curie: the golden file already asserts the consequence. #1746 is the
boundary that the guard must not cross: its recovered start has to stay
under the same gradient tolerances, and it did, on the instrumented build.
No new assertion was added, because a test-file edit was out of scope.

Grace: the plain R-CMD-check shards do not see this. The coverage job's
`-O0 --coverage` build is the one that keeps the artefact. A green check
shard is not evidence that this ladder's `opt$convergence` is stable.

## 10. Known Limitations And Next Actions

The coverage shard has not been re-run here. The local instrumented build
matches the recovery value CI stored, and with the guard that start is no
longer labelled converged, but only the coverage job can confirm the fresh
adaptation no longer returns 1.006. If it still does, and the finite-difference
gradient at the unmoved stall (locally 0.033) is somehow under 1e-4 there,
the ranking would prefer 1.884 over 1.909 and `opt$convergence` could still
be 1. That gradient is two orders of magnitude above the tolerance on the
build used here.
