# Symbolic alignment and estimand freeze

Status: candidate freeze pending independent method approval and post-coefficient
source qualification. No fit result may silently change these estimands.

## Nonspatial public-route model

For cell (c), trait (t \in \{1,2,3\}), and source (d\), define

\[
\eta_{ct}=\alpha_t + \beta_t x_c + \lambda_t u_c + e_{ct},\qquad
u_c\sim N(0,1),\quad e_{ct}\sim N(0,\psi_t).
\]

The shared cell covariance is

\[
\Sigma=\Lambda\Lambda^\mathsf{T}+\Psi,\qquad
\Psi=\operatorname{diag}(\psi_1,\psi_2,\psi_3).
\]

Each source observes the same relative intensity after its declared observation
process (q_{cd}=\gamma_d+\delta_d b_{cd}):

\[
Y_{ctd}\sim\operatorname{Poisson}\{a_{cd}\exp(\eta_{ct}+q_{cd})\}
\]

for count arms, and

\[
Y_{ctd}\sim\operatorname{Bernoulli}
\left[1-\exp\{-a_{cd}\exp(\eta_{ct}+q_{cd})\}\right]
\]

for the complementary-log-log arm. Source 1 is the count anchor. The final
source is the detection arm; an optional middle source is another count arm.
Every source is declared with `isdm_source(law, observation = ~ bias_x)`.

| Equation | DGP draw | Public R formula/declaration | Fitted target | Extractor/score | Frozen comparison |
|---|---|---|---|---|---|
| \(\alpha_t\) plus source intercept contrast | fixed ecological and observation intercepts | `0 + trait` plus observation-formula intercepts | QR reference-coded named `b_fix` columns | project the complete true fixed predictor through the exact fitted `X_fix`; require residual <= `1e-8` | per-column absolute bias and RMSE; raw alpha/gamma are not compared separately |
| \(\beta_t\) | fixed ecological slope | `trait:env` | named `b_fix` interaction columns | fitted design names | absolute bias and RMSE |
| \(\delta_d\) | source bias slope | `isdm_source(..., observation = ~ bias_x)` | named source-masked `b_fix` columns | exact fitted `X_fix_names` after QR coding | per-column absolute bias and RMSE |
| \(u_c,\lambda_t\) | one shared Gaussian score and loadings | `latent(0 + trait \| cell_id, d = 1)` | rotation-dependent internals | never interpreted raw | only their implied covariance and centered surface count |
| \(e_{ct},\psi_t\) | independent trait cell effect | ordinary `latent()` diagonal companion | \(\Psi\) | square the fitted `sd_B`; TMB stores log-SD, not variance | each trait's median relative error must pass |
| \(\Sigma\) | \(\Lambda\Lambda^T+\Psi\) | ordinary latent covariance | total trait covariance | `extract_Sigma(..., part = "total")`; `report$Sigma_B` alone is shared-only | median relative Frobenius error |
| \(\eta_{ct}\) | ecological predictor before support and source bias | public `predict(..., type="link")` with source effect and offset neutralized for scoring | relative-intensity surface | center within trait | correlation and normalized RMSE |

For every named target, availability must be at least 0.85 on the all-attempt
denominator. Availability requires a valid truth binding, an eligible fit, and
a finite correctly named estimate. Bias and RMSE use available records only;
missing records never pass. Coefficients are gated separately. The weak/full
RMSE ratio uses attempt-matched seeds where that target is available in both
regimes, while both regimes retain their separate all-attempt availability.
The full and weak attempts keep unique registered attempt seeds but share one
recorded structural seed for the ecological covariate, latent effects, truth,
and source-bias surfaces; observation draws use the unique attempt seed.

Full overlap observes every source over every cell. Weak overlap assigns
source-specific windows with a preregistered common bridge, so the source graph
is connected but weakly supported. The disconnected slice assigns disjoint cell
blocks. Disjoint blocks are not automatically non-identifiable: distributional
and shared-slope assumptions can still identify parameters. It is therefore a
retained stress result whose recovery and diagnostic behavior are reported
separately; it cannot promote the ordinary model and is not required to refuse.

## Spatial held-out public-route model

For location (s\),

\[
\eta_t(s)=\alpha_t+\beta_t x(s)+\lambda_t w(s),
\]

where (w(s)) is one Matérn field represented by the fitted SPDE mesh. The
public fit uses

```r
value ~ 0 + trait + trait:env + offset(log_support) +
  spatial_latent(0 + trait | coords, d = 1)
```

with `mesh =` and the same `isdm_sources()` declaration. Twenty per cent of
unique generating coordinates are withheld inside the mesh hull, including all
traits and all source rows at each withheld coordinate. Point-map scoring supplies
anchor-source `newdata` with `log_support = 0` and `bias_x = 0`, so predictions
are observation-process-neutral, effort-free relative intensities. A separate
all-source held-out grid tests row-wise family/link dispatch without entering
the ecological map score. No SPDE slope, phylogenetic tier, kernel tier, or
structured-source latent term is admitted.

| Quantity | Oracle | Gate interpretation |
|---|---|---|
| Training-row eta | `predict(fit, newdata = training)` versus in-sample eta | deterministic identity, maximum error at most `1e-10` |
| Row response scale | Poisson rows use `exp`; cloglog rows use `-expm1(-exp(.))` | every eligible row must use its declared source law |
| Held-out eta | known DGP eta at withheld in-hull coordinates | centered per trait; correlation and normalized RMSE |
| Out-of-hull rows | zero SPDE basis row | documented classed warning on every request |

## Marginal SPDE map interval

The later interval route, if the spatial point gate passes, draws fixed effects,
loadings, and the SPDE field jointly from a usable sparse TMB joint precision.
For each of `nsim = 1000` draws it recomputes the nonlinear loading-field
product, then takes empirical 0.025 and 0.975 type-1 order-statistic quantiles
of eta. Response-scale
bounds are the monotone inverse-link transforms of those link-scale endpoints.

One preregistered interior coordinate is evaluated for each species in each
replicate. Species-specific coverage uses 600 independent replicate indicators
per cell; spatial-average secondary summaries use a cluster bootstrap by
replicate. Coverage is conditional among finite ordered intervals, while
availability is separately gated on all attempts. The Wilson 90% acceptance
interval is applied species by species,
not to a pooled pseudo-independent species total. This interpretation preserves
the approved Wilson gate while respecting within-replicate cross-species
dependence.

## Explicit non-estimands

Raw latent axes, unaligned loadings, absolute abundance, occupancy,
detectability, an “average-level” confidence interval, an observation prediction
interval, a new exchangeable-level interval, SPDE slope intervals, and per-axis
LV intervals are outside this programme. The joint-draw implementation must
extract the marginal covariance from the relevant block of the full inverse
precision; it must not invert the corresponding precision submatrix.
