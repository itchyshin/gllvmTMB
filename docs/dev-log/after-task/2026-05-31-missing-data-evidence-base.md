# Evidence base: model-based missing-data layer (FIML via Laplace)

**Branch**: `missing-data-evidence`
**Date**: `2026-05-31`
**Scope**: Curated, load-bearing evidence memo for the gllvmTMB / drmTMB
missing-data layer (Design 59, the shared FIML-via-Laplace contract; Design 67,
the gllvmTMB missing-predictor lane) and the planned positioning article (#365).
This is NOT a systematic review. It is a short set of verified anchors the
article and the design docs will cite.

## How to read this memo

Each target gives: **the claim** (one line) -> **verified anchors** (authors,
year, venue, what they actually show) -> **maps to** (which phase / design-doc
section the citation supports) -> **caveat / contested** (where the literature
does NOT support a strong claim).

Epistemic tags used inline:
- **[fact]** -- established in the cited source.
- **[inference]** -- a reasonable reading the source supports but does not state
  verbatim.
- **[our-claim]** -- a positioning claim of ours that the literature is
  consistent with but does not itself assert.

All citations below were verified against the publisher record and/or OpenAlex
(authors, year, venue, page range, and the substantive claim) on 2026-05-31.
Items I could not fully verify, or where the existing design-doc citation is
wrong, are flagged **CORRECTION** or **UNVERIFIED**.

---

## Target 1 -- FIML is asymptotically equivalent to multiple imputation, and both beat listwise deletion / ad-hoc single imputation under MAR

**Claim.** Under missing-at-random (MAR) with distinct (separable) parameters
and a correctly specified model, full-information maximum likelihood (FIML) and
proper multiple imputation (MI) are asymptotically equivalent and both dominate
listwise deletion and single ad-hoc imputation. **[fact]** for the comparison of
methods; **[inference]** that "equivalent" extends cleanly to our structured
ecological models (the equivalence theory is for the classes those papers
study).

**Verified anchors.**
- **Rubin (1976)**, *Biometrika* 63(3):581-592, doi:10.1093/biomet/63.3.581.
  The taxonomy and the ignorability conditions: MCAR / MAR / MNAR, and the
  result that the missingness mechanism is ignorable for likelihood inference
  under MAR + distinct parameters. **[fact]**
- **Little & Rubin (2019)**, *Statistical Analysis with Missing Data*, 3rd ed.,
  Wiley, doi:10.1002/9781119482260. The standard book-length treatment of the
  taxonomy and of likelihood/Bayes methods for incomplete data. **[fact]**
- **Schafer & Graham (2002)**, *Psychological Methods* 7(2):147-177,
  doi:10.1037/1082-989X.7.2.147 (PMID 12090408). The state-of-the-art review:
  "two general approaches that ... come highly recommended: maximum likelihood
  (ML) and Bayesian multiple imputation (MI)"; clarifies MAR; argues both beat
  case deletion and ad-hoc fill-ins. This is the primary FIML-vs-MI-vs-deletion
  anchor. **[fact]**
- **Collins, Schafer & Kam (2001)**, *Psychological Methods* 6(4):330-351,
  doi:10.1037/1082-989X.6.4.330 (PMID 11778676). ML and MI "tend to yield
  similar results when implemented in comparable ways"; quantifies the
  inclusive (auxiliary-variable) vs restrictive strategy trade-off. **[fact]**
- **Enders (2010)**, *Applied Missing Data Analysis* (1st ed.), Guilford Press,
  ISBN 978-1606236390. Textbook rationale for ML, Bayesian estimation, MI, and
  MNAR models. (A 2nd ed. exists; cite the 1st unless the article needs the
  update.) **[fact]**
- **Graham (2009)**, *Annual Review of Psychology* 60:549-576,
  doi:10.1146/annurev.psych.58.110405.085530 (PMID 18652544). Practical review;
  emphasises auxiliary variables for bias/power and the practical equivalence of
  the two modern approaches. **[fact]**

**Maps to.** Design 59 section 2 ("Why ML is valid here"; "FIML as the
alternative to MI") and section 1 (positioning). The MAR/distinct-parameter
condition is the gate on validity that drives the section 9 sensitivity gates.

**Caveat / contested.**
- The asymptotic-equivalence and "both beat deletion" results are proven for the
  model classes those papers study (normal-model and GLM-type analyses). Extending
  them to our latent-variable / phylogenetic / spatial joint models is a reasonable
  **[inference]**, not a transferred theorem. The article should not claim the
  equivalence is a theorem for gLLVMs.
- All of it is conditional on **correct model specification under MAR**. Under
  MNAR, neither FIML nor MI is unbiased without an explicit nonresponse model
  (Rubin 1976; Enders 2010) -- hence our MNAR sensitivity gate (section 9).
- Listwise deletion is unbiased (though inefficient) under MCAR and, for
  regression coefficients, under some MAR-on-predictors patterns; "deletion is
  always biased" would be an overstatement. The honest claim is "deletion is
  inefficient and biased under general MAR." **[fact]**

---

## Target 2 -- FIML is a single joint model; MI is draw -> analyse -> pool; congeniality is why the FIML path sidesteps a class of MI pitfalls

**Claim.** FIML fits one likelihood in which the imputation model and the
analysis model are identical by construction, so the "uncongeniality" problem of
MI (imputation model and analysis model implying different things) cannot arise
on the FIML path. MI wins its flexibility precisely by separating the two models,
which is also where it can go wrong (uncongeniality; "transform-then-impute"
hazards). **[fact]** for the mechanism; **[our-claim]** that this is a positive
selling point for FIML in our fixed-analysis-model setting.

**Verified anchors.**
- **Meng (1994)**, *Statistical Science* 9(4):538-558,
  doi:10.1214/ss/1177010269. Defines congeniality and shows MI inference can be
  invalid (typically conservative) when the analysis procedure is uncongenial to
  the imputation model. The conceptual basis for the claim that a single joint
  model has no congeniality gap. **[fact]**
  (Note: some indexes give the page range as 538-573 including the discussion;
  the article proper is 538-558.)
- **von Hippel (2009)**, *Sociological Methodology* 39(1):265-291,
  doi:10.1111/j.1467-9531.2009.01215.x. "Transform, then impute" for
  interactions / squares: imputing a transformed predictor and its components
  separately yields mutually inconsistent imputed values; careful handling is
  needed. A concrete uncongeniality-adjacent hazard that a single joint
  likelihood avoids (the transform is inside the model). **[fact]**
  **CORRECTION:** the task brief and Design 59 section 11 cite this as "von
  Hippel (2007)". The transform-then-impute paper is **2009**, Sociological
  Methodology 39:265-291. (Von Hippel does have a separate 2007 paper, "Regression
  with missing Y's", Sociological Methodology 37:83-117 -- a different result.
  Use 2009 for the transform-then-impute claim.)
- Supporting: **Schafer & Graham (2002)** (as above) for the framing that ML's
  imputation and analysis models coincide.

**Maps to.** Design 59 section 1 / section 1b (the two-path framing; FIML =
imputation-model-is-the-formula) and Design 67 section 1.1 ("the family lives in
the predictor model" -- the predictor model is part of the same likelihood, so
it is congenial with the response model by construction).

**Caveat / contested.**
- Congeniality is a real advantage only because **our analysis model is fixed and
  known**. When the downstream analysis is unknown or varied across many users,
  MI's separation is a feature, not a bug (this is the sister-path argument,
  Target 7). Do not over-sell congeniality as making FIML strictly better.
- A correctly specified single joint model also *can* be misspecified -- the
  congeniality argument removes the imputation/analysis mismatch, not
  specification error in the joint model itself. The honest framing: FIML trades
  MI's uncongeniality risk for joint-specification risk.
- **Schenker & Taylor (1996)**, *Comput. Stat. Data Anal.* 22(4):425-446,
  doi:10.1016/0167-9473(95)00057-7, is a partially parametric **MI methods**
  paper, not an FIML-vs-MI equivalence proof. Design 59 section 2 cites it
  alongside Schafer & Graham for "asymptotically equivalent"; that pairing
  overstates what Schenker & Taylor show. Anchor the equivalence claim to
  Schafer & Graham (2002) and Collins et al. (2001); cite Schenker & Taylor only
  as an MI-methods reference if needed.

---

## Target 3 -- missing predictors as latent quantities integrated out by the likelihood (distinct from measurement error)

**Claim.** A principled likelihood treatment of missing covariates factorises
the joint density `p(y | x) p(x)` and integrates the missing covariate out of
the marginal likelihood, rather than imputing it as a preprocessing step. This
is the mixed-model / latent-quantity route, and it is conceptually distinct from
measurement error (where observed x is itself noisy). **[fact]** for the
factorisation; **[our-claim]** for "integrate by Laplace rather than EM" (Target
4 supplies the engine justification).

**Verified anchors.**
- **Ibrahim (1990)**, "Incomplete data in generalized linear models", *JASA*
  85(411):765-769, doi:10.1080/01621459.1990.10474938. The original GLM
  missing-covariate likelihood via EM by the method of weights -- establishes the
  `p(y|x) p(x)` factorisation and marginalisation of missing x. **[fact]**
- **Ibrahim, Chen, Lipsitz & Herring (2005)**, "Missing-Data Methods for
  Generalized Linear Models: A Comparative Review", *JASA* 100(469):332-346,
  doi:10.1198/016214504000001844. The comparative review of ML, MI, fully
  Bayesian, and weighted estimating equations for missing covariates, under MAR
  and nonignorable mechanisms. The key anchor for "missing predictors are handled
  by a covariate model inside the likelihood." **[fact]**
- Supporting (also in Design 59 section 11): Ibrahim, Chen & Lipsitz (1999),
  *Biometrics* 55(2):591-596 -- a step in the same series. (Not separately
  re-verified here; the 1990 and 2005 anchors carry the claim.)

**Maps to.** Design 59 section 2 ("Missing covariates -> joint factorization"),
section 6 (the marginal-likelihood integral), and Design 67 section 2.1
(Gaussian `mi(x)` as a latent `x_mis`). The conservative Level-1 independent
covariate model default (section 3) is exactly choosing a simple `p(x)`.

**Caveat / contested -- the explicit non-goal.**
- This is **NOT measurement error**. In our design, an *observed* x is exact;
  only the *missing* entries `x_mis` are latent (Design 59 section 4 non-goal;
  Design 67 section 0). Measurement error needs an observation model
  `x_obs | x_true` (known SEs, replicates, or validation data) and treats true x
  as latent even when observed -- out of scope for v1. The classic reference for
  that distinct problem is Carroll, Ruppert, Stefanski & Crainiceanu (2006),
  *Measurement Error in Nonlinear Models*, CRC (listed in Design 59 section 11;
  cite only to delimit scope, not as a method we implement). Keeping these
  separate in the article prevents a reviewer from reading our `mi()` as an
  errors-in-variables claim.
- **Structured confounding** is the real risk when `p(x)` shares the analysis
  model's structured field (Design 59 section 3): the spatial result (Dupont,
  Marques & Kneib 2023, arXiv:2309.16861) is established; the phylogenetic
  analogue (Wang, Edge, Schraiber & Pennell 2025) is a **preprint, not
  peer-reviewed** -- cite as indicative only. This is why the joint y-x field is
  opt-in, not default.

