# After-task — reconciled Gaussian REML contract

**Branch:** `codex/gaussian-reml-certificate-reconciled-20260719`  
**PR:** #768 (draft)  
**Outcome:** implementation contract landed for review; covariance-improvement
certificate and release promotion withheld.

## What changed

The Gaussian REML path now requires a full-rank observed fixed-effect design
with positive residual degrees of freedom. Predictor-informed
`latent(..., lv = ~ x)` fails loudly under `REML = TRUE`, because the existing
restriction integrates `b_fix` but not the additional `alpha_lv_B` mean block.
Dense Patterson--Thompson restricted-likelihood tests independently check
ordinary `indep()`, `dep()`, and latent-plus-Psi covariance representatives,
including a perturbed-parameter comparison. The latent-rank article, Rd, and
validation register state the same boundary.

## Evidence and gates

- Focused `NOT_CRAN=true` tests for `gaussian-reml`, `lv-reml`, and the
  dependent `diag-tier-alias` fixture pass.
- `pkgdown::check_pkgdown()` passes; the latent-rank article renders.
- Final `R CMD check --as-cran` has two vdiffr snapshot failures and the normal
  new-submission NOTE. The four earlier alias-fixture failures were removed by
  keeping that non-REML alias test on ML. No snapshots were accepted or changed.
- The separate paired profile screen is **WITHHELD**: its predeclared health
  and lower-confidence-band gate did not admit either target to 500-profile or
  15,000-replicate certification. Fisher, Grace, and Noether consequently did
  not admit a public improvement claim. The evidence record remains in closed
  PR #767, which was superseded only because its immutable-baseline history
  conflicted with protected current-main developer-log work.

## Scope and release status

No non-Gaussian REML, AGHQ, profile-coverage, or general covariance-improvement
claim is made. No `check-log.md`, Bartlett, CI-11, multinomial/tier-2a, or Ayumi
file was edited. The release rung is **NOT READY**: local snapshots and current
PR CI remain gates, independently of the withheld REML certificate.

## Review roles

Rose's pre-publish and D-43 admission records were completed for the evidence
run and withheld promotion. This reconciled branch additionally ran a
source-level stale-wording scan and pkgdown check; a final Rose closure awaits
the replacement PR's CI outcome.
