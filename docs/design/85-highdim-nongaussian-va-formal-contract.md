# Design 85 -- High-dimensional non-Gaussian VA formal contract

**Status:** pre-code, research-only contract. This document authorises neither
implementation nor compute. Any prototype governed by it must remain internal,
non-exported, and outside the shipped `gllvmTMB()` method surface.

**Numbering note:** Designs 83 and 84 are already allocated to multinomial
work. This is therefore Design 85; no multinomial design is superseded.

**Decision:** the only admissible next high-dimensional experiment is a
Gaussian variational approximation to the ordinary unit-score posterior for a
complete, multi-trial binomial-logit GLLVM with
`latent(..., unique = FALSE)`. Rank is chosen upstream by the existing
marginal-ML/Laplace workflow. The VA does not select rank and does not define a
new likelihood.

## 1. Why this contract is narrower than the earlier VA memo

The O3 work establishes a fixed-coordinate marginal-integration reference at
`q = 1` and `q = 2`; it stops before `q >= 3` because tensor quadrature scales
exponentially. It fixes the fitted fixed-effect and loading coordinates and is
explicitly not an AGHQ refit, Cox--Reid adjustment, or non-Gaussian REML
estimator [O3 spike, lines 6--26 and 64--76](../dev-log/spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md).

Design 72 is an informative predecessor, not current implementation authority.
Its Phase-1 mean-field Gaussian/Poisson prototype is parked, and its own record
says that convergence without recovery is insufficient and that an ELBO is not
a marginal likelihood [Design 72, lines 59--99, 379--408](72-variational-approximation-feasibility.md).
This contract revives no parked source file or public `method = "VA"` proposal.
It instead defines one new, falsifiable research comparison for the regime O3
cannot scale to.

The package boundary remains unchanged: stacked-trait, long-format,
multivariate GLLVM data only. Single-response GLMMs belong in `glmmTMB`, and
spatial-only single-response models belong in `sdmTMB`. No phylogenetic,
animal, spatial, kernel, within-unit, cluster, missing-data, mixed-family,
random-slope, predictor-informed-score, `unique = TRUE`, or explicit
`+ unique()` term is admitted here.

## 2. Symbols and data contract

Let

- `i = 1, ..., N` index units and `t = 1, ..., T` index traits;
- `q` be the fitted latent rank, with `1 <= q <= T`;
- `y_it` be the observed number of successes and `n_it` the known number of
  trials;
- `x_it in R^p` be a fixed, finite design row and `beta in R^p` its coefficient;
- `lambda_t in R^q` be row `t` of the loading matrix `Lambda`;
- `u_i in R^q` be the ordinary unit-level latent score; and
- `eta_it = x_it^T beta + lambda_t^T u_i`.

The data are **complete multi-trial binomial** data:

\[
  n_{it} \in \{2,3,\ldots\},\qquad
  y_{it} \in \{0,\ldots,n_{it}\},
\]

for every one of the `N T` unit-trait cells. There are no response masks,
case weights, offsets, fractional successes, single-trial Bernoulli rows, or
trait-specific links. `X` is fixed in advance and full column rank. Every rank
candidate uses byte-identical response cells, trial counts, `X`, family, link,
starts policy, and optimiser policy.

The model is

\[
\begin{aligned}
  u_i &\overset{\mathrm{iid}}{\sim} N_q(0,I_q),\\
  y_{it}\mid u_i
    &\sim \operatorname{Binomial}(n_{it},p_{it}),\\
  \operatorname{logit}(p_{it}) &= x_{it}^T\beta+\lambda_t^T u_i.
\end{aligned}
\]

Thus the fitted ordinary latent covariance is exactly

\[
  \Sigma_B = \Lambda\Lambda^T.
\]

There is no fitted diagonal `Psi`. The logistic link residual convention
`pi^2 / 3`, if used later for interpretation, is not a free covariance
parameter and must not be inserted into this ELBO.

## 3. Rank is selected by ML before VA

The candidate set `Q_ML` must be predeclared and satisfy
`Q_ML subset {0, ..., min(T, 6)}` and must contain `0`. The rank-zero candidate
is the same fixed-effects model without an ordinary latent term; positive-rank
candidates use the existing ordinary `latent(..., unique = FALSE)` TMB/Laplace
ML route. The primary rule
is the smallest healthy rank attaining the minimum BIC; ties within two BIC
units choose the smaller rank. AIC and fit-health diagnostics are recorded but
do not override this predeclared rule. This follows the existing rank article's
principle that rank selection compares penalised marginal ML fits with the
same likelihood approximation, not scree values
[rank article](../../vignettes/articles/model-selection-latent-rank.Rmd).