---

## Target 4 -- Laplace approximation of the marginal likelihood with latent quantities (the TMB engine justification)

**Claim.** Integrating the latent quantities (`x_mis`, random effects `b`, the
covariate-model effects `b_x`) out of the marginal likelihood by the Laplace
approximation, with gradients from automatic differentiation, is a standard and
well-justified route; TMB is the implementation. **[fact]**

**Verified anchors.**
- **Kristensen, Nielsen, Berg, Skaug & Bell (2016)**, "TMB: Automatic
  Differentiation and Laplace Approximation", *Journal of Statistical Software*
  70(5):1-21, doi:10.18637/jss.v070.i05. The engine paper: evaluates and
  maximises the Laplace approximation of the marginal likelihood with random
  effects integrated out by AD. This is the direct citation for our integrator.
  **[fact]** (Already in `vignettes/refs.bib` as `kristensen2016`.)
- **Skaug & Fournier (2006)**, "Automatic approximation of the marginal
  likelihood in non-Gaussian hierarchical models", *Comput. Stat. Data Anal.*
  51(2):699-709, doi:10.1016/j.csda.2006.03.005. The Laplace-plus-AD basis
  predating TMB (ADMB), i.e. the general method our random-effect treatment
  rests on. **[fact]** (Already in refs.bib via the Fournier/Skaug entry.)
