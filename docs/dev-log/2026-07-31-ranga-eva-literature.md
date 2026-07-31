# EVA literature review — what the corpus says, and what it does not

**Date:** 2026-07-31. **Author:** Ranganathan (Ranga), grounded-research librarian.
**Corpus:** NotebookLM notebook `b25e6c9f-500b-43da-8487-6430ce01d09b`, "GLLVM estimation
engines — VA, EVA, AGHQ, penalised Laplace" — 32 sources at session start, extended to 39
during this run (added: the EVA paper's actual full text, Korhonen's 2020 thesis record,
Niku et al. 2019 PLOS ONE full text, three current `gllvm` CRAN/vignette pages). Every
numbered finding below was read from primary-source full text I fetched and grepped myself,
or verified against it — not taken on NotebookLM's `ask()` say-so alone (per the standing
guardrail that NotebookLM answers can hallucinate or mis-attribute).

**Self-citation check:** every source is third-party. The corpus is built around the `gllvm`
R package (Niku, Hui, Warton, Taskinen, Korhonen, van der Veen et al.) and independent
groups benchmarking it (Mauri & Dunson, Duke; Batardière/Chiquet/Mariadassou, INRAE;
Giordano/Broderick/Jordan; Polson/Scott/Windle). None is Shinichi Nakagawa's or gllvmTMB's
own work. No exclusions were needed.

**Relationship to concurrent project work:** two same-day files already exist in this
worktree — `docs/dev-log/2026-07-31-eva-literature-correction.md` (a prior lane's partial
literature pass on the same notebook, which found the same headline quote answered in Q2
below) and `docs/dev-log/2026-07-31-eva-misuse-probe.md` (Gauss's numerical re-derivation of
the measurement itself). Both are **internal project analysis, not literature** — I treat
them as context for the final section only, clearly separated from corpus findings.

---

## Q1. What exactly did the EVA paper(s) demonstrate, and under what conditions?

**The paper.** Korhonen, P., Hui, F.K.C., Niku, J., & Taskinen, S. (2023). "Fast and
universal estimation of latent variable models using extended variational approximations."
*Statistics and Computing*, 33, Article 26. DOI `10.1007/s11222-022-10189-w`. Open access
(CC BY 4.0). I fetched the actual full text (not just the abstract page) from the JYX
repository bitstream.

**Simulation design, verbatim:**

> "Two main simulation settings were considered, with the intention of covering both the
> scenarios where m ≪ n... and those where m ≫ n... In the first setting, we generated
> multivariate data with four possible response types (overdispersed counts, binary,
> semi-continuous, and proportional data) based on GLLVMs fitted to the testate amoebae
> data... In the second simulation setting, we generated multivariate data again with the
> above four possible response types, but this time based on GLLVMs fitted to a dataset
> containing species of birds recorded across Borneo."

Setting 1 exact sizes:

> "The original testate amoebae data consisted of count records of m = 48 species at n = 263
> sites across Finland. All GLLVMs fitted to the data included q = 2 environmental covariates
> (water pH and temperature) and p = 2 latent variables... We varied the number of units as n
> = 50, 120, 190 and 260... We simulated 1000 datasets for each value of n."

Setting 2 (Appendix B, not in the main-text extract I could pull, but referenced): fixed n,
increasing number of responses m, based on the Bornean bird dataset (m = 177 species at n =
37 sites in the original data).

Four response families, each compared against a different subset of competitors because
standard closed-form VA is only sometimes available:

> "1. Overdispersed counts simulated from a negative binomial GLLVM... compared... to those
> fitted using standard VA, LA, VA-GH and MCMC... 2. Binary responses... These binary GLLVMs
> used either a probit link (fitted using the standard VA approach) or the logit link (fitted
> using the LA approach)... Standard VA was excluded from the simulations involving a logit
> link binary GLLVM, as per the discussion in Sect. 4.2. In place of VA, comparisons involving
> the logit link used VA-GH with either 5 or 9 quadrature points. 3. Semi-continuous responses
> simulated from a Tweedie GLLVM... Standard VA was again excluded... 4. Proportions data
> simulated from a beta GLLVM... Standard VA was again excluded."

**Metrics reported — and yes, the loadings/latent covariance WAS among them:**

