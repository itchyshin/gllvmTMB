# Rose pre-publish audit — Gaussian REML contract and certificate funnel (2026-07-19)

**Verdict: FAIL for public promotion / release; PASS for the narrow source-contract
consistency check.** This is a release gate, not a statement that the Gaussian
REML certificate has been earned.

| Surface | What was checked | Evidence | Verdict |
| --- | --- | --- | --- |
| Code | `REML = TRUE` integrates only `b_fix`; the predictor-informed `lv` mean block `alpha_lv_B` is excluded rather than silently partially restricted. The observed design must have full rank and `n > p`. | `R/lv-predictor.R`, `R/fit-multi.R`; focused `gaussian-reml` and `lv-reml` tests | PASS |
| Method contract | Dense Patterson--Thompson restricted likelihood agrees with the TMB objective for ordinary `indep()`, `dep()`, and latent-plus-Psi fixtures, including a perturbed covariance parameter. | `tests/testthat/test-gaussian-reml.R`; `docs/design/03-likelihoods.md` | PASS |
| Article | ML remains the rank-selection estimator; REML is only a selected-Gaussian covariance refit. The article names the Gaussian-only exclusions and cites MIS-33. | `vignettes/articles/model-selection-latent-rank.Rmd`; temporary rendered copy `/tmp/gllvmtmb-model-selection-reml.html` | PASS |
| Reference text | The `REML` parameter and `reml_bridge()` companion error state the same all-Gaussian, unweighted, dropped-response, full-rank/positive-df, no-`mi()`/no-`lv`/no-`Xcoef_fixed` contract. | `R/gllvmTMB.R`, `R/reml-bridge.R`, `man/gllvmTMB.Rd` | PASS |
| NEWS | No release-note or "improves small-sample coverage" claim was added. | `git diff -- NEWS.md` is empty | PASS |
| Validation register | MIS-33 records engine/oracle coverage and explicitly distinguishes engine-admitted source/tier/slope forms from the absent 0.6 recovery certificate. LV-09 withdraws its invalid REML leg. | `docs/design/35-validation-debt-register.md` | PASS |
| pkgdown | `pkgdown::check_pkgdown()` still fails because `_pkgdown.yml` lacks the existing reference topics `kernel_scalar`, `reml_bridge`, and `scalar`. A full `pkgdown::build_articles(lazy = FALSE)` was attempted; targeted temporary rendering confirms the edited article, but the site as a whole is not clean. | local command output; `_pkgdown.yml` | FAIL (release blocker, outside this slice) |
| Release check | `R CMD check --as-cran` entered installation then its R subprocess was terminated by the local host (`Killed: 9`); full `devtools::test()` also has pre-existing visual-snapshot and Tweedie failures. | `/tmp/gllvmtmb-reml-check-live.HIOCEt/check.stdout`; `/tmp/gllvmtmb-full-test-20260719.log` | FAIL (no release rung) |
| Certificate admission | There are no 100/500/15,000 paired profile-interval shards, raw-replicate recomputation, conditional/unconditional denominators, MCSE, or fresh Fisher/Grace/Noether D-43 decisions. | `dev/reml-paired-funnel.R` pilot-only output and execution record | NOT DONE — WITHHOLD |

The following scans were run against the touched public surfaces:

```sh
rg -n "REML = TRUE|REML|MIS-33|non-Gaussian" R/gllvmTMB.R R/reml-bridge.R R/lv-predictor.R man/gllvmTMB.Rd vignettes/articles/model-selection-latent-rank.Rmd docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md
rg -n "gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/model-selection-latent-rank.Rmd R/gllvmTMB.R man/gllvmTMB.Rd
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/gllvmTMB.R man/gllvmTMB.Rd vignettes/articles/model-selection-latent-rank.Rmd docs/design/03-likelihoods.md
```

Verdict: the newly edited REML surfaces use the current names and do not present
non-Gaussian REML, `lv` REML, or an unearned coverage improvement as supported.
Existing compatibility references to `gllvmTMB_wide()` and `meta_known_V()` are
not changed by this slice and are not presented as the new primary API.

**Public-claim rule:** do not alter NEWS, README status, or release language
until a separately reviewed certificate has passed the predeclared coverage and
D-43 admission gates. The exact current release rung is **NOT READY**.