- Precedent packages built on this engine, both already cited by the package:
  **Brooks et al. (2017)**, glmmTMB, *R Journal* 9(2):378-400,
  doi:10.32614/RJ-2017-066; and the sdmTMB paper
  (Anderson, Ward, English, Barnett & Thorson 2025, *JSS* 115(2) -- per Design 59
  section 11; the JSS volume/issue should be re-confirmed at citation time as the
  article is recent). These establish "Laplace-TMB random effects in ecological
  GLMMs" as standard practice. **[fact]** for the precedent;
  **UNVERIFIED** on the exact sdmTMB JSS volume/issue/year here.

**Maps to.** Design 59 section 2 ("Why Laplace, not EM") and section 6 (the
integral `L(theta) = int ... d x_mis db db_x`, Laplace = joint mode + Gaussian
curvature); Design 67 section 2.1 ("`x_mis` is just another random effect"). The
EBLUP / conditional-mode output (with SE from the inverse joint Hessian) is the
Robinson (1991, *Statist. Sci.* 6:15-32) / Harville (1976) BLUP machinery
(Design 59 section 11) -- "EBLUP, not posterior mean".

**Caveat / contested.**
- The Laplace approximation is **exact for Gaussian latent quantities** and only
  approximate otherwise; its accuracy for discrete or strongly non-Gaussian
  latent structure is not guaranteed. This is exactly why Design 67 section 2.2
  routes *discrete* missing predictors through an **exact finite-state sum**, not
  a Laplace integral. The article should state that the Laplace justification
  covers the *continuous* `x_mis` path; discrete predictors are marginalised
  exactly, not approximated.
