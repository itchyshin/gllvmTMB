# VA ELBO bisection — is the R3 prototype's ELBO actually wrong?

**Date:** 2026-07-25
**Branch:** `claude/va-implementation-20260725` (worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-va-impl`)
**Scripts (scratch, not tests):**
`/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad/va-elbo-bisect{,2,3}.R`
**Input:** the fixture and saved fit from `dev/va-first-light.R` /
`dev/va-first-light-RESULTS.md` (same seed `20260725`, same N=80×T=6 binomial
`n_trials=12`, `q=2`, ordinary loadings-only `latent(unique=FALSE)`/`rr()`
fixture). No new DGP was drawn; this bisects the existing recorded run.

## Verdict up front

**Neither term is wrong.** The KL term and the expected-log-likelihood
(Gauss-Hermite) term were both independently re-derived and matched the
template to machine precision. The reported "ELBO sits above Laplace" finding
is a **comparison artefact**: at the same fixed global parameters, an
independent brute-force 2-D quadrature of the true marginal log-likelihood
shows that it is **Laplace's own logLik that is biased low here by
~1.12 nats**, not the ELBO that is too high. The ELBO is in fact a valid,
tight lower bound on the true marginal log-likelihood at both the VA's own
optimum (gap −0.153) and at Laplace's optimum (gap −0.148). No code was
edited.

## 1. Apples-to-apples check

Already established by the prior run (`dev/va-first-light-RESULTS.md` §1, §4):
gllvmTMB's own Laplace fit (`latent(0+trait|unit, d=2, unique=FALSE)`) and
`glmmTMB::rr(0+trait|unit, d=2)`'s Laplace fit agree to `5e-9`
(`gap_model = -0.0000000053`) on the identical formula, data, family
(binomial, `n_trials=12`), and structure (loadings-only, no Psi) that the VA
prototype itself uses. This rules out a model-mismatch artefact: the
comparison is genuinely apples-to-apples on structure, family, `q`, and data.
Re-verified here, not re-derived.

## 2. KL term check

Closed form: `KL(N(m,LL') || N(0,I_q)) = 0.5*(tr(LL') + m'm - q - logdet(LL'))`.

Extracted `m` (N×q) and `L_flat` (N×q², the per-unit Cholesky factor as
reported by the template) from the saved healthy fit
(`va_fit$report$m`, `va_fit$report$L_flat`, `va_fit$report$kl_by_unit`), then
recomputed `S_i = L_i L_i'`, `tr(S_i)`, `m_i'm_i`, `logdet(S_i)`
(`determinant(Si, logarithm=TRUE)`) and the KL formula **in plain R**, per
unit, independently of the template's C++ arithmetic:

```
KL check: max abs diff (hand vs template) across all 80 units: 4.440892e-16
sum(kl_hand)  = 106.5080304200
total_kl (template) = 106.5080304200
```

Exact match to double-precision floor. **The KL term (`inst/tmb/gllvmTMB_va_r3.cpp:208-220`)
is correct** — no dropped 1/2, no sign error, no `log det(L)` vs `log det(LL')`
confusion, no `-q` omission.

## 3. Expected log-likelihood term check

For each observation, `mu_by_obs` and `v_by_obs` (the projected mean and
variance `v_it = ||L_i' lambda_t||^2`) were extracted from the report, and
`E_q[softplus(eta)]` was independently recomputed two ways for 9 spot-checked
observations spanning the full range of `mu`/`v` in the fixture:

- **Monte Carlo**, 5,000,000 draws of `eta ~ N(mu, v)` per observation.
- **Independent reference Gauss-Hermite**, `statmod::gauss.quad.prob(H=401, dist="normal")`
  — a different R implementation of Gauss-Hermite from the template's own
  hand-rolled Golub–Welsch construction.

```
obs | mu       | v      | template  | MC(5e6)   | GHref(401) | tmpl-MC   | tmpl-GHref
  1 | -0.2727  | 0.1867 | 0.58850963| 0.58857245| 0.58850963 | -6.28e-05 | -8.9e-16
  2 | -0.2351  | 0.2440 | 0.61175875| 0.61188565| 0.61175875 | -1.27e-04 | -1.9e-15
  3 | -0.1913  | 0.0457 | 0.60771187| 0.60766540| 0.60771187 | +4.65e-05 | -8.9e-16
 50 | -0.8560  | 0.2691 | 0.38174291| 0.38171836| 0.38174291 | +2.45e-05 | -1.1e-15
100 | -0.1424  | 0.0212 | 0.62709750| 0.62708922| 0.62709750 | +8.28e-06 | -6.7e-16
200 | -0.9881  | 0.2774 | 0.34352344| 0.34357224| 0.34352344 | -4.88e-05 | -1.1e-15
300 |  0.1364  | 0.0248 | 0.76674920| 0.76679782| 0.76674920 | -4.86e-05 | -1.3e-15
400 |  0.0073  | 0.0172 | 0.69892626| 0.69895939| 0.69892626 | -3.31e-05 | -2.2e-16
480 | -0.2090  | 0.0324 | 0.59809196| 0.59806534| 0.59809196 | +2.66e-05 | -3.3e-16
```

Template matches the independent 401-node GH reference to **machine
precision** (`~1e-15`-`~1e-16`) at every spot-check, and matches Monte Carlo
to within its own `~1e-4` statistical noise floor. **The template's H=61
physicists'-convention quadrature, softplus expansion, and small-`v`
heat-kernel branch (`inst/tmb/gllvmTMB_va_r3.cpp:37-79`) are all correct** —
no physicists'/probabilists' convention error, no missing `sqrt(2)`/`1/sqrt(pi)`
scaling, no binomial-coefficient error. `expected_loglik` assembly
(`log_choose + y*mu - n*softplus_expectation`) is exact by construction since
`E[eta] = mu` and `Var[eta] = v` hold exactly for a Gaussian `q`.

## 4. Attribution — the real explanation

Both terms check out and the assembly (`expected_loglik - total_kl`,
`inst/tmb/gllvmTMB_va_r3.cpp:299-302`) reproduces `elbo` to `1e-10`. So the
mathematics inside the template is not the problem. The remaining candidate
per the task brief is: **the Laplace comparison itself is off.**

This was tested directly, not just argued. A variational bound is only
guaranteed to satisfy `ELBO(theta) <= log p(y; theta)` **at the same fixed
global parameters** `theta = (beta, Lambda)` — it says nothing about
`ELBO(theta_VA) <= logLik_Laplace(theta_Laplace)` when the two methods
optimize to *different* points and the reference method (Laplace) is itself
only an approximation, not the exact integral.

**Experiment.** Refit gllvmTMB's Laplace route fresh in this worktree on the
same fixture, extract its converged `(beta_hat, Lambda_hat)`
(`b_fix`/`Lambda_B` from `fit_gt$opt$par`/`fit_gt$report`), then:

- **(a)** Re-optimize the VA prototype's variational parameters only (`m`,
  `log_L_diag`, `L_off`), with `beta`/`theta_rr` mapped/fixed at Laplace's own
  `(beta_hat, Lambda_hat)` via `.va_r3_make_objective(..., fixed_global=...)`
  (already-supported machinery, unmodified) — giving `ELBO` at Laplace's exact
  point.
