# Cross-family LV predictor bridge: engine and evidence audit

Date: 2026-08-27
Audited base: `a7b75f75dac2b5c23525afdfec26abbaf59aab16`
Lane checkpoint: `6500ea624`

## Automatic-Psi rank-identifiability alignment

For `P` physical response rows after any verified multinomial contrast
expansion, `L` logical responses, latent rank `K`, and `Q` latent-predictor
columns, the lower-triangular loading
constraint leaves

\[
p_\Lambda = PK - K(K-1)/2
\]

free loading parameters after removing rotational degrees of freedom. The
predictor coefficient matrix contributes `p_alpha = KQ` parameters. The
observable rotation-invariant pair is `B_lv = Lambda alpha^T` plus the total
covariance, with at most

\[
p_{B,\Sigma} = PQ + P(P+1)/2
\]

distinct coordinates. An automatic trait-specific diagonal companion contributes
one parameter for each Psi slot the engine actually estimates (`p_Psi = 1`
when `common = TRUE` and at least one slot is free). Single-trial binomial and
multinomial slots are mapped off; pure ordinal/delta fits drop the automatic
companion. A necessary joint mean-covariance dimension condition is therefore
`p_Lambda + p_alpha + p_Psi <= p_B,Sigma`. The logical count `L` is used only
for the public rank cap `K <= L`; it must not replace the physical engine
dimension `P` in parameter accounting.

| Symbol in prose | Keyword / covstruct | DGP draw | Recovery extractor | Truth / gate |
|---|---|---|---|---|
| `Lambda` | `latent(..., d = K)` | `e_i` enters through `Lambda e_i` | `extract_Sigma(part = "shared")` | `p_Lambda = PK - K(K-1)/2`; `P` includes verified multinomial contrasts |
| `alpha` | `lv = ~ x` | `M_i alpha` | internal `alpha_lv_B`; interpreted through `B_lv` | `p_alpha = KQ`; raw axes are not cross-fit targets |
| `Psi` | automatic `latent(..., unique = TRUE)` companion | trait diagonal innovation | `extract_Sigma(part = "unique")` | one per engine-free slot, or 1 with `common = TRUE`; structural binary/multinomial slots are excluded |
| `Sigma` | automatic-Psi total | `Lambda e_i + epsilon_i` | `extract_Sigma(part = "total")` | contributes `P(P+1)/2` observable coordinates |
| `B_lv` | `lv = ~ x` | `M_i alpha` | `extract_lv_effects(type = "trait_effect")` | contributes `PQ` observable coordinates; `B_lv = Lambda alpha^T` is rotation invariant |

The loadings-only `unique = FALSE` route has `p_Psi = 0` and retains the
existing rank bound `K <= L`. Passing this necessary dimension gate is not a
general identifiability, recovery, or interval-calibration certificate.
Status: pre-implementation receipt; no scientific fit was run

## Verdict

The cross-family correlation model and its extractors already exist. The new
work is a predictor-informed admission and evidence bridge, not a new
correlation implementation.

At the audited base, the TMB parameterization is already rank-generic:
`alpha_lv_B` is an `n_lv_B` by `d_B` matrix, the template constructs every
column of `U_B_total`, and it reports and ADREPORTs
`B_lv_unit = Lambda_B %*% t(alpha_lv_B)`. The linear predictor consumes the
total mean-plus-innovation score on every axis. The immediate defect exposed by
the RED contract is therefore the R-side exact-cell guard, subject to live-fit
verification.

This does **not** establish arbitrary all-family composition. Gaussian and
lognormal responses currently use the same scalar `sigma_eps`; that equality
must remain an explicit constrained model or be replaced by separate Gaussian
and lognormal family-scale slots before a general joint claim is allowed.

The integration adjudication selects the smallest backward-compatible repair:
`log_sigma_eps` remains the parameter name but becomes length two only when
Gaussian and lognormal coexist. Slot 1 is the Gaussian raw-scale SD and slot 2
is the lognormal log-scale SD. Pure-family and other mixed fits retain the
existing length-one contract, and repeated traits within one family retain the
package's existing shared within-family observation-scale parameter. This lane
does not claim a new per-trait residual-variance model.

## Symbolic contract

For unit `i`, latent dimension `d`, trait loading matrix `Lambda`, and unit-level
predictor row `M_i`,

\[
u_i = M_i\alpha + e_i,\qquad e_i\sim N(0,I_d),
\]

\[
\Sigma_{shared}=\Lambda\Lambda^\top,\qquad
R_{shared}=\operatorname{cov2cor}(\Sigma_{shared}),\qquad
B_{lv}=\Lambda\alpha^\top.
\]

The scientific cross-fit targets are `R_shared` and `B_lv`. Raw `Lambda`, raw
`alpha`, and signed latent scores are rotation-dependent and are not acceptance
targets. If ordinary `latent()` carries its diagonal companion, then total
unit-tier covariance is `Sigma_shared + Psi`; this does not change the
definition of either target above.

## Unequal-scale sentinel alignment

