# Design 110 — VA(GH) H = 7 across all scalar response families

**Status:** Gate E PASS, 18/18 scalar cells, 2026-08-06. Arc 1 implemented and
light-tested the scalar family surface; the public H = 7/GH promotion is now
authorised but is recorded separately from the arithmetic verdict. Arc 2 is
authorised after the public/light closeout but has not been launched. This
contract does not admit multinomial or any other non-scalar
likelihood, does not make an accuracy claim for `H = 7`, and does not make an
ELBO usable as `logLik`, AIC, BIC, or an LRT.

**Supersession boundary.** Designs 104–105 provide the density derivations and
Design 108 provides the wider parity programme. This document fixes the narrower
implementation decision now authorised by the maintainer: the VA template uses
the same `family_id` (0–15) and `link_id` values as the Laplace template, uses an
exact expectation whenever one exists, and otherwise uses ordinary one-dimensional
Gauss–Hermite quadrature with `H = 7` as the candidate default. The old VA-only
codes (`3 = NB2`, `4 = binomial-probit`) are retired inside the implementation;
the public family/link meaning does not change.

## 1. Common symbolic contract

For response cell `(i,t)`, each variational tier contributes to

\[
  \eta_{it}\sim N(\mu_{it},v_{it}),\qquad
  \mu_{it}=x_{it}^{\mathsf T}\beta+
    \sum_k\lambda_{kt}^{\mathsf T}m_{k,g_k(i)},\qquad
  v_{it}=\sum_k\lambda_{kt}^{\mathsf T}S_{k,g_k(i)}\lambda_{kt}.
\]

Every admitted family supplies the scalar expectation

\[
  Q_{it}=E\{\log p(y_{it}\mid\eta_{it},\vartheta_t)\}.
\]

With physicists' Gauss–Hermite nodes and weights, the generic route is

\[
  Q_{it}^{(H)}=\pi^{-1/2}\sum_{h=1}^{H}w_h
  \log p\{y_{it}\mid\mu_{it}+\sqrt{2v_{it}}a_h,\vartheta_t\}.
\]

The full objective remains `-ELBO`: the sum of response expectations minus the
existing Gaussian KL terms. `H` changes numerical integration only; it does not
change the statistical model. When `v` tends to zero, every route must converge
to the matching conditional Laplace density at `eta = mu`.

## 2. Frozen 18-cell family/link registry

| family_id | family/link cell | route | additional fitted parameter(s) | scalar log-density or exact expectation |
|---:|---|---|---|---|
| 0 | Gaussian / identity | EXACT | `log_sigma[t]` | `-log(sigma)-log(2pi)/2-{(y-mu)^2+v}/(2 sigma^2)` |
| 1 | binomial / logit | GH; JJ explicit alternative | none | `lchoose(n,y)+y eta-n softplus(eta)` |
| 1 | binomial / probit | GH; AC/AC2 explicit alternatives | none | `lchoose(n,y)+y logPhi(eta)+(n-y)logPhi(-eta)` |
| 1 | binomial / cloglog | GH | none | `lchoose(n,y)+y log{1-exp[-exp(eta)]}-(n-y)exp(eta)` |
| 2 | Poisson / log | EXACT | none | `y mu-exp(mu+v/2)-lgamma(y+1)` |
| 3 | lognormal / log | EXACT | `log_sigma_lognormal[t]` | Gaussian expectation on `log(y)` plus `-log(y)` |
| 4 | Gamma / log | EXACT | `log_phi_gamma[t]` | with shape `a`: `a log(a)-lgamma(a)+(a-1)log(y)-a mu-a y exp(-mu+v/2)` |
| 5 | NB2 / log | GH | `log_phi_nbinom2[t]` | shifted-softplus form already used by the VA engine |
| 6 | Tweedie / log | GH | `log_phi_tweedie[t]`, `logit_p_tweedie[t]` | nodewise `dtweedie(y,exp(eta),phi,p,TRUE)` |
| 7 | Beta / logit | GH | `log_phi_beta[t]` | nodewise beta density with mean `invlogit(eta)` and precision `phi` |
| 8 | beta-binomial / logit | GH | `log_phi_betabinom[t]` | nodewise beta-binomial density with `n_trials` |
| 9 | Student-t / identity | GH | `log_sigma_student[t]`, `log_df_student[t]` | `dt((y-eta)/sigma,df,TRUE)-log(sigma)` |
| 10 | zero-truncated Poisson / log | GH | none | `y eta-exp(eta)-lgamma(y+1)-log{1-exp[-exp(eta)]}` |
| 11 | zero-truncated NB2 / log | GH | `log_phi_truncnb2[t]` | NB2 density minus its stable zero-mass normaliser |
| 12 | delta lognormal / log | HYBRID | `log_sigma_lognormal_delta[t]` | GH logit occurrence plus exact positive lognormal expectation when `y>0` |
| 13 | delta Gamma / log | HYBRID | `log_phi_gamma_delta[t]` | GH logit occurrence plus exact positive Gamma expectation when `y>0` |
| 14 | ordinal probit | GH | ordered cutpoint increments | stable nodewise `log{Phi(c_y-eta)-Phi(c_(y-1)-eta)}` |
| 15 | NB1 / log | GH | `log_phi_nbinom1[t]` | nodewise NB1 with size `exp(eta)/phi` and probability `1/(1+phi)` |

