---
name: add-family
description: Add a new gllvmTMB response family with likelihood, simulation, tests, and documentation.
---

# Add a Distribution Family

Use this skill when adding a new response family to `gllvmTMB`.

## Required Outputs

- R family constructor in `R/families.R`.
- TMB density branch in `src/gllvmTMB.cpp`'s `family_id` switch.
- The family's integer slot must be added to the engine map in
  `R/fit-multi.R` (around line 33-99) so the parser dispatches to it.
- Simulation support in `R/simulate-site-trait.R` (or in
  `simulate.gllvmTMB_multi`) when relevant.
- Parameter-recovery tests under `tests/testthat/`.
- Documentation in `R/families.R`'s shared `@rdname families` block.
- Update to `docs/design/02-family-registry.md` (the canonical list of
  what the engine supports).

## Checklist

1. Define response dimension: per-trait univariate, or a delta-style
   pair of GLMs sharing a single column.
2. Define distributional parameters: mean, dispersion, shape, mix
   probability, etc. Decide which are estimated per-trait and which
   are shared.
3. Define links and inverse links. Fail loud (`cli::cli_abort`) if the
   user passes an unsupported link.
4. Define native parameter meanings. Document them in the family
   constructor's roxygen.
5. Define what `predict(type = "response")`, `fitted()`, and
   `simulate.gllvmTMB_multi()` return for the new family.
6. Define the variance rule or explain why no finite variance is
   available.
7. Define valid parameter bounds and the unconstrained internal scale
   (log for positive, atanh for correlations, etc.).
8. Write the likelihood on numerically stable scales (`dpois(...,
   log = TRUE)`, `dbinom(..., log = TRUE)`, etc.).
9. Add a starting-value strategy in `R/fit-multi.R` so the optimiser
   doesn't begin at NaN.
10. Add simulation tests for typical and boundary cases (see the
    `add-simulation-test` skill).
11. Add tests for link-scale predictions, response-scale predictions,
    and fitted-response summaries.
12. Add user-facing documentation including a one-paragraph "When to
    use this family" gloss and a `\examples{}` block.

Do not add families just because they are available elsewhere.
Families should serve a clear multivariate / stacked-trait use case.
