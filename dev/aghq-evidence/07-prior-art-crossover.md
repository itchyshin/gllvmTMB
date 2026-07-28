# Prior art for the Laplace/AGHQ crossover in small-sample factor-loading recovery

Read-only literature note. Tools used: `WebSearch` and `WebFetch` (no NotebookLM
session was available in this context). Every citation below was checked against
at least one search result or fetched abstract; anything I could not independently
confirm is marked **UNVERIFIED**. I did not find a single paper that reproduces our
exact experiment (binomial GLLVM, T=4 traits, q=1, Laplace vs AGHQ(k=15) across an
n-ladder) — the literature below establishes each *piece* of the mechanism
separately, and I say so explicitly where the fit to our case is an inference
rather than a quote.

## The measurement this note is explaining

```
    n     Laplace   AGHQ(k=15)
 3200      0.794      1.0021
 1600      0.791      1.152
  800      0.810      1.063
  400      0.796      1.279
  200      0.836      1.967
  100      0.892      1.893
   50      1.209      2.576
   25     14.534      3.011
```
ratio = ||Lambda_hat|| / ||Lambda_true||, medians over 6-30 seeds, binomial GLLVM,
T=4 traits/site, q=1. Source: `05-descend-RESULT.txt` / `05-descend.csv` in this
same evidence directory (already-run simulation, not literature).

---

## 1. The crossover — is it documented that more accurate integration can be *worse* than Laplace in small samples?

**Partially, and the field is not unanimous.** Two directly relevant, real papers
disagree with each other:

- **Ju, K., Lin, L., Chu, H., Cheng, L.L., & Xu, C. (2020).** "Laplace
  approximation, penalized quasi-likelihood, and adaptive Gauss–Hermite
  quadrature for generalized linear mixed models: towards meta-analysis of binary
  outcome with sparse data." *BMC Medical Research Methodology*, 20, 152.
  https://doi.org/10.1186/s12874-020-01035-6 — explicitly states **AGHQ did not
  show better properties than Laplace approximation in terms of convergence rate,
  bias, coverage, and the possibility of producing very large odds ratios**, and
  that Laplace kept a lower proportion of large (>50%) bias than AGHQ across all
  their sparse-data scenarios. This is the closest documented instance of your
  observation (B) — a real published finding that AGHQ is not simply "the more
  accurate integration, hence more accurate estimator" once clusters/groups get
  small and sparse. The paper does **not** frame this as "error cancellation,"
  and does not give a mechanism — it reports the crossover empirically without
  explaining it.

- **Capanu, M., Gönen, M., & Begg, C.B. (2013).** "An assessment of estimation
  methods for generalized linear mixed models with binary outcomes." *Statistics
  in Medicine*, 32(26). https://doi.org/10.1002/sim.5866 — in their simulations,
  adaptive Gaussian quadrature (AGQ) is **never worse** than Laplace; AGQ has
  "negligible bias" once there are 5+ observations per random effect, and the
  paper's summary is "AGQ preferable as the number of observations per random
  effect increases," not that AGQ *degrades* below Laplace. This directly
  contradicts the Ju et al. framing for their own simulation design.

  My reading: **the crossover is context-dependent** (meta-analysis with very few,
  very sparse studies vs. a moderate binary-cluster design), not a universal law.
  It is documented, but only as an empirical finding in specific designs — I found
  no theorem that says "AGHQ must eventually cross below Laplace as n shrinks."

- **Joe, H. (2008).** "Accuracy of Laplace approximation for discrete response
  mixed models." *Computational Statistics & Data Analysis*, 52, 5066–5074.
  (ScienceDirect blocked full-text fetch for me; relying on search-result
  summary, so treat the exact wording as **UNVERIFIED**, though the substance is
  corroborated by Breslow & Lin below.) Reported finding: Laplace bias is largest
  for binary/ordinal responses (vs. count), is worst when the response is
  discrete and cluster size is small, and **decreases as cluster size
  increases** — "cluster size" here means observations per random effect/cluster,
  not the number of clusters. Joe does not examine AGHQ, so it speaks to
  mechanism (A) only, not the crossover in (B).

