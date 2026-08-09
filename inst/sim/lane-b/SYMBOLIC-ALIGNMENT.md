# Lane B B2 ordinary Bernoulli symbolic alignment

The frozen ordinary data-generating model is

\[
u_i \sim N_q(0,I_q), \qquad
\eta_{it}=\beta_{t0}+\sum_{j=1}^{p}\!x_{ij}\beta_{tj}
 +\sum_{k=1}^{q}\!u_{ik}\lambda_{tk}+o_{it},
\qquad
Y_{it}\sim\operatorname{Bernoulli}\{g^{-1}(\eta_{it})\}.
\]

Here `q` is 1 or 2, `g` is logit, probit, or complementary log-log,
and the finite offset is frozen at `o_it = 0`. Bernoulli models have no
additional unique/residual variance. The latent covariance target is the
rotation-invariant matrix `Sigma = Lambda %*% t(Lambda)`.

| Symbolic object | Simulator | Fit formula / control | Recovered object | Assertion |
|---|---|---|---|---|
| Trait intercept `beta[t,0]` | Cell-fixed intercept calibrated to the frozen marginal prevalence | `0 + trait` | fixed-effect vector | finite; calibrated targets are 0.50 or the recycled 0.01/0.05/0.20/0.80/0.95/0.99 sequence |
| Trait slopes `beta[t,j] = 0.35 (-1)^(t+j) / sqrt(j)` | `lane_b_slopes()` with `p=1` (low) or `p=3` (high) | `(0 + trait):xj` | fixed-effect vector | beta error is computed only in this frozen coordinate system |
| Scores and loadings `u_i`, `Lambda` | deterministic L'Ecuyer-CMRG substreams; QR-oriented cell-fixed loadings with RMS latent SD 0.5 or 1.5 | `latent(0 + trait | unit, d=q, unique=FALSE)` | shared `extract_Sigma(..., part="shared")$Sigma` | effective rank equals `q`; covariance error is Frobenius error on `Sigma`, not raw loadings |
| Offset `o_it` | an explicit finite zero for every row | `offset(offset)` | fixed, not estimated | all offsets must be finite and exactly zero; nonzero binary offsets remain outside this frozen campaign |
| Bernoulli response and link | `rbinom(..., size=1)` after the frozen inverse link | `binomial(link=...)` | likelihood and whole-unit marginal prediction | complete `unit x trait` train/test rectangles; fresh test units; log loss uses marginal predictions integrated over new scores |

The four arms use the same generated data and rotate execution order by
replicate. `ml_ridge` adds the existing loading ridge with `tau=2`;
`mspl_ridge_internal` is a private ablation hook, never a public API claim.
Every attempted fit, including capability absence, solver errors, non-finite
objectives, and non-stationary solutions, remains an attempt row.

The spatial extension replaces `u_i` by jointly simulated nu=1 Matérn fields
over training and withheld-block prediction locations. `spatial_indep` uses six
independent fields; `spatial_latent_q1/q2` uses one or two unit-variance fields
and the same QR loading construction. Fits use `spatial_indep()` or
`spatial_latent()` plus a package mesh. Range risk stays on `log(range)` and is
not folded into covariance RMSE.

The strict post-launch spatial adjudicator aligns the fitted objects and the
promotion claim as follows. It is a one-way gate: it can withhold a cell that
passed the frozen v1 metrics, but it cannot promote a cell that v1 rejected.

| Symbol in prose | Keyword / structure | DGP draw | Recovery extractor | Truth / assertion |
|---|---|---|---|---|
| Primary penalised point `theta_hat` | `spatial_indep()` or `spatial_latent()` | primary deterministic start stream | retained primary attempt diagnostics | usable, scaled score at most `1e-4`, no boundary or clamp contact |
| Independent point `theta_hat_alt` | same fitted formula and data | alternate deterministic start stream | retained alternate attempt diagnostics | optimizer-successful, stationary, rank-correct, and boundary-free |
| Marginal covariance `Sigma_spa` | independent diagonal or rank-`q` spatial covariance | marginal SD one and QR-oriented loadings | direct marginal-scale covariance reconstruction | expected rank and frozen SD/covariance-function recovery gates |
| Effective range `r=sqrt(8)/kappa` | native isotropic SPDE mesh | range fraction `0.15` or `0.60` of the domain | fitted `kappa` and three-distance covariance function | frozen bias/RMSE gates and no spatial boundary contact |
| Link-by-structure claim | one of three links by three spatial structures | both sample sizes, both prevalence profiles, both range regimes | eight strict cell verdicts | all eight cells pass; evidence is never inherited across links or structures |

For ordinary, targeted quasi, and spatial multistart gates, covariance
agreement is evaluated from the retained scientific-order covariance vectors as

\[
\frac{\lVert\widehat\Sigma_{\mathrm{alternate}}-
\widehat\Sigma_{\mathrm{primary}}\rVert_F}
{\max\{1,\lVert\widehat\Sigma_{\mathrm{primary}}\rVert_F\}} \le 10^{-4}.
\]

The runner's elementwise diagnostic remains in the immutable raw ledger, but it
is not the promotion statistic.

The 24-cell permutation surface generates each ordinary audit dataset once and
then applies original, reverse, and cell-seeded random trait orders. Fixed
effects, truth, outcomes, statuses, and covariance are permuted together;
stored estimates are returned to scientific trait order before the `1e-6`
objective/beta/covariance invariance checks. Promotion requires the exact
24-cell by 200-replicate by three-order by four-arm by two-start ledger and all
reverse/random comparisons; a missing or failed comparison withholds every
Lane B headline.

