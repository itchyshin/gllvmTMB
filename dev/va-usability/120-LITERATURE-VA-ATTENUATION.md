# Literature check: VA/EVA loading attenuation in binary GLLVMs

**Question posed (2026-08-05):** is our measured finding — binary-GLLVM latent
scores recover well under variational approximation (VA) while the
loading/covariance point estimates are severely and asymptotically (non-vanishing)
attenuated, worse for the logit/Jaakkola–Jordan (JJ) / Pólya–Gamma (PG) bound than
for probit, and cured by exact Gauss–Hermite quadrature — already documented in the
literature?

**Verdict: PARTLY known.** The general phenomenon of variational Bayes (VB)
underestimating **posterior uncertainty/covariance** (a credible-interval-width
problem) is well established and explicitly documented for GLLVM/EVA. Consistency
(vanishing bias) of the variational **point estimate** is the standard claim in the
recent theory literature. **No source found — in the curated corpus or by direct
web search — states our specific claim**: a **non-vanishing point-estimate
bias/attenuation** in loadings/Σ under VA/EVA for **binary** GLLVMs, worsening for
logit vs. probit, tied specifically to the JJ/PG bound, with the
scores-good/loadings-biased dissociation. That combination appears to be a genuine
gap, not a rediscovery.

## Method

Reused an existing curated NotebookLM corpus rather than building a new one (Law 3
duplicate-ingestion guardrail): notebook **`b25e6c9f-500b-43da-8487-6430ce01d09b`**,
*"GLLVM estimation engines — VA, EVA, AGHQ, penalised Laplace (accuracy & variance
bias)"* (created 2026-07-30; 33 sources, `status: ready`), already scoped almost
exactly to this question. Interrogated it with six narrow, citation-required
questions (full Q&A in the notebook's conversation history,
`conversation_id 3f2ecb1e-863c-47e2-98c5-6a419f88c98a`). Cross-checked every
load-bearing citation surfaced by the notebook against independent WebSearch
(venue/year/authors) and one WebFetch of the Wang & Blei abstract. No self-citation:
none of gllvmTMB's own vignettes, drafts, or dev-log files are in the corpus or in
this note's source list.

## 1. Variational covariance/uncertainty underestimation (general) — well documented, but this is a DIFFERENT claim than ours

Two distinct phenomena get called "underestimation" in this literature, and they
must not be conflated:

- **(A) Posterior-uncertainty underestimation** — the variational credible interval
  for a parameter is too narrow, but the point estimate (the mode/mean of the
  approximating distribution) can still be accurate. This is old and well known.
- **(B) Point-estimate bias** — the estimated parameter *value itself* (e.g.
  `Σ̂ = Λ̂Λ̂ᵀ`) is systematically wrong, converging to the wrong number. This is
  our claim.

Corpus + verified citations for (A):

- **Wang, Y. & Blei, D.M. (2019).** "Frequentist Consistency of Variational Bayes."
  *JASA* 114(527), 1147–1161 (arXiv:1705.03439). Proves the variational **point
  estimate is consistent and asymptotically normal** under standard regularity
  conditions (a variational Bernstein–von Mises theorem) — i.e. (B)-type bias
  *vanishes* in their setting. A companion result, cited secondhand inside the
  corpus (from Keck 2025, below), states covariance/variance estimates
  "underestimate the true variance of the posterior asymptotically" — that is
  case (A), not (B); I could not confirm from the abstract alone (WebFetch) whether
  Wang & Blei themselves state the (A)-gap is non-vanishing in the n→∞ limit or
  only that mean-field ignores posterior correlations. **Mark this specific
  non-vanishing-ness detail UNVERIFIED at primary-source level** (retrieved via a
  secondary citation, not the primary text).
- **Giordano, R., Broderick, T. & Jordan, M.I. (2015).** "Linear Response Methods
  for Accurate Covariance Estimates from Mean Field Variational Bayes." *NeurIPS
  28* (arXiv:1506.04088). States plainly: "a well known major failing of MFVB is
  that it underestimates the uncertainty of model variables (sometimes severely)
  and provides no information about model variable covariance." Proposes the
  linear-response-VB (LRVB) fix — case (A) correction, not a point-estimate
  debiaser.
- **Keck, J. (2025).** "Frequentist Asymptotics of Variational Laplace."
  arXiv:2507.17697 — **MSc thesis** (Freie Universität Berlin), not peer-reviewed;
  weight accordingly. States variational Laplace covariance estimates
  "underestimate the true variance of the posterior asymptotically (Wang and Blei,
  2019)," and separately proves (in "two toy examples") that variational Laplace
  point estimates are asymptotically consistent and efficient — again, (A) persists,
  (B) vanishes, in their examples.