- **Breslow, N.E., & Lin, X. (1995).** "Bias correction in generalised linear
  mixed models with a single component of dispersion." *Biometrika*, 82(1),
  81–91. https://doi.org/10.1093/biomet/82.1.81 — derives the classical result
  that first-order Laplace (equivalently PQL) variance-component bias is **O(1)
  in the number of clusters** but shrinks with the **number of observations per
  cluster**; correction factors bring it close to a second-order Laplace
  expansion. This is the textbook source for exactly the "Laplace bias is flat in
  n, driven by observations-per-cluster" structure in your observation (A).

- **Lin, X., & Breslow, N.E. (1996).** "Bias correction in generalized linear
  mixed models with multiple components of dispersion." *Journal of the American
  Statistical Association*, 91(435), 1007–1016. (DOI not independently
  confirmed in this session — **UNVERIFIED** exact DOI, but title/venue/pages
  confirmed by two independent search hits.) Extends the above to multiple
  dispersion components; same qualitative conclusion.

- **Pinheiro, J.C., & Chao, E.C. (2006).** "Efficient Laplacian and adaptive
  Gaussian quadrature algorithms for multilevel generalized linear mixed
  models." *Journal of Computational and Graphical Statistics*, 15(1), 58–81.
  https://doi.org/10.1198/106186006X96962 — a computational-algorithm paper
  (nested AGQ for multilevel models); I found no explicit small-n
  crossover/error-cancellation discussion in the available summaries. Relevant
  as the standard AGQ-for-GLMM reference, not as evidence for the crossover
  itself.

- **Rabe-Hesketh, S., Skrondal, A., & Pickles, A. (2002).** "Reliable estimation
  of generalized linear mixed models using adaptive quadrature." *The Stata
  Journal*, 2(1), 1–21. First proposal of adaptive quadrature for multilevel
  models; framed entirely as ordinary-quadrature-fails-so-use-AGHQ. No small-n
  degradation of AGHQ relative to Laplace/PQL is discussed in the material I
  could retrieve.

- **Rabe-Hesketh, S., Skrondal, A., & Pickles, A. (2005).** "Maximum likelihood
  estimation of limited and discrete dependent variable models with nested
  random effects." *Journal of Econometrics*, 128(2), 301–323. (DOI not
  independently confirmed — **UNVERIFIED**.) General ML/AGHQ framework paper for
  gllamm; same caveat as above — no crossover discussion found.

- **Liu, Q., & Pierce, D.A. (1994).** "A note on Gauss-Hermite quadrature."
  *Biometrika*, 81(3), 624–629. https://doi.org/10.1093/biomet/81.3.624 —
  establishes that order-1 (A)GHQ **is** the Laplace approximation, and higher
  orders are progressively more accurate integral approximations. This is the
  formal basis for calling AGHQ(k=15) "more accurate" than Laplace as an
  *integration* method — it says nothing about finite-sample *estimation* bias,
  which is the separate issue at stake here.

- **Raudenbush, S.W., Yang, M.-L., & Yosef, M. (2000).** "Maximum likelihood for
  generalized linear models with nested random effects via high-order,
  multivariate Laplace approximation." *Journal of Computational and Graphical
  Statistics*, 9(1), 141-157. https://doi.org/10.1080/10618600.2000.10474870 —
  compares PQL, GHQ, AGHQ, and sixth-order Laplace; reports 6th-order Laplace as
  "remarkably accurate," implying (but not directly testing your regime) that
  *integration* accuracy and *finite-sample estimator* accuracy are not the same
  axis. No explicit crossover/cancellation claim found.

**Verdict on the "error cancellation" framing specifically**: I found **no**
paper (Breslow-Lin, Joe, Pinheiro-Chao, Rabe-Hesketh et al., Ju et al., or
Capanu et al.) that states the *explicit* claim you are making — "Laplace's
small-sample adequacy is two errors cancelling." Ju et al. (2020) is the closest
real analogue (a documented AGHQ-worse-than-Laplace crossover in small/sparse
regimes) but they do not attribute it to bias cancellation; they simply report
the empirical ranking. The cancellation account is **your interpretation of an
otherwise-undocumented juxtaposition of two known-separately mechanisms** (the
O(1/cluster-size) integration bias of Laplace, and the O(1/n-clusters) finite-
sample estimation bias of ML) — plausible, consistent with both mechanisms'
known directions and scalings, but not something I can point to as an existing
citation. Treat it as your own synthesis, not a replicated literature claim.

## 2. The ML small-sample bias for variance components/loadings in GLMMs: direction and scaling

