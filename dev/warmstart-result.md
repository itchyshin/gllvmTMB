# VA-R3 factor-analytic warm start — decisive verification

Research-only, internal. Worktree `/private/tmp/gllvmtmb-va-wiring-20260726`,
branch `claude/va-wiring-20260726`. Edits confined to
`R/va-r3-proto.R::.va_r3_default_parameters()` (plus two new private helpers
in the same file); no `R/gllvmTMB.R`, `NAMESPACE`, or `src/gllvmTMB.cpp`
touched, no export tags added.

## What changed

`.va_r3_default_parameters(data, start_id)` no longer initialises the
loadings (`theta_rr`) from data-blind constants for `start_id == 1`. It now:

1. Reuses the already-computed `beta` (the existing `lm.fit` moment estimate)
   to get the fixed-effect contribution `eta_fixed <- X %*% beta`.
2. Forms link-scale pseudo-residuals `Z` (N x T): `qlogis(clamped
   (y+0.5)/(n_trials+1)) - eta_fixed` for binomial, `log(y+0.5) - eta_fixed`
   for Poisson, `y - eta_fixed` for the Gaussian anchor.
3. Eigendecomposes `cor(Z)` and takes `Lambda <- eigenvectors[,1:q] %*%
   diag(sqrt(pmax(eigenvalues[1:q], 0)))` — the gllvm `starting.val = "res"`
   idea.