- **Blei, D.M., Kucukelbir, A. & McAuliffe, J.D. (2017).** "Variational Inference:
  A Review for Statisticians." Standard review; corpus cites it for the general
  claim that under regularity conditions the MFVB posterior mean is frequentist-consistent.

**None of this literature's "asymptotic underestimation" claims are about
point-estimate bias in a model's own variance/loading parameter (case B). They are
about the variational posterior's own uncertainty being too narrow.** This is the
central distinction our finding needs to be checked against, and on this reading,
general VB theory does not predict our result — if anything it argues point
estimates should be *consistent*.

## 2. GLLVM/JSDM-specific literature

- **Hui, F.K.C., Warton, D.I., Ormerod, J.T., Haapaniemi, V. & Taskinen, S.
  (2017).** "Variational Approximations for Generalized Linear Latent Variable
  Models." *JCGS* 26(1), 35–43. Per the notebook's retrieval of their Setting 1
  (binary/probit), VA point estimators "performed excellently," with
  "significantly lower mean Procrustes error for the λ's" than alternatives — i.e.
  the founding VA-for-GLLVM paper reports **good** loading recovery, not
  attenuation, for probit. Caveat worth flagging (my own methodological
  observation, not stated by the paper): Procrustes error is typically computed
  after fitting a rotation **and dilation/scale** factor between estimated and true
  loadings; if their Procrustes metric includes a free scale parameter, a uniform
  shrinkage of `Λ̂` (exactly the kind of attenuation we measured as
  `sum(Σ̂_jj)/sum(Σ_jj) ≈ 0.51`) would be absorbed by the fitted scale and would
  not appear as Procrustes "error" at all. I did not verify whether their
  Procrustes computation is scale-free or scale-fitting — **flag, not resolved**.
- **Korhonen, P., Hui, F.K.C., Niku, J. & Taskinen, S. (2023).** "Fast and
  universal estimation of latent variable models using extended variational
  approximations." *Statistics and Computing* 33(1), 1–16 (arXiv:2107.02627) — the
  EVA paper. Two directly relevant, exact quotes surfaced and corroborated across
  two independent notebook queries: "the fact that in EVA we underestimate the
  latent variable posterior covariances even more than in standard VA requires
  careful consideration. The potential use of bootstrap-based methods to overcome
  this issue, as suggested in **Dang and Maestrini (2021)**, will be considered in
  future" (Dang & Maestrini citation not independently verified — **UNVERIFIED**).
  On inspection this is **case (A)** — the per-observation variational covariance
  `Â_i` of the latent scores `u_i`, governing prediction-region width, confirmed by
  a follow-up quote: "the traces of the variational covariance matrices from EVA
  are often greater than those produced by standard VA" (larger `Â_i`, i.e. wider,
  not narrower — the opposite direction from ours, and still about score
  uncertainty, not Σ point-estimate bias). Separately, the paper defines **VA-GH**
  (Gauss–Hermite quadrature substituted for the closed-form bound where none
  exists, e.g. **the logit link**) as its own benchmark and reports "EVA generally
  performed much closer to VA-GH than LA" for logit, and "EVA and VA performing
  fairly evenly" against each other for probit — i.e. the paper's own framing
  already treats quadrature (VA-GH) as more trustworthy than the closed-form bound
  for logit, which is directionally consistent with our story, but (a) their VA-GH
  used only 5–9 quadrature nodes (not a converged/exact reference), (b) they report
  closeness *between approximate methods*, not bias against the true simulating
  parameter, and (c) the underlying appendix tables with raw numbers are not
  hydrated in the corpus, so I cannot confirm or rule out a residual logit-specific
  bias from their own numbers.
- **Niku, J., Warton, D.I., Hui, F.K.C. & Taskinen, S. (2019).** "Efficient
  estimation of generalized linear latent variable models." *PLOS ONE* 14(5),
  e0216129. Per the notebook: "The variational approximation method performed
  better overall... producing less biased estimates... By contrast, the estimates
  based on the Laplace approximation were severely biased, especially when the
  sample size was small." This is a VA-vs-**Laplace** comparison, not
  VA-vs-exact-quadrature — does not bear on our claim either way.
