# Bernoulli in the Design-85 VA prototype — guard lifted, ELBO measured against truth

**Date:** 2026-07-25
**Branch:** `claude/va-implementation-20260725` (worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-va-impl`)
**Script:** `dev/va-bernoulli.R` (scratch, not a test file)
**Verdict:** **IMPLEMENTED.** `n_trials = 1` is now admitted. The ELBO is a
valid and tight lower bound on the brute-force TRUE marginal log-likelihood at
Bernoulli, and at the same parameter point it is **19.5× closer to truth than
Laplace**.

Nothing here is exported, tested, advertised, or promoted. No `NAMESPACE`,
`DESCRIPTION`, or `tests/` file was touched.

---

## 1. Why the guard was lifted — and the one thing that would have stopped it

The task's decision rule was: do **not** implement if the guard exists for a
mathematical reason, or if GH quadrature is inadequate at `n_trials = 1`, or if
the brute-force ground truth does not stabilise for Bernoulli. All three came
back negative.

**(a) The guard was a scope choice, and the corpus says so in its own words.**
Design 85's data contract
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:57-66`) lists
"single-trial Bernoulli rows" among excluded shapes with no justifying clause,
alongside response masks, offsets, and fractional successes. The frozen
implementation map
(`docs/dev-log/research/2026-07-20-va-r3-symbolic-implementation-map.md:42-43`)
lists "trial counts below two" beside pure scope-freeze exclusions such as rank
bounds and missing-cell bans. The same document, at lines 26-27, names the
mechanism outright:

> "Sparse binary at high `q` lies OUTSIDE Design 85's admitted data contract
> (**Bernoulli excluded by analogy**; projected-variance fail-closed at 4)."

"Excluded by analogy" is the corpus's own characterisation. No document in
Design 85, the symbolic map, the two NO-GO reports, or Design 86 records a
numerical, algebraic, or identifiability mechanism by which the R3 ELBO fails
at `n_it = 1`. Design 86 routes around the guard with a different estimator
(EVA) rather than revisiting it, which is why it was never re-examined.

**(b) Gauss-Hermite accuracy is independent of `n_trials` by construction.**
`n_trials` never enters `va_r3_softplus_expectation()`
(`inst/tmb/gllvmTMB_va_r3.cpp:45-79`). The quadrature integrates
`softplus(mu + sqrt(v) Z)` against `q(u_i)`; `n` only multiplies the resulting
scalar in `ell = log_choose + y*mu - n*softplus_expectation`
(`inst/tmb/gllvmTMB_va_r3.cpp:288`). Holding `(mu, v)` fixed and varying
`n_trials` in `{1, 2, 5, 12}` leaves the softplus-term error identical to
machine precision. At H=61, worst relative error across the tested
`mu × v(≤9) × n_trials` grid was 5.8e-8, checked against `integrate()` and
statmod's independent GH rule (which agree with each other to 1e-15). The
premise that Bernoulli "sharpens the integrand" is false for this
parameterisation — the integrand never contains `n` at all.

**(c) `log C(n, y)` is degenerate but finite at `n = 1`.**
`lgamma(2) - lgamma(y+1) - lgamma(2-y)` is exactly `0` for `y ∈ {0, 1}`
(verified numerically, and again inside `dev/va-bernoulli.R` by a
`stopifnot(max(abs(log_choose_vec)) < 1e-12)`). This term is not a failure
point.

**(d) The verification instrument survives.** The brute-force per-unit 2-D
product Gauss-Hermite marginal likelihood — the route the entire VA
verification programme rests on — converges *more* cleanly at Bernoulli than it
did at `n_trials = 12`: the H-ladder is fixed to ~3e-11 from H=61 onward (see
§4), versus a ~1.5e-4 wobble at H=21 in the binomial bisection.

