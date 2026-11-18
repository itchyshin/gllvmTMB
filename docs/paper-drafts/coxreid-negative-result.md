<!--
Evidence-chapter draft section for the gllvmTMB methods paper.
No manuscript directory (docs/paper/, paper/, ms/, .tex, .qmd with manuscript
frontmatter) exists in this repository as of this writing; this file is a
standalone markdown draft pending a decision on manuscript format and
location. Convert headings/citations to the paper's eventual format
(LaTeX/Quarto) at integration time. Cross-references are left as HTML
comments naming the source file and are not yet resolved to paper section
numbers or a bibliography.
-->

# Restricted-likelihood corrections do not transfer: a pre-registered negative

<!-- source: docs/design/121-coxreid-validation-slice.md -->
<!-- source: dev/coxreid-ab/RESULTS.md -->
<!-- source: R/fit-multi.R (REML/Cox-Reid hypothesis-block comment, ~L2812-2841) -->

## Motivation

Small-cluster variance-component estimation under a Laplace approximation
carries two largely independent sources of bias: quadrature error in the
marginal likelihood, and a downward small-sample bias in the profile
likelihood for the variance parameters once fixed effects are concentrated
out. Adaptive quadrature addresses only the first; Cox--Reid (1987)
adjusted profile likelihoods -- integrating, rather than profiling, the
fixed effects out as a nuisance block -- address the second. In a
cross-repository comparison on a cumulative-logit ordinal model (40 seeds,
against `glmmTMB`/`glmer`/`lme4`), the two corrections composed: plain
Laplace carried a −7.3% bias in the random-effect standard deviation,
adaptive quadrature alone narrowed this to −5.0% with the node sweep
plateauing flat, and adding the Cox--Reid adjustment narrowed it further to
−0.9%. This motivated testing whether the same adjustment reduces bias in
the latent-variable standard deviation of a stacked-trait GLLVM.

Two caveats were stated as reasons the transfer might fail, not discovered
after the fact (Reid & Fraser 2003): the adjustment is strictly justified
only when the parameter of interest is orthogonal to the nuisance block,
and it is not invariant to reparametrising that block. In an ordinary
mixed model this is usually academic, since the parameter of interest is a
single scalar SD. In gllvmTMB's parameterisation, variance instead lives in
a loading matrix and a diagonal residual covariance -- a structural
difference that makes both caveats live rather than theoretical.

## Pre-registered design

An opt-in, unvalidated route already existed
(`allow_nongaussian_reml = TRUE`) realising the Cox--Reid likelihood for
non-Gaussian families. Before any evidence was collected, a validation
slice was pre-registered: the estimand (bias in the latent SD against known
simulation truth -- agreement with plain Laplace was explicitly rejected as
an oracle, since Laplace's own bias is what is under test), the design (two
arms, Laplace-ML versus Laplace + Cox--Reid; families `binomial` and
`ordinal_probit` on a probit link, since the package has no logit
cumulative-ordinal family matching the motivating result exactly; `T` in
{4, 8}; `n` in {100, 200}; one latent dimension), and four kill criteria:
**K1** (no effect) — a bias reduction under 2 percentage points at `n=100`
in both families kills the hypothesis; **K2** (non-invariance) — a sign
flip or >3-point difference between two nuisance-block parametrisations
demotes the approach to a curiosity; **K3** (ridge confounding) — an effect
that vanishes once the loading-ridge penalty is equalised across arms is
attributed to regularisation, not the estimator; **K4** (interval harm) —
point-bias improvement bought with coverage degradation is not
recommended. An MCSE governance clause required every threshold to clear
roughly twice its achieved MCSE before adjudication, or be reported as
underpowered.

## What ran

The full campaign ran arms A and B only: 1,600 fits (both families, both
trait counts, both sample sizes, 100 seeds/cell), ridge held off and
identical in both arms. Convergence was 100% (800/800) in both arms. A
third (quadrature) arm and a fourth (reparametrisation) arm were part of
the pre-registered design but not run; K2 and K3 as formal tests remain
open.

## Result: K1 fires

At the pre-registered gate, the adjustment did not reduce bias. Median
absolute bias in the latent SD moved from 7.26 to 10.84 percentage points
for `binomial`, and from 3.08 to 4.39 for `ordinal_probit` — reductions of
−3.58 and −1.31 points, both the wrong sign and short of the 2-point bar.
Every one of eight family × trait-count × sample-size cells showed the
adjusted arm's bias equal to or larger than the baseline's.

The MCSE clause mattered unexpectedly. The literal spec statistic (SE of
the mean paired difference) did not clear 2 points in either family,
because a degenerate/runaway tail — concentrated in `n=100` cells, and more
common under the adjustment (36 versus 22 runaway fits of 1,600, ~4.5%
versus ~2.75%; an observed asymmetry we report without a causal claim,
though it runs in the direction of the pre-registered concern about
enlarging the random vector) — inflated it by two orders of magnitude. Because the median was the pre-specified
primary metric for exactly this reason, its bootstrap MCSE was reported
instead, clearing the governance bar by 22–53×: the null is well-powered,
not a coin flip.

## Why a clean death is informative

The design turned a possibly ambiguous outcome into an unambiguous one: a
threshold fixed before the data existed was crossed in the negative
direction with adequate precision. The substantive reading is structural,
not accidental. Cox--Reid's benefit in the motivating comparison arose
where the interest parameter is a scalar SD, comfortably separated from
the fixed-effect nuisance block. In gllvmTMB's parameterisation the
analogous variance lives jointly in a loading matrix and a diagonal
residual covariance, and Reid and Fraser's own caveats — orthogonality is
not automatic, and the adjustment is not invariant to how the nuisance
block is written — are exactly what a change of parameterisation could
break. This campaign did not test either caveat directly (K2's
reparametrisation arm was not run), so it cannot say which mechanism is
responsible. What it establishes is narrower and firmer: the benefit
measured elsewhere does not follow the likelihood family alone into this
model class. Whether the parameterisation is the responsible mechanism is
precisely what the untested reparametrisation arm would adjudicate; here
it remains the leading explanation, not a demonstrated one.

## Scope

Scoped narrowly: `n` in {100, 200}, `T` in {4, 8}, one latent dimension,
two families (ordinal on a probit, not logit, link), one ridge setting
held equal and off. K2 (non-invariance) and K4 (interval coverage) remain
genuinely open, not resolved either way. No promotion decision follows:
the non-Gaussian Cox--Reid route stays opt-in and unvalidated; this
evidence is one input against promoting it further, not a formal closure.