Denote the result by `q_ML`. If `q_ML = 0`, the VA experiment stops with
`not_applicable_rank_zero`: there is no latent posterior to approximate. If
`q_ML > 0`, the joint VA experiment fixes `q = q_ML`. It does **not** compare
ELBOs across ranks. Separately:

- `q = 1` and `q = 2` are low-dimensional reference fixtures, whether or not
  either is `q_ML` for the applied fixture;
- `q = 4` and `q = 6` are known-DGP scalability and numerical-stress fixtures,
  conditional on `T >= q`, whether or not either wins ML selection; and
- a failed or unhealthy ML candidate is not rescued into the candidate set by
  a numerically finite VA fit.

Calling this an "ML-selected VA fit" means only that ML selected `q`. It does
not mean that the VA objective is ML.

## 4. Fixed and optimised coordinates

| Stage | Fixed coordinates | Optimised coordinates | Quantity produced |
|---|---|---|---|
| ML rank selection | data, `X`, candidate `q`, formula, `unique = FALSE` | `beta`, packed `Lambda`; unit scores are Laplace-integrated | Laplace marginal-ML objective, BIC, `q_ML` |
| O3 reference, `q = 1/2` | data, `q`, fitted `beta_ML`, fitted `Lambda_ML` | none for the existing O3 integral; its adaptive modes/Hessians are numerical integration coordinates | fixed-coordinate AGHQ marginal objective |
| Conditional VA reference, `q = 1/2` | data, `q`, the same `beta_ML`, the same `Lambda_ML`, quadrature rule | all unit-specific variational `m_i`, `L_i` | ELBO and variational posterior moments at the O3 coordinates |
| Joint VA target | data, `q = q_ML > 0`, quadrature rule | `beta`, packed `Lambda`, every `m_i`, every `L_i` | maximum ELBO and rotation-invariant fitted summaries; no VA object when `q_ML = 0` |
| `q = 4/6` stress | known DGP, fixed stress rank, quadrature rule | same as joint VA | numerical scaling and known-DGP recovery evidence only |

No coordinate is silently profiled, restricted, or integrated under another
name. In particular, the VA means and covariances are ordinary optimiser
parameters, never TMB `random` parameters. The negative objective returned to
an optimiser is `-ELBO`.

## 5. Variational family and ELBO

Use one unit-specific **full-covariance** Gaussian factor,

\[
  q_i(u_i)=N_q(m_i,S_i),\qquad S_i=L_iL_i^T,
\]

and `q(U) = product_i q_i(u_i)`. `L_i` is lower triangular with strictly
positive diagonal. A mean-field `S_i` is out of scope for this first contract:
it would make the approximation depend more strongly on the chosen latent-axis
orientation and would confound the high-rank result with a second approximation
choice.

For

\[
  \mu_{it}=x_{it}^T\beta+\lambda_t^Tm_i,
  \qquad
  v_{it}=\lambda_t^TS_i\lambda_t,
\]

the exact Gaussian expectation of the binomial-logit contribution is

\[
\begin{aligned}
 E_{q_i}\{\log p(y_{it}\mid u_i)\}
  ={}& \log {n_{it}\choose y_{it}} + y_{it}\mu_{it}\\
     &{}-n_{it}E_{Z\sim N(0,1)}
       [\operatorname{softplus}(\mu_{it}+\sqrt{v_{it}}Z)].
\end{aligned}
\]

The remaining expectation is one-dimensional regardless of `q`. With
physicists' Gauss--Hermite nodes and weights `(a_h,w_h)`, define

\[
 G_H(\mu,v)=\pi^{-1/2}\sum_{h=1}^H w_h
   \operatorname{softplus}(\mu+\sqrt{2v}\,a_h).
\]

The deterministic quadrature ELBO is

