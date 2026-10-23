# Pat applied-reader review — covariance teaching

**Verdict: P2 before the permitted article renders.** Source-only review of
`git diff da6398a9` for the three approved articles. No R, fitting,
compilation, rendering, source edit, or git write was performed.

## One actionable reader finding

- **P2 — spatial counterexample needs to say that the two diagonal companions
  differ.** `vignettes/articles/spatial-models.Rmd:382` says, “Positive diagonal
  Psi values can bring both totals to `(3,3,3)`.” An applied reader can reasonably
  read this as one common Psi vector, which would defeat the point of the
  counterexample. Replace it with: “Adding a *different* positive diagonal
  Psi to each decomposition can bring both total diagonals to `(3,3,3)`.”
  This preserves the mathematical example while making the structural
  non-uniqueness legible.

## Passed reader checks

- The `eval = FALSE` wide calls are labelled structural translations, and each
  relevant article says it does not demonstrate long/wide parity:
  `covariance-correlation.Rmd:531-543`,
  `cross-family-correlations.Rmd:384-399`, and
  `spatial-models.Rmd:330-351`.
- The distinction between an estimated between-unit Psi, an observation-level
  random effect, and a fixed family/link residual is clear; the OLRE discussion
  does not imply NB/Tweedie-plus-OLRE support
  (`covariance-correlation.Rmd:546-567`). The ICC text makes the useful point
  that only levels intended to carry shared cross-trait structure need
  `latent()` (`covariance-correlation.Rmd:452-466`).
- The cross-family page plainly identifies the one-number result as a
  residual-augmented latent-liability/model-scale association rather than an
  observed-response correlation, retains the ordinal-probit refusal, and limits
  the seeded known-truth comparison to teaching rather than recovery evidence
  (`cross-family-correlations.Rmd:350-356`, `401-405`, `425-448`).
- The four added/required alt texts identify the chart type, displayed quantity,
  and the direction needed to interpret it. They are meaningful as source text;
  rendered-page inspection remains owed by the parent.

## Render focus after the P2 wording fix

Confirm that the spatial equations at `spatial-models.Rmd:378-383` wrap without
obscuring the plain-language conclusion, and that the four alt strings appear
in the generated HTML as intended.

## Resolution check — 2026-08-31

**PASS.** The P2 is resolved at `spatial-models.Rmd:382-383`: “Different
positive diagonal Psi companions” makes the required contrast explicit and
keeps the intended total-diagonal conclusion readable. The revised covariance
preamble also passes the applied-reader check (`covariance-correlation.Rmd:379-386`): it says that communality and ICC use the covariance specified by the model, confines the omitted-Psi warning to this nonzero-Psi worked DGP, and makes clear that an intentionally loadings-only covariance is a different model rather than an automatic error.

No additional findings were raised. The earlier render-focus check remains a
rendered-page verification item, not a source-review blocker.
