# R3 symbolic-to-implementation map

**Status:** frozen before prototype code

R3 is a standalone, research-only objective. It does not alter the shipped TMB
template or expose a fitting method. The admitted binomial model is

\[
u_i\sim N_q(0,I_q),\qquad
y_{it}\mid u_i\sim\operatorname{Binomial}(n_{it},p_{it}),\qquad
\operatorname{logit}(p_{it})=x_{it}^T\beta+\lambda_t^Tu_i.
\]

The variational family is `q_i(u_i) = N_q(m_i, L_i L_i^T)` with a full,
unit-specific lower-triangular `L_i` and log-transformed diagonal.

## Alignment table

| Symbol | Formula / package boundary | DGP draw | Prototype coordinate | Verification target |
|---|---|---|---|---|
| `y_it, n_it` | complete multi-trial binomial-logit only | `y_it ~ Binomial(n_it, plogis(eta_it))`, `n_it >= 2` | immutable integer vectors plus unit/trait indices | byte identity with the ML/O3 cells and likelihood constants |
| `beta` | fixed-effect design shared with ML | planted finite vector | ordinary parameter vector | analytic-gradient and known-DGP recovery |
| `Lambda` | ordinary `latent(..., unique = FALSE)` | planted lower-triangular loading matrix | exact live `theta_rr_B` packing: raw diagonal then strict lower triangle column-wise | exact pack/unpack; `Sigma_B = Lambda Lambda^T` |
| `u_i` | ordinary unit score, prior `N(0,I_q)` | iid standard normal | integrated by the model; represented by `m_i,L_i` | analytic Gaussian posterior and q=1/2 AGHQ moments |
| `m_i` | no public keyword | not a DGP parameter | `N x q` ordinary parameter matrix | finite gradient; q=1/2 posterior-mean RMSE |
| `S_i=L_iL_i^T` | no public keyword | not a DGP parameter | log diagonal plus packed strict-lower entries per unit | SPD; analytic Gaussian covariance; q=1/2 AGHQ covariance error |
| `G_H(mu,v)` | internal one-dimensional GH expectation | not a DGP parameter | stable softplus, physicists' nodes/weights, smooth small-`v` even expansion | frozen scalar integration grid and 15/25/61 ladder at identical coordinates |
| `KL_i` | prior exactly `N(0,I_q)` | not a DGP parameter | `0.5*(sum(L_i^2)+m_i^Tm_i-2sum(log diag L_i)-q)` | independent scalar KL and sign checks |
| `ELBO_H` | internal objective only | not a likelihood parameter | negative ELBO returned to `nlminb`, with one bounded BFGS polish only after the frozen `nlminb` polish ladder; `beta`, `Lambda`, `m`, `L` are never `random=` | lower-bound inequality at fixed q=1/2 coordinates and finite AD gradients |
| `q_ML` | ML/BIC candidate set includes zero | planted rank in recovery studies | selected outside the prototype | rank zero returns not-applicable before objective construction |

## Standalone TMB interface

The research template accepts `y`, `n_trials`, `X`, zero-based `unit_id` and
`trait_id`, `N`, `T`, `q`, physicists' GH nodes/weights, and a family selector
used only for the Gaussian algebra anchor versus admitted binomial-logit work.
Parameters are `beta`, live-packed `theta_rr`, `m`, per-unit log-Cholesky
diagonals, and per-unit strict-lower Cholesky entries. No parameter is supplied
to TMB's `random=` argument.

The R adapter must fail before compilation/objective construction for q=0,
q>6, q>T, incomplete cells, trial counts below two, non-logit or non-binomial
requests, any `Psi`/structured/provider marker, non-finite `X`, or a rank-
deficient `X`. q=0 is returned as `not_applicable_rank_zero`, not an error from
the TMB objective.

## Numerical contract

- `softplus(x) = max(x,0) + log1p(exp(-abs(x)))`.
- `v_it = ||L_i^T lambda_t||^2`; no covariance matrix or inverse is formed.
- For small `v`, use an even-order expansion in `v` so AD never differentiates
  `sqrt(v)` at zero. Test value/first-derivative continuity and threshold
  sensitivity before accepting the branch.
- Compute `log choose(n,y)` with log-gamma functions.
- Four deterministic starts are attempted; at least three are required for an
  admitted optimizer result. Code zero, finite objective/parameters, maximum
  absolute gradient below `1e-4`, and best-objective agreement within `1e-6`
  are all required.

## Claim boundary

Passing this map and its tests authorises only the next cheap falsification
stage. It does not make the ELBO a likelihood, provide frequentist uncertainty,
select rank, support q>=3 tensor AGHQ, expose a public VA method, or support
non-Gaussian REML.
