# Cross-family LV predictor bridge: engine and evidence audit

Date: 2026-08-27  
Audited base: `a7b75f75dac2b5c23525afdfec26abbaf59aab16`  
Lane checkpoint: `6500ea624`  
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
must remain an explicit constrained model or be replaced by separately
identified family/trait scales before a general joint Gaussian-plus-lognormal
claim is allowed.

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

- **Gauss + Emmy:** no C++ change is justified for the first bridge. Start with
  rank 2/3, complete response, one numeric predictor, ordinary unit-tier
  `latent()`, and existing family/link routing. Preserve the existing fences on
  masks, extra covariance blocks, fixed `X + X_lv`, transformed/multiple LV
  predictors, and mixed binomial links. Add a logical-response-rank check rather
  than counting expanded multinomial pseudo-traits.
- **Noether + Fisher:** old cross-family correlation evidence and old rank-1
  `B_lv` evidence do not prove joint recovery. The smallest new evidence must
  evaluate both `R_shared` and `B_lv` in the same retained attempts. Correlation
  intervals are not required for a point-estimate claim and should not be
  reopened.
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