- Laplace/FIML standard errors can be **negatively biased under non-normality**
  (Allison 2003 -- see Target 6). Hence the bootstrap-SE cross-check gate
  (Design 59 section 9). Cite this as a known limitation, not a fatal flaw.

---

## Target 5 -- phylogenetic / structured trait imputation: borrowing strength across related species, AND its signal-dependent limits

**Claim.** Phylogeny (and trait correlations) can improve recovery of missing
trait values by borrowing strength across related species -- but the benefit is
**signal-dependent**: when phylogenetic signal is weak, phylogenetic imputation
adds noise and can be no better than (or worse than) complete-case analysis. This
is the single most important honesty point in the memo. **[fact]**

**Verified anchors -- the method works when signal is strong.**
- **Penone, Davidson, Shoemaker, Di Marco, Rondinini, Brooks, Young, Graham &
  Costa (2014)**, "Imputation of missing data in life-history trait datasets:
  which approach performs the best?", *Methods Ecol. Evol.* 5(9):961-970,
  doi:10.1111/2041-210X.12232. Phylogeny + trait correlations improve prediction
  of missing trait values (Carnivora benchmark, 10-80% missing); also notes trait
  data are typically **not** missing at random. **[fact]**
- **Goolsby, Bruggeman & Ane (2017)**, "Rphylopars: fast multivariate
  phylogenetic comparative methods for missing data and within-species
  variation", *Methods Ecol. Evol.* 8(1):22-27, doi:10.1111/2041-210X.12612.
  The direct method precedent: a likelihood-based phylogenetic trait-imputation
  engine (multivariate, linear-time). This is the closest existing-method analogue
  to our Phase 3 phylo `mi()`. **[fact]**
  **NOTE:** OpenAlex records the issue year as 2017 (vol 8, issue 1) but the online
  publication as 2016; cite as **2017** (the issue of record). Some indexes show
  2016 -- harmless, but be consistent.

