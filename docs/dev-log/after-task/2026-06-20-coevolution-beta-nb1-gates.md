# After-task — coevolution Beta + nbinom1 two-kernel recovery gates (COE-04)

**Date:** 2026-06-20 · **Author:** Claude (Ada) · **Branch:**
`claude/coevo-beta-nb1-gates-20260620` → PR · **Slice:** COE-04 non-Gaussian
recovery breadth (Design 65 C3).

## Scope / outcome

Extends the COE-04 non-Gaussian two-kernel recovery evidence with **nbinom1**
(linear-variance overdispersed counts, log link) and **Beta** (proportions in
(0, 1), logit link) gates, mirroring the existing Poisson / NB2 / Gamma cells in
`tests/testthat/test-coevolution-two-kernel.R`. Each gate fits a two-kernel
coevolution model (`kernel_latent` × 2 named tiers), confirms each component
recovers its **own** planted `Gamma_shape` (own cor > 0.95, cross < 0.15) and that
the two-component model beats either one-component fit (ΔlogLik > 15), over
calibrated clean-recovery seeds.

Test-only; no engine / grammar / export change.

## Family-specific DGP notes

- **nbinom1** (seeds 5201, 5202): NB1 variance is `mu(1 + phi)` — linear in `mu`,
  so at a given mean it carries less identifying information than NB2's
  `mu(1 + mu/size)`. The cell therefore uses a gentler DGP than the NB2 cell
  (dispersion 0.8, intercept 1.7, 14 reps) to keep recovery clean. Draw is
  `rnbinom(mu, size = mu / nb1_disp)` so the realised variance matches the NB1
  form; `family = nbinom1()`.
- **Beta** (seeds 6103, 6104): `rbeta(mu*phi, (1-mu)*phi)` with `mu = plogis(eta)`,
  precision `phi = 15`, `intercept = 0` (baseline mean 0.5, most informative);
  `family = Beta()`. Continuous and informative, so recovery is clean (unlike the
  binary-Bernoulli case, which is intrinsically uninformative for between-unit
  covariance).

Seeds were calibrated by a search over candidate seeds (the phy/non component
labels are seed-sensitive — the optimizer can swap which tier carries which
loadings — exactly as in the existing Poisson/NB2/Gamma cells).

## Checks (`GLLVMTMB_HEAVY_TESTS=1`, `NOT_CRAN=true`)

- `test-coevolution-two-kernel.R` — **472/0** (was 432; +40 from the two new
  gates × 2 seeds). New gates: nbinom1 **20/0**, Beta **20/0**. No regression to
  the existing 432.

## Register / promotion

Do **not** self-promote the COE-04 register row — that is a maintainer-gated
scientific-coverage decision. This slice adds evidence breadth (Poisson + NB2 +
Gamma + nbinom1 + Beta now covered); the remaining queued family is mixed-family
two-kernel recovery.