- **Mauri, L. & Dunson, D.B. (2025).** "Factor pretraining in Bayesian
  multivariate logistic models" [FLAIR]. *Biometrika* 112(4), asaf056 (orig.
  arXiv:2409.17441, 2024). The one source that explicitly separates the two cases
  for **binary/logistic** GLLVMs: "GLLVM-LA suffers from undercoverage, and
  GLLVM-EVA provides valid uncertainty quantification for `B` but not for
  `ΛΛᵀ`" — again framed as **coverage/uncertainty (A)**, not point bias. Their own
  Theorem 1/2 posterior-concentration argument needs **both n and p (number of
  responses) to diverge**, and separately cites **Haberman (1977)** for the
  classical Neyman–Scott/incidental-parameters inconsistency of *joint MLE*
  (treating `u_i` as fixed parameters) when n→∞ with p fixed — a mechanism the
  paper says VA/marginalization is designed to avoid, not one it shows VA/EVA
  actually suffers from. Their reported point-estimate errors (root normalized
  squared error) for GLLVM-EVA's `ΛΛᵀ` do shrink monotonically from n=100 to n=500
  at fixed p ∈ {50,100,200} — but 100–500 is a narrow range; a
  root-mean-squared-error metric conflates shrinking variance with a fixed residual
  bias and would keep dropping toward a nonzero floor for a while before
  flattening (exactly the shape we see in our own n=150→2000 series). **Their data
  do not have enough range to distinguish "bias → 0" from "bias → plateau"** —
  this is my own inference from their reported numbers, not a claim the paper
  makes.

## 3. Jaakkola–Jordan / Pólya–Gamma bound specifically tied to variance bias

- **Polson, N.G., Scott, J.G. & Windle, J. (2013).** "Bayesian Inference for
  Logistic Models Using Pólya–Gamma Latent Variables." *JASA* 108(504), 1339–1349
  (arXiv:1205.0310). Full text not hydrated in the corpus (abstract only); abstract
  makes no bias/variance-underestimation claim (it is an exact-Gibbs-sampling
  paper, not variational).
- **Durante, D. & Rigon, T. (2019).** "Conditionally Conjugate Mean-Field
  Variational Bayes for Logistic Models." *Statistical Science* 34(3), 472–485
  (arXiv:1711.06999). Abstract only in the corpus; establishes the formal
  equivalence between the JJ tangent bound and PG data augmentation as a
  conditionally-conjugate MFVB scheme, "restoring conjugacy," but the retrieved
  abstract text does not itself assert a bias/variance-underestimation result.
- A general WebSearch (outside the curated corpus) returned an unsourced but
  plausible-sounding secondary claim that "the stochastic gradient descent
  Jaakkola and Jordan [method] and the variational Bayes EM algorithm — both of
  which use the Jaakkola and Jordan bound — underestimate the variance by a
  similar amount," attributing the general fix to Giordano/Broderick/Jordan
  (2015). **I could not trace this back to a specific primary paragraph in this
  session — mark UNVERIFIED**, though it is consistent with (A) above and with
  the general MFVB folklore (Bishop *PRML*; Turner & Sahani 2011, neither directly
  checked this session).
- **No source, in the corpus or via direct web search, ties the JJ/PG bound
  specifically to a *point-estimate* (case B) bias in variance/loading
  parameters**, still less one that fails to vanish with n. The
  Taskinen conference-slide source in the corpus confirms only the *mechanistic*
  fact that motivates using a bound at all: "VA has proven to be accurate...in
  cases where the VA lower bound can be attained in closed form... sadly this is
  not always the case. A prime example is the case of Bernoulli distributed
  responses with logit link" — i.e. standard closed-form Gaussian VA has no
  closed form for logit, which is *why* EVA/LA/JJ-type bounds are needed there and
  not (as much) for probit. This is background confirming the logit/probit
  asymmetry in the toolset, not a bias claim.

## 4. Documented fixes

All documented fixes in the corpus target **case (A)**, not case (B):

- **Linear response VB (LRVB)** — Giordano, Broderick & Jordan (2015), above:
  corrects the underestimated covariance of the variational posterior.
- **M-estimation / sandwich correction** — Westling, T. & McCormick, T.H. (2019).
  "Beyond Prediction: A Framework for Inference With Variational Approximations in
  Mixture Models." *JCGS* 28(4), 778–789. Frames the variational point estimate as
  a profile M-estimator and derives a model-robust ("sandwich") covariance plus a
  one-step efficiency correction — again a **CI-width** fix layered on a point
  estimate they treat as already a valid M-estimator (i.e. assumed unbiased, not
  itself corrected).
- **Applied to counts**: Batardière, B., Chiquet, J. & Mariadassou, M. (2024).
  "Evaluating Parameter Uncertainty in the Poisson Lognormal Model with Corrected
  Variational Estimators." arXiv:2411.08524. Per the notebook: they report the PLN
  variational point estimates `(B̂, Σ̂)` already have "small or no bias, as the
  RMSE keeps decreasing towards small values with increasing n," and confine their
  contribution to a sandwich-based variance correction, explicitly **rejecting**
  both Laplace (intractable at full-rank Σ) and exact/composite-likelihood
  quadrature (infeasible beyond ~100 variables) as alternatives on computational
  grounds — i.e. they do not recommend switching to quadrature for the covariance.
  Worth noting for our own reconciliation: PLN has exactly the GLLVM-like
  structure (one latent Gaussian vector per row) yet its variational Σ̂ is reported
  bias-free — this is a same-shaped comparator that did **not** show our
  phenomenon, which is circumstantial evidence (not proof) that the culprit in our
  finding is more likely the **discreteness + bound** (Bernoulli/logit needing a
  JJ/PG-type bound) than merely "one incidental latent vector per row" as such,
  since PLN has the latter without the former and appears fine.