**Verified anchors -- the limits (cite these next to the wins).**
- **Johnson, Isaac, Paviolo & Gonzalez-Suarez (2021)**, "Handling missing values
  in trait data", *Global Ecology and Biogeography* 30(1):51-62,
  doi:10.1111/geb.13185. Key findings: Rphylopars was the most accurate method
  tested, **yet estimates were still inaccurate even at 5% missing**; under
  strong biases **no method worked well and imputation was not always better than
  complete-case analysis**; recommends bias checks before and after imputation.
  This is the strongest single anchor for the signal/bias-dependence caveat.
  **[fact]**
  **CORRECTION:** the task brief and Design 59 section 11 list the authors as
  "Johnson, Fitzpatrick, Pearse & Revell (2021)". The verified authorship is
  **Johnson, Isaac, Paviolo & Gonzalez-Suarez** (GEB 30(1):51-62, online 2020,
  issue 2021). The "Fitzpatrick / Pearse / Revell" attribution is incorrect and
  must be fixed wherever it appears.
- **Molina-Venegas (2024)**, "How to get the most out of phylogenetic imputation
  without abusing it", *Methods Ecol. Evol.* 15(3):456-463,
  doi:10.1111/2041-210X.14198 (online 2023, issue 2024). Argues phylogenetic
  imputation is routinely misused: many imputed values are trusted without
  demonstrating the data meet the conditions for the prediction to be worthwhile;
  a "significant" randomization test for signal is not the same as *strong* signal.
  Directly grounds the **phylo-signal gate**. **[fact]**
- **Molina-Venegas, Moreno-Saiz, Castro Parga, Davies, Peres-Neto & Rodriguez
  (2018)**, "Assessing among-lineage variability in phylogenetic imputation of
  functional trait datasets", *Ecography* 41(10):1740-1749,
  doi:10.1111/ecog.03480. Prediction accuracy varies **among lineages/tips**; a
  Monte Carlo method estimates tip-level expected accuracy -- i.e. reliability is
  not uniform across the tree. **[fact]**
  **CORRECTION:** this 2018 paper is in **Ecography**, not *Methods Ecol. Evol.*
  Design 59 section 11 lists "Molina-Venegas (2024) MEE" and the task brief lists
  "Molina-Venegas et al. (2018)"; they are two different papers (2018 Ecography;
  2024 MEE). Keep both, with the correct venues.