- Classical **linear**-model result (background, not GLMM-specific): ML variance
  estimates are biased **downward** by a factor related to degrees of freedom
  used by fixed effects — this is exactly why REML exists. Several of the
  general-audience sources found (e.g., the *Modeling Clustered Data with Very
  Few Clusters* review, `tandfonline.com/doi/full/10.1080/00273171.2016.1167008`)
  restate this: "ML estimates of intercept variance are highly negatively
  biased... REML vastly reduces the bias."
- For **binary/discrete GLMMs** specifically, Capanu, Gönen & Begg (2013, cited
  above) find both PQL and Laplace **underestimate** the variance component in
  their sparse binary scenarios (PQL worse than Laplace), consistent with your
  observation (A)'s direction (downward) for Laplace.
- What I did **not** find a clean, direct statement of: that *exact* ML/AGHQ
  variance-component or loading estimates become **upward** biased as the
  *number of clusters* (not cluster size) shrinks, in a binary/discrete GLMM or
  GLLVM specifically. The closest general-purpose result is **Self, S.F., &
  Liang, K.Y. (1987)**, "Asymptotic properties of maximum likelihood estimators
  and likelihood ratio tests under nonstandard conditions," *Journal of the
  American Statistical Association*, 82(398), 605–610.
  https://doi.org/10.1080/01621459.1987.10478472 — establishes that when a true
  variance parameter is at or near the boundary of its parameter space (zero),
  the small-sample MLE distribution is a projection of a Gaussian onto the
  admissible (non-negative) region. This produces a mechanical **upward** pull
  on variance-like estimates at small sample sizes purely from the boundary
  constraint, independent of any integration-approximation bias. This is a
  standard, well-established mechanism, but it is about the boundary-truncation
  problem, not specifically about "AGHQ vs Laplace."
- **A separate, and I think underused, candidate mechanism for your specific
  metric**: your target quantity is a **norm** of a vector estimator,
  `ratio = ||Lambda_hat|| / ||Lambda_true||`. By Jensen's inequality, for any
  estimator with nonzero sampling variance, `E[||Lambda_hat||] >= ||E[Lambda_hat]||`
  — i.e., even a *marginally unbiased* Lambda_hat produces an upward-biased norm,
  and the size of that inflation grows with the estimator's variance relative to
  the true norm (worse at small n, worse for a noisier estimator). This is a
  documented general phenomenon under different names — "regression to the
  mean"/"winner's curse" for the absolute value of a coefficient (see the
  general treatment in the *Winner's Curse* literature, e.g. van Zwet & Cator,
  "The Significance Filter, the Winner's Curse and the Need to Shrink,"
  arXiv:2009.09440), and "transformation-induced bias" for convex functionals of
  unbiased estimators (Rainey, "Transformation-Induced Bias," *Political
  Analysis*, Cambridge Core). **I did not find this Jensen/norm-inflation point
  applied specifically to GLLVM factor-loading norms or to an AGHQ-vs-Laplace
  comparison** — this is my own inference connecting a well-established general
  statistical fact to your specific metric, offered as a candidate *additional*
  (not alternative) explanation for why AGHQ's higher estimation variance at
  small n could inflate `||Lambda_hat||` even beyond whatever genuine point-bias
  exists in the components of Lambda_hat. Worth checking directly against your
  own simulation output (component-wise bias vs. norm-of-estimator bias) rather
  than treating this note as confirmation.

## 3. The remedies, and their evidence

- **(a) Cox & Reid (1987) adjusted profile likelihood.** Cox, D.R., & Reid, N.
  (1987), "Parameter orthogonality and approximate conditional inference,"
  *Journal of the Royal Statistical Society, Series B*, 49(1), 1–39.
  https://doi.org/10.1111/j.2517-6161.1987.tb01422.x. For non-Gaussian variance
  components specifically, **Lee, Y., & Nelder, J.A. (1996)**, "Hierarchical
  generalized linear models," *JRSS B*, 58(4), 619–656.
  https://doi.org/10.1111/j.2517-6161.1996.tb02105.x, generalise this to an
  h-likelihood-based REML analogue (`h_A = h - (1/2) log det(M)`), which for
  ordinary linear mixed models reduces to REML and to the Cox-Reid dispersion
  correction. This is the standard non-Gaussian generalisation of REML that the
  literature actually uses in practice (`hglm`/HGLM software family), rather
  than applying Cox-Reid directly at the GLLVM scale.