4. Rotates `Lambda` into the packer's required lower-triangular form via a
   **QR decomposition of the transpose of its top q x q block**: `t(L1) = Q1
   R1` implies `L1 %*% Q1` is lower triangular, and `Q1` is a legitimate
   right-rotation because it's orthogonal (`Lambda %*% Q1 %*% t(Lambda %*%
   Q1) = Lambda %*% t(Lambda)` is preserved). The residual numerical noise in
   the nominally-zero strict upper triangle is checked (< 1e-6) then
   hard-zeroed, since `.va_r3_pack_theta_rr()` requires exact zero.
5. Falls back to the original constant-diagonal start on any degeneracy
   (`N < 2`, non-finite residuals/correlation/eigendecomposition, or a
   rotation whose upper-triangle residual exceeds 1e-6) — verified directly
   (`N = 1` fixture returns `NULL` from `.va_r3_warm_theta_rr()`).

Multi-start structure: **start 1 = warm** (the eigen-based `theta_rr` above).
**Starts 2-4 = warm + the pre-existing jitter**, i.e. the same jitter
formulas the old code used (`diagonal_scale <- c(0.10,-0.10,0.20,-0.20)[k]`
on the diagonal, `0.01*k*sin(...)` off-diagonal) are now *added* to the warm
`theta_rr` instead of replacing a zero vector. `m`, `log_L_diag`, `L_off`
(the variational-posterior parameters) are unchanged — only the loadings
get a data-driven start.

Sanity checks run before the decisive verification:
- Rotation preserves `Lambda %*% t(Lambda)` exactly (`all.equal` on a random
  5x2 matrix) and the packed/unpacked round-trip matches.
- The full 4-start `.approximation_engine_fit()` pipeline still runs end to
  end on a Bernoulli fixture: all 4 starts healthy, `objective_agreement =
  TRUE`, best-three range `1.5e-8` — the agreement gate is exercised, not
  vacuous.
- Degenerate `N = 1` fixture: `.va_r3_warm_theta_rr()` returns `NULL`, so
  `.va_r3_default_parameters()` falls back to the constant start.

## Fixture note (read before the numbers)

I could not locate the exact script/seed convention that produced the
handoff's stated baseline numbers (`-530.5412` cold Poisson ELBO; raw-eigen
relative Frobenius `0.78-0.99` vs converged-fit `1.14-5.34`) anywhere in this
worktree's `dev/` or `docs/dev-log/`. I reconstructed the fixtures from the
closest matching generators already in the repo:

- Bernoulli: `simulate_bernoulli_gllvm(n_units, n_traits, q, seed, lambda_sd
  = 0.9, beta_sd = 0.4)` from `dev/controlled-gh-vs-jj.R`, called directly
  with `seed = 1, 2, ..., 6` (n_trials = 1 throughout).
- Poisson: `build_fixture_pois(n_units, n_traits, d, seed)` from
  `dev/poisson-health-diagnosis-repro.R`, called with `seed = 7` instead of
  that file's default `20260726`.

With these reconstructions the numbers below do **not** reproduce the
handoff's exact historical figures (confirmed against the pre-edit code too,
see below) — but the same *qualitative* phenomenon the handoff described is
reproduced, and is the more important result (§3).

## 1. ELBO: cold vs warm (§(a))

Bernoulli, n=60, T=12, q=2, seeds 1-6. Single-start comparison: same
optimizer pipeline (`nlminb` + up to 2 polish passes + BFGS fallback,
identical to `.va_r3_fit()`'s per-start body) run once from the **cold**
constant-diagonal `theta_rr` and once from the **warm** eigen `theta_rr`,
with everything else (`beta`, `m`, `log_L_diag`, `L_off`) identical.

| seed | ELBO cold | ELBO warm | warm − cold | conv (c/w) | max|grad| (c/w) |
|---|---|---|---|---|---|
| 1 | −460.576862 | −460.576862 | +0.000000 | 0/0 | 8.6e-05 / 9.4e-05 |
| 2 | −424.479736 | −424.479736 | −0.000000 | 0/0 | 5.4e-05 / 8.2e-05 |
| 3 | −460.862230 | −460.862230 | +0.000000 | 0/0 | 2.3e-04 / 6.5e-05 |
| 4 | −437.278896 | −437.278896 | −0.000000 | 0/0 | 5.4e-05 / 4.3e-05 |
| 5 | −444.428453 | −444.428453 | −0.000000 | 0/0 | 2.4e-05 / 6.8e-05 |
| 6 | −433.375702 | −433.375702 | +0.000000 | 0/0 | 9.9e-05 / 4.4e-05 |

**Warm ≥ cold holds on 6/6 seeds**, but the difference is at the 1e-4 to
1e-6 level in every case — below the optimizer's own gradient tolerance.
Read honestly: this is **not** "warm reaches a higher ELBO than cold"; it is
**cold and warm converge to the same point** on this fixture (both directly,
and via the identical objective value to 6 decimal places). The premise
("a higher ELBO proves the cold start was converging to a worse optimum")
does not apply here — there is no evidence of two different optima on this
harness; both starts are drawn into a single attracting basin.

## 2. Relative Frobenius error of Sigma_B vs truth (§(b))

`Sigma_B <- Lambda %*% t(Lambda)` is rotation-invariant (unlike individual
loadings), so a direct Frobenius comparison against `Lambda_true %*%
t(Lambda_true)` needs no Procrustes alignment.

| seed | relFrob cold | relFrob warm |
|---|---|---|
| 1 | 1.3021 | 1.3021 |
| 2 | 0.8230 | 0.8230 |
| 3 | 1.8880 | 1.8879 |
| 4 | 1.5308 | 1.5308 |
| 5 | 1.6626 | 1.6625 |
| 6 | 2.0305 | 2.0305 |

Warm is (marginally) better or equal on 6/6 seeds, but the improvement is in
the 4th decimal place — not a meaningful accuracy gain from the warm start
*as an initial condition for the same optimizer*.

## 3. The actual finding: the optimizer walks away from the good start

This is the decision-relevant result. I also compared the **raw, unoptimized
warm-start loadings** (`Sigma_B` built directly from the eigen-decomposition,
before any `nlminb` call at all) against the same truth:

| seed | relFrob RAW eigen (no optimization) | relFrob CONVERGED (cold or warm) |
|---|---|---|
| 1 | 0.8471 | 1.3021 |
| 2 | 0.8848 | 0.8230 |
| 3 | 0.8282 | 1.8880 |
| 4 | 0.8342 | 1.5308 |
| 5 | 0.8582 | 1.6626 |
| 6 | 0.8653 | 2.0305 |

The raw eigen guess beats the converged VA fit on **5/6 seeds** (all but
seed 2, where they're within 0.06 of each other) — reproducing the
*direction* of the handoff's stated defect (though not its exact numbers;
see the fixture note above). Wiring the eigen decomposition in as an
**initial value only** does not fix this: `nlminb` runs from the warm start
to convergence and lands at essentially the *same* optimum cold reaches
(§1-2), which is *worse*, in Sigma_B, than not optimizing at all. The
accuracy problem here is downstream of the starting point — in the ELBO
surface, its optimum, or the optimizer's tolerance/scaling — not fixed by
this change alone. This warm start improves the starting point; it does not
by itself improve where the optimizer ends up.

## 4. Timing and evaluations, interleaved (§(c))

Main run (cold, warm) per seed, in that order, after one discarded warm-up
fit that absorbs the compile/first-tape penalty:

| seed | time cold (s) | time warm (s) | evals cold (fn/gr) | evals warm (fn/gr) |
|---|---|---|---|---|
| 1 | 0.785 | 0.674 | 144/108 | 124/92 |
| 2 | 0.604 | 0.525 | 4/2 | 95/73 |
| 3 | 0.889 | 0.588 | 3/1 | 104/78 |
| 4 | 0.699 | 0.552 | 119/93 | 89/78 |
| 5 | 0.492 | 0.411 | 27/5 | 75/56 |
| 6 | 1.011 | 0.771 | 4/2 | 4/2 |

Mean wall-clock: cold 0.747 s, warm 0.587 s (warm faster on 6/6 seeds, ~21%
mean reduction). Total fn+gr evaluations: cold 512, warm 870 (warm did
*more* evaluations in most seeds but still finished faster — a strong
tell that this is not just "fewer iterations"). Because the per-seed order
was always cold-then-warm, I checked for an order confound directly:
re-ran seeds 1-2 twice, once cold-first and once warm-first (`dev/warmstart-order-check.R`).

| seed | order | first fit time | second fit time |
|---|---|---|---|
| 1 | cold→warm | cold 0.779 s | warm 0.666 s |
| 1 | warm→cold | warm 0.662 s | cold 0.783 s |
| 2 | cold→warm | cold 0.591 s | warm 0.529 s |
| 2 | warm→cold | warm 0.519 s | cold 0.566 s |

Warm is faster **regardless of call order** — this is not a
first-call/session-warmup artifact. The timing benefit is real on this
fixture, even though the ELBO/Sigma_B accuracy is not (§1-3).

## 5. Poisson still works (n=40, T=8, q=2, seed=7)

`.approximation_engine_fit(engine = "va_r3", ..., family = "poisson", link =
"log", H = 15L)` on the reconstructed fixture:

- **status:** `failed_health_gate`
- **ELBO:** −550.6616 (`negative_elbo_gh = 550.6616`)
- **healthy starts:** 1/4 (start 4 healthy: conv 0, max|grad| 8.5e-05;
  starts 1-3 conv 0 but max|grad| in 1.1e-4 to 5.0e-4, just above the 1e-4
  gate)
- **max projected variance:** 1.21 (within the 4.0 domain limit — the
  gate failure is the gradient tolerance, not the variance-domain check)

I re-ran the identical fixture through the **pre-edit** code (via `git
stash` on `R/va-r3-proto.R` only, then restored) as a direct before/after
comparison: the pre-edit (cold) pipeline gives the **exact same** ELBO
(−550.6616) with 0/4 healthy starts. So on this specific reconstructed
fixture, both old and new code converge to the identical stationary point;
the warm start changed the health-gate count from 0/4 to 1/4 (one start's
gradient now clears 1e-4) but did not change the reported ELBO or reach the
required ≥3-healthy threshold either way. It "still works" in the sense that
Poisson produces a finite, deterministic, reproducible result under the new
code — but the family stays marginal on this fixture, not newly healthy.

I could not reproduce the handoff's stated `-530.5412` for a "seed=7"
Poisson fixture with either the old or the new code, using this
reconstruction of the generator — see the fixture note above. The number
"legitimately moved" is honest but I cannot confirm it moved *from
-530.5412 specifically*, only that this reconstructed fixture's answer
(-550.6616) is identical under old and new code, and that Poisson does not
error or return non-finite results under the new warm-start path.

## Bottom line

- The warm start is implemented as specified: data-driven, correctly
  rotated into the packer's contract, verified round-trip-exact, with a
  working degenerate fallback, and the 4-start jitter structure preserved
  (start 1 warm; starts 2-4 warm+jitter, still genuinely re-checked for
  agreement — confirmed on a live 4-start run: 4/4 healthy, agreement range
  1.5e-8).
- **It does not raise the achieved ELBO or improve Sigma_B recovery** on
  the fixture tested here — cold and warm converge to the same basin to
  within optimizer tolerance. The framing "a higher ELBO proves the cold
  start was converging to a worse optimum" does not hold on this evidence;
  there is no sign of two different local optima being distinguished by the
  start.
- **It is reproducibly faster** (~21% mean wall-clock, order-checked) on
  this fixture, without changing the answer.
- **The raw (unoptimized) eigen estimate is closer to truth than the
  converged fit on 5/6 seeds** — this reproduces the qualitative shape of
  the originally-reported defect and is the more important finding: the
  gap between "3-line eigen decomposition" and "our fit" is not primarily a
  bad-starting-value problem, since starting at the good value and
  optimizing to convergence still lands at the worse point. Fixing that
  requires looking at the objective/optimizer, not only the initial
  condition — outside this task's scope.

## Files

- Edited: `/private/tmp/gllvmtmb-va-wiring-20260726/R/va-r3-proto.R`
  (`.va_r3_default_parameters()`, plus new `.va_r3_rotate_to_lower_triangular()`
  and `.va_r3_warm_theta_rr()`).
- Verification scripts (dev/, not touching R/): `dev/warmstart-verify.R`,
  `dev/warmstart-order-check.R`. Raw per-seed results:
  `dev/warmstart-bernoulli-results.rds`.