- **(b)** Independently compute the **true** `log p(y; beta_hat, Lambda_hat)`
  by brute-force per-unit 2-D (q=2) product Gauss-Hermite quadrature in plain
  R (`statmod::gauss.quad(H, kind="hermite")`, log-sum-exp stabilized),
  entirely outside both TMB and the VA machinery. Checked for quadrature-order
  convergence: `H=21` gives `-1014.8250842481`; `H=31/45/61/81/101` all agree
  to `-1014.8252377...` (stable to `1e-9`) — this is a numerically exact
  reference, not an approximation artefact of its own.

```
gllvmTMB Laplace logLik at (beta_hat, Lambda_hat):        -1015.9431193939
ELBO at the SAME (beta_hat, Lambda_hat) [VA, fixed_global]: -1014.9734014818
Brute-force TRUE log p(y; beta_hat, Lambda_hat) [H=61-101]: -1014.8252377883

Laplace approximation ERROR at its own optimum (Laplace - TRUE): -1.1178816041
ELBO - TRUE at the SAME theta (must be <= 0):                    -0.1481636920
```

**Laplace underestimates the true marginal log-likelihood by ~1.12 nats at
its own optimum on this cell.** The VA's ELBO, evaluated at that identical
`theta`, is a valid and much tighter lower bound (gap 0.148 nats). This was
cross-checked a second way, at the VA's own joint optimum
(`beta_VA, Lambda_VA` unpacked from `va_fit$best$par`, `theta_rr` via
`.va_r3_unpack_theta_rr`):

