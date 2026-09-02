# Symbolic alignment: zero-inflated families (Arc D)

Per `symbolic-alignment` discipline: this table is the contract the C++/R
code below must match term-by-term. Decisions 1-8 in the task brief are
already made and are not re-litigated here.

## Shared structure

All three families are a two-component MIXTURE (not a hurdle): the count
process is active at every observation, including `y = 0`.

| Symbol | Meaning | R name | TMB name | Link |
|---|---|---|---|---|
| $\pi_t$ | structural zero-generating probability, trait $t$ | `zi` (report) | `logit_zi(t)` (`PARAMETER_VECTOR`, length `n_traits`) | logit; `zi = invlogit(logit_zi)` |
| $\mu_{it}$ | count-process mean at row $i$, trait $t$ | (unchanged) | `eta_o` -> `exp(eta_o)` (poisson/nbinom2) or `invlogit(eta_o)` (binomial) | log (poisson/nbinom2); logit (binomial) |
| $\phi_t$ | NB2 overdispersion, trait $t$ (zi_nbinom2 only) | `phi_nbinom2` (report) | `log_phi_nbinom2(t)` (REUSED, not a new vector) | log |
| $N_i$ | trial count, row $i$ (zi_binomial only) | `n_trials` | `n_trials(o)` (existing DATA vector) | n/a |

Zero-part is per-trait intercept-only: NO covariates, NO random effects, NO
per-observation richness (Decision 2). This is a deliberate divergence from
drmTMB's `eta_zi = X_zi %*% beta_zi` (recon section D) and matches the
Julia oracle's `Λ_z = 0` v1 scope (recon section C).

## Density (mixture-at-zero form)

For all three families, with $F_c(\cdot)$ the ordinary (non-inflated) count
CDF and $f_c(\cdot)$ its pmf:

$$
P(Y_{it} = 0) = \pi_t + (1-\pi_t) f_c(0 \mid \mu_{it}, \ldots)
$$
$$
P(Y_{it} = k) = (1-\pi_t) f_c(k \mid \mu_{it}, \ldots), \quad k \ge 1
$$

and consequently the mixture CDF has the closed form used by the
randomized-quantile residual (Design: matches drmTMB's `logspace_add` idiom
exactly, recon section D):

$$
F_{\text{mix}}(y) = \pi_t + (1-\pi_t) F_c(y), \quad y \ge 0.
$$

### zi_poisson (family_id 17)

$$
\log P(Y=0) = \text{logspace\_add}\big(\log \pi_t,\; \log(1-\pi_t) - \mu_{it}\big)
$$
$$
\log P(Y=k>0) = \log(1-\pi_t) + \log \text{dpois}(k, \mu_{it})
$$

No dispersion parameter. `mu = exp(eta_o)`.

### zi_nbinom2 (family_id 18)

Reuses `log_phi_nbinom2(t)` (Decision 4 -- a deliberate departure from the
Julia oracle's single shared scalar `r`, per open question 2, answered:
per-trait, matching gllvmTMB's existing nbinom2 convention everywhere else).

$$
\log P(Y=0) = \text{logspace\_add}\big(\log \pi_t,\; \log(1-\pi_t) + \log f_{\text{NB2}}(0 \mid \mu_{it}, \phi_t)\big)
$$
$$
\log P(Y=k>0) = \log(1-\pi_t) + \log f_{\text{NB2}}(k \mid \mu_{it}, \phi_t)
$$

using the same `dnbinom_robust(y, log_mu, log_v_minus_mu, true)` kernel the
plain `nbinom2` branch (fid 5) already uses, with
`log_v_minus_mu = 2*log_mu - log_phi_nbinom2(t)`.

### zi_binomial (family_id 19)

$$
\log P(Y=0) = \text{logspace\_add}\big(\log \pi_t,\; \log(1-\pi_t) + N_i \log(1-p_{it})\big)
$$
$$
\log P(Y=k>0) = \log(1-\pi_t) + \log \text{dbinom}(k, N_i, p_{it})
$$

`p_it = invlogit(eta_o)` (logit link only, matching plain `binomial()`'s
default; no probit/cloglog route for the zero-inflated count part in v1 --
not requested, keeps the fence simple).

**Identifiability note (Decision 6).** With $N_i = 1$ (Bernoulli /
single-trial 0-1 data), $P(Y=1) = (1-\pi_t) p_{it}$ collapses $\pi_t$ and
$p_{it}$ into one free product -- the model is not identified from the
marginal alone (both parameters trade off along a ridge with no curvature
in $\pi_t$ separately). `zi_binomial()` is therefore refused unless the
response carries trials with **at least one row per trait having trials
$\ge 2$** (checked at parse time in `R/fit-multi.R`, mirroring the
zero-truncated-count input-validation pattern at `R/fit-multi.R:3753-3755`
noted in the recon). The refusal names plain `binomial()` as the working
alternative, per the task brief.

## Where it enters (recon open question 4, answered)

This is NOT the delta/hurdle (fid 12/13) shared-eta architecture. The count
process's score/Fisher information is nonzero at $y=0$ (a `y=0` row still
carries a $\partial \mu_{it}/\partial \eta$ term through the mixture), unlike
a hurdle where the positive-part likelihood is simply absent for $y=0$ rows.
Implementation: a fresh `else if (fid == 17/18/19)` block in `obs_loglik`
(the shared per-row density lambda used by both the plain Laplace loop and
the AGHQ per-node loop), NOT a reuse of the fid 12/13 branches.

