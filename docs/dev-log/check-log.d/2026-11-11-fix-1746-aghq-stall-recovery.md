# Check-log: AGHQ cap-1 stall recovery on the honest objective (#1746)

**Goal:** make the default Laplace auto-refit (`aghq = 9`, loading ridge
`tau = 2`) on the seed-2003 runaway cell of `test-runaway-warning.R`
converge for a numerical reason rather than by round-off luck. No tolerance,
guard, assertion or default was changed.

## Root cause (measured)

On this cell, AGHQ runs two starts. They behave like this:

| Start | Behaviour on `main` |
| --- | --- |
| Laplace warm start | Converges on the surrogate rule with no margin: pass 14 has relative gradient 9.19e-07 against 1e-06 and mode shift 9.95e-05 against 1e-04. |
| Empirical-logit start | Always ends `stalled (no honest descent at cap 1 after backtracking); max \|grad\| = 0.00188 (relative 5.37e-06)`, at -O2, at `-O0 --coverage`, and on CI. This is the exact CI message. |

On CI the warm start also missed its marginal test, so neither start
converged. The stalled start had the lower honest objective F, so it was
selected and its stall surfaced as the "AGHQ did not converge" warning at
`test-runaway-warning.R:63-65`.

Why the empirical-logit start stalls: the surrogate gradient (nodes frozen at
the iterate) omits dF through the adaptation point, and at k = 9 that term does
not vanish. At the stalled point, central finite differences of F (with
re-adaptation) give max |grad F| = 0.01693. The value is identical for
h = 1e-3, 1e-4, 1e-5 and 1e-6, so F is smooth and the number is real. The
surrogate reports 0.0019 there. Every surrogate step raised F linearly in the
step length, so the step pointed uphill in F. A step along -grad F lowers F
(-6.6e-5 at step 0.1). BFGS on F reaches F = 349.0207240 with
|grad F| = 8e-8. That is 1.66e-4 below the stall point and 1.71e-4 below the
warm start's "converged" point, where |grad F| = 0.0180.

## Change

`R/fit-multi.R`: new `.gllvmTMB_aghq_recover_descent()`, called only from the
terminal cap-1 stall branch of the adaptation loop. It:

1. tilts the surrogate by c'(theta - theta0), with
   c = grad F - grad S (central differences of F), so it is first-order
   consistent with F;
2. takes a capped (25-iteration) optimiser step and keeps it only on a strict
   decrease of F, halving down to `aghq_rho_min`;
3. stops on no descent or after 3 steps, never on the tolerances;
4. judges convergence on the honest gradient against the unchanged
   `aghq_grad_tol` / `aghq_grad_tol_rel`.

Otherwise the stall is reported as before, now carrying the honest gradient.
The comment that called the surrogate fixed point "stationarity of F" was
corrected.

## Commands

The R toolchain was installed with r2u (R 4.6.2, TMB 1.9.25, Matrix 1.7-6 and
RcppEigen 0.3.4.0.2, the same versions as the CI coverage job). Two builds were
made: `R CMD INSTALL` at the default `-O2`, and one with
`R_MAKEVARS_USER` setting `C/CXX/CXX11..20FLAGS = -O0 --coverage` and
`LDFLAGS = --coverage`. That is covr's flag set. The fixed libraries reuse
byte-identical `gllvmTMB.so` files (verified with `cmp`).

    Rscript repro.R <lib> verbose        # the test-runaway-warning cell, default control
    testthat::test_dir("tests/testthat", package = "gllvmTMB", load_package = "installed",
      filter = "^(runaway-warning|degenerate-laplace-optima|aghq-multistart-convergence|aghq-golden|aghq-auto-ridge|aghq-auto-psi-equivalence)$")
    # plus a 20-file AGHQ sweep at -O2 adding aghq-conditional-prediction, aghq-control-wiring,
    # aghq-summary-predictions, aghq-surface, censored-poisson, confirmatory-lambda,
    # fixed-effect-priors, joint-sdm-binary-long-wide, julia-unsupported-args-1347,
    # loading-ridge-curvature, missing-response-nongaussian, multinomial-fence,
    # temporal-program-kernel-replicated, zi-families

## Results

| Run | main | fix |
| --- | --- | --- |
| Runaway cell, -O2 | converged, start 1, penalised F 349.02089515 | converged, start 2 (`cap-1 stall recovered by 2 first-order-corrected steps`, honest rel. grad 3.12e-07), penalised F 349.02072404, max \|dpar\| 0.0060 |
| Runaway cell, -O0 --coverage | identical to -O2 (start 2 stalls, start 1 converges) | identical to -O2 |
| New test `#1746` (in `test-aghq-multistart-convergence.R`) | FAIL 4 at -O2 and at -O0 (exact CI stall message) | PASS 7 at -O2 and -O0 |
| Six named files, -O2 | FAIL 0 / PASS 368, 6.4 min | FAIL 0 / PASS 368 (+7 new), 10.1 min |
| Six named files, -O0 --coverage | FAIL 0 / PASS 368, 40.1 min | see PR body for the final run |
| 20-file AGHQ sweep, -O2 | FAIL 0, 8.1 min | FAIL 0, 12.0 min |

Time moves only in files whose fits end on the stall branch. At -O2,
`aghq-multistart-convergence` goes from 70 s to 278 s (about 50 s of that is
the new test) and `runaway-warning` from 20 s to 41 s. At -O0,
`aghq-multistart-convergence` goes from 443 s to 1671 s. That file runs in
coverage shard 2, which took 44 min on main run 42938549464.

Not run: the full suite, `R CMD check`, covr itself, and macOS or Windows.
Locally the `-O0 --coverage` build does NOT reproduce CI's warm-start miss
(round-off differs; CI uses `/opt/R` from r-lib/setup-r). That is why the
regression test rebuilds the stalling start through the internal
`aghq_start_par` hook instead of relying on which way round-off breaks.

## Claim boundary

This makes the stall exit honest and recovers convergence when F really
descends to a stationary point. It does not change the main convergence rule:
a warm-start fit can still be called `converged` at a surrogate fixed point
whose honest gradient exceeds the tolerances (0.018 on this cell). That is
left as a design question for the maintainer. No validation-debt row moves.