\[
\boxed{
\begin{aligned}
 \mathcal L_H(\beta,\Lambda,m,L)
 ={}&\sum_{i=1}^N\sum_{t=1}^T
 \left[\log {n_{it}\choose y_{it}}+y_{it}\mu_{it}
       -n_{it}G_H(\mu_{it},v_{it})\right]\\
 &-\frac12\sum_{i=1}^N
 \left[\operatorname{tr}(S_i)+m_i^Tm_i
       -\log|S_i|-q\right].
\end{aligned}}
\]

The bracketed half-term is exactly
`sum_i KL{N(m_i,S_i) || N(0,I_q)}`; the second line contributes its
**negative** to the ELBO. As `H` increases, only numerical
quadrature error separates `L_H` from the mathematical ELBO. This is a direct
ELBO for logit binomial observations evaluated by deterministic one-dimensional
Gauss--Hermite quadrature. It does not claim that the expectation is closed
form, and it is a bounded alternative to (not a silent rewrite of) the
second-order EVA route recorded in Design 72.

## 6. Loading identification and the live-engine boundary

The prototype must reconstruct `Lambda` from the same packed coordinates as
the live ordinary B-tier engine:

1. the first `q` entries are the diagonal;
2. the remaining `Tq - q(q+1)/2` entries fill the strict lower triangle
   column-by-column; and
3. the strict upper triangle is exactly zero.

This matches the live TMB unpacker
[src/gllvmTMB.cpp, lines 773--805](../../src/gllvmTMB.cpp). It is essential for
fixed-coordinate equality with O3 and with the shipped ML fit.

There is a pre-existing documentation/implementation discrepancy that this
prototype must not hide. Design 04 describes positive, exponentiated loading
diagonals [Design 04, lines 125--147](04-random-effects.md), whereas the live
TMB code copies `lam_diag(j)` without `exp()`. Therefore, under this contract:

- loading diagonals remain **raw unconstrained live-engine coordinates**;
- the lower-triangular constraint removes continuous rotations but leaves
  axis-sign reflections;
- pass/fail targets are `Sigma_B = Lambda Lambda^T`, fitted probabilities,
  and (where needed) Procrustes/sign-aligned loadings, never unaligned raw
  `Lambda` or raw scores; and
- changing loading diagonals to `exp(log_lambda_diag)` is a separate engine
  reparameterisation. Doing it inside the VA prototype is a **NO-GO** because
  it breaks the O3/ML fixed-coordinate contract.

Any claim that the live engine already has positive loading diagonals is also
a NO-GO until the source and design prose are reconciled.

## 7. Numerical and transform requirements

1. Parameterise each variational Cholesky diagonal as
   `L_i[k,k] = exp(rho_i[k])`. Strict-lower entries are unconstrained. Compute
   `log|S_i| = 2 sum_k rho_i[k]` and
   `tr(S_i) = sum_{j,k} L_i[j,k]^2`; never form a determinant or matrix inverse.
2. Compute `v_it` as `||L_i^T lambda_t||^2`; do not form `S_i`. The scalar
   expectation routine must implement the continuous `v -> 0` limit. A naive
   differentiated `sqrt(v)` at exactly zero is prohibited; use a documented
   small-`v` even-order expansion or an equivalently smooth custom routine,
   with threshold sensitivity checked.
3. Compute `softplus(x)` as `max(x,0) + log1p(exp(-abs(x)))`. Compute
   `log choose(n,y)` with log-gamma functions. Direct `log(1 + exp(x))`, raw
   factorials, explicit probabilities near zero/one, and clipping `eta` are
   prohibited.
4. Every objective and gradient evaluation must remain finite. Non-finite
   values fail loudly with the unit, trait, and offending coordinate class;
   they are not replaced by an arbitrary large constant and counted as
   convergence.
5. Quadrature nodes/weights and their normalisation are immutable data. The
   `H = 15` and `H = 25` ladder is required before selecting a production
   research value. The 25-node result is the reference unless the total
   `|L_25 - L_15| < 1e-4` **and** the per-observation maximum difference is
   below `1e-8` at the same coordinates.
6. Optimiser convergence requires code zero, maximum absolute analytic
   gradient below `1e-4`, finite parameters, and agreement of the best
   objective from at least three deterministic starts within `1e-6`. A finite
   ELBO alone is not convergence.

No other positive parameter is introduced. In particular, the loading
diagonal is not put on a log scale under this live-engine-matching contract.

## 8. Symbolic-to-implementation alignment

