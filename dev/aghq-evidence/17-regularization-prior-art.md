# Prior art for a regularization/prior fix to the small-*n* loading-divergence problem

Read-only literature note. Tools used: `WebSearch` and `WebFetch` only (no
NotebookLM session available in this context; no package code was read or run —
this is citation-gathering, cross-checked against `dev/aghq-evidence/10-penalty-prior.md`
in this same directory, which already ran the empirical ridge-penalty slice this
note supplies citations for). Every claim below is either a **direct quote/close
paraphrase from a fetched source**, or explicitly flagged **UNVERIFIED** where a
search only returned a secondary summary I could not confirm against a primary
text. I invented no citations; where I found nothing, I say so.

---

## Answer up front (the four things asked for in RETURN)

**(a) Is a prior on the loading/discrimination parameter standard practice in IRT?**
Yes, for the specific commercial/legacy tradition (BILOG-MG, and flexMIRT's own
defaults) that grew up around exactly this divergence problem — but it is
**not** universal across all IRT software. The academic open-source R packages
most likely to be a gllvmTMB user's reference point (`ltm`, and by all evidence
`TAM`) run **pure marginal ML with no default prior**, and `mirt` requires the
user to opt in explicitly via a `PRIOR = (...)` statement — nothing is applied
unless asked for. So "IRT always regularizes the discrimination parameter" is an
overstatement; the accurate claim is narrower: *the software lineage that
specifically targets calibration stability under Heywood-like divergence
(BILOG's descendants) ships a default lognormal-type prior on discrimination,
and the open-source MML packages do not.* Canonical theory citation: **Mislevy
(1986)**, Bayes modal estimation, Psychometrika 51, 177–195.

**(b) What do the ecology packages default to?**
Split finding, and it is informative: **HMSC ships a shrinkage prior on
loadings by default** (multiplicative gamma process, Bhattacharya & Dunson 2011
via Tikhonov et al. 2017); **`boral` puts a prior on loadings but an
uninformative/flat one, not a shrinkage prior** (`normal(0, 100)`-scale by
default — a weak prior, not a regularizer); **`gllvm` puts no prior or penalty
on loading magnitude at all** — its identifiability handling is purely a
*rotational* constraint (upper-triangular zeros + positive diagonal), which
fixes rotation/reflection but does nothing about the loadings' scale
diverging; **VAST** likewise only imposes rotational/sign constraints
(lower-triangular loadings, sum-to-zero on factors), not a scale penalty;
**sdmTMB** has no native multi-species JSDM/loadings machinery to check against
(single- or few-species spatial GLMMs) — this is a **nothing found**, reported
as such rather than guessed. So among the closest comparators, **HMSC is the
one clear precedent for "ship a default shrinkage prior on loadings,"** and
`gllvm`/VAST are the clear counter-evidence that a maturity-benchmark package
can and does ship *without* one, using rotational constraints alone.

**(c) Single most defensible penalty form + strength, with citation:**
The literature converges on penalizing the *boundary-avoidance* quantity, not
an arbitrary ridge on raw loadings — in the classical (continuous-response)
factor-analysis literature that quantity is the unique variance Ψ, per
**Akaike (1987)**, *Factor analysis and AIC*, Psychometrika 52, 317–332, and
most concretely per **Sterzinger (2025/2026)**, *Maximum softly penalised
likelihood in factor analysis* (arXiv:2510.06465; reported as accepted at
Psychometrika — journal/DOI **UNVERIFIED**, see §3), whose penalty is
```
P*(theta) = -(rho*n/2) * tr( Psi^{-1/2} Lambda Lambda' Psi^{-1/2} )
```
(the Akaike form) with a **derived, not fitted, tuning rate** `rho = 2*sqrt(2/n^3)`,
chosen so the penalty is `o_p(sqrt(n))` — vanishing fast enough, as `n` grows,
to preserve first-order ML consistency and asymptotic normality, while still
being strong enough at small `n` to keep the estimate off the boundary. This
is exactly the kind of "principled, not tuned on the truth" rate the task asks
for, because it is derived from an information-accumulation argument, not
calibrated against a known `Lambda_true`.
**But — important qualification for gllvmTMB's binary case, not found stated
this way in any single source, my own synthesis of two separate facts below:**
this whole Ψ-boundary machinery assumes a free unique-variance parameter to
regularize. A Bernoulli/binomial-logit response has **no free residual
variance** — Ψ is fixed by the link, not estimated — so the Heywood-case
degeneracy cannot show up as `Psi -> 0`; by the mechanism **Wang, De Boeck &
Yotebieng (2023)** describe (§2 below), it shows up **directly as the loading
itself diverging** (their "extremely large discrimination" case). That is
precisely why the IRT literature, not the classical Ψ-penalty literature, is
the load-bearing analogy for this project: the penalty needs to sit **on
Lambda itself** (equivalently, on `tr(Sigma) = tr(Lambda Lambda')`, confirmed
algebraically identical at `q=1` in `10-penalty-prior.md` in this directory),
in the same spot IRT puts its lognormal prior on discrimination — not on a Ψ
term this model class does not have free.

**(d) Reasons this could be a bad idea (as valuable as support):**
- The Ju et al. (2020) finding already on file in `07-prior-art-crossover.md`
  (BMC Med Res Methodol, AGHQ not uniformly better than Laplace under sparse
  binary data) is a caution that "more exact machinery" can misbehave in ways
  a prior papers over rather than fixes — a prior changes *where* the optimum
  sits, it does not diagnose *why* the surface is flat there.
- Every classical-FA source (Van Driel 1978, Kano 1998) treats a Heywood case
  as **diagnostic information** ("your q or your n is not supporting this
  model") as much as a nuisance to be regularized away; several authors
  explicitly warn against mechanically suppressing the symptom (see §2).
- Bias-at-large-n is the sharpest version of the risk (§5): **any** prior/ridge
  is by construction a shrinkage estimator, and shrinkage estimators are
  biased at every finite `n` by design — the open question the literature
  does *not* fully answer for this exact model is how fast that finite-sample
  bias decays relative to `n=3200`'s already near-unbiased 1.0021 ratio. The
  Sterzinger rate is the only source found that gives an explicit asymptotic
  guarantee here (bias vanishes at `o_p(n^{-1/2})` relative rate), and even
  that guarantee is for the classical Ψ-penalty, not a Lambda-penalty in a
  binary-response model — extending it to this project's exact setting is an
  **inference, not a proven result**.

---

## 1. Item response theory — the closest mature analogue

### 1a. Is a prior on discrimination standard practice, and what's the citation?

**Theory:** Yes, with a specific, well-cited origin. **Mislevy, R.J. (1986).**
"Bayes modal estimation in item response models." *Psychometrika*, 51,
177–195. doi:10.1007/BF02293979. This is the paper search results converge on
as *the* canonical citation for placing priors on item (and person) parameters
in 1PL/2PL/3PL models and maximizing the posterior mode (EM-based) instead of
the raw marginal likelihood, specifically to stabilize estimation. Related/
earlier: Swaminathan & Gifford's Bayesian estimation papers for the 1PL/2PL/3PL
(cited alongside Mislevy in the software-review literature) — I did not
independently pull full bibliographic details for these and flag them
**UNVERIFIED** pending a direct check.

**What the major implementations actually default to:**

| Software | Prior on discrimination by default? | Evidence found |
|---|---|---|
| **BILOG-MG** | **Yes** — lognormal(0, 0.5) on the slope/discrimination `a`, alongside a Beta prior on the guessing parameter `c`. | Convergent secondary-source synthesis (multiple independent search summaries agree on "lognormal(0, 0.5)" and cite Mislevy & Bock's BILOG lineage). I could **not** get a direct quote from the primary BILOG-MG manual text itself (not fetchable in this session) — treat the *existence* of a default lognormal prior on `a` as well-supported, and the exact **(0, 0.5)** parameterization as **moderate-confidence, not independently verified against the primary manual**. |
| **flexMIRT** | **Yes, it has its own native defaults** — directly confirmed quote from a peer-reviewed software review: *"Only the normal, log-normal and two-parameter beta distributions are supported. If not specified, default priors are used where appropriate."* (flexMIRT v3.5 software review, PMC5985703). Critically, the **same review's own replication exercise had to manually add explicit `Prior` statements in the `<Constraints>` section specifically "to match the BILOG-MG default priors,"** which only makes sense if flexMIRT's own native defaults are **not** identical to BILOG-MG's — i.e., flexMIRT ships *a* default, but not necessarily the *same* lognormal(0,0.5). The exact native flexMIRT default numeric values are **UNVERIFIED** (not found in the sources I could fetch). |
| **`mirt` (R)** | **No default prior applied unless the user opts in.** `mirt.model()`'s documented syntax is `PRIOR = (items, ..., parameterName, priorType, val1, val2)` — an entirely opt-in mechanism the user must write explicitly (e.g. `PRIOR = (1-5, d, norm, 0, 2)`). I could not get a clean text extraction of the full CRAN PDF manual to find an explicit sentence saying "no prior by default" (the PDF is compressed and did not render through the fetch tool), so this is inferred from the consistent syntax documentation across every source found, not a direct quote — **moderate-high confidence, not a verbatim confirmation**. |
| **`ltm` (R)** | **No prior; pure marginal ML.** Rizopoulos (2006), *ltm: An R Package for Latent Variable Modeling and Item Response Theory Analyses*, Journal of Statistical Software 17(5). Estimation is described as marginal maximum likelihood via Gauss-Hermite quadrature; the discrimination parameter is either fixed by the user (`discr = <value>`) or estimated with **no prior distribution mentioned anywhere** in the package documentation found. |
| **`TAM` (R)** | **No evidence of a default prior on discrimination found.** `tam.mml.2pl()`'s documented arguments (`B.fixed`, `xsi.fixed`, `beta.fixed`) are all about *fixing/constraining* specific entries, not about a Bayesian prior; nothing in the fetched documentation suggests a default prior distribution is placed on the slope matrix `B`. Reported as a **negative finding** (nothing found), not a confirmed absence — the full technical manual (Robitzsch et al.) was not exhaustively searched. |

**Reading:** the pattern is not "IRT does this by default," it is "the software
lineage built around calibrating live testing programs, where a divergent item
would silently corrupt a test bank, defaults to a stabilizing prior; the
academic/open-source estimation packages default to unregularized MML and
leave the user to add a prior if they hit trouble." That is arguably even more
useful as prior art for gllvmTMB, because it is evidence that **the
"regularize the loading/discrimination parameter" fix is specifically the one
adopted by the tools built for production stability**, not a purely academic
curiosity.

### 1b. Is the flat-likelihood/quadrature-instability finding here connected to a Heywood case in the IRT literature?

Yes — directly, and this is probably the single most load-bearing citation for
the whole investigation:

**Wang, S., De Boeck, P., & Yotebieng, M. (2023).** "Heywood Cases in
Unidimensional Factor Models and Item Response Models for Binary Data." *Applied
Psychological Measurement*, 47(2), 141–154. doi:10.1177/01466216231151701.
(Preprint: arXiv:2108.04925.) Quote (via fetched abstract/summary): *"Heywood
cases are known from linear factor analysis literature as variables with
communalities larger than 1.00"* and this same underlying problem *"shows up as
nonconvergence cases in theta parameterized factor models and as extremely
large discriminations in item response theory (IRT) models."* I.e., **the paper
states explicitly that an IRT discrimination parameter blowing up to an
extreme/unbounded value is the same underlying degeneracy as a classical
Heywood case (communality ≥ 1, unique variance ≤ 0) — just relabeled because
the binary-response parameterization has no free residual variance to go
negative.** This is exactly the failure mode described in the task (loadings
inflating a Sigma with a nearly flat objective).

A second, more recent and more technical paper narrows this further:
**Verkuilen, J., & Johnson, P.J. (2024).** "A Definition of a Heywood Case in
Item Response Theory Based on Fisher Information." *Entropy*, 26(12), 1096.
doi:10.3390/e26121096. This paper explicitly frames Heywood-type degeneracy in
IRT in terms of the **Fisher information / curvature of the likelihood**,
which is conceptually the same diagnostic the task already used (the near-flat
nll sweep across quadrature nodes). I was not able to fetch its full text in
this session (403 on the publisher page) so I cannot quote it verbatim; the
title, journal, year, and DOI above come from a direct search-result match
(MDPI Entropy listing + PMC mirror, PMC11675695), not from reading the paper —
flagged as **citation confirmed, content summary UNVERIFIED beyond the
abstract-level description search returned.**

---

## 2. Heywood cases / improper solutions in classical factor analysis

All six names given in the brief were checked; five resolved to real,
verifiable citations, one (Van Driel) resolved cleanly and the others are
consistent with standard psychometric-literature knowledge of this topic:

- **Van Driel, O.P. (1978).** "On various causes of improper solutions in
  maximum likelihood factor analysis." *Psychometrika*, 43, 225–243.
  Identifies causes of Heywood cases: small sample size, poorly defined
  factors, over-extraction, underidentification, model misspecification,
  sampling fluctuation combined with a true value near the boundary, and
  outliers. Recommends checking whether a confidence interval around the
  negative/near-zero unique-variance estimate includes zero, as a diagnostic
  for "chance near-boundary" vs. a genuine misspecification.
- **Anderson, J.C., & Gerbing, D.W. (1984).** "The effect of sampling error on
  convergence, improper solutions, and goodness-of-fit indices for maximum
  likelihood confirmatory factor analysis." *Psychometrika*, 49, 155–173. Monte
  Carlo finding directly on point: **nonconvergent and improper solutions
  occurred more frequently at smaller sample sizes and with fewer indicators
  per factor** — this is the classical-FA analogue of the task's own n≤800
  bimodal-divergence measurement.
- **Boomsma, A. (1985).** "Nonconvergence, improper solutions, and starting
  values in LISREL maximum likelihood estimation." *Psychometrika*, 50,
  229–242. Monte Carlo robustness study of the same three problems
  (nonconvergence / improper solutions / starting-value sensitivity) in a SEM
  context.
- **Bollen, K.A. (1987).** "Outliers and improper solutions: A confirmatory
  factor analysis example." *Sociological Methods & Research*, 15, 375–384.
  Shows a single unusual observation can be sufficient to produce a Heywood
  case, i.e., improper solutions are not always a sample-size story — they can
  be an outlier-sensitivity story.
- **Kano, Y. (1998).** "Improper solutions in exploratory factor analysis:
  Causes and treatments." In *Data Science, Classification, and Related
  Methods* (Springer). Organizes causes into three buckets — sampling
  fluctuation, model underidentification, model misfit — and gives a
  diagnostic checklist matched to which bucket applies, explicitly treating
  the improper solution as **diagnostic signal about model/data fit**, not
  merely noise to regularize away.
- **Martin, J.K., & McDonald, R.P. (1975).** "Bayesian estimation in
  unrestricted factor analysis: A treatment for Heywood cases." *Psychometrika*,
  40, 505–517. The earliest Bayesian-prior treatment found: maximizes the
  **posterior**, not the likelihood, using a prior on the error-covariance
  matrix that assigns zero probability to negative unique variances (so a
  negative/improper solution is structurally impossible under the posterior
  rather than merely discouraged). Also introduces the **exact Heywood case**
  (a unique variance estimate exactly at zero) vs. **ultra-Heywood case**
  (strictly negative) distinction, which is a useful vocabulary the task's own
  "40-50% diverge" measurement could be re-expressed in (are the divergent
  fits landing near a boundary value, or genuinely unbounded/ultra-Heywood?).

Two more directly on point, found opportunistically rather than named in the
brief:

- **Chen, F., Bollen, K.A., Paxton, P., Curran, P.J., & Kirby, J.B. (2001).**
  "Improper Solutions in Structural Equation Models." *Sociological Methods &
  Research*, 29(4), 468–508. A broad, later survey of the same problem class in
  SEM. (Title/venue confirmed via search result; not independently read in
  full — flag as citation-confirmed only.)
- The **De Boeck / Wang / Yotebieng** and **Verkuilen / Johnson** IRT papers in
  §1b above are themselves squarely in this literature — they are the bridge
  the task specifically asked about between the classical-FA Heywood
  literature and the binary-IRT discrimination-divergence literature.

**On frequency as a function of sample size:** none of the sources fetched give
a single number transferable to this project's exact design (T traits, q
factors, binomial links), but Anderson & Gerbing's Monte Carlo direction
(smaller n and fewer indicators per factor → more nonconvergence/improper
solutions) is qualitatively identical to the task's own measurement (bimodal
divergence at n≤800, resolved by n=3200).

---

## 3. Regularized / penalized factor analysis, and choosing the penalty strength

**Ridge/boundary-avoidance penalties restoring curvature:**

- **Akaike, H. (1987).** "Factor analysis and AIC." *Psychometrika*, 52,
  317–332. Confirmed real (ERIC EJ363000; Semantic Scholar; multiple
  citations). Frames a factor-analysis penalty as equivalent to a Bayesian
  model choice, and is the origin of the `tr(Psi^{-1/2} Lambda Lambda'
  Psi^{-1/2})` penalty form used downstream by Sterzinger (below). I did not
  find, and do not claim, an explicit "Akaike proved this restores curvature to
  a flat likelihood" sentence — the curvature-restoration property is
  Sterzinger's contribution (below), building on Akaike's penalty form.
- **Sterzinger, P.** "Maximum softly penalised likelihood in factor analysis."
  arXiv:2510.06465 (posted Oct 2025; a companion Cambridge-hosted Psychometrika
  page exists at `cambridge.org/.../maximum-softly-penalized-likelihood-in-
  factor-analysis` — **journal acceptance and exact DOI are UNVERIFIED**, based
  only on a derived DOI string `10.1017/psy.2026.10092` returned by a fetch
  summarizer, not read directly from a publisher page). This is the most
  directly relevant paper found for the task's exact question ("is there a
  ridge penalty that restores curvature to a flat/boundary-adjacent
  likelihood, and how do you pick its strength without tuning on the truth?"):
  - States the problem exactly as the task frames it: *"Estimation in
    exploratory factor analysis often yields estimates on the boundary of the
    parameter space. Such occurrences, known as Heywood cases, are
    characterised by non-positive variance estimates."*
  - Formally proves existence of penalized-ML estimates **in the interior** of
    the parameter space (i.e., the penalty provably prevents the boundary
    degeneracy) for two penalty forms — the Akaike (1987) form above, and a
    second form attributed to "Hirose et al. (2011)" (I could **not**
    independently verify this second citation's exact title/journal — the
    2011 date does not match the Hirose & Yamamoto paper on the same general
    topic that I *could* verify, which is dated 2015, *Statistics and
    Computing* 25(5), 863–875, "Sparse estimation via nonconcave penalized
    likelihood in a factor analysis model" — these may be different papers or
    a preprint/journal date mismatch; flagged **UNVERIFIED**, do not cite
    "Hirose et al. 2011" without checking the original further).
  - Gives an explicit, derived (not fitted) **rate for the penalty strength**:
    `rho = 2*sqrt(2/n^3)`, justified because it makes the penalty
    `o_p(sqrt(n))` — i.e., it vanishes fast enough relative to the likelihood's
    own curvature growth that **consistency and asymptotic normality of the
    ML estimator are preserved** at large `n`, while still being active enough
    at small `n` to keep the optimizer off the boundary. This is the paper's
    direct answer to "how strong should the penalty be, non-circularly" — the
    rate is derived from an asymptotic argument about information
    accumulation, not calibrated against a known truth.

**Sparse/regularized loadings more broadly (a different goal — sparsity, not
just boundary-avoidance — but same toolkit):**

- **Hirose, K., & Yamamoto, M. (2015).** "Sparse estimation via nonconcave
  penalized likelihood in a factor analysis model." *Statistics and
  Computing*, 25(5), 863–875 (also arXiv:1205.5868). Nonconvex (SCAD/MCP-style)
  penalty for sparse loadings, implemented in the CRAN package **`fanc`**
  (pathwise coordinate descent + EM).
- **Jacobucci, R., Grimm, K.J., & McArdle, J.J. (2016).** "Regularized
  structural equation modeling." *Structural Equation Modeling*, and the
  companion **`regsem`** R package (arXiv:1703.08489). Supports ridge and lasso
  penalties on SEM/factor-model parameters, and — directly answering the
  task's "principled, non-circular tuning" question from a different angle —
  ships **cross-validation** for choosing the penalty strength `lambda`
  empirically rather than by an asymptotic rate. This is a genuinely different
  discipline from Sterzinger's derived rate: CV tunes against
  held-out predictive fit, not against the (unknown, in real applications)
  true loading scale, so it is *also* non-circular, just via a different
  mechanism (data-driven, not asymptotic-rate-driven).

**Net read for "single most defensible penalty form + strength":** for this
project's exact situation (binary link, no free unique variance, small-n
divergence with a flat sweep across quadrature accuracy), the best-supported
choice is a boundary-avoidance-style penalty in the Akaike/Sterzinger family,
adapted to sit on `Lambda`/`tr(Sigma)` rather than on a nonexistent `Psi`
(reasoning spelled out in the RETURN section above), with the penalty strength
set by an asymptotic o_p(sqrt(n))-type rate (Sterzinger's derivation) as the
primary defensible choice, and cross-validation (Jacobucci/`regsem`) as a
credible empirical fallback if a project-specific asymptotic rate cannot be
derived cleanly for the binomial-GLLVM case. **Neither option has been shown
in the literature to be validated for exactly this model class (binary GLLVM,
q latent factors, T traits) — both are transfers from adjacent literatures,
not a direct hit.**

---

## 4. What the comparable ecology packages actually do

- **`gllvm`** (Niku, Hui, Taskinen, Warton, van der Veen; Niku et al. 2019,
  *Methods in Ecology and Evolution*, 10(12), 2173–2182). Identifiability is
  handled by **fixing the upper-triangular entries of the loading matrix to
  zero and constraining the diagonal to be positive** — a rotation/reflection
  constraint only. No shrinkage prior or penalty on loading *magnitude* was
  found in any source describing the package's default behavior across
  Laplace, variational (VA), or extended-variational (EVA) estimation. This is
  a **negative finding, reported as such** — gllvm is direct evidence that a
  mature, actively-developed JSDM package in this exact application area ships
  *without* a default magnitude-regularizing prior on loadings.
- **`boral`** (Hui, F.K.C., 2016, *Methods in Ecology and Evolution*,
  doi:10.1111/2041-210X.12514). Confirmed from the CRAN manual: *"By default,
  uninformative priors are used for all parameters. That is, normal priors
  with mean zero and variance given by `hypparams[1]` are assigned to all
  intercepts, coefficients relating to latent variables, [and] cutoffs for
  ordinal responses."* The default prior **type** vector is
  `c("normal","normal","normal","uniform")`. This is a prior on loadings, but
  a **flat/weakly-informative one** (large default variance), not a shrinkage
  prior — it regularizes numerically (keeps MCMC well-behaved) but is not
  designed to pull loadings toward zero the way HMSC's shrinkage prior is.
- **HMSC** (Ovaskainen & Tikhonov et al.). **Tikhonov, G., Abrego, N., Dunson,
  D., & Ovaskainen, O. (2017).** "Using joint species distribution models for
  evaluating how species-to-species associations depend on the environmental
  context." *Methods in Ecology and Evolution*, 8(4), 443–452. HMSC's latent
  factor loadings use a **multiplicative gamma process shrinkage prior**,
  whose originating statistical-methods citation is **Bhattacharya, A., &
  Dunson, D.B. (2011).** "Sparse Bayesian infinite factor models." *Biometrika*,
  98(2), 291–306. That paper's own description (confirmed via abstract/PMC):
  *"a multiplicative gamma process shrinkage prior on the factor loadings
  which allows introduction of infinitely many factors, with the loadings
  increasingly shrunk towards zero as the column index increases."* This is
  the clearest positive precedent in the brief's list: **a widely-used,
  peer-reviewed JSDM framework ships a default shrinkage prior specifically on
  the latent loadings, adopted directly from a general Bayesian-statistics
  methods paper, not reinvented in-house.**
- **VAST** (Thorson). **Thorson, J.T., Ianelli, J.N., Larsen, E.A., Ries, L.,
  Scheuerell, M.D., Szuwalski, C., & Zipkin, E.F. (2016)** and **Thorson, J.T.,
  Scheuerell, M.D., Shelton, A.O., See, K.E., Skaug, H.J., & Kristensen, K.
  (2015)**, "Spatial factor analysis: a new tool for estimating joint species
  distributions and correlations in species range," *Methods in Ecology and
  Evolution*, 6(6), 627–637 (author list for the 2016 SDFA extension not
  independently re-verified in this session — flag as **secondary-source
  citation, not independently confirmed**). VAST's identifiability handling,
  per its user manual (confirmed via search summary): **all loadings matrices
  are lower-triangular (upper-triangle fixed at 0), with a sum-to-zero
  constraint on factors across years for the spatio-temporal case** — again a
  rotational/sign constraint, **not** a magnitude-shrinkage prior. Consistent
  with `gllvm`'s approach, not with HMSC's.
- **sdmTMB**: **nothing found.** Search returned no evidence that sdmTMB
  implements a multi-species/JSDM-style factor-loadings model at all (its
  scope is single- or few-species spatial/spatiotemporal GLMMs with spatially
  varying coefficients) — there is no default-prior question to answer because
  the relevant model class does not appear to exist in this package. Reported
  as a clean negative rather than guessed.

**Design-precedent reading:** of the four ecology packages with an actual
loadings matrix to regularize, **one (HMSC) ships a genuine shrinkage prior**
(and cites a general Bayesian-statistics paper, Bhattacharya & Dunson 2011, as
its source rather than inventing one), **one (`boral`) ships a prior that is
weak/flat by design**, and **two (`gllvm`, VAST) ship no magnitude prior at
all**, relying purely on rotational constraints. This is a genuine split in
the field, not a consensus — "everyone in ecology already regularizes
loadings" would be an overstatement; the accurate summary is "the one package
in this list built by people whose main methodological lineage is Bayesian
sparse-factor-model theory (HMSC/Ovaskainen-Tikhonov, descending from
Bhattacharya & Dunson) does it, and the two built by people whose lineage is
TMB/Laplace-approximation multivariate GLMs (`gllvm`, VAST) do not."

---

## 5. The sign of the risk — what a loading prior costs

Findings specific to *this* question (does a loading prior bias the
large-sample estimator) are thin in the literature relative to the boundary-
avoidance question; what was found:

- **Sterzinger's own selling point is precisely a bias/consistency guarantee**
  — the `o_p(sqrt(n))` rate is explicitly designed so that, asymptotically,
  the penalized estimator inherits the unpenalized ML estimator's consistency
  and asymptotic normality. This is a **theoretical** guarantee about the
  *rate* at which any penalty-induced bias vanishes, not a demonstrated finite-
  sample number comparable to the task's own `n=3200` measurement
  (`||Lambda_hat||/||Lambda_true|| = 1.0021`). Whether the specific rate is
  fast enough to leave `n=3200` still at ~1.002 (rather than pulling it to,
  say, 0.98) is **not evaluated in the source** and would need to be checked
  empirically for this project's own model — which is exactly what
  `10-penalty-prior.md` in this same directory already set out to do
  empirically (I did not re-derive or check its numeric results here; that is
  simulation work, out of scope for this literature-only note).
- **`regsem`'s documented framing (Jacobucci et al.) is explicitly a
  bias-variance trade language**: *"particularly useful when there is a small
  parameter to sample size ratio, as penalties can reduce model complexity and
  reduce bias of parameter estimates"* — note this literature's framing is
  usually that ridge/lasso penalties reduce **variance** at a cost of some
  **bias**, with the trade being favorable at small n/small-sample-per-
  parameter ratios and unfavorable (net harmful) once n is large enough that
  the unpenalized estimator's variance was already small — which is
  qualitatively consistent with the task's own finding that the estimator is
  "essentially unbiased" already at n=3200 and the concern that a fixed-
  strength penalty could un-necessarily bias that regime. No source found
  gives a quantitative crossover point.
- **A caution rather than a support finding**, already on file in this
  directory (`07-prior-art-crossover.md`): **Ju, K., Lin, L., Chu, H., Cheng,
  L.L., & Xu, C. (2020).** "Laplace approximation, penalized quasi-likelihood,
  and adaptive Gauss–Hermite quadrature for generalized linear mixed models:
  towards meta-analysis of binary outcome with sparse data." *BMC Medical
  Research Methodology*, 20, 152. doi:10.1186/s12874-020-01035-6. Found that
  more accurate integration (AGHQ) did **not** uniformly improve on Laplace
  under sparse binary data — a documented instance of "the more sophisticated
  fix isn't automatically the better one" in a closely related (though not
  identical) small-sample-binary-GLMM setting. This does not bear directly on
  loading priors, but is relevant caution about assuming any single technical
  fix (whether better quadrature or a regularizing prior) is unambiguously an
  improvement without checking it in-regime.
