# NB2 dispersion vs. observation-level / latent random effect: identifiability, small-sample bias, and known fixes

**Grounded literature synthesis (NotebookLM), 2026-07-13.**
Notebook `79f9785f-1bcf-454f-94b9-d0024a4d52d2`. 68 sources imported (67 processed, 1 errored — a Medium "double GLM" post).

> **Provenance caveat — read first.** NotebookLM built the answers partly from the 67 corpus sources and partly from an auto-generated internal report titled *"Advanced Statistical Challenges in Modeling Count Data..."*. That report is a **secondary synthesis NotebookLM wrote from the corpus plus the research prompt**, not a peer-reviewed source. Below, claims whose only grounding is that internal report — or which trace back to the *research prompt's own background text* (e.g. the "~0.5× recovery at n=800" simulation figure) — are marked **[report-only]** or **UNVERIFIED**. Claims grounded in a real corpus source (journal, package doc, forum, preprint) name that source.

---

## Question

When an NB2 (quadratic negative-binomial) model **also** carries an observation-level random effect (OLRE) or a latent log-scale random effect, both mechanisms generate observation-level overdispersion. Is the resulting NB-dispersion (φ / size / k / θ) vs. random-effect-variance (ψ) confounding a documented identifiability/estimation problem? Is small-sample bias of the NB dispersion MLE (collapse toward Poisson) documented, and are there bias-corrected or restricted-likelihood dispersion estimators? What are the known fixes (one-not-both, shared dispersion, priors, profiling), and what do glmmTMB / gllvm / brms recommend? In multivariate GLLVMs/JSDMs, is per-response dispersion over-parameterized and is shared dispersion the standard remedy?

---

## Is it a known problem (with citations)

- **NB2 and OLRE are the same overdispersion mechanism twice.** NB2 is a Poisson–Gamma mixture; a Poisson-OLRE is a Poisson–lognormal mixture. Both act at the observation level, so including both is **functionally redundant**. Grounded in a Cross Validated thread ("Is the OLRE term meaningful in the negative binomial model?", stats.stackexchange.com) where the answer calls NB + OLRE "a weird construction" and redundant. The foundational NB-as-mixed-Poisson framing is **Lawless, J. F. (1987), *Canadian Journal of Statistics*** (in the corpus; canonical primary source, though the model's prose leaned on the internal report rather than quoting Lawless directly).

- **Weak identifiability / likelihood ridge.** With one observation per unit, residual (dispersion) and random-effect variance are jointly (near-)unidentifiable — different (φ, ψ) combinations give near-identical log-likelihoods. Grounded in the **GLMM FAQ (Bolker, bbolker.github.io)**, which warns that when an individual is measured once, the residual and random-effect terms are confounded and jointly unidentifiable, and a StackOverflow mixed-model thread making the same point (n_obs ≤ n_random-effects). The specific "geometric confounding of φ and ψ / likelihood ridge" framing is **[report-only]**.

- **Direction of the bias.** The claim that this confounding biases the random-effect variance **downward** while biasing NB dispersion **upward** (toward Poisson) is **[report-only]** as a general statement, and the concrete "recovery ~0.5× truth at n=800, ~1.0× when φ is fixed" figure comes from the **research prompt's own background** — **UNVERIFIED** against any external paper in the corpus. It is consistent with, but not independently corroborated by, the small-sample-bias literature below.

**Bottom line for this section:** the redundancy and weak-identifiability are documented (Lawless 1987; GLMM FAQ; Cross Validated), but mostly in methods folklore / package guidance / forums rather than a single canonical "NB-vs-OLRE non-identifiability" theorem paper.

---

## NB dispersion small-sample bias + corrections

**The bias is documented and primary-sourced:**

- **Lloyd-Smith, J. O. (2007), *PLoS ONE* 2(2):e180.** Simulation study: small-sample MLEs of *k* are **biased toward overestimating k** — i.e. *underestimating* overdispersion — and degrade toward the Poisson limit when the sample fails to capture the heavy right tail. Direct quote from the source: the paper studies "the bias, precision, and confidence interval coverage of maximum-likelihood estimates of *k* from highly overdispersed distributions," finding small-sample k̂ "biased toward overestimating *k*." Primary, full-text in corpus.
- **Gregory, R. D. & Woolhouse, M. E. J. (1993), *Acta Tropica*.** Method-of-moments small-sample upward bias of k̂ (systematic underestimation of mean/variance, overestimation of k). Referenced within Lloyd-Smith's bibliography. *(Note: the internal report miscited this as "2000"; the correct year is 1993, per Lloyd-Smith's reference list.)*
- **Saha, K. & Paul, S. (2005), *Biometrics*.** Documents substantial positive small-sample bias of the NB dispersion MLE and proposes a bias-corrected MLE. In corpus ("Bias-corrected maximum likelihood estimator of the negative binomial dispersion parameter", PubMed); cited as corroborating the small-sample positive bias.