- **(b) Firth (1993) bias reduction.** Firth, D. (1993), "Bias reduction of
  maximum likelihood estimates," *Biometrika*, 80(1), 27–38.
  https://doi.org/10.1093/biomet/80.1.27. Removes the first-order (O(1/n)) bias
  term from the score equation; in canonical exponential families this is
  equivalent to a Jeffreys-prior penalty. Firth's method is a **fixed-effects**
  bias-reduction tool by default (logistic/Poisson regression); its extension to
  variance/covariance parameters in mixed/latent-variable models is not the
  same off-the-shelf recipe, and I found no paper directly applying vanilla
  Firth correction to GLLVM factor loadings.
- **(c) Penalty/MAP priors on variance components — this is the remedy with the
  strongest direct evidence for your exact failure mode (small number of
  clusters, discrete/sparse response, boundary-adjacent variance/loading).**
  **Chung, Y., Rabe-Hesketh, S., Dorie, V., Gelman, A., & Liu, J. (2013)**, "A
  nondegenerate penalized likelihood estimator for variance parameters in
  multilevel models," *Psychometrika*, 78(4), 685–709.
  https://doi.org/10.1007/s11336-013-9328-2. Directly targets the problem of
  ML/REML variance estimates collapsing to (or being pulled toward) the zero
  boundary **when the number of groups is small**, proposes a log-gamma(2, λ)
  penalty (posterior mode under a weakly informative prior) calibrated so the
  penalized estimate sits about one standard error away from zero when the raw
  MLE is zero, and gives simulation evidence of the correction. This is by the
  same author (Rabe-Hesketh) named in your prompt for the AGHQ/adaptive-
  quadrature literature, and is specifically a small-number-of-groups remedy —
  it is the best-matched citation to your problem shape of anything found in
  this search.
- **(d) Bootstrap/analytic bias correction.** General bootstrap bias-correction
  for GLMM variance components is well established as a technique (ratio
  correction for variance components, mean correction for fixed effects; see
  e.g. the `lmeresampler` package documentation and associated literature on
  parametric bootstrap for mixed models), but I found no paper claiming it is
  *preferred* over penalty/MAP approaches for GLMM/GLLVM variance components —
  the two are typically presented as alternative tools (bootstrap is more
  general-purpose/expensive; MAP/penalty is closed-form/cheap but requires
  choosing a prior/penalty family).

**Which is actually recommended, on what evidence**: of the four, only (c) —
penalty/MAP priors on variance components, specifically Chung, Rabe-Hesketh,
Dorie, Gelman & Liu (2013) — is (i) aimed explicitly at the "few clusters,
boundary-adjacent variance parameter" failure mode you are seeing, (ii)
supported by simulation evidence in the original paper, and (iii) already
implemented in shipped software (the `blme` R package implements this
estimator). Cox-Reid/h-likelihood REML-analogues (a) are the standard
generalization for *point estimation bias* in variance components generally,
but are not specifically a small-number-of-clusters remedy — they correct the
`O(1/n_obs-per-cluster)`-type profile-likelihood bias, which is closer to your
mechanism (A) (Laplace's flat bias) than to your mechanism (B) (AGHQ's growth at
small n).

## 4. Cox-Reid in a latent-variable model — does the adjustment's size depend on the nuisance information share?

- **Reid, N., & Fraser, D.A.S. (2003).** "Likelihood inference in the presence
  of nuisance parameters." Proceedings of PHYSTAT2003 (Stanford, SLAC), in *L.
  Lyons, R. Mount, R. Reitmeyer (eds.), SLAC eConf C030908*, pp. 265–271.
  (Preprint mirror: arXiv:physics/0312079.) Confirms two things you named: (i)
  the Cox-Reid adjustment requires the nuisance parameter block to be
  (approximately) **orthogonal** to the parameter of interest, and where exact
  orthogonality is unavailable the adjustment is only approximate; and (ii) it
  states explicitly that **the Cox-Reid adjusted likelihood is not invariant to
  one-to-one reparametrizations of the nuisance parameter** — a genuine, cited
  limitation, not an inference on my part.
