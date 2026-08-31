# Noether final mathematical review

Review scope: the approved `PLAN.md` and the five-file diff from
`da6398a9d8df78c04dc4645dfa3fd4c3bd8d75e3` on
`codex/covariance-teaching-20260831`. This is the one final source review before
the permitted article renders. No source files were edited; no R, fits,
compilation, rendering, or simulation was run. Line numbers below refer to the
reviewed working-tree source.

## Final verdict: PASS within the approved scope

The one P2 raised below was addressed by the parent during this same review
round. Source inspection confirmed that `covariance-correlation.Rmd:379–386`
now distinguishes the intended covariance/decomposition from a universally
required Psi, and lines 410–415 condition communality interpretation on the
chosen decomposition and its identifiability. No actionable P1/P2 remains in
the approved five-file scope. This closure is source inspection only, not
another fit or validation round.

The spatial wording at `spatial-models.Rmd:382–383` now also explicitly says
that different positive Psi companions bring each total diagonal to `(3,3,3)`;
this is mathematically correct.

## Finding retained for provenance: addressed

**[P2, addressed] Qualify the blanket claim that a loadings-only fit gives the wrong
summary.** `vignettes/articles/covariance-correlation.Rmd:381–385` still says
both summaries require the full decomposition and that computing them from a
no-residual fit gives the wrong answer. This conflicts with the corrected ICC
explanation at lines 460–466: an ICC requires the appropriate covariance at each
participating level, not a universally mandatory nonzero Psi or shared-factor
decomposition. A deliberately specified loadings-only covariance can be the
intended model; its communality is one by construction, not a numerical error.
Scope the warning to the worked example's nonzero Psi, for example:

> Communality uses the chosen shared/diagonal decomposition, whereas the ICC
> uses the appropriate variance at each participating level. In this worked
> example the generating covariance contains nonzero Psi, so omitting that
> component changes the intended variance partition and can distort these
> summaries.

The neighbouring statement at lines 409–413 that adding a Psi slot makes
communality informative should likewise be conditional on an interpretable,
identified decomposition; the new qualification at lines 52–58 correctly
explains why rotation invariance alone is insufficient.

This is a prose-only correction. It does not require a new fit, changed model,
changed estimand, or changed calculation.

## Checked mathematical claims

- **Spatial ambiguity: PASS.** `spatial-models.Rmd:368–385` correctly separates
  rotation invariance from uniqueness of the shared/diagonal split, identifies
  total spatial covariance as the target, and makes no guarantee of estimator
  stability. The paragraph at lines 386–393 retains the bounded evidence claim.
- **Residual-augmented association: PASS.**
  `cross-family-correlations.Rmd:401–405,425–440` and
  `R/extract-correlations.R:809–825` now identify the summary as a
  latent-liability/model-scale association, not observed-response correlation.
  The false automatic-commensurability claim was removed from the changed help
  block. The covariance formula at R lines 796–801, the `extract_Sigma()` call at
  line 938, and the ordinal-probit refusal at lines 923–935 are preserved;
  only the first diagnostic sentence changes. The reviewed Rd parameter text
  agrees with this source.
- **ICC choice: PASS**, including the inspected resolution of the P2 above.
  `covariance-correlation.Rmd:460–466,506–529` permits `latent()` where shared
  covariance is intended and `indep()` where the tier is diagonal. The two-level
  example is explicitly a chosen structure, not a general ICC requirement.
- **Psi, OLRE, and family/link residual: PASS.**
  `covariance-correlation.Rmd:479–485,548–567` distinguishes the components,
  retains the named binary residual conventions and Poisson OLRE illustration,
  and does not claim NB/Tweedie-plus-OLRE support or identifiability.
- **Seeded evidence: PASS.** `cross-family-correlations.Rmd:61–72,323–332,442–448`
  describes one known-truth realization, allows sampling, estimation, and
  optimization discrepancies, and avoids repeated-simulation recovery or
  sample-size guarantees. The corrected conditional model at lines 92–105
  consistently uses `z_i`.

## Exact manual counterexample check

For the first loading matrix, its Gram matrix has diagonal
`(1, 5/4, 1/2)` and off-diagonal entries `(1/2, 1/2, 3/4)`.
For the second, the diagonal is `(2, 9/8, 33/64)`; its last off-diagonal is
`1/8 + 5/8 = 3/4`, and the other two are each `1/2`. Both matrices have
rank two because their first two loading rows are linearly independent.

The respective diagonal Psi vectors
`(2, 7/4, 5/2)` and `(1, 15/8, 159/64)` are strictly positive. Both yield

```
Sigma = [ 3    1/2  1/2 ]
        [ 1/2  3    3/4 ]
        [ 1/2  3/4  3   ].
```

An orthogonal rotation preserves the entire loading Gram matrix. Since these
Gram diagonals differ, the two decompositions cannot be related solely by
rotation or sign change. Their communalities differ as well:
`(1/3, 5/12, 1/6)` versus `(2/3, 3/8, 11/64)`.

## Preserved boundaries

The reviewed diff changes no evaluated fit body, DGP, seed, rank, uniqueness
choice, optimizer, extractor calculation, or estimand. Added wide patterns are
explicitly `eval = FALSE` and explicitly disclaimed as parity evidence:
`covariance-correlation.Rmd:88–103,531–544`,
`cross-family-correlations.Rmd:384–399`, and
`spatial-models.Rmd:330–351`. This review does not establish execution success,
long/wide numerical parity, simulation recovery, interval calibration, or
rendered-page correctness; those remain the parent's separately approved gates.

## Deferred neighbour outside the approved scope

The unchanged `R/extract-sigma.R:545–548` still says the softmax residual makes
the categorical block commensurable with any single-scale trait, whereas its
own lines 505–509 correctly require additional scientific assumptions. The
parent has been informed and will retain this as a separate documentation
follow-up. It was not edited or promoted into an additional gate for this
five-file slice.