**Bias-corrected / restricted estimators that exist:**

- **Cordeiro, G. M. & McCullagh, P. (1991), *JRSS Series B*.** First-order (O(n⁻¹)) bias corrections for MLEs in GLMs — including the **dispersion parameter** — via a supplementary weighted regression. Primary; the source states the formulae correct "the linear parameters, linear predictors, the dispersion parameter and fitted values in generalized linear models... to order n⁻¹ ... by means of a supplementary weighted regression."
- **Firth, D. (1993), *Biometrika*.** Penalized-likelihood score adjustment that removes first-order bias (prevents estimates drifting to boundaries/infinity).
- **Kosmidis, I. & Firth, D. (2009), *Biometrika*** — mean bias-reducing score adjustments; **Kenne Pagui, E. C., Salvan, A. & Sartori, N. (2017), *Biometrika*** — median bias-reducing adjustments; **Kosmidis, I., Kenne Pagui, E. C. & Sartori, N. (2020), *Statistics and Computing*** — mixed adjustments (mean bias reduction for regression coefficients, **median bias reduction for the dispersion parameter, the default**). All grounded in the **`brglm2::brnb` R documentation** (search.r-project.org), which implements bias-reduced NB regression (`type = "AS_mean" / "AS_median" / "AS_mixed"`).
- **Al-Khasawneh, M. F. (2010), *Asian Journal of Mathematics & Statistics*.** Combines method-of-moments and maximum-quasi-likelihood dispersion estimators via variance-test weights to reduce bias. In corpus.
- **REML / h-likelihood.** Restricted / hierarchical-likelihood estimators account for degrees of freedom spent on fixed effects to stabilize variance-component and dispersion estimates. Grounded generally in the GLMM FAQ (Knudson et al. 2021, *Stat*, listed there) and the corpus's **Lee & Nelder h-likelihood** entry ("Generalized linear models with random effects: Unified analysis via H-likelihood"); the specific application to the NB dispersion parameter is **[report-only]**.

**Note:** No source in the corpus reports a bias-correction method **specifically for the NB-dispersion-vs-latent-variance ridge**. The corrections above target the NB dispersion MLE in an ordinary NB regression, not the joint NB+random-effect identifiability problem. Treat the leap from "bias-corrected NB dispersion" to "fixes the ridge" as **UNVERIFIED**.

---

## Known fixes / recommended practice (shared dispersion, priors, one-not-both, profiling)

1. **Use one mechanism, not both (NB OR OLRE).** The recommended default is Poisson+OLRE *or* NB2, not both, unless the data are genuinely multi-level (repeated measures within a unit) so the two variances attach to different levels. Grounded in the Cross Validated NB+OLRE thread (redundant construction) and, for the OLRE side, **Harrison, X. A. (2014), *PeerJ* 2:e616** ("Using observation-level random effects to model overdispersion in count data", multiple copies in corpus) — the canonical OLRE reference. Harrison's guidance (OLRE for additive log-scale noise vs. NB when variance scales with the square of the mean) is attributed via the internal report and Bolker's GLMM bibliography; **Harrison 2014/2015 full text is in the corpus as the primary OLRE source**, so the "one-not-both" recommendation is well-grounded, the fine-grained "which one when" wording is partly [report-only].

2. **Model the dispersion instead of absorbing it in a redundant RE — `dispformula` (glmmTMB).** Rather than a second overdispersion term, model φ as a function of covariates via `dispformula = ~ predictor`. Grounded in the Frontiers "versatile workflow for linear modelling in R" article and the glmmTMB materials in the corpus (Brooks et al. — "glmmTMB balances speed and flexibility...").

3. **Shared / pooled dispersion across responses (multivariate).** See next section — this is the headline fix for GLLVMs.

4. **Weakly-informative priors on dispersion (Bayesian).** In brms/Stan, a regularizing prior (e.g. Gamma) on the shape/dispersion parameter keeps φ from collapsing to the Poisson limit. Grounded partly in the corpus's brms NB thread ("Comparing variance or sd of parameters in brms with negative binomial") but the specific "Gamma prior prevents Poisson collapse" recommendation is **[report-only]** — treat as plausible, not source-proven.

5. **Fixing / profiling the dispersion.** The prompt's own finding (recovery ≈ 1.0× when φ is fixed at truth) motivates fixing or profiling φ. The corpus does **not** contain a paper that recommends profiling-out the NB dispersion to cure the NB-vs-RE ridge — **UNVERIFIED** as an externally-endorsed fix, though it is the logical implication of the identifiability problem.

---