- **The specific scaling claim you asked about — that the adjustment's *size*
  shrinks when the nuisance (fixed-effect) block carries a small share of the
  total information — I did not find stated as a general theorem anywhere in
  this search.** It is, however, consistent with the *structure* of the
  adjustment term itself: the Cox-Reid penalty is `-(1/2) log det(j_φφ(τ,
  φ̂_τ))`, the log-determinant of the *observed information for the nuisance
  parameters alone*. When the nuisance block (here, T=4 trait intercepts) is
  small relative to the total amount of data/information in the likelihood (many
  sites × traits, one q=1 latent factor per site), that log-determinant term is
  necessarily a small piece of the total log-likelihood scale, so a ~1% shift
  from applying the adjustment is dimensionally unsurprising — but this is
  *my* dimensional-analysis inference from the formula, not a result I can
  cite. Mark it as **AGENT-INFERRED**, consistent with the formula but not a
  literature-verified scaling law.
- The general Cox-Reid → REML connection (point 3a above, via Lee & Nelder 1996)
  is the standard route by which people generalize "REML corrects for
  fixed-effect degrees of freedom" to non-Gaussian variance components — and
  REML's own correction is well known to matter *more* when the fixed-effect
  block is large relative to the data (more df consumed → bigger ML
  underestimate → bigger REML correction), which is the same qualitative
  direction as your empirical finding (weak correction with few fixed effects),
  even though I could not find a citation stating it as a general scaling
  theorem for the *non-Gaussian* Cox-Reid case specifically.

## 5. GLLVM-specific / IRT analogue

- **Item response theory is indeed the closest established literature**, as you
  suspected, but what I found documents small-sample bias **in the discrimination
  (loading-like) parameter of the 2PL model**, generally in the **downward**
  direction for standard marginal maximum likelihood (MMLE), not upward:
  - Search results on 2PL small-sample calibration (e.g. the hierarchical-Bayes
    2PL small-sample literature reviewed in PMC7262992 and PMC10700496,
    "underestimation of the item discrimination parameter... across all sample
    sizes and test lengths" for standard non-hierarchical MMLE) point the
    opposite direction from your AGHQ-upward-bias-at-small-n result. Note this
    is a genuinely different estimation method (MMLE via EM,
    Bock & Aitkin 1981) and a genuinely different small-sample regime (small
    number of *examinees*, i.e., analogous to your latent-variable dimension
    being estimated per unit — closer to "small n" in the same sense as your
    ladder) — so the **direction mismatch (IRT: downward; your AGHQ: upward) is
    a real discrepancy worth flagging**, not just noise. It may reflect that
    standard 2PL MMLE bias studies are usually run at moderate-to-large sample
    sizes (n=250-1000) where they are still in a different bias regime than
    your n=25-200 range; I did not find IRT simulations descending as low as
    your n=25-200 range to check whether the sign flips there too.
  - **Bock, R.D., & Aitkin, M. (1981).** "Marginal maximum likelihood estimation
    of item parameters: Application of an EM algorithm." *Psychometrika*, 46(4),
    443–459. https://doi.org/10.1007/BF02293801 — the foundational MMLE/EM
    reference against which essentially all IRT small-sample bias studies are
    benchmarked; establishes MMLE via numerical (originally Gauss-Hermite)
    quadrature over the latent trait, i.e., the direct IRT analogue of your
    AGHQ approach.
- **GLLVM computational-methods literature** (closest to gllvmTMB itself):
  - **Niku, J., Brooks, W., Herliansyah, R., Hui, F.K.C., Taskinen, S., & Warton,
    D.I. (2019).** "Efficient estimation of generalized linear latent variable
    models." *PLOS ONE*, 14(5), e0216129.
    https://doi.org/10.1371/journal.pone.0216129 — the `gllvm` R package paper;
    compares Laplace and variational approximation for GLLVM likelihoods and
    reports accuracy/computational trade-offs, but the material I retrieved does
    not include an AGHQ-vs-Laplace small-n crossover comparison specifically —
    it is the right paper to check directly (full text) for whether they ran an
    n-descent like yours, rather than something I can confirm from search alone.
  - **Bianconcini, S., & Cagnone, S. (2012).** "Estimation of generalized linear
    latent variable models via fully exponential Laplace approximation."
    *Journal of Multivariate Analysis*, 112, 183–193. A second-order/fully-
    exponential refinement of Laplace for GLLVMs — relevant as "yet another
    accuracy tier between first-order Laplace and full quadrature," but I found
    no explicit small-n bias-direction comparison for it either.
  - **Bianconcini, S., Cagnone, S., & Rizopoulos, D.** "Approximate likelihood
    inference in generalized linear latent variable models based on integral
    dimension reduction." (arXiv:1503.01249; later journal version exists but I
    could not confirm the exact venue/year in this session —
    **UNVERIFIED venue**.) The abstract promises a comparison of asymptotic
    properties across approximation methods, but I could not retrieve the
    specific numeric small-n bias comparison from the fetched excerpt — treat
    any claim about "DRM vs AGH similar bias, DRM underestimates Monte Carlo
    variance" as **UNVERIFIED**; it surfaced in an AI-generated search summary
    I could not trace to a specific page of the paper, so I am flagging rather
    than repeating it as fact.
  - General factor-analysis-with-categorical-indicators literature (Forero,
    Maydeu-Olivares & Gallardo-Pujol 2009, *Structural Equation Modeling*,
    16(4), 625–641) confirms the broader psychometric point that **loading
    estimators for ordinal/binary indicators are known to be small-sample
    sensitive**, and separately, classical exploratory factor analysis
    "capitalization on chance" is a well known phenomenon whereby principal-
    component-type loading estimates are **inflated (overestimated)** in small
    samples — consistent in *direction* with your AGHQ-upward-at-small-n result,
    though this literature is about EFA/PCA estimators, not ML/AGHQ-based GLLVM
    fitting, so treat the match as a directional analogue rather than a direct
    hit.