- No source proposes a bias-correction/debiasing procedure for case (B), and no
  source recommends "quadrature for the covariance, VA for the scores" as a
  deliberate two-tier recipe — the EVA paper's own use of VA-GH as an internal
  benchmark (§2 above) is the closest thing to that idea in print, but it is not
  offered as a general prescription.

## 5. The scores-good / loadings-biased dissociation specifically

**Not found anywhere** — not in the curated corpus (explicitly asked twice, in two
different framings, across turns 1 and 2 of the notebook conversation; both
returned "no source documents this dissociation"), and not in a broader web search
for VA/IRT/factor-analysis literature on attenuated loadings with well-recovered
scores. The nearest tangential hits (VAE-based item-response models reporting bias
reduction in *ability* estimates as item count grows; classical attenuation of
correlations from unreliable *sum scores* in the IRT literature) are conceptually
adjacent but are about different estimators (amortized VAEs; observed-score
reliability), not GLLVM-VA/EVA, and were not followed up in depth given the scope
of this check.

## 6. Synthesis (AGENT-INFERRED — my construction from the evidence above, not any single source's claim)

The literature gathered here is more consistent with "VA point estimates should be
consistent" than with our finding, on its face — but every consistency proof found
(Wang & Blei 2019; Keck 2025; the FLAIR posterior-concentration theorem; the PLN
sandwich-correction paper) either (a) is stated for smooth/conjugate/log-link
settings without a JJ/PG-type bound standing in for a genuinely intractable
discrete likelihood, or (b) — FLAIR specifically — requires **both** n and the
number of responses p to diverge jointly, not n alone. If our own simulation held p
(number of responses) fixed or modest while letting n→∞, that is a regime none of
these consistency results were shown to cover, and the Neyman–Scott/incidental-
parameter mechanism FLAIR invokes for joint-MLE (Haberman 1977) — while nominally
avoided by marginalization/VA — could plausibly resurface if the *approximation to
that marginalization* (the JJ/PG bound) carries a fixed per-observation slack that
does not shrink with n, because each `u_i`'s posterior is only ever informed by the
p responses in its own row, not by the other n−1 rows. This is a plausible,
citation-grounded hypothesis for reconciling "VA is consistent in the literature"
with "we found a non-vanishing bias" — not a documented result, and it should be
labeled as such wherever it is used.

## Sources consulted (all outside gllvmTMB's own material; no self-citation)

1. Hui, Warton, Ormerod, Haapaniemi & Taskinen (2017), *JCGS* 26(1):35–43.
2. Korhonen, Hui, Niku & Taskinen (2023), *Statistics and Computing* 33(1):1–16 (arXiv:2107.02627).
3. Niku, Warton, Hui & Taskinen (2019), *PLOS ONE* 14(5):e0216129.
4. Mauri & Dunson (2025), *Biometrika* 112(4):asaf056 (arXiv:2409.17441).
5. Wang & Blei (2019), *JASA* 114(527):1147–1161 (arXiv:1705.03439).
6. Giordano, Broderick & Jordan (2015), *NeurIPS 28* (arXiv:1506.04088).
7. Keck (2025), arXiv:2507.17697 [MSc thesis, unreviewed].
8. Blei, Kucukelbir & McAuliffe (2017), *JASA* 112(518):859–877 [standard VI review; venue not re-verified this session — recalled].
9. Polson, Scott & Windle (2013), *JASA* 108(504):1339–1349 (arXiv:1205.0310).
10. Durante & Rigon (2019), *Statistical Science* 34(3):472–485 (arXiv:1711.06999).
11. Westling & McCormick (2019), *JCGS* 28(4):778–789.
12. Batardière, Chiquet & Mariadassou (2024), arXiv:2411.08524.
13. Taskinen, S., conference slides "On fast maximum likelihood-based estimation
    of joint species distribution models," University of Helsinki [lower-tier,
    non-peer-reviewed source; used only for the logit/probit closed-form
    background fact].

NotebookLM corpus: notebook `b25e6c9f-500b-43da-8487-6430ce01d09b` ("GLLVM
estimation engines — VA, EVA, AGHQ, penalised Laplace (accuracy & variance
bias)"), reused as-is (not modified); conversation `3f2ecb1e-863c-47e2-98c5-6a419f88c98a`.