## Fitted-response / variance rules

- `fitted_response_rule`: $E[Y_{it}] = (1-\pi_t)\mu_{it}$ (Decision 5).
- `variance_rule`:
  - zi_poisson: $\text{Var}(Y) = (1-\pi)\mu[1 + \pi\mu]$
  - zi_nbinom2: $\text{Var}(Y) = (1-\pi)\mu\left[1 + \mu\left(\pi + \frac{1}{\phi}\right)\right]$
  - zi_binomial: $\text{Var}(Y) = (1-\pi)Np[1-(1-\pi)Np/N + \pi N p]$ i.e.
    $(1-\pi)N p (1 - p) + \pi(1-\pi)(Np)^2$ (standard ZI-variance
    decomposition $\text{Var} = (1-\pi)\text{Var}_c + \pi(1-\pi)\mu_c^2$
    applied to each count kernel's own $\text{Var}_c$/$\mu_c$).

## Simulator draw

`rzero_inflated(n, pi, ...)`: draw `z ~ Bernoulli(1 - pi)` (z=1 -> count
process fires); if `z == 0`, `y = 0`; else `y ~ Poisson(mu)` /
`NegBinom(mu, phi)` / `Binomial(N, p)` respectively. This is the standard ZI
simulation identity and matches the mixture density above by construction.

## Naming (recon open question 4)

`zi_poisson()`, `zi_nbinom2()`, `zi_binomial()` -- confirmed, not
`zip()`/`zinb()`/`zib()`. Julia's `ZIPoisson`/`ZINB`/`ZIB` and drmTMB's
`model_type` strings `"zi_poisson"`/`"zi_nbinom2"` are recorded as capability-
ledger aliases only (`dev/gapclose/build-capability-status.R`), never as R
exports.

## Recon open questions -- resolution log

1. **Zero-probability parameterisation richness.** RESOLVED per-trait
   intercept-only (Decision 2 in the task brief). Matches the Julia oracle's
   v1 scope; explicitly narrower than drmTMB's per-observation `X_zi %*%
   beta_zi`.
2. **NB2 dispersion scale.** RESOLVED: reuse `log_phi_nbinom2` per-trait
   (Decision 4), a deliberate divergence from Julia's shared scalar `r`.
3. **14-slot contract has no `zi` slot.** RESOLVED at the doc layer: Design
   02's "Distributional parameter naming" section (L125-141, already in the
   repo before this arc) already lists `zi` as a named `dpars` entry with
   logit link -- so no registry-contract change was needed, only using it.
4. **Naming discipline.** RESOLVED: `zi_poisson()`/`zi_nbinom2()`/
   `zi_binomial()`, matching Design 62's reservation of the `zi_*` prefix.
5. **Smallest nbinom2 recovery test.** Found:
   `tests/testthat/test-betabinomial-recovery.R` (closest structural analogue
   -- per-trait dispersion + rank-1 latent + `cbind()` trials) is used as the
   direct template for `test-zi-recovery.R`.
6. **`simulate.gllvmTMB_multi()` per-family RNG dispatch.** Located:
   `R/methods-gllvmTMB.R:.draw_y_per_family()` (~line 1555), a per-row
   `if (fid == ...)` chain; fid 17/18/19 branches added there.
7. **Per-family opt-in gating lists.** All four locations named in the
   recon (`R/diagnose.R`, `R/predictive-diagnostics.R`,
   `R/dispersion-trait-map.R` usage in `R/fit-multi.R`, the
   `family_to_id()` error enumeration) are updated in this arc; see
   `dev/gapclose/arcD/D1-report.md` for the exact line ranges touched.