**The one thing that would have stopped this and did not: separation.** Design
85's Gate 2 and Gate 3 both restrict their claims to "otherwise healthy,
**non-separated** replicates"
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:405, 417-420`), but
`grep -n -i "separat"` over `R/va-r3-proto.R` and `inst/tmb/gllvmTMB_va_r3.cpp`
found **no separation handling of any kind** — the only rank check is
`qr(X)$rank != ncol(X)`, which catches exact collinearity, not separation.
`dev/VA-TRAP-MAP.md:682-684` names separation as a mechanism a sibling
prototype could not exclude. At `n_trials ≥ 2` the aggregate counts damp the
pull to the boundary; at `n_trials = 1` the responses are pure 0/1, which is
exactly where a separated design sends `beta` to infinity while every
finite-precision health check still reports success. So a guard was written
(§3) rather than the block being lifted bare.

## 2. What changed

Two files, 74 insertions / 4 deletions.

**`R/va-r3-proto.R`**

- `.va_r3_validate_data()`: `any(n_trials < 2L)` → `any(n_trials < 1L)`, with
  the message updated to `n_trials >= 1`, plus a comment recording that the old
  bound was a scope freeze and why the objective is well-defined at `n = 1`.
- One call added to the new `.va_r3_check_separation()` on the binomial branch.
- New unexported helper `.va_r3_check_separation(y, n_trials, X)` (§3).

**`inst/tmb/gllvmTMB_va_r3.cpp`**

- `if (nd < 2.0 || ...)` → `if (nd < 1.0 || ...)`, message updated to
  `integer n >= 1`, with a comment recording that `n` only multiplies the
  softplus expectation and enters `log C(n, y)`, which is zero at `n = 1`.

Nothing else. The Gaussian-anchor branch, the quadrature, the KL term, the
four-start health gate, the `max projected variance <= 4` domain gate, and the
default empirical-logit starts are all untouched.

## 3. The separation guard

`.va_r3_check_separation()` refuses, with a typed error, before any objective
is constructed. Detection is by **divergence, not by a bare magnitude
threshold**: the marginal logistic regression `y ~ X - 1` is fitted twice, once
at `epsilon = 1e-8, maxit = 25` and once at `epsilon = 1e-12, maxit = 200`. A
finite MLE lands on the same coordinate both times; a separated one keeps
walking outward, because where it stops is set by the tolerance rather than by
the data. Refusal triggers when `max|eta|` drifts by more than 1 between the
two runs, or when either fit is non-finite, or (backstop) when `max|eta|`
exceeds 15.

Measured behaviour on the fixture below:

| design | `max\|eta\|` @1e-8 | @1e-12 | drift | outcome |
|---|---:|---:|---:|---|
| unmodified Bernoulli fixture | 0.5465 | 0.5465 | 0.0000 | **accepted** |
| trait 1 forced all-zero | 18.5661 | 27.5661 | 9.0000 | **refused** |
| trait 1 forced all-one | 18.5661 | 27.5661 | 9.0000 | **refused** |
| trait 1 = 1 success in 60 (extreme, finite MLE) | 4.0775 | 4.0775 | 0.0000 | **accepted** |
| first-light `n_trials = 12` fixture | 0.4359 | 0.4359 | 0.0000 | **accepted** |
| perfect single predictor column | 26.5661 | 31.5664 | 5.0003 | **refused** |

A bare magnitude threshold would have failed here: `glm.fit`'s deviance-epsilon
stopping rule reports `converged = TRUE` at `|eta| = 18.57` on the separated
design, so the first version of this guard (limit 30, single fit) did **not**
fire. That miss is recorded rather than quietly fixed.

**Scope of the guard, stated plainly.** It reads the **marginal** design only.
It is a sound refusal for complete and quasi-complete separation induced by the
fixed-effect design — the case these fixtures can actually produce — and it
makes **no claim** about the joint `(beta, Lambda, m, L)` surface. It is
deliberately conservative; an extreme but genuinely finite design can trip it,
and refusing is the intended outcome in that case.

## 4. The Bernoulli run

Fixture: `seed = 20260725`, `N = 60` units × `T = 5` traits, `q = 2`, complete
grid (300 cells), `n_trials = 1`, `y` split 165 zeros / 135 ones. Ordinary
loadings-only `latent(0 + trait | unit, d = 2, unique = FALSE)`, binomial
logit. This is the identical construction the ground-truth probe used, so the
truth numbers are independently reproducible.

**VA fit:** `status = healthy`, 4 of 4 starts healthy, best-three objective
range 1.3e-09, `max projected variance = 2.98` (inside the prototype's own
limit of 4 — an open risk that did not bite), 20.6 s including the one-time
TMB compile. `H = 61`.

**Brute-force truth, H-ladder** (per-unit 2-D product Gauss-Hermite,
log-sum-exp):

| H | truth at `theta_VA` | truth at `theta_Laplace` |
|---:|---:|---:|
| 31 | -195.933534685637 | -196.802514582507 |
| 61 | -195.933545708826 | -196.802514788802 |
| 101 | -195.933545713995 | -196.802514788773 |
| 151 | -195.933545713961 | -196.802514788773 |
| spread over {61,101,151} | 5.2e-09 | 2.9e-11 |

Stable. The `theta_Laplace` column reproduces the independent ground-truth
probe's value to all printed digits.

### Scoreboard

| quantity | value |
|---|---:|
| TRUTH at `theta_VA` | **-195.9335457140** |
| ELBO at `theta_VA` | **-196.2631880207** |
| **ELBO − TRUTH (same theta)** | **-0.3296423067** |
| TRUTH at `theta_Laplace` | **-196.8025147888** |
| gllvmTMB Laplace at `theta_Laplace` | **-198.1977358340** |
| **LAPLACE − TRUTH (same theta)** | **-1.3952210452** |
| ELBO at `theta_Laplace` (fixed-global) | **-196.8739433338** |
| **ELBO − TRUTH (same theta)** | **-0.0714285450** |

### What the numbers say

1. **The ELBO is a valid lower bound at Bernoulli.** Both gaps to truth are
   negative (-0.3296 at `theta_VA`, -0.0714 at `theta_Laplace`). No sign
   violation, no bound violation.

2. **At the identical parameter point, the ELBO beats Laplace by 19.5×.**
   Evaluated at `theta_Laplace`, the ELBO sits 0.0714 nats below truth while
   the Laplace approximation sits 1.3952 nats below it. This is the
   apples-to-apples comparison — same theta, same data, both measured against
   the same brute-force integral, neither used as the other's yardstick.

3. **Laplace's error is worse at Bernoulli than at `n_trials = 12`.** 1.395
   nats here versus ~1.12 nats on the binomial fixture in
   `dev/va-elbo-bisection-RESULTS.md`. The direction is what the VA motivation
   predicts: less per-cell information, worse curvature approximation.

4. **The VA optimum reaches a genuinely better parameter point.** True
   log-likelihood is 0.869 nats *higher* at `theta_VA` (-195.934) than at
   `theta_Laplace` (-196.803), by the same brute-force integral. Laplace's
   optimum is not the true MLE on this fixture and the VA's is closer to it.
   Note the tension with (2): the ELBO's own gap to truth is *larger* at
   `theta_VA` (0.330) than at `theta_Laplace` (0.071), because the VA optimum
   sits at a larger-`Lambda` point where the variational bias is bigger. Both
   things are true; neither is contradicted.

5. **Zero warnings.** `grep -i "warning\|error"` over the full run log matches
   only the compiler's own `-DTMB_EIGEN_DISABLE_WARNINGS` flag string. One
   incidental `NaNs produced` in `stats::qlogis` appears in the separate
   adversarial regression script when hand-mutated invalid data (`y = 2`,
   `n = 1`) is pushed past the R validator to test the C++ guard directly; that
   is an artefact of the deliberately-malformed test input, not of any live
   path.

## 5. Regression checks

- `n_trials = 12` end-to-end fit (N=40, T=5, q=2): `status = healthy`,
  ELBO -440.8870169755, 3 of 4 starts healthy. The previously-verified path
  still runs.
- C++ template still refuses `n = 0` and `y > n` when the R validator is
  bypassed: *"gllvmTMB_va_r3: binomial cells require integer n >= 1 and
  0 <= y <= n"*.
- R validator still refuses `n_trials = 0`.
- `family = "gaussian_anchor"` branch untouched: `status = healthy`,
  ELBO -207.4996730304.

## 6. What this does NOT cover

- **One seed, one fixture, one `(N, T, q)` cell.** No replication, no multi-seed
  evidence, no coverage or recovery claim, no bias/RMSE against a known DGP.
  Design 85's Gate 3 is untouched by this run.
- **No `Psi`/`unique = TRUE`, structured, provider, `lv`, or missing-data
  route.** All still rejected.
- **Sparse binary is not demonstrated.** This fixture is balanced (135/300 ≈
  0.45). Design 86's admission band is `p̄ ∈ [0.03, 0.10]`, and nothing here
  says the projected variance stays inside the prototype's `<= 4` gate at that
  sparsity — it merely did not bite at `p̄ ≈ 0.45`, where it reached 2.98.
- **The separation guard is marginal-only** (§3). Latent-side degeneracy is not
  detected.
- **`q > 2` is untested here.** The brute-force truth used above is a 2-D
  product rule and does not extend cheaply past `q = 2`; at higher `q` the
  verification instrument itself would need replacing.
- **No statement about EVA or Design 86.** This is Design 85's Gauss-Hermite VA
  at `n_trials = 1`, nothing more.

## 7. Files

- `R/va-r3-proto.R` — guard relaxed, `.va_r3_check_separation()` added.
- `inst/tmb/gllvmTMB_va_r3.cpp` — `n >= 2` → `n >= 1`.
- `dev/va-bernoulli.R` — the driver (scratch).
- `dev/va-bernoulli-RESULTS.md` — this file.

Scratch artefacts (not committed):
`/private/tmp/claude-503/.../scratchpad/va-bernoulli.log`,
`va-bernoulli-results.rds`, `va-bern-regress.R`.