## What glmmTMB / gllvm / brms recommend

- **glmmTMB.** Use `dispformula` to model heteroscedastic dispersion explicitly rather than stacking a redundant random effect (Frontiers workflow article; Brooks et al. glmmTMB paper, in corpus).

- **gllvm — this is the most directly relevant, and well-grounded.**
  - `disp.formula` is *"a vector of indices, or alternatively formula, for the grouping of dispersion parameters (e.g. in a negative-binomial distribution, ZINB, tweedie)... Defaults to NULL so that all species have their own dispersion parameter."* (gllvm CRAN / RDocumentation). **Nuance:** the argument is `disp.formula` (a vector of indices *or* a formula); the name **`disp.group` does not appear in the gllvm docs in this corpus** — it is secondary-literature phrasing for the same grouping capability. Correct this in any gllvmTMB-facing text.
  - **gllvm 2.0 paper** (corpus title "gllvm 2.0: fast fitting of advanced ordination methods and joint species distribution models"; the model attributed it to **Korhonen et al., 2025, *PeerJ***, while the corpus copy is the JYX/Jyväskylä repository preprint — treat the *PeerJ* venue/author-year as **UNVERIFIED**, confirm before citing). It explicitly demonstrates a **common dispersion across species**: *"...we set `disp.formula=shapeForm` to a vector of ones which leads to a common dispersion parameter across all species..."* and a **trait-grouped** variant: `shapeForm <- ifelse(Traits$GROUP=="INVERT",1,2)` to share one φ for invertebrates and another for seaweeds. This is done *"to avoid volatile estimation"* — direct evidence that per-species dispersion is treated as fragile/over-parameterized and shared dispersion is the remedy.
  - **Poisson warm-start.** gllvm supports passing a fitted object as starting values via `control.start = list(start.fit = ...)`; the docs describe `start.fit` as *"object of class 'gllvm' which can be given as starting parameters for count data (poisson, NB, or ZIP)"* with a worked example fitting Poisson first (`fit.p <- gllvm(y, family = poisson())`) then feeding it to a harder family. The "fit Poisson first to get past the flat likelihood region before NB" rationale is stated in the internal report **[report-only]**, but the mechanism (`start.fit`) is documented primary.

- **brms.** Regularizing priors on the dispersion/shape parameter to stabilize estimation — **[report-only]** as above; the corpus has a relevant brms-NB thread but not an explicit source-stated recommendation.

---

## Key references (author, year, venue)

Grounding tier in brackets: **[primary]** = full text/excerpt or authoritative doc in corpus; **[doc]** = package documentation; **[forum]** = Q&A site; **[report-only]** = only in NotebookLM's generated report; **[corpus, uncited]** = present in the 67 sources but not cited in the answers.

- Lawless, J. F. (1987). Negative Binomial and Mixed Poisson Regression. *Canadian Journal of Statistics* 15(3):209–225. **[primary; corpus, uncited]** — foundational NB-as-mixed-Poisson.
- Lloyd-Smith, J. O. (2007). Maximum Likelihood Estimation of the Negative Binomial Dispersion Parameter for Highly Overdispersed Data. *PLoS ONE* 2(2):e180. **[primary]** — small-sample bias of k̂.
- Gregory, R. D. & Woolhouse, M. E. J. (1993). *Acta Tropica*. **[primary, via Lloyd-Smith bib]** — MoM small-sample bias.
- Saha, K. & Paul, S. (2005). Bias-corrected maximum likelihood estimator of the negative binomial dispersion parameter. *Biometrics* 61(1):179–185. **[primary]**.
- Cordeiro, G. M. & McCullagh, P. (1991). Bias Correction in Generalized Linear Models. *JRSS Series B* 53(3):629–643. **[primary]**.
- Firth, D. (1993). Bias reduction of maximum likelihood estimates. *Biometrika* 80(1):27–38. **[doc, via brglm2]**.
- Kosmidis, I. & Firth, D. (2009). *Biometrika*. **[doc, via brglm2]** — mean bias-reducing scores.
- Kenne Pagui, E. C., Salvan, A. & Sartori, N. (2017). *Biometrika*. **[doc, via brglm2]** — median bias reduction.
- Kosmidis, I., Kenne Pagui, E. C. & Sartori, N. (2020). Mean and median bias reduction in generalized linear models. *Statistics and Computing* 30:43–59. **[doc, via brglm2]** — `brnb` default.
- Al-Khasawneh, M. F. (2010). *Asian Journal of Mathematics & Statistics*. **[primary]** — combined MoM + quasi-likelihood dispersion estimator.
- Harrison, X. A. (2014). Using observation-level random effects to model overdispersion in count data. *PeerJ* 2:e616. **[primary]** — OLRE reference; (2015, *PeerJ* 3:e1114 companion also in the corpus/bibliography).
- Lee, Y. & Nelder, J. A. Generalized linear models with random effects: unified analysis via H-likelihood. **[primary]** — h-likelihood dispersion estimation.
- Brooks, M. E. et al. glmmTMB balances speed and flexibility among packages for zero-inflated GLMMs. **[primary]** — glmmTMB / `dispformula`.
- "A versatile workflow for linear modelling in R." *Frontiers in Ecology and Evolution* (2023). **[primary]** — glmmTMB `dispformula`/`ziformula` usage.
- gllvm package documentation (CRAN / RDocumentation) — `disp.formula`, `control.start$start.fit`. **[doc]**.
- gllvm 2.0 paper (JYX preprint; possibly Korhonen et al. 2025, *PeerJ* — **verify author/year/venue**). **[primary]** — shared dispersion `disp.formula`, warm-start.
- Niku et al. Efficient estimation of generalized linear latent variable models (PMC). **[primary; corpus, uncited]** — GLLVM estimation.
- GLMM FAQ (Bolker); GLMM bibliography (Bolker), bbolker.github.io. **[primary/doc]** — confounding of residual and RE variance.
- Cross Validated: "Is the OLRE term meaningful in the negative binomial model?"; "Identifiability with negative binomial model"; StackOverflow mixed-model confounding thread. **[forum]**.
- Hilbe, J. M. *Negative Binomial Regression* (Cambridge). **[corpus, uncited]** — standard NB reference.
- Multivariate Poisson-lognormal (PLNmodels) and Poisson-log-normal-vs-Poisson preprints. **[corpus, uncited]** — the JSDM count-model backdrop.