> "To assess performance, all methods were compared in terms of: (1) the empirical bias and
> the empirical root mean squared error (RMSE) of the regression coefficients and the
> dispersion parameters... (2) the corresponding empirical coverage probability of 95% Wald
> confidence interval (CI)... (3) the Procrustes error between the predicted and true n×p
> matrices of latent variables, and similarly between the estimated and true m×p loading
> matrices... (4) average computation time in seconds."

So: **bias/RMSE/coverage were computed for B (and dispersion parameters), not for Λ or
Σ = ΛΛᵀ.** The loadings matrix Λ was assessed, but only via **Procrustes error** — a
rotation-and-scale-aligned distance between the estimated and true loading matrices, borrowed
from the ordination literature. **Σ = ΛΛᵀ itself (the raw, unaligned trace or the object our
own measurement calls `Sigma`) is never named or reported as a target in this paper.**
Procrustes alignment answers "did we recover the right factor structure up to rotation," not
"is the point estimate of the structural covariance the right scale" — these are different
questions, and the paper only answers the first for Λ.

**Result for the response family that matches ours (binary, logit link):**

> "Next, for the binary GLLVM with logit link, the computation times are presented in Fig.
> 1b. Again, EVA was clearly the fastest of all the methods... In terms of empirical bias and
> RMSE, EVA generally performed much closer to VA-GH than LA, the latter of which seemed to
> struggle on all but the largest sample size... Figure 3c presents the empirical coverage
> probabilities for the coefficients of pH, indicating that both EVA and LA tended to
> undercover a small amount."

This is about **B** (the pH regression coefficient), not Λ or Σ. Nothing quantitative on Λ's
Procrustes error specifically for the logit case survived into the main-text excerpt I could
pull (it is tabulated in "Appendix B.1," which is supplementary and not part of the fetched
text).

**One passage matters more than any of the metrics above** — the paper's own Discussion
names an unresolved, self-reported covariance problem:

> "Finally, the fact that in EVA we underestimate the latent variable posterior covariances
> even more than in standard VA requires careful consideration. The potential use of
> bootstrap-based methods to overcome this issue, as suggested in Dang and Maestrini (2021),
> will be considered in future."

Read this precisely: it is about the **posterior/variational covariance of the individual
predicted latent scores** (the per-observation matrix Aᵢ used for prediction regions), not
about Σ = ΛΛᵀ (the population-level structural covariance implied by the loadings, a point
estimate). It is also **underestimation**, the opposite direction from a 10⁷–10⁹-fold
overestimate. It is genuine, author-acknowledged evidence that EVA has a covariance-related
weakness beyond VA's — but it is not a direct hit on the specific object or the specific
direction our measurement reports. See the final section for how these connect.

---

## Q2. Does the corpus report EVA's accuracy for the loadings/latent covariance specifically, as opposed to B?