| Symbol in prose | R/formula contract | Known-DGP draw | Prototype coordinate or calculation | Recovery / reference target |
|---|---|---|---|---|
| `y_it, n_it` | complete `cbind(success, failure)` equivalent; binomial logit only | `y_it ~ Binomial(n_it, plogis(eta_it))`, all `n_it >= 2` | immutable integer data | exact cells and likelihood constants match O3/ML input |
| `beta` | same fixed-effect RHS for every rank | fixed planted vector | unconstrained optimiser vector | coefficient bias plus fitted-probability error; not ELBO alone |
| `Lambda` | ordinary `latent(..., d = q, unique = FALSE)` | planted lower-triangular matrix | exact live `theta_rr_B` pack/unpack | `Sigma_B`, Procrustes/sign-aligned loadings |
| `u_i` | ordinary unit score, no `lv`, source, slope, or other tier | iid `N_q(0,I_q)` | integrated under model; represented by `m_i,L_i` under VA | O3 posterior moments at `q=1/2`; no raw-score population claim |
| `S_i=L_iL_i^T` | no user-facing keyword | not a DGP parameter | unit-specific full variational covariance; log Cholesky diagonal | SPD, finite KL, O3 moment comparison at `q=1/2` |
| `mu_it` | fixed plus ordinary latent contribution | `x_it^T beta + lambda_t^T u_i` | `x_it^T beta + lambda_t^T m_i` | conditional mean algebra identity |
| `v_it` | none; variational projection only | not a DGP parameter | squared norm `||L_i^T lambda_t||^2` | agrees with explicit `lambda_t^T S_i lambda_t` to numerical tolerance |
| `G_H(mu,v)` | internal quadrature only | not a DGP parameter | stable 1-D Gauss--Hermite expectation | 15/25 ladder and direct high-precision scalar reference |
| `KL_i` | none | prior is exactly `N(0,I_q)` | `0.5*(sum(L_i^2)+m_i^Tm_i-2sum(rho_i)-q)` | agrees with a direct multivariate-normal KL calculation |
| `Sigma_B` | `extract_Sigma(..., part = "shared")` conceptual target | `Lambda Lambda^T` | `Lambda * Lambda^T` | primary rotation-invariant recovery target |
| `q_ML` | predeclared ML candidate set including zero | planted ranks in simulation only | selected outside VA by healthy-fit BIC rule | selection frequency reported separately from VA performance; zero stops VA as not applicable |

An empty or differently implemented cell in this table is a contract failure,
not an invitation to reinterpret the symbol.

## 9. Valid comparisons

The following comparisons are valid and required:

1. **At identical fixed `beta_ML, Lambda_ML`, `q = 1/2`:** optimise only
   `(m_i,L_i)` and compare the VA lower bound with the O3 AGHQ marginal
   log-likelihood. Up to stated quadrature error,
   `ELBO <= log marginal likelihood`; on the negative-objective scale the
   inequality reverses.
2. **At identical fixed coordinates:** compare VA posterior means and
   covariances with moments computed from the O3 quadrature reference.
3. **After joint optimisation at fixed rank:** compare `beta`, `Sigma_B`,
   fitted probabilities, convergence, and runtime with the shipped ML/Laplace
   fit and with known DGP truth. Raw loading and score comparisons require
   sign/rotation alignment.
4. **Within one method and rank:** compare the 15/25-node VA objectives at the
   same parameter vector, and compare deterministic starts after they reach
   the same optimum.
5. **Across `q = 1,2,4,6`:** compare computational scaling and known-DGP
   recovery summaries only. The stress ranks are not evidence that those ranks
   should be selected.

## 10. Prohibited interpretations and outputs

The following language or behaviour is prohibited:

- calling `L_H` a marginal log-likelihood, exact likelihood, restricted
  likelihood, REML, AI-REML, Cox--Reid adjustment, or AGHQ;
- computing or exposing `logLik`, AIC, BIC, LRT, likelihood-ratio profile, or
  model weights from the ELBO;
- selecting `q` by maximised ELBO or comparing ELBO values across ranks as if
  they shared an equal approximation gap;
- describing a smaller negative ELBO as better marginal fit than a Laplace or
  AGHQ objective;
- interpreting the inverse VA Hessian as calibrated frequentist uncertainty;
- treating variational `m_i` or `S_i` as model parameters, true latent scores,
  or repeated-sampling uncertainty for `u_i`;
