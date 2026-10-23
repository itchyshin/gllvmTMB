# Cross-family article render pre-run receipt

Date: 2026-08-27

Candidate: dirty working tree above checkpoint `78530fcc78878a8c1234448f95dab11903dd92db`, rebased onto verified main `870944744ff090fe8676e853ebc03957204571c0`.

## Work and estimate

The evaluated article performs two related local fits: a five-family
Gaussian/binomial/Poisson/ordinal/multinomial rank-3 loadings-only
predictor-informed model
with 500 units and six observations per unit, followed by the same model
without the ordinal response for the reference-invariant nominal summary.

Measured lower-bound evidence is the retained five-family rank-3 canary
(8.58 seconds at its small route-health size) and the rank-2/rank-3 pair
(18.76 seconds total). Scaling conservatively for the larger replicated article
fixture gives an estimated local runtime of **8--25 minutes**. This is below
the 30-minute local gate. Stop and re-report if elapsed time reaches 30 minutes.

## Correctness smoke

The render passes only if:

- both fits return without an error;
- the reported `B_lv` table is finite and name-aligned to the six pseudo-traits;
- the shared covariance and correlation matrices are finite and name-aligned;
- the ordinal automatic-summary refusal is retained;
- the reference-invariant non-ordinal summary is returned; and
- the rendered HTML exists and is non-empty.

The render is documentation verification, not a recovery or calibration
campaign. Every failed attempt is retained in the lane check record.

The first render used the automatic-Psi spelling. An initial covariance-only
review classified that shape as over-parameterised, so the lane conservatively
rerendered the article with `unique = FALSE`. A later joint mean-covariance
audit corrected the classification: the six-physical-row shape passes the
necessary dimension screen, but that screen is not recovery or calibration
evidence. Both render attempts remain preserved; the loadings-only article is
retained because its scientific target is the shared covariance.

## Result

PASS. The evaluated render completed in approximately 2.5 minutes, well below
the 30-minute stop line, and wrote
`/private/tmp/gllvmtmb-cross-family-article/cross-family-correlations.html`
(92,886 bytes). The main fit reported convergence code 0 and positive-definite
Hessian status. The rendered six-row `B_lv` comparison was finite and correctly
labelled (`g`, `b`, `p`, `o`, `cat:2`, `cat:3`); the covariance comparison was
finite; the ordinal automatic-summary refusal appeared verbatim; and the
non-ordinal reference-invariant summary returned finite values for Gaussian,
binomial, and Poisson partners.

## Conservative loadings-only rerender

After the initial automatic-Psi review, the loadings-only evaluated render
completed in approximately 1.5 minutes and wrote
`/private/tmp/gllvmtmb-cross-family-article-repair/cross-family-correlations.html`
(93,452 bytes). The main fit again reported convergence 0 and `pdHess = TRUE`.
The six labelled `B_lv` rows, shared correlations, ordinal refusal, and
non-ordinal reference-invariant summary were present and finite. This
loadings-only render remains the landing article because it isolates the shared
covariance; the earlier attempt remains recorded above rather than being erased.

## Joint-screen wording rerender

After correcting the parser to count the joint observable pair `(B_lv,
Sigma)`, the exact-current-source article rendered again in approximately two
minutes to
`/private/tmp/gllvmtmb-cross-family-article-joint-gate/cross-family-correlations.html`
(93,589 bytes). The main fit reported convergence 0 and `pdHess = TRUE`; all
six labelled `B_lv` rows were finite, shared correlations were present, the
ordinal refusal was retained, and the non-ordinal reference-invariant summary
remained finite. The rendered prose now says the automatic-`Psi` shape passes
only a necessary dimension screen and deliberately retains the loadings-only
teaching fit. This third attempt supersedes the wording of the two earlier
renders without deleting their receipts.
