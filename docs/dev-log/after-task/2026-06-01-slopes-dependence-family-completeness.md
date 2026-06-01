# After-task — slopes × dependence × family completeness audit

**Date:** 2026-06-01
**Author lens:** Claude Code
**Branch:** `claude/random-slopes-dependence-status-bHMFb`

## Scope

Maintainer asked "where are we now — all random slopes and all dependence
done for all families?" and to make the answer formal with a systematic
gap-closure plan. Read-only synthesis; no engine, grammar, family, or
likelihood code touched.

## Outcome

Added `docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md`:
a consolidated completeness view across the three axes (random slopes ×
dependence modes × families) plus a checkable gap tracker.

Key findings (grounded in Design 35 register + Design 61 capability
status, `origin/main` HEAD `3ef12df`):

- **Answer: no, not the full cross-product.** Intercept dependence and
  Gaussian slopes are broadly covered; non-Gaussian slopes are covered for
  the diagonal (`phylo_indep`) and block-diagonal (`phylo_latent`,
  `spatial_latent`) modes.
- **Concentrated open work**, not scattered: (a) non-Gaussian
  full-unstructured `dep` slopes are RESERVED on one shared
  identifiability question (GAP-B1/B2/B3/B5/B6); (b) two CI coverage
  gates failing (CI-08 Gaussian, CI-10 mixed-family → GAP-B7/B8);
  (c) a short tail of blocked/partial families (truncated/censored,
  mixtures, gengamma, delta/hurdle latent correlation).
- Gap tracker splits Track A (parallelizable: cross-package fixtures,
  hygiene) from Track B (maintainer-sequenced: engine/estimand/family).

## Checks

Documentation-only change. No tests run (no R behaviour changed). The
audit cross-references Design 35 row IDs; Design 35 remains the source of
truth where it disagrees.

## Follow-up / needs maintainer

- **Decision required:** the identifiability cluster (non-Gaussian
  unstructured `dep` slopes) is the single biggest "are we done" lever —
  invest in bigger-n recovery studies or formally reserve those modes.
  This must be sequenced before any engine code.
- Track A GAP-A1 (poisson cross-package fixture) and GAP-A2 (nbinom2
  cross-package fixture) are independent and can start immediately.
- Ratify Design 61 §1–§2 as the status reference (GAP-A7) and link this
  audit from it.
</content>