The delta cells use the same linear predictor for occurrence and positive-part
components because that is the model currently implemented by the Laplace
engine. The positive component is not evaluated when `y = 0`.

## 3. Parameter and support alignment

Family parameters use the same transformed scales as `src/gllvmTMB.cpp`, and a
parameter vector is mapped out for traits that do not use it. One deliberate
pre-existing difference remains: Design 108 made Gaussian and lognormal VA
residual scales per-trait, whereas the Laplace template uses one shared
`log_sigma_eps`. Production VA preserves that richer per-trait model. A private
`match_laplace_residual_sd = TRUE` comparator mode ties the pure-Gaussian or
pure-lognormal VA scales to one free value; Arc 2 must use that mode when calling
the Laplace fit a matched comparator. A mixed Gaussian-plus-lognormal VA fit
cannot yet tie the two separate parameter vectors and therefore is not matched
Laplace evidence. Ordinal cutpoints use the Laplace engine's first-cutpoint plus
exponentiated increment construction. Missing responses must bypass the density
entirely.

Support checks are performed before TMB evaluation: Beta requires `0 < y < 1`;
positive, lognormal, and Gamma components require `y > 0`; truncated counts
require positive integers; binomial and beta-binomial require integer
`0 <= y <= n`; ordinal responses require valid category codes; count families
require non-negative integers. A failing family/link cell is fenced individually
rather than disabling a healthy cell.

At quadrature nodes, tail-safe forms are mandatory. In particular: no direct
`log(1-exp(x))`; no direct subtraction of ordinal CDFs; no avoidable `exp(eta)`
inside a log-sum; and boundary probabilities for Beta/beta-binomial are handled
inside the nodewise integrand. `H = 61` is a diagnostic oracle, not the default,
because its far-tail nodes can be numerically harsher than `H = 7`.

### Why seven nodes is a candidate, not a theorem

The literature supports a node ladder, not a universal value of `H`. Korhonen
et al. (2023) used 5 or 9 ordinary Gauss-Hermite points in GLLVM VA examples;
it did not test seven nodes across response families. Adaptive-quadrature work
has examined orders including 5, 7, 9, and 11 and recommends increasing the
order until the resulting inference is stable, but that work approximates a
marginal random-effects likelihood rather than the fixed Gaussian expectation
used here. Rabe-Hesketh et al. (2002) likewise shows that the required adaptive
order is model-dependent. Therefore `H = 7` sits between published GLLVM choices
and is economical enough to test, but the package must earn it independently in
every cell through Gate E and the Arc-2 H ladder.

## 4. Gate E — permission to make H = 7 the default

**Verdict (2026-08-06): PASS, 18/18 cells.** The durable per-cell receipt is
`docs/dev-log/audits/2026-08-06-va-gh-h7-gate-e.md`. It records the independent
tail oracles, fixed-parameter map checks, compiled arithmetic, finite-gradient
and Hessian checks, and all-family light fits. This is permission to promote the
GH default and scalar family/link fence; it is not Arc-2 recovery or uncertainty
coverage evidence.