- claiming variance-component, interval, coverage, rank-selection, or
  high-dimensional accuracy from optimizer convergence alone;
- folding a diagonal `Psi`, logistic `pi^2/3`, overdispersion term, or
  observation-level random effect into `Sigma_B`;
- widening to Bernoulli, incomplete responses, mixed families, alternative
  links, structured sources, random slopes, or public syntax by analogy; or
- using this research prototype to weaken the project's Gaussian-only REML
  boundary. The package's speed design explicitly reserves REML/AI-REML
  language for exact Gaussian restricted-likelihood work
  [Design 43](43-asreml-speed-techniques.md).

The prototype result object, if built later, must carry
`research_only = TRUE`, `objective_type = "ELBO_GH"`, `rank_source = "ML_BIC"`,
`family = "binomial"`, `link = "logit"`, `unique = FALSE`, the quadrature
order, and the exact source commit. It must not inherit class
`gllvmTMB_multi` or methods that imply marginal likelihood.

## 11. Acceptance and NO-GO gates

Gates are sequential. A later gate cannot compensate for a failed earlier
gate, and tolerances cannot be widened after seeing the result.

### Gate 0 -- scope and coordinate freeze

- A byte-identity checksum confirms that VA, ML, and O3 receive the same
  ordered complete response cells, trials, trait IDs, unit IDs, and `X`.
- The live packed loading reconstruction agrees exactly with `Lambda_B` from
  the ML report.
- `unique = FALSE` is asserted; every excluded keyword/family/data shape fails
  before objective construction.

**NO-GO:** any implicit `Psi`, changed loading transform, missing cell, trial
count below two, or parked VA source copied without a fresh derivation audit.

### Gate 1 -- algebra and autodiff

- Stable scalar `G_H` agrees with a high-precision one-dimensional integration
  reference to `1e-10` on a grid spanning large negative, central, and large
  positive `mu` and small-to-large `v`.
- The explicit KL bracket, the negative-KL ELBO contribution, and the returned
  negative objective each agree with independent scalar calculations before
  any optimisation test.
- Packed/full `Lambda`, projected `v`, KL, and total ELBO agree with direct
  reference calculations to `1e-10` on tiny fixtures.
- Analytic/autodiff gradients agree with central finite differences to
  relative error `1e-5` away from declared boundaries; the small-`v` routine
  is value- and first-derivative continuous at its switch.
- On an ordinary Gaussian `latent(..., unique = FALSE)` fixture with the same
  `X`, packed-loading map, and full per-unit variational covariance, the
  Gaussian posterior is represented exactly. The variational posterior means,
  covariances, objective, and gradients must agree with the analytic Gaussian
  solution to `1e-8`. This is an algebra/geometry anchor, not evidence about
  non-Gaussian approximation quality.

**NO-GO:** clipping is needed for finiteness, the KL sign is wrong, constants
are omitted, or the negative-objective sign is inconsistent.

### Gate 2 -- low-dimensional O3 references

- Preserve the landed O3 anchors: one-node joint-Laplace differences below
  `1.4e-9` at `q = 1` and `9.8e-8` at `q = 2`, with the existing stable node
  ladders. These are fixed-coordinate numerical references only.
- At those identical `beta_ML, Lambda_ML`, the optimised quadrature ELBO does
  not exceed the O3 marginal log-likelihood by more than `1e-6` total.
- Against O3 posterior moments, unit-level VA means have RMSE below `0.05`,
  covariance relative Frobenius error has median below `0.10`, and no unit
  exceeds `0.25` on the deliberately non-separated reference fixtures.
- The VA 15/25-node ladder meets Section 7 and all optimiser gates pass.

**NO-GO:** a bound violation beyond numerical tolerance, material posterior-
moment failure, or dependence of the conclusion on one start.

### Gate 3 -- joint-fit known-DGP recovery at `q = 1/2`

- Use a predeclared multi-seed known-DGP design, not the O3 deterministic
  fixture alone. Report all attempted fits and Monte Carlo standard errors.
- Primary targets are `beta`, `Sigma_B`, and fitted probabilities. Raw
  `Lambda` is secondary and aligned; raw scores are not recovery targets.
