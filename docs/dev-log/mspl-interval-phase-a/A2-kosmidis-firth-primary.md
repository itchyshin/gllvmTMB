# A2 — Kosmidis & Firth (2021) primary-source verification

**Primary source accessed:** full text obtained via `WebFetch` of `https://arxiv.org/pdf/1812.01938`
(arXiv v4, 25 Mar 2020; 19 pages total — 10-page main text + 6-page supplementary proof
document, both saved and read via the PDF extraction tool). This is the arXiv preprint of
Kosmidis & Firth (2021), *Jeffreys-prior penalty, finiteness and shrinkage in binomial-response
generalized linear models*, Biometrika 108(1):71–82. Page numbers below refer to the printed
page footer of the PDF (main text pp. 1–10, supplementary pp. 1–6 of its own numbering).

---

## Q1 — What exactly does the paper claim about Wald-interval coverage under the Jeffreys penalty?

**VERIFIED.** Section 2.2 "Finiteness", p. 5, final paragraph (main text):

> "there will always be a parameter vector with large enough components that the usual
> Wald-type confidence intervals β̃ₜ ± z₁₋α/₂ sₜ(β̃), or confidence regions in general, will
> fail to cover regardless of the nominal level α that is used."

Operative quote (<15 words, exact location): *"will fail to cover regardless of the nominal
level α"* (Kosmidis & Firth 2021, §2.2, p. 5).

**Precise conditions under which the claim holds** (VERIFIED, reconstructed from the
surrounding argument, same paragraph and Theorem 1/Corollary 1, pp. 5–6):
- Applies to the maximum-penalized-likelihood (MPL) estimator β̃ from penalizing the
  log-likelihood by (a power of) Jeffreys' invariant prior, for any fixed full-rank design
  matrix X (any a > 0 in their general penalty family, eq. 4; a = 1/2 is the Jeffreys/Firth
  case).
- The argument is a **finite-sample existence argument, not an asymptotic or typical-case
  one**. It rests on two facts proved/assumed earlier in the paper: (i) β̃ is *always finite*
  for any data (Corollary 1, itself following from Theorem 1's limit result
  lim_{r→∞}|XᵀW*(r)X| = 0); (ii) because y₁,…,yₙ are realizations of *binomial* (hence
  discrete-valued) random variables, β̃ can take only a **finite number of possible values**
  for any given X. Consequently, for *any* fixed n and X there exists **some** true parameter
  vector with sufficiently large components that no finite-width Wald interval built around a
  bounded estimator can ever reach it — "there will always be a parameter vector with large
  enough components" (i.e. an existence/worst-case statement, not a claim that failure is
  frequent or typical across the parameter space).
- The authors flag this as a "notable, and perhaps undesirable, side-effect... that have been
  largely overlooked in the literature" (p. 5) — i.e. presented as an overlooked implication of
  their own finiteness result, not as a new theorem with its own formal proof in this paper.

---

## Q2 — Does the claim extend to profile / penalized-likelihood-ratio intervals? (LOAD-BEARING)

**VERIFIED — YES, the paper explicitly extends the claim to profile intervals of the penalized
likelihood.** Same paragraph, immediately following the Wald-interval sentence (§2.2, p. 5):

> "it is also true when the penalized likelihood is profiled for the construction of confidence
> intervals, as is proposed, for example, in Heinze & Schemper (2002), and in Bull et al. (2007)
> for multinomial regression models."

Quote (<15 words): *"also true when the penalized likelihood is profiled"* (Kosmidis & Firth
2021, §2.2, p. 5).

The paper also cites, as independent supporting evidence for the profile-interval failure,
complete-enumeration studies: *"This has also been observed in the complete enumerations of
Kosmidis (2014) for proportional odds models"* (p. 5, paraphrase-length quote kept under 15
words: *"observed in the complete enumerations of Kosmidis (2014)"*).

**Nuance for how load-bearing this is:** the profile-interval extension is stated as a bare
assertion backed by citation (to Heinze & Schemper 2002, Bull et al. 2007, and Kosmidis 2014),
**not** derived as a new formal theorem within this paper — Theorems 1–3 in the main text
concern finiteness and shrinkage of the *point estimator*, not interval coverage per se. The
reasoning that makes it plausible is the same boundedness logic as for Wald intervals: a
profile-likelihood interval from a bounded (finite-everywhere) penalized log-likelihood is
still built from information about a finite-valued estimator, so the same "some sufficiently
extreme true β cannot be reached" argument applies. But the paper does not walk through this
extension step by step for the profile case — it is a stated conclusion with citations, not an
independently proved result.