- **No source found** directly measuring "cost of a loading-shrinkage prior at
  large n" in a JSDM/GLLVM context specifically (HMSC, `boral`, `gllvm` papers
  do not report a large-n bias audit of their own priors in the sources
  fetched here) — this appears to be a **gap in the literature** rather than
  something I failed to find; if true, it strengthens the case for treating
  the large-n bias check as this project's own contribution rather than
  something citable from elsewhere.

---

## What was NOT found (explicit negatives, as requested)

- No paper found that runs the task's *exact* experiment (binomial-logit
  GLLVM, verified-exact AGHQ likelihood, n-ladder, quadrature-node sweep on
  the argmin). The literature above supports the mechanism piecewise, not as
  a single reproducing study.
- No primary-source confirmation of BILOG-MG's or flexMIRT's *exact* default
  numeric prior hyperparameters (only secondary-source agreement for BILOG-MG;
  flexMIRT confirmed to have *a* default, exact values not found).
- No large-n bias audit, in any ecology-JSDM paper found, of that package's
  own default loading prior/penalty.
- No evidence sdmTMB has any loadings-based JSDM model to check against.
- The "Hirose et al. (2011)" penalty cited by Sterzinger could not be matched
  with confidence to a specific verified paper (the only Hirose factor-
  analysis-penalty paper independently confirmed is Hirose & Yamamoto 2015,
  which is a different penalty family — sparse/nonconcave, not the trace-based
  Ψ boundary-avoidance form Sterzinger describes for "Hirose et al. 2011").