---

## Bottom line for gllvmTMB (is there a principled fix beyond gllvm's engineering heuristics?)

**Short answer: the problem is real and documented, but there is no single "principled" estimator in the literature that dissolves the NB-dispersion-vs-latent-variance ridge. The endorsed practice is exactly the set of engineering choices gllvm already uses — and those choices are the recommended standard, not just gllvm-local hacks.**

1. **The confounding is genuine and known.** NB2 and OLRE/latent log-scale REs are the same overdispersion mechanism, hence redundant and weakly identified with one observation per unit (Lawless 1987; GLMM FAQ; Cross Validated). gllvmTMB is right to treat "NB dispersion + latent overdispersion" as a design hazard, not a modelling free lunch.

2. **The small-sample NB-dispersion bias is well-established** (Lloyd-Smith 2007; Saha & Paul 2005; Gregory & Woolhouse 1993), and **real bias-corrected estimators exist** (Cordeiro–McCullagh 1991; Firth 1993; Kosmidis & Firth 2009; Kenne Pagui et al. 2017; Kosmidis et al. 2020 via `brglm2::brnb`; REML/h-likelihood). **However**, none of these was demonstrated *on the joint NB+random-effect ridge* in the corpus — they fix the NB-dispersion MLE in a plain NB regression. Applying them as a cure for the ridge is a reasonable hypothesis, **UNVERIFIED** by these sources.

3. **The remedies that ARE endorsed are the ones gllvm already implements:** (a) **don't use both** NB and a latent overdispersion term for the same level (Harrison 2014; Cross Validated); (b) **share/pool dispersion across responses** — `disp.formula` set to a constant or trait-grouped vector — explicitly *"to avoid volatile estimation"* (gllvm 2.0); (c) **warm-start from a Poisson fit** to get past the flat likelihood region (`control.start$start.fit`, gllvm docs); (d) model dispersion rather than stack a redundant RE (glmmTMB `dispformula`); (e) **priors on dispersion** in a Bayesian fit (plausible, [report-only]). So gllvm's "heuristics" are the field-standard remedies, not idiosyncratic workarounds.

4. **Gap / opportunity for gllvmTMB.** No source offers a purpose-built restricted/profile-likelihood or penalized estimator for *the joint NB-dispersion + latent-variance identifiability problem specifically*. That is an open methods niche: e.g. a REML-style or integrated/profile treatment of φ, or a penalty/prior that pins φ, evaluated by recovery simulation (the prompt's own "fix φ ⇒ recovery ≈1.0×" result is the obvious pilot). Pursuing it would be **novel**, but nothing in this corpus validates it yet — it must be established by gllvmTMB's own simulation evidence, not asserted from prior literature. **UNVERIFIED as existing practice.**

**Practical default to advertise now:** for count GLLVMs, prefer shared/structured dispersion (`disp.formula`) over per-species φ, avoid pairing NB2 with a latent overdispersion term at the same level, and warm-start from Poisson. That is the principled, literature-backed recommendation. A dedicated bias-corrected/profiled dispersion estimator for the ridge is a research direction, not a settled fix.