**Verdict on the corpus harvest's claim:** CONFIRMED. "Just use profile intervals" is
explicitly **not** presented as a fix by the primary source. The design doc's fence against
shipping "penalty on + Wald CIs" should, on this evidence, extend to "penalty on + naive
profile CIs" as well, per the primary text's own statement — though see Q4 for a specific
named alternative construction that the Kosmidis lineage does consider more defensible.

---

## Q3 — Parameter region of under-coverage; any complementary conservative/over-covering region?

**VERIFIED (region of guaranteed failure):** "large enough components" of β (p. 5) — i.e. a
large-|β| / extreme-effect regime, structurally the regime associated with (quasi-)complete
separation, since separation is what drives the *unpenalized* MLE to ±∞ in the first place
(Albert & Anderson 1984 result, restated §1 p. 2 of the same paper).

**UNVERIFIED / NOT FOUND — no complementary conservative or over-covering region is described
anywhere in the primary text or its supplementary material.** I read the complete document
(main text §1–§6, all of the supplementary proof/algorithm sections S1–S3) and found no
statement anywhere characterizing over-coverage, conservativeness, or "safe" behaviour of Wald
or profile MPL intervals in a complementary (e.g. small-|β|, well-identified, non-separated)
region. The paper is silent on this axis entirely.

The only nearby result is **Theorem 2 (Shrinkage, §2.3, p. 6)**, which is about the *point
estimator* and the *volume* of Wald confidence ellipsoids, not their coverage probability: MPL
estimates shrink toward equiprobability (π → 1/2, not literally β → 0) relative to the metric
of the expected information, and — quote (<15 words): *"approximate confidence ellipsoids...
are reduced in volume"* (§2.3, p. 6) relative to the MLE's. A smaller ellipsoid is not the same
claim as over-coverage; the paper does not connect this shrinkage result to a coverage-direction
claim.

**Conclusion for Q3:** the primary source proves an *existence* statement (guaranteed failure
somewhere, for sufficiently extreme true β) and says nothing about the rest of the parameter
space. This is **logically consistent with, not contradicted by**, the campaign's own finding
of mostly-over-coverage (0.988–1.000) elsewhere and under-coverage concentrated in a
cloglog/high-prevalence cell — because the paper never claims under-coverage is *typical*, only
that it is *unavoidable somewhere*. The two findings do not conflict; they simply describe
different, disjoint regions of the same phenomenon that the primary paper itself never
characterizes jointly.

*(Secondary/vault-only lead, not verified against a primary source in this task, flagged for a
possible separate follow-up: Firth 1993/Heinze & Schemper 2002 are described in the vault's
ENGINEERING-NOTEBOOK as producing "coverage close to 100% one-sided in high-separation
regimes" for Wald SEs from the Firth-corrected fit — if true this would be a directly relevant
complementary-region result, but it is attributed to Heinze & Schemper 2002, not to K&F 2021,
and was not checked against its own primary text in this task.)*

---

## Q4 — Does the paper or its immediate successors propose a defensible interval construction?

**Within Kosmidis & Firth (2021) itself: NO proposal.** VERIFIED (absence). Section 6
"Concluding remarks" (p. 10) discusses only the *coefficient path* over a ∈ (0, 5] and closes
with: *"development of general procedures for selecting a, are interesting, open research
topics"* (p. 10) — i.e. explicitly left open, not resolved with an interval recommendation.

**In Kosmidis's own software lineage (brglm / brglm2): YES — a specific, named, defensible
construction exists.** VERIFIED against the CRAN documentation for `confint.brglm` in the
`brglm` package (I. Kosmidis's earlier CRAN package, predecessor to `brglm2`, which K&F 2021
itself cites and demonstrates in Example 1):

- The default `ci.method = "union"` is: *"based on the union of the confidence intervals
  resulted by profiling"* the ordinary (unpenalized) deviance at the ML fit **and** the
  penalized deviance at the MPL fit, attributed to **Kosmidis (2007)** (his own earlier work,
  predating K&F 2021).