- VA bias and RMSE must be reported beside byte-identical ML/Laplace results.
  VA passes only if its `Sigma_B` relative Frobenius RMSE is no more than
  `0.05` worse in absolute terms than ML and no planted axis collapses in more
  than 5% of otherwise healthy, non-separated replicates.

**NO-GO:** success is declared from convergence rate alone, failed fits are
excluded from denominators, or bands are widened post hoc.

### Gate 4 -- ML rank hand-off

- The BIC/tie/health rule is frozen before simulation and includes the
  rank-zero candidate.
- Report how often ML selects each candidate under planted ranks; then run VA
  at the selected rank without re-selection.
- If rank zero wins, record `not_applicable_rank_zero` and do not construct or
  optimise variational coordinates.
- When ML selects the wrong rank, label the VA result conditional on that
  selected model; do not charge or credit VA with the rank-selection result.

**NO-GO:** any ELBO-based rank choice or use of VA convergence to override an
unhealthy ML candidate.

### Gate 5 -- `q = 4/6` stress

- Run separate known-DGP stress cells with `T >= 6`, adequate `N`, non-sparse
  trial outcomes, planted full-rank `Lambda`, and the same complete
  multi-trial family/link contract.
- Record wall time, peak memory, objective/gradient evaluations, convergence,
  quadrature-ladder stability, `Sigma_B` recovery, axis-collapse rates, and
  predictive scoring against an independently generated replicate response at
  the same planted unit scores. The replicate is not used in fitting. Report
  per-cell binomial negative log score and squared-error (Brier-style) loss for
  the posterior-predictive mean.
- Across at least 50 predeclared seeds per stress rank, at least 90% must meet
  the optimiser gate; no more than 5% of healthy fits may lose a planted axis;
  and the VA-versus-ML `Sigma_B` RMSE degradation remains within the Gate-3
  `0.05` margin.
- A GO also requires one predeclared practical advantage over Laplace at both
  `q = 4` and `q = 6`: either the successful-fit rate is at least 10 percentage
  points higher, or median wall time is at least 25% lower while p95 wall time
  is no higher and successful-fit rate is no more than 2 percentage points
  lower. In either case, VA's mean negative log score may be no more than
  `0.01` per cell worse and its mean squared-error loss no more than `0.005`
  worse than Laplace. These margins are frozen before the first stress run.
- This campaign belongs on Totoro or DRAC and its outputs remain local; it is
  never a GitHub Actions simulation workflow or artifact.

**NO-GO:** tensor quadrature over `R^q`, superlinear-in-`N` storage, silent
non-finite retries, failure of both practical-advantage alternatives, degraded
recovery/collapse/predictive scoring beyond the frozen margins, or a
stress-only convergence result presented as inferential validation.

### Gate 6 -- claim audit

No public API, package reference page, NEWS feature claim, validation-register
promotion, inference method, or rank recommendation follows from Gates 0--5.
A separate maintainer decision, simulation-review sign-off, TMB likelihood
review, documentation cascade, and public-object contract would be required.

## 12. Local evidence used

- [O3 gllvmTMB hooks](../dev-log/spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md):
  exact model, fixed-coordinate boundary, `q = 1/2` numerical anchors, and
  hard stop before `q >= 3`.
- [O3 handover](../dev-log/handover/2026-07-19-codex-aghq-o3-handoff.md):
  admitted evidence and explicit list of unsupported interpretations.
- [Design 72](72-variational-approximation-feasibility.md): Gaussian VA
  coordinates, ELBO/KL form, parked Phase-1 result, bias warnings, and
  likelihood-comparison boundary.
- [VA Phase-1 report](../dev-log/after-task/2026-06-03-va-phase1-proof.md):
  convergence-versus-identifiability lesson and the need to compare recovery,
  not convergence alone.
- [Random-effects design](04-random-effects.md) and
  [live TMB unpacker](../../src/gllvmTMB.cpp): symbolic latent model and the
  loading-parameterisation discrepancy that must remain explicit.
- [Testing strategy](05-testing-strategy.md): known-DGP, fit-health,
  rotation-aware recovery, and all-attempt denominator discipline.
- [Formula grammar](01-formula-grammar.md): VA/AGHQ remain outside the package
  MVP and ordinary `latent(..., unique = FALSE)` is the loadings-only subset.
- [ASReml speed design](43-asreml-speed-techniques.md): Gaussian-only boundary
  for REML/AI-REML terminology in this package.