Each of the 18 cells receives an independent verdict. A cell passes only when:

1. its `v -> 0` value matches the corresponding conditional density;
2. an exact route agrees with a direct scalar oracle to `1e-10`, or a GH route
   agrees with adaptive/high-order integration to `1e-6` ordinarily and a
   predeclared `1e-4` in extreme-tail fixtures;
3. the TMB objective and gradient are finite and its gradient agrees with a
   numerical reference to `5e-4` in the light fixture;
4. one known-DGP light fit is healthy, including one mixed-family and one
   multi-tier fixture across the programme;
5. existing exact/GH/JJ/AC/AC2 cells retain their prior behaviour when selected
   explicitly; and
6. the family is individually fenced on any failure.

The H ladder is `5, 7, 9, 15, 61`. `H = 7` becomes the automatic GH order only
after all pre-existing public cells and every newly admitted cell satisfy the
conditions above. Exact routes ignore `H`. The package default remains Laplace.

The primary fitted comparator is this package's own matched Laplace route. A
direct scalar integral is the primary arithmetic oracle. `gllvm` is a secondary
comparator only where family, link, parameterisation, estimator, data, and latent
structure genuinely match; disagreement does not by itself decide that this
engine is wrong.

## 5. Inference contract

Fixed-effect VA-Wald uncertainty is based on the profiled Schur information

\[
  I_{\beta\beta\cdot v}
  =H_{\beta\beta}-H_{\beta v}H_{vv}^{-1}H_{v\beta},
\]

where `v` denotes all non-fixed variational and model coordinates. It is exposed
only for a healthy, positive-definite profiled information matrix and is labelled
as VA-Wald. It is checked against the full inverse-Hessian beta block as an
algebraic oracle. Loading uncertainty is not exposed as generic elementwise
Wald inference; covariance summaries must respect rotational invariance.

For latent scores, `q(u_i)=N(m_i,S_i)` provides posterior standard deviations
`sqrt(diag(S_i))`. These are labelled **variational posterior SD**, not
frequentist standard errors. Neither surface converts the ELBO into a marginal
log likelihood.

## 6. Arc 2 boundary

Only a recorded Gate-E pass may launch Arc 2. Totoro runs the broad all-family
campaign first (up to 150 cores, one BLAS thread per worker). DRAC supplies an
independent SLURM-array confirmation, one seed per task, with keepers copied to
`/project`. Campaign outputs remain local and are never GitHub Actions artifacts.
The campaign reports family-specific H-ladder stability, recovery relative to
known truth and matched Laplace, beta-Wald coverage, invariant covariance
recovery, latent posterior-SD calibration, failure retention, and MCSE. No pooled
success rate can conceal a failing family.

## 7. Explicit exclusions

`family_id = 16` multinomial is a coupled softmax expectation and is not scalar;
it requires a separate design. Families with separate occurrence/positive
predictors, latent dispersion predictors, zero-inflation mixtures, and
constructor-only families absent from the Laplace 0–15 scalar dispatch are also
outside this arc. Structured tiers, random slopes, missingness, and other model
axes may use the new family arithmetic only where their own existing VA gate has
already admitted them; this contract does not silently validate those axes.

## References

- Korhonen, P., Hui, F. K. C., Niku, J., & Taskinen, S. (2023). Fast and
  universal estimation of latent variable models using extended variational
  approximations. *Statistics and Computing*, 33, 26.
  <https://doi.org/10.1007/s11222-022-10189-w>
- Bilodeau, B., Stringer, A., & Tang, Y. (2025). Asymptotics of numerical
  integration for two-level mixed models. *Bernoulli*, to appear.
  <https://arxiv.org/abs/2202.07864>
- Rabe-Hesketh, S., Skrondal, A., & Pickles, A. (2002). Reliable estimation of
  generalized linear mixed models using adaptive quadrature. *The Stata
  Journal*, 2, 1-21. <https://doi.org/10.1177/1536867X0200200101>