```
TRUE log p(y; beta_VA, Lambda_VA)  [H=61, H=81 agree to 1e-9]: -1014.8142091652
VA ELBO at its OWN joint optimum:                              -1014.9671261098
ELBO - TRUE (must be <= 0):                                    -0.1529169446
```

Same picture: the VA's ELBO is a valid, tight (~0.15 nat) lower bound on the
*true* marginal log-likelihood at both parameter points tested. It is
Laplace's own reported logLik, not the ELBO, that sits far (~1.1 nat) from
the truth here. `glmmTMB::rr()`'s Laplace agreeing with gllvmTMB's Laplace to
`5e-9` only shows the two implementations share the *same* Laplace
approximation error — it does not certify that Laplace is close to the exact
integral, and per-unit information here is modest (`n_trials=12` binomial
trials informing a `q=2`-dimensional per-unit random effect), which is exactly
the regime where second-order Laplace bias of this size is plausible.

**Conclusion:** the original "`ELBO (-1014.967) > Laplace (-1015.943)`,
therefore RED FLAG" reasoning in `dev/va-first-light-RESULTS.md` rested on
treating Laplace's logLik as a reliable proxy for the true log p(y). That
premise is false on this cell: Laplace itself is biased low here by more than
a full nat, and once compared against an independent brute-force ground truth
instead, the ELBO's own inequality holds cleanly and with a comfortably tight
margin. `gllvm`'s own VA sitting 5.21 nats below Laplace does not rescue the
premise either — it says nothing about how close Laplace sits to the truth,
only that `gllvm`'s (differently structured/optimized) VA bound is looser
than ours on this cell.

## 5. Edits made

**None.** `R/va-r3-proto.R` and `inst/tmb/gllvmTMB_va_r3.cpp` are unchanged.
No bug was located to fix; both terms were independently verified correct,
and the apparent bound violation was fully explained as a Laplace-approximation
artefact, not an ELBO defect.

## 6. Warnings, verbatim

No runtime warnings were raised by any script in this bisection (gllvmTMB
Laplace refit, the fixed-`theta` VA re-optimization, or the brute-force
quadrature scripts). `grep -i warning` over the captured logs
(`va-elbo-bisect2.log`) matches only the compiler flag literal
`-DTMB_EIGEN_DISABLE_WARNINGS` in the one-time `clang++` compile invocation —
a build define, not a warning, identical to what the prior
`dev/va-first-light-RESULTS.md` run found. The one-time package startup
banner ("gllvmTMB is EXPERIMENTAL...") is the package's own lifecycle notice,
not a warning.

## 7. What this changes about the prior verdict

`dev/va-first-light-RESULTS.md` §9 concluded "OBJECTIVE-SUSPECT" based on the
sign/magnitude of `ELBO - Laplace`. That comparison-based verdict should be
revised: **the objective itself checks out term-by-term against independent
references, and the bound holds at both fixed points tested.** This does not
by itself certify the VA prototype as production-ready (the earlier NO-GO's
procedural concerns — rank-selection hand-off, replicate health-gate failures
at 8/50 — are untouched by this bisection, and only 2 fixed `theta` points on
one seed/cell were probed here, not a full recovery study). But the specific
"ELBO must be below Laplace" falsification is retracted: it was a comparison
artefact, not a defect in the KL term, the quadrature term, or their assembly.