- The documentation states the underlying problem in almost the same terms as K&F 2021,
  additionally citing Brown et al. (2001): penalized-likelihood profile intervals *"could
  exhibit low or even zero coverage for hypothesis testing on large parameter values"* and
  *"misbehave illustrating severe oscillation"*.
- The recommended remedy (quote, <15 words): *"slightly conservative, illustrate less
  oscillation and avoid the loss of coverage"* — i.e. the union construction trades a modest
  conservativeness for avoiding the guaranteed-failure region K&F 2021 describes. A "mean"
  alternative (averaging the two profile intervals' endpoints instead of taking their union) is
  offered as less conservative but with more residual oscillation.

**Caveat (UNVERIFIED extension):** I could not confirm whether the *current* `brglm2` package
(the actively maintained successor, which is what K&F 2021 and this repo's design doc would
actually use) still exposes this same `"union"`/`"mean"` choice under `confint.brglmFit()` in
identical form — the accessible documentation fragments for `brglm2::confint.brglmFit` returned
only a minimal signature (`object, parm, level, ...`) with no visible `type`/`ci.method`
argument or Details section in the sources I could fetch. The "union" method is a **verified,
precisely named Kosmidis-lineage proposal**, but its exact current API surface in `brglm2`
specifically (vs. the older `brglm`) is **not confirmed** and should be checked directly in R
(`?confint.brglmFit`) before citing it as gllvmTMB's adopted construction.

**Sterzinger & Kosmidis (2023), "Maximum softly-penalized likelihood for mixed effects logistic
regression", Statistics and Computing 33, article 53 (DOI 10.1007/s11222-023-10217-3; arXiv
2206.02561):** PARTIALLY CHECKED (read pp. 1–6 of 29 main text plus the appendix, not the full
inference/simulation sections 5–9). Two relevant, verified findings:
- This paper does **not** target the plain Jeffreys-penalized fixed-effects-only estimator of
  K&F 2021; it proposes a *different, "soft"* composite penalty (Jeffreys for fixed effects,
  negative-Huber-loss composition for variance components) for **mixed-effects** logistic
  regression, scaled specifically so that — quote (<15 words) — the resulting estimator has
  *"consistency, asymptotic normality, and Cramér-Rao efficiency"* (abstract, p. 1), formally
  proved as Theorem B.2 in the appendix (p. 16).
- This is a structurally different fix from "construct a better interval": rather than
  proposing a new interval type for the K&F estimator, it changes the **penalty scaling** so
  that the penalty becomes asymptotically negligible relative to the likelihood, restoring
  standard first-order (Wald) asymptotics for the *softly*-penalized estimator. Whether this
  paper makes any explicit interval-construction recommendation (Wald vs. profile) for MSPL
  itself was **not verified** — Sections 5–9 (results, discussion, concluding remarks) were not
  read in this pass; this is flagged as incomplete rather than answered.
- One incidental but verified data point from the pages read: in a simulation comparing MSPL to
  a *competitor* method (`bglmer` with normal/t priors, not MSPL itself), the paper reports —
  quote (<15 words) — *"Wald-type confidence intervals about the fixed effects are found to
  systematically undercover"* (p. 6) for that competitor. This is evidence of Wald undercoverage
  for a *different* (non-Jeffreys, non-MSPL) penalized method, offered here only as corroborating
  context, not as a claim about K&F's own estimator.

---

## Summary of citations used

- Kosmidis, I. & Firth, D. (2021). Jeffreys-prior penalty, finiteness and shrinkage in
  binomial-response generalized linear models. *Biometrika* 108(1), 71–82. [PRIMARY —
  arXiv:1812.01938v4, full text read]
- `brglm` R package, `confint.brglm` documentation (I. Kosmidis), citing Kosmidis (2007) and
  Brown et al. (2001). [Successor software documentation, verified via RDocumentation]
- Sterzinger, P. & Kosmidis, I. (2023). Maximum softly-penalized likelihood for mixed effects
  logistic regression. *Statistics and Computing* 33, article 53. [Successor paper, partially
  checked — pp. 1–6 and appendix of 29]