**Yes — and I traced the pre-supplied quote to its primary source and verified the numbers
behind it.** The source is Mauri, L. & Dunson, D.B., "Factor pre-training in Bayesian
multivariate logistic models" (Duke University; arXiv preprint in the corpus). This is an
**independent group** (not the gllvm authors) proposing a competing method ("FLAIR") for the
identical model class: Bernoulli responses with the **logit link** (verbatim: "We consider
data generated from model (S13) with h⁻¹(π) = log{π/(1−π)} the logit link function") —
matching our failing case's family and link exactly. They benchmark their method against
`gllvm`'s LA and EVA fits directly.

**Full context of the quote.** In their supplementary "Lower Dimensional Scenarios" (n, p) ∈
{100, 500} × {50, 100, 200}, q = k = 2 latent factors, 50 replications per cell:

> "Table S2 provides additional evidence of the frequentist validity of FLAIR credible
> intervals; these intervals had valid frequentist coverage on average over entries of B and
> ΛΛᵀ for p ≥ 100 while suffering only a mild under-coverage for p = 50. **In contrast,
> GLLVM-LA suffers from undercoverage, and GLLVM-EVA provides valid uncertainty
> quantification for B but not for ΛΛᵀ.**"

I pulled the literal Table S2 numbers (average frequentist coverage of 95% CIs, ×100) to
verify this is not an overstatement:

| p | n | GLLVM-EVA: ΛΛᵀ coverage | GLLVM-EVA: B coverage |
|---|---|---:|---:|
| 50 | 100 | 79.52 ± 4.54 | 97.27 ± 0.30 |
| 50 | 500 | 67.18 ± 4.72 | 97.60 ± 0.29 |
| 100 | 100 | 71.55 ± 5.50 | 97.50 ± 0.24 |
| 100 | 500 | 90.67 ± 2.63 | 97.74 ± 0.19 |
| 200 | 100 | 78.00 ± 3.62 | 97.63 ± 0.18 |
| 200 | 500 | 39.47 ± 3.60 | 97.70 ± 0.56 |

B's coverage sits just above nominal 95% in every cell (mild over-coverage); ΛΛᵀ's coverage
is badly below nominal in every cell, and gets **worse**, not better, at the largest n and p
tested (39.47% at n=500, p=200). The quote is accurate and, if anything, understates how bad
the ΛΛᵀ-coverage gap is at the largest sizes tested.

**The same table also reports point-estimate accuracy (RNSE), which the coverage quote alone
does not capture — and this is new material beyond what the prior lane's note found.** Table
S1, Root Normalized Squared Error for ΛΛᵀ (×100, mean ± SE over 50 replications):

| p | n | GLLVM-LA: ΛΛᵀ RNSE | GLLVM-EVA: ΛΛᵀ RNSE |
|---|---|---:|---:|
| 50 | 100 | >100 | >100 |
| 50 | 500 | 65.38 ± 0.29 | 27.07 ± 0.54 |
| 100 | 100 | 80.18 ± 15.82 | 87.82 ± 7.83 |
| 100 | 500 | 65.70 ± 0.31 | 25.11 ± 0.56 |
| 200 | 100 | 79.07 ± 13.96 | 73.29 ± 2.67 |
| 200 | 500 | 66.08 ± 0.26 | 23.80 ± 0.35 |

At the smallest, hardest cell (p=50, n=100), **both** GLLVM-LA's and GLLVM-EVA's ΛΛᵀ point
estimate have relative error exceeding 100% — i.e., the estimate is less informative than
guessing zero. This is genuine, independent, quantitative confirmation that **GLLVM-EVA's
Λ-derived covariance point estimate can be severely wrong, specifically in the small-n
regime, in a Bernoulli-logit model** — the same family/link as our measurement. But note the
**magnitude**: RNSE capped/reported as ">100%" means the error is on the order of the true
norm itself (roughly a multiplicative factor of 1–3×), not 10⁷–10⁹×. Nothing in this paper,
or anywhere else in the corpus, reports an error of the magnitude in our own measurement.
The paper does not characterize the *direction* (over- vs under-shrunk) of the ΛΛᵀ error —
RNSE is directionless.

**One more precise, useful data point from the same table: EVA was consistently faster than
LA in every cell**, e.g., 4.97s vs 13.47s at (p=50,n=100); 267.89s vs 848.70s at (p=200,
n=500) — independent confirmation of the EVA-vs-LA speed ordering claimed in the EVA paper
itself (see Q5). This paper never runs a "GLLVM-VA" arm at all for this logit-link model —
consistent with Q1's finding that standard closed-form VA excludes logit.

---

## Q3. What does the literature say EVA requires to work properly?

**Starting values.** The EVA paper does not propose its own starting-value method — it
explicitly borrows one:

> "As starting values for EVA, we use the proposal in Section 3.2 in Niku et al. (2019a)."

I fetched that paper (Niku, Brooks, Herliansyah, Hui, Taskinen, Warton (2019), "Efficient
estimation of generalized linear latent variable models," *PLOS ONE* 14(5)) and read Section
3.2 directly:

> "We propose a new data driven method for constructing initial values for parameters in a
> GLLVM. In this approach, we first fit a GLM... to each response variable (species), from
> which the obtained estimates... are used as starting values for the fixed parameters in the
> GLLVM. Starting values for latent variables uᵢ and their loadings γⱼ are then constructed
> by applying factor analysis to the Dunn-Smyth residuals from the fitted GLMs... For the
> remainder of this article, we will refer to this method for constructing starting values as
> **res**."

This `res` method (GLM residuals → factor analysis → rotate to satisfy the identifiability
constraint) is the one both the original VA paper and EVA rely on, and — confirmed directly
against the current CRAN vignette below — remains gllvm's **default**.

**Restarts are explicitly recommended, not automatic.** From Niku et al. (2019), comparing
`res`, `res3` (three jittered restarts, keep best log-likelihood), `zero`, and `random`
starting-value strategies:

> "A widely used strategy to work around this issue is to use several random starting values
> and to pick up the solution with highest log-likelihood value. In case of complex models and
> large datasets however, the use of several random starting values may however be too time
> consuming... Overall, these findings suggest that res and res3 were the best strategies for
> choosing starting values. All methods res, zero and random have been implemented as
> different options... in the R package gllvm with res as the default."

**Identifiability constraints on the loadings.** From the original VA paper (Hui et al.,
2017, JCGS):

> "...act as identifiability constraints to avoid location and scale invariance. We also
> impose constraints on the latent variable coefficient matrix to avoid rotation invariance.
> Specifically, we set all the [upper triangular elements to zero and diagonal elements
> positive]."

This is the standard factor-analytic identifiability fix (upper-triangular-zero,
positive-diagonal constraint) — it fixes rotation, not scale runaway; nothing in the corpus
describes a constraint that bounds Λ's *magnitude* away from implausible values.

**Current, live package guidance (gllvm CRAN vignette "Assessing Convergence in gllvm
models," fetched directly, version 2.0.13, published 2026-07-09 — the most current
first-party source in the corpus) is the single richest answer to "what EVA requires":**

> "In addition to these, it is always recommended to use multiple initial runs with different
> starting points with `n.init`. Repeating the estimation with different random starts can
> also reveal whether the solution is stable."

> "Approximation method: Variational, Extended Variational or Laplace approximation... There
> are alternative approximation methods implemented in the gllvm package, and **switching the
> method can stabilize convergence**... `method = "VA"` Variational approximation (**default**)
> `method = "EVA"` Extended Variational approximation... In addition, research has shown that
> some methods for some distributions and models may work better and produce better behaved
> likelihood function, and others may have certain problems, see for example discussion about
> VA's underestimation of variance for random effects [linking GitHub issue #237, discussed in
> Q4]."

Two facts here matter for interpreting any EVA-vs-VA comparison: **EVA is not gllvm's
default method — VA is** — and the package's own documentation treats "switch the
approximation method" as a *recommended remedy* for convergence problems, implying the
authors expect instability to be method- and problem-dependent, not uniform.

**A worked, official, on-point example of loadings taking extreme, badly-identified values.**
The same vignette walks through a real convergence failure and finds — among the flagged
"problematic parameters" — the loadings themselves:

> "Look for 'negative variances': ... `sigmaLV lambda lambda lambda lambda ... -2.939017597
> 37.277876483 -7.548098679 -0.208650756 14.424832344 ...` ... There are lot of 'negative
> variances', which can be a result from non negative Hessian."

and the general diagnosis:

> "large gradients or a singular (non-invertible) Hessian indicate that convergence was
> likely not achieved... which may stem from an ill-behaved likelihood function — for example,
> a flat likelihood surface, multimodality, ridges in the likelihood, or near-collinearity
> among parameters."

This is not from a random-slope EVA/Bernoulli fit specifically, but it is the package's own,
current, first-party demonstration that **loading (`lambda`) parameter estimates can take
wild, non-sensible magnitudes (here, values from −21 to +37) exactly when the Hessian
diagnostics flag non-convergence** — establishing that this failure mode is known,
documented, and diagnosable by the tooling itself, not a hypothetical.

---

## Q4. Any published report of EVA failing badly, being unstable, or sensitive to starts?

**No peer-reviewed paper in the corpus reports EVA itself diverging or blowing up.** What the
literature reports about instability is either (a) about LA, or (b) about EVA being *better*
than the alternative that fails. From Hui et al. (2017), about the Laplace approximation
specifically:

> "...the Laplace approximation tended to suffer from convergence problems, with updates
> between successive iterations not always producing an increase in the log-likelihood and
> there being a strong sensitivity to starting points."

From Niku et al. (2019), ranking starting-value strategies by log-likelihood stability:

> "The biggest differences were seen when the Laplace approximation method and the variational
> approximation method were implemented without TMB and applied to binary data."

**The closest thing to a direct report — current, first-party, and unresolved — is a live
GitHub issue, not a publication**, which I am flagging explicitly as a different kind of
source (developer discussion, not peer review) but is unusually decision-relevant: `gllvm`
issue #237, "VA underestimates effects in binary models" (opened 2025-08-14 by Bert van der
Veen, a `gllvm` co-author per the CRAN `Authors@R` field; most recent activity 2026-02-20;
**state: OPEN**). The original post, reproducing Ormerod & Wand (2012)'s GVA simulation
inside `gllvm`:

> "As is clear in set 2 and set 3 (the logistic model), our implementation severely
> underestimates the standard deviation of the random effect... This is something I have
> encountered before in probit models in gllvm (diagnosed as estimated LVs taking very small
> values)... In contrast to EVA and LA on the same data, the VA objective does not seem to
> have a unique minimum for sigma. This seems odd, given that EVA is supposed to be a less
> accurate version of VA."

Francis K.C. Hui (an EVA co-author) replying, and explicitly extending the worry to the
**loadings**:

> "A deeper worry would be that if it occurs for variance components row effects, then perhaps
> it also occurs with latent variables in either the loadings (since this is reduced-rank
> random effects covariance matrix) and/or the scale of the latent variables when this is also
> estimated?"

Bert van der Veen's reply:

> "Yes, I suspect it also occurs for the loadings and for correlation parameters of random
> effects more generally."

And, most consequential for interpreting any EVA-vs-VA comparison on Bernoulli-logit data:

> "the advice to people using the software when this happens has been to change to LA/EVA."
> — Bert van der Veen
> "It also explains why EVA might do better, as it includes local curvature information in the
> form of a Hessian." — Francis Hui
> "AGH/EVA/LA does not have this problem because they do not [need to] introduce such latents
> in handling such problems." — Francis Hui

**Read this precisely, because the direction matters.** This thread is about standard **VA**
(a Polya-Gamma-style auxiliary-latent construction, now apparently implemented for the logit
link in current `gllvm` — a capability the 2017/2019/2023 papers explicitly say does not
exist in closed form) **underestimating** a scalar random-effect variance, collapsing it
toward zero. The authors' own expectation, stated repeatedly in this thread, is that **EVA is
the more stable alternative**, not the less stable one. It is not evidence that EVA itself
blows up; if anything it is evidence the package authors currently believe the opposite. It
is, however, unambiguous, current, first-party confirmation that (a) `gllvm`'s VA-family
methods have a live, unresolved, author-acknowledged instability for binary-response models,
(b) the instability is suspected — not yet confirmed by them — to extend to the loadings, and
(c) EVA is the documented, standard troubleshooting remedy for VA instability on binary data,
which is what makes a finding of EVA *itself* failing badly on the same data type notable
against the developers' own stated priors.

**A second, independent, first-hand user report — different mechanism, same failure
signature (huge coefficient/SE blow-up), also worth citing as "independent user report of
failure."** `gllvm` issue #246, "Very high standard errors of coefficient estimates" (closed,
opened 2026-04-27), a negative-binomial VA fit:

> "I found that coefficients of some species that are completely absent from one of the
> treatment types have very high standard errors (ranging from ~1900-3870000)."

Diagnosed by another independent commenter as quasi-complete separation, a classical
MLE-family pathology, not unique to VA/EVA/GLLVMs:

> "You may want to google, or us some AI, and look for 'quasi-complete' separation. Although
> it is often mentioned in the context of logistic regression, you can get the same problem
> with count data with lots of zeros." — Alain Zuur

> "Not only are the standard errors huge, but the estimates themselves are also very large...
> I don't think this is an issue with gllvm, as it also happens with univariate models."
> — Rodolfo Pelinson, who reproduces the same coefficient/SE explosion in plain `glmmTMB`
> with no latent variables at all.

This is about **B**, not Λ, and about NB, not Bernoulli — but it is a genuine, independent,
first-hand report of a `gllvm` VA fit producing wildly inflated point estimates (not just
poor coverage), attributed to a general MLE-separation mechanism that is a natural risk for
sparse/binary-like data specifically.

---

## Q5. The scalability claim — exact regime, and where it breaks down

**The claim, verbatim, from the EVA paper's abstract:**

> "...while being computationally more scalable than both methods in practice."

and from the Discussion:

> "EVA was the most computationally efficient method of all the ones compared, in pretty much
> every situation... EVA was substantially faster and scaled computationally better than LA."

**The regime it was demonstrated in:** m = 48 species, n = 50/120/190/260 sites (Setting 1);
and, in Setting 2 (Appendix B, sizes not recovered in the text I could fetch), a fixed n with
increasing m based on up to 177 bird species. The paper reports the comparison only
graphically (Fig. 1a/1b) — **no literal seconds are given in the accessible text** for these
cells; the qualitative claim ("EVA was clearly the fastest") is as precise as the main paper
gets.

**Literal timing numbers, in a genuinely comparable Bernoulli-logit regime, come from the
independent FLAIR paper (Q2), not from the EVA paper itself:**

| p | n | GLLVM-LA time (s) | GLLVM-EVA time (s) |
|---|---|---:|---:|
| 50 | 100 | 13.47 ± 1.12 | 4.97 ± 0.21 |
| 50 | 500 | 74.14 ± 2.49 | 61.05 ± 1.11 |
| 200 | 100 | 132.78 ± 8.89 | 26.40 ± 1.32 |
| 200 | 500 | 848.70 ± 106.34 | 267.89 ± 18.46 |

EVA is faster than LA in every cell here (independent confirmation of the LA-vs-EVA half of
the claim), but **the paper never runs a "GLLVM-VA" arm against EVA for logit at all**,
because (per Q1) standard closed-form VA is unavailable for the logit link. **There is no
source anywhere in this corpus that benchmarks EVA against VA, specifically on Bernoulli-logit
data — the comparison our own measurement makes has no literature precedent to either confirm
or contradict it.**

**The regime where the claim was explicitly said not to hold:** Mauri & Dunson, motivating
their own FLAIR method as an alternative to `gllvm`, state a hard scalability ceiling for the
whole LA/VA/EVA family:

> "Niku et al. (2017, 2019a) developed an efficient implementation of the Laplace
> approximation... while Hui et al. (2017); Niku et al. (2019b); Korhonen et al. (2022)
> developed variational approximations. **These methods take a few hours for each model fit
> for p ≈ 1,000**, leading to computational problems in our motivating applications, which
> have p = 10,000 − 100,000."

**The mechanism for LA's specifically poor scaling** (relevant background, not about EVA) is
given by Niku et al. (2019):

> "the other possible reason for more rapid growth in computation time for the Laplace
> approximation method, when m increases, comes from the complexity of the approximation
> itself, where there is a term log det{G(Ψ;û₋ᵢ)}, where G(Ψ;û₋ᵢ) has dimension m, and so
> computing its determinant has a complexity that grows at a rate O(m³)."

**Bottom line on Q5:** the "EVA is more scalable" claim is (a) always relative to LA, VA-GH,
or MCMC — never to standard VA where standard VA exists in closed form (it's excluded, not
outraced) — and (b) demonstrated only up to m ≈ 48–200 species in the corpus's most granular
sources; an independent group explicitly describes the same method family as taking "a few
hours" per fit by p ≈ 1,000, motivating them to build a faster alternative. Nothing in the
corpus speaks to n = 400, p = 20 specifically.

---

## What this implies for our measurement

Four distinct findings, kept carefully separate by direction and by object, because
conflating them would overstate what the literature actually supports:

**1. The literature confirms EVA has a real weakness on Λ/Σ-type quantities relative to B —
but of a different scale than what was measured.** Q2's FLAIR benchmark is an independent,
verified, same-family/link (Bernoulli-logit) confirmation that GLLVM-EVA's ΛΛᵀ point estimate
and interval coverage are markedly worse than its B estimate and coverage — RNSE up to ">100%"
and coverage as low as 39% at the largest size tested. This is directionally consistent with
"EVA's Λ-derived covariance is its weak point," but the reported magnitude (order of 1–3×
error) is many orders of magnitude short of a 4.8×10⁷ median / 5.5×10⁹ max attenuation. The
literature supports "EVA's covariance recovery is unreliable here," not "EVA's covariance
recovery is unreliable by seven orders of magnitude."

**2. The one EVA-specific covariance defect the authors admit in print is real but is a
different object, in the opposite direction.** The EVA paper's own Discussion (Q1) says EVA
underestimates the *posterior* covariance of individual predicted latent scores, more than
standard VA does. That is Aᵢ (per-observation uncertainty), not Σ = ΛΛᵀ (the structural,
population-level parameter our own measurement calls `Sigma`), and it is underestimation, not
the ~10⁷-fold overestimation measured. These should not be treated as the same phenomenon.

**3. The literature's account of *why* VA-family methods misbehave on binary data (GitHub
issue #237) points at a plausible mechanism class, but for the opposite direction and a
different method.** The open, current, author-driven discussion of `gllvm`'s newer
Polya-Gamma-based VA-for-logit implementation collapsing a random-effect SD toward zero is
about VA, not EVA, and about underestimation, not blow-up. Its most transferable content is
methodological, not directional: it establishes that (a) the package's binary-response
machinery is known, current, and unresolved-unstable; (b) the authors themselves suspect —
without yet having confirmed — that the same instability could reach the loadings; and (c)
their own expectation is that EVA is the *more* stable choice for exactly this data type,
which is the opposite of what our own measurement found. If our own numbers are right, they
are surprising relative to the developers' own current model of where the risk lies, not a
confirmation of it.

**4. The best mechanistic parallel available in the corpus is Heywood-case / boundary-solution
theory, and the package's own convergence vignette shows the same signature in the loadings.**
Classical ML factor analysis has a large literature (eight sources in this corpus) on
"Heywood cases" — the objective genuinely preferring an inadmissible boundary or degenerate
solution over the true parameter, especially in small/sparse-data regimes. The `gllvm`
convergence vignette's own worked example (Q3) shows loadings (`lambda`) taking wild values
(−21 to +37) precisely on fits its own Hessian diagnostics flag as non-converged, with the
diagnosis explicitly naming "multimodality" and "ridges in the likelihood" as causes. **This
is the closest statistical-literature analogue to a genuinely objective-preferred degenerate
optimum, as opposed to an ordinary estimation bias** — and it is a first-party,
package-documented phenomenon, not a hypothetical.

**Relevant internal-project context (not literature — flagged separately per the provenance
rule).** A concurrent probe in this repository
(`docs/dev-log/2026-07-31-eva-misuse-probe.md`, by a different agent, working from the same
Bernoulli grid) independently re-derived and validated `gllvm`'s own EVA objective function
and reports that the extreme attenuation is **not a uniform point-estimate bias** but a
**bimodal mixture**: roughly two-thirds of Bernoulli-logit cells converge to a scale-degenerate
mode that beats the true parameters on EVA's own objective by ~291 nats (restarts make this
worse, not better, because gllvm keeps the restart with the best objective value); the
remaining cells have a median attenuation of ~1.2, comparable to Laplace. If that internal
finding is correct, it reframes the right question from "how biased is EVA's covariance
estimator" to "how often does EVA's objective have a spurious global optimum for
Bernoulli-logit data, and why" — which is exactly the Heywood-case/boundary-solution framing
in point 4, not the coverage-only framing in point 1. **No source in the literature corpus
quantifies a degenerate-mode rate for EVA the way that internal probe does; this appears to be
new ground, not something the published literature has already characterized.**

**On the scalability contradiction (Q5):** our own measurement (n=400, p=20: Laplace 6.52s,
`gllvm` VA 72.83s, `gllvm` EVA 315.34s) directly contradicts the paper's "more scalable" claim
at this specific size — but the claim was never demonstrated at, or benchmarked against
standard VA at, this specific combination of family (Bernoulli-logit, where VA is excluded by
design in every source in this corpus) and size. The contradiction is real and worth recording,
but it lands in a regime the literature simply never tested a VA-vs-EVA comparison in.

**On the family/link mismatch worth flagging to whoever wrote the measurement code:** every
source in this corpus that discusses why EVA exists says, in some form, that closed-form VA is
unavailable for Bernoulli-logit specifically (Q1, Q2). Yet our own grid apparently ran a
`gllvm_va` arm on Bernoulli data that returned ordinary-looking numbers (median attenuation
0.92, per the internal probe). Current `gllvm` (2.0.13) evidently now offers *some* VA
implementation for logit that none of the peer-reviewed papers in this corpus describe or
benchmark — and GitHub issue #237's own language ("the VA polya-gamma set up of this model...
at least in the case of logit link") strongly suggests, without being a direct confirmation
from a paper, that this is a newer Polya-Gamma-augmented VA variant, i.e., a capability added
to the package after 2023, running exactly the machinery that issue #237 shows is unstable (in
the underestimation direction) and unresolved as of 2026-02-20. This is a testable question for
the numerical side, not a literature question — I flag it as UNVERIFIED beyond the GitHub
thread's own wording.

> Related: `docs/dev-log/2026-07-31-eva-literature-correction.md` ·
> `docs/dev-log/2026-07-31-eva-misuse-probe.md` ·
> NotebookLM `b25e6c9f-500b-43da-8487-6430ce01d09b`