**Maps to.** Design 59 section 3 ("Phylogenetic imputation must be conservative +
diagnosed"), the Phase 3 flagship (section 7), and the section 9 phylo-recovery
gate ("high vs low signal -> borrowing helps when strong, degrades to
~independent when weak"). Design 67 section 2.1 (Phase 3 reuses `Ainv_phy_rr`)
and section 6 (the Phase 3 gate). The empirical signal-dependence in Johnson 2021
/ Molina-Venegas 2024 is what the phylo-signal gate operationalises.

**Caveat / contested -- state this plainly in the article.**
- "Phylogenetic imputation recovers missing traits" is **NOT** an unconditional
  result. The evidence is that it helps **only when phylogenetic signal is strong
  and missingness is not severely biased**, and that it can underperform
  complete-case analysis otherwise (Johnson et al. 2021). Our design's correct
  posture -- borrowing that **degrades gracefully toward independent when signal
  is weak**, behind a signal/reliability gate -- is consistent with this
  literature and is the honest claim. **[our-claim]**, well-supported.
- Trait databases are typically **MNAR** (Penone et al. 2014), which neither our
  FIML path nor any imputation method corrects without an explicit nonresponse
  model -> the MNAR sensitivity gate (Design 59 section 9).
- **Circularity warning:** phylogenetically imputed values must not be reused to
  re-estimate phylogenetic signal (a documented hazard; e.g., the "cautionary
  note on phylogenetic signal estimation from imputed databases", Evol. Biol.
  2021, Springer -- listed for completeness, **not separately re-verified here**).
  Design 59 section 3 already encodes the "warn against circular downstream
  reuse" rule.

---

## Target 6 -- why model-based beats ad-hoc for structured ecological data (the article's opening)

**Claim.** For structured ecological data (species related by phylogeny, sites by
space, traits by covariance), a single model that represents the missingness
inside the likelihood is more transparent and more defensible than detached
preprocessing (case deletion, mean fill, or an imputation step disconnected from
the analysis), because the missing-data model is part of the formula and its
uncertainty propagates through the same Hessian. **[our-claim]**, supported in
parts by Targets 1-5.

**Verified anchors (assembled from above; no new method needed).**
- General "model-based > deletion / ad-hoc single imputation under MAR":
  **Schafer & Graham (2002)**; **Collins et al. (2001)**; **Graham (2009)**;
  **Enders (2010)** (Target 1). **[fact]**
- Missing covariates belong in a covariate model inside the likelihood:
  **Ibrahim et al. (2005)**; **Ibrahim (1990)** (Target 3). **[fact]**
- The structured-data context (joint modelling of many correlated responses) is
  exactly the gLLVM/JSDM setting: **Warton, Blanchet, O'Hara, Ovaskainen,
  Taskinen & Walker (2015)**, "So Many Variables: Joint Modeling in Community
  Ecology", *Trends Ecol. Evol.* 30(12):766-779, doi:10.1016/j.tree.2015.09.007;
  **Ovaskainen et al. (2017)**, *Ecology Letters* 20(5):561-576,
  doi:10.1111/ele.12757 (HMSC); **Hui (2016)**, "boral", *Methods Ecol. Evol.*
  7(6):744-750, doi:10.1111/2041-210X.12514. These establish the audience and the
  "everything in one likelihood" idiom our layer extends to missingness.
  **[fact]** that these are the JSDM/gLLVM anchors; **[our-claim]** that
  extending the joint model to missingness is the natural next step.

**Maps to.** Design 59 section 1 (motivation: "more transparent than detached
multiple imputation because the imputation model is part of the formula, not
hidden preprocessing") and the article's opening framing (#365).

**Caveat / contested.**
- "Model-based is more transparent" is a **design value**, not an empirical
  result -- present it as such. The empirical backing is the narrower, verified
  set of results in Targets 1-5 (equivalence to MI, dominance over deletion under
  MAR, signal-dependent phylo imputation). Do not let the opening imply that a
  joint model is *empirically* superior in all cases; its advantage is
  transparency + congeniality + uncertainty propagation **when the joint model is
  correctly specified**.
- The transparency advantage is partly rhetorical against *bad* MI practice
  (single imputation, ignoring imputation uncertainty). Against *proper* MI it is
  the congeniality / single-fit argument (Target 2), not a blanket superiority.

---

## Target 7 -- sister-path framing: MI with ML/GNN imputers + Rubin/conformal (pigauto-style) is a legitimate alternative, not a competitor

**Claim.** Multiple imputation with flexible (e.g., GNN/ML) imputers and proper
pooling (Rubin's rules, optionally conformal intervals) is a legitimate, often
preferable, route -- it is **complementary** to FIML, not a rival. MI earns its
keep when the analysis model is unknown or varied, when trait types are mixed, or
when tree uncertainty must be propagated; FIML earns its keep when the analysis
model is fixed and structured. **[our-claim]**, grounded in the
congeniality/equivalence literature.

**Verified anchors.**
- Equivalence-and-complementarity backbone: **Schafer & Graham (2002)** and
  **Collins et al. (2001)** -- ML and MI are the two recommended approaches and
  agree asymptotically when comparably implemented; the choice is pragmatic
  (Target 1). **[fact]**
- When MI's separation is a feature (analysis model unknown/varied): **Meng
  (1994)** congeniality argument, read the other direction -- MI's decoupling is
  what lets one imputation serve many analyses (Target 2). **[inference]**
- Rubin's pooling rules: **Rubin (1987)**, *Multiple Imputation for Nonresponse
  in Surveys*, Wiley (the canonical source of "Rubin's rules"). **UNVERIFIED**
  here (not separately checked this session); standard and uncontroversial --
  verify the edition/DOI at citation time if cited.
- pigauto specifics (the sister package) -- the GNN+BM blend, conformal intervals,
  and tree-uncertainty support via **Nakagawa & de Villemereuil (2019)**,
  *Systematic Biology* (per Design 59 section 1b/11) -- are **internal /
  package-level**, not re-verified bibliographically here; the
  Nakagawa & de Villemereuil citation in Design 59 section 11 should be
  volume/page-checked before the article cites it (**UNVERIFIED** this session).

**Maps to.** Design 59 section 1b (the explicit two-path table; "kept SEPARATE
from the engine"; `with_pigauto()` workflow) and section 4 ("No MI engine in
`miss_control()`"). The article's positioning section should present FIML and MI
as complementary, citing the equivalence literature so neither path is strawmanned.

**Caveat / contested.**
- Do **not** claim FIML is strictly better than MI. The verified literature says
  they are asymptotically equivalent under comparable, correct implementation
  (Target 1). The honest differentiator is operational: **single fit + congenial
  by construction + handles missing predictors in-model** (FIML) vs **flexible
  imputer + model-agnostic + handles rich trait types / tree uncertainty** (MI).
- Conformal prediction for imputation is an active area; treat conformal-interval
  claims as method-dependent and cite the specific pigauto implementation rather
  than a general guarantee.

---

## Summary of corrections to the existing design-doc / brief citations

These are bibliographic errors found while verifying; fix them in Design 59
section 11, Design 67, and the article before citing:

1. **von Hippel "2007" -> 2009.** The transform-then-impute paper is von Hippel
   (2009), *Sociological Methodology* 39(1):265-291. (A different 2007 von Hippel
   paper exists -- "Regression with missing Y's" -- so the year matters.)
2. **Johnson et al. (2021) authorship.** Correct authors are **Johnson, Isaac,
   Paviolo & Gonzalez-Suarez**, *Global Ecology and Biogeography* 30(1):51-62 --
   NOT "Johnson, Fitzpatrick, Pearse & Revell".
3. **Molina-Venegas 2018 venue.** "Assessing among-lineage variability ..." is in
   **Ecography** 41(10):1740-1749, not *Methods Ecol. Evol.* (The 2024 "How to get
   the most out ..." paper IS in *Methods Ecol. Evol.* 15(3):456-463.) Two
   distinct papers.
4. **Schenker & Taylor (1996)** is an MI-methods paper (*Comput. Stat. Data Anal.*
   22(4):425-446), not an FIML-vs-MI asymptotic-equivalence proof; anchor the
   equivalence claim to Schafer & Graham (2002) / Collins et al. (2001) instead.
5. **Goolsby et al. Rphylopars** -- issue of record is vol 8(1), 2017 (online
   2016); cite consistently as 2017.

## Items flagged UNVERIFIED this session (verify before citing)

- sdmTMB paper (Anderson et al. 2025) exact *JSS* volume/issue/year.
- Rubin (1987) *Multiple Imputation for Nonresponse in Surveys* edition/DOI.
- Nakagawa & de Villemereuil (2019) *Systematic Biology* volume/pages (tree
  uncertainty; used by pigauto).
- Wang, Edge, Schraiber & Pennell (2025) phylogenetic-confounding preprint --
  confirmed in Design 59 as a **non-peer-reviewed preprint (PMC)**; cite as
  indicative only, and re-check whether it has since been published.
- "Cautionary note on phylogenetic signal estimation from imputed databases"
  (Evol. Biol. 2021) -- used only to support the circularity warning; verify
  authors/volume if cited.

## The 2-3 most important evidence points for the article (#365)

1. **FIML and proper MI are asymptotically equivalent under MAR + correct
   specification, and both dominate listwise deletion / single imputation**
   (Schafer & Graham 2002; Collins et al. 2001). This lets the article position
   the layer as a *legitimate frequentist alternative to MI*, not a novel
   estimator with something to prove -- the burden is specification, not validity.
2. **Phylogenetic imputation is signal-dependent and is NOT always better than
   complete-case analysis** (Johnson et al. 2021; Molina-Venegas 2024; Penone et
   al. 2014). This is the credibility-defining honesty point: it justifies the
   phylo-signal gate and the "degrade-to-independent-when-weak" default, and it
   pre-empts the obvious reviewer objection. Lead the Phase 3 / phylo section with
   this caveat, not after it.
3. **Congeniality** (Meng 1994): because the imputation model *is* the analysis
   model in FIML, the uncongeniality failure mode of MI cannot occur on our path
   -- but this advantage exists only because our analysis model is fixed, which is
   exactly why MI remains the right tool when the analysis is unknown/varied
   (the complementary sister-path framing). This is the cleanest one-sentence
   differentiator between the two paths.