## Standard vs. unusual: verdict on (A) and (B)

- **(A) — Laplace's flat, n-independent ~20% downward bias, driven by
  observations-per-cluster (here T=4 traits/site) rather than number of
  clusters — is a STANDARD, well-established result.** It is exactly the
  Breslow & Lin (1995) / Lin & Breslow (1996) / Joe (2008) finding: first-order
  Laplace (≈PQL) bias in GLMMs is an O(1/cluster-size) phenomenon that does not
  vanish as the number of clusters grows, and is worse for binary/discrete
  responses than for continuous ones. Your T=4 is fixed across the whole n-ladder,
  which is exactly why the bias you measured is flat from n=200 to n=3200 — this
  is the textbook signature, not a surprise finding.
- **(B) — AGHQ becoming markedly worse (upward biased) than Laplace below about
  n≈400 is a REAL BUT LESS-ESTABLISHED, context-dependent result.** It is
  documented in at least one real published comparison (Ju et al. 2020, in a
  meta-analysis/sparse-binary-data context) but contradicted in direction/
  severity by another (Capanu, Gönen & Begg 2013, in a different binary-GLMM
  design where AGQ never got worse than Laplace). I found no general theorem
  guaranteeing this crossover, and no paper that frames it — as you do — as
  "two errors cancelling" for Laplace. The magnitude and the specific shape
  (crossover point, then Laplace's own blow-up at n=25) both look like they
  are your own simulation's original contribution rather than a replication of
  a known curve. The most likely *general* mechanisms underlying it — boundary-
  adjacent MLE bias (Self & Liang 1987) and Jensen/norm inflation of a noisy
  vector estimator — are individually standard statistical facts, but their
  *combination*, applied to a GLLVM factor-loading norm specifically, is not
  something I found already written down.

## Single most useful citation for the small-n remedy

**Chung, Y., Rabe-Hesketh, S., Dorie, V., Gelman, A., & Liu, J. (2013). "A
Nondegenerate Penalized Likelihood Estimator for Variance Parameters in
Multilevel Models." *Psychometrika*, 78(4), 685–709.
https://doi.org/10.1007/s11336-013-9328-2.**

It is the one paper found here that (i) is aimed at exactly your failure
regime — small number of groups, variance/loading-like parameters pulled toward
a boundary — (ii) comes from the same methodological lineage as the AGHQ
literature you are drawing on (Rabe-Hesketh), (iii) gives a concrete, already-
implemented penalty (log-gamma(2, λ) posterior mode, shipped in the `blme`
package) rather than a purely theoretical proposal, and (iv) reports simulation
evidence for the fix. If gllvmTMB wants a "next thing to try" for the n<400
regime rather than just documenting the crossover, this is the most directly
transferable remedy of everything surveyed.