| Symbol in prose | R/TMB route | DGP draw | Recovery surface | Truth |
|---|---|---|---|---|
| `u_i = M_i alpha + e_i` | `latent(..., d = 2, unique = FALSE, lv = ~ x)` / `U_B_total` | `outer(x, alpha) + E`, `E_ik ~ N(0,1)` | total, mean, and innovation from `extract_ordination()` | exact score identity; raw signed axes are route-health only |
| `B_lv = Lambda alpha^T` | `B_lv_unit` | planted `Lambda` and `alpha` | `extract_lv_effects()` / `B_lv_unit` | planted rotation-invariant trait effects |
| `Sigma_shared = Lambda Lambda^T` | existing ordinary unit `latent()` | planted `Lambda` | `extract_Sigma(part = "shared", link_residual = "none")` | planted shared covariance and `R_shared` |
| `y_g | eta_g ~ Normal(eta_g, sigma_g)` | Gaussian rows, `log_sigma_eps[1]` in joint 0+3 fits | raw-scale Gaussian residual draw | joint `sigma_eps["gaussian"]` | `sigma_g`, deliberately unequal to `sigma_l` |
| `log(y_l) | eta_l ~ Normal(eta_l, sigma_l)` | lognormal rows, `log_sigma_eps[2]` in joint 0+3 fits | log-scale lognormal residual draw | joint `sigma_eps["lognormal"]` | `sigma_l`, deliberately unequal to `sigma_g` |

The equal-scale parity control evaluates the old and new density calculations
at the same parameter value. The unequal-scale sentinel is the acceptance test;
the parity control alone cannot prove that the pooled compromise is gone.

## Source pins

| Claim | Pinned source on audited base | Finding |
|---|---|---|
| Rank-generic predictor coefficient | `src/gllvmTMB.cpp:1049,1535-1564` | `alpha_lv_B` has `d_B` columns; all axes enter `U_B_total`; `B_lv_unit` is reported and ADREPORTed. |
| Total score enters every response | `src/gllvmTMB.cpp:2606` | The response predictor selects `U_B_total(s,k)` for every latent axis when predictor-informed LV is active. |
| Existing cross-family shared covariance | `vignettes/articles/cross-family-correlations.Rmd:188-214` | The reader workflow already fits five response families and extracts `part = "shared"` with no link residual. |
| Existing multinomial cross-block | `tests/testthat/test-cross-family-multinomial.R:144-166` | Gaussian plus multinomial fits and its shared covariance/correlation extractor route are already tested. |
| Default-Psi multinomial rule | `tests/testthat/test-cross-family-multinomial.R:235-259` | Automatic Psi works with mapped-off multinomial contrasts; an explicit diagonal companion is refused. |
| Current R admission fence | `R/lv-predictor.R:250-335` | Exact programme cells require one binomial link, rank one, loadings-only geometry, one covariance term, and complete responses; arbitrary mixtures are refused. |
| Shared continuous scale | `src/gllvmTMB.cpp:1018,2745-2805` | A single `log_sigma_eps` supplies both Gaussian and lognormal likelihood branches. |

## Independent review synthesis

- **Gauss + Emmy:** the rank bridge itself needs no C++ change, but the final
  all-family composition needs a backward-compatible length-one-or-two
  `log_sigma_eps` vector. Start with rank 2/3, complete response, one numeric
  predictor, ordinary unit-tier `latent()`, and existing family/link routing.
  Preserve the existing fences on masks, extra covariance blocks, fixed
  `X + X_lv`, transformed/multiple LV predictors, and mixed binomial links. Add
  a logical-response-rank check rather than counting expanded multinomial
  pseudo-traits.
- **Noether + Fisher:** old cross-family correlation evidence and old rank-1
  `B_lv` evidence do not prove joint recovery. The smallest new evidence must
  evaluate both `R_shared` and `B_lv` in the same retained attempts. Correlation
  intervals are not required for a point-estimate claim and should not be
  reopened. They preferred per-trait observation scales; integration retained
  the package's established within-family sharing contract because the stated
  goal changes family composition, not residual-variance saturation. The
  Gaussian/lognormal cross-family tie is still removed.
- **Rose + Grace:** until the ordered PR #1216/random-slope integration releases
  shared paths, only additive plan, test, driver, and artifact paths may change.

## RED receipt

Command:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-lv-cross-family-predictor-bridge.R", reporter = "summary")'
```

Measured wall time: 4.4 seconds. The rank-2 loadings-only and rank-3 automatic-Psi
contracts both failed at `R/lv-predictor.R:326` with the intended current guard:
“Arbitrary mixtures and duplicate-family trait shapes are not admitted.” The
explicit-Psi negative control passed. No production file had been edited.

## Next pre-run gate

After the ordered integration receipt and one rebase, the first live fit will be
one deterministic complete-response smoke, not a campaign. It must check finite
labelled `Sigma_shared`, `R_shared`, and `B_lv`, plus
`U_B_total = U_B_mean + innovation`. Its runtime projection must be recorded
before execution and must not exceed 30 minutes. Any larger recovery grid stops
after a measured pre-run receipt for explicit approval.