Frozen source receipts:

- ordinary manifest SHA-256: `7a95fddb25fb239c751a1a9a8fdd41b995d9e0d4c59fa150e1f834506095b0dd`
- arms manifest SHA-256: `67919144a82ef60aaf0770c372c796baaf0e927265e5c1d81b80d52e121f1dfc`
- permutation manifest SHA-256: `6471d2f78e3ac29da33591cdc2571dbb5a11dd49c9be7c70a1564973b545cf60`
- spatial manifest SHA-256: `f8c83569d4f6e4e14e0efba49015f0e10be948a4fb60953118d3be60f147364e`

## Targeted quasi-complete supplement

The frozen prevalence campaign generated complete separation often, but
quasi-complete separation only five times in 72,000 ordinary datasets and not
at all for cloglog. That realized sample is too small for the predeclared
one-sided Wilson gate. The corrective supplement is a conditional numerical
stress experiment, not a parameter-recovery experiment and not a replacement
for the immutable prevalence campaign.

### A — aims

The primary aim is to test whether opt-in LA-MSPL returns finite, stationary,
multistart-stable point estimates when one trait has a fixed-design
quasi-complete separation certificate. The secondary aim is to establish this
result separately for logit, probit, and cloglog at latent ranks one and two and
at two loading strengths.

### D — data-generating and conditioning mechanism

The base six-trait model retains the ordinary Bernoulli GLLVM above, with 200
independent units, three trait-specific slopes, `q` in `{1,2}`, loading RMS in
`{0.5,1.5}`, and balanced finite-parameter truths. For trait 1 only, the
training response is conditioned to the following exact pattern. Write

\[
x_{i1}\in\{-1,0,1\},\qquad
y_{i1}=0\;\text{when }x_{i1}=-1,\qquad
y_{i1}=1\;\text{when }x_{i1}=1.
\]

At `x1 = 0`, four covariate rows spanning the intercept, `x2`, and `x3`
coordinates are each duplicated once with `y = 0` and once with `y = 1`.
Consequently any separating direction has zero intercept, `x2`, and `x3`
coefficients, while its `x1` coefficient gives equality on the duplicated
boundary rows and strict separation elsewhere. The resolved design is full
rank and the fixed-design certificate must therefore be exactly
`QUASI_COMPLETE`, never inferred from prevalence. The other five training
traits and all held-out responses remain Bernoulli draws from the finite base
GLLVM. Each of the 12 cells has 500 replicates. The usable-rate MCSE is 0.45
percentage points at the target rate 0.99 and 0.97 percentage points at 0.95.
Under the frozen one-sided Wilson gate, 495/500 usable fits fail with lower
bound 0.97960, while 496/500 pass with lower bound 0.98230.

| Symbolic object | Covstruct keyword | Supplement construction | Recovery target | Truth / assertion |
|---|---|---|---|---|
| Fixed predictor `x1` | `(0 + trait):x1` | exact `-1/0/1` support | B0 certificate | trait 1 is `QUASI_COMPLETE` |
| Nuisance fixed predictors `x2,x3` | `(0 + trait):x2 + (0 + trait):x3` | paired boundary rows spanning nuisance coordinates | resolved fixed design | full column rank |
| Scores and loadings `u_i, Lambda` | `latent(0 + trait | unit, d=q, unique=FALSE)` | same Gaussian draw and QR-oriented loadings as the ordinary campaign | `Sigma = Lambda Lambda^T` | effective rank `q` |
| Bernoulli links | `binomial(link=...)` | logit, probit, cloglog in separate cells | penalized Laplace point | finite stationary solution |
| Conditional trait-1 outcome | no extra keyword | exact quasi-complete pattern | no parameter-recovery claim | stress-test status only |

### E — estimands

The targets are the replicate-level indicator of a finite usable LA-MSPL fit,
the scaled penalized score, boundary/clamp contact, covariance rank, and
agreement of the penalized objective and `Sigma` across two starts. The forced
trait's fixed-effect error and held-out log loss are diagnostic only and are
excluded from promotion because the conditioning step does not preserve a
finite trait-1 coefficient truth.

### M — methods

All four frozen arms are retained in rotated order: LA-ML, LA with the existing
loading ridge, LA-MSPL, and the private MSPL-plus-ridge ablation. Only LA-MSPL
determines the quasi-complete point-estimation gate; the other arms describe
the numerical landscape and ridge redundancy.

### P — performance measures

A cell passes only when the trait-1 certificate is exact in every replicate,
the LA-MSPL usable rate is at least 0.99, its one-sided 95% Wilson lower bound
is at least 0.98, every retained usable fit has scaled gradient at most
`1e-4`, no fit contacts a boundary or clamp, and all usable fits satisfy the
frozen multistart objective and covariance tolerances. Every attempt and
failure remains in the denominator. Binomial MCSE is reported for the usable
rate.

This ADEMP amendment follows Morris, White, and Crowther (2019, *Statistics in
Medicine* 38:2074–2102) and the transparent-reporting checklist of Williams et
al. (2024, *Methods in Ecology and Evolution* 15:1926–1939). Its scope is
deliberately narrower than the main campaign: it supplies the missing
quasi-complete numerical stratum and does not license general inference.
