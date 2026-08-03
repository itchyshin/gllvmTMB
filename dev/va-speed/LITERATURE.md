# Literature brief — fast VI for GLLVMs (NotebookLM synthesis, digested)

**Corpus:** "Scalable VI for GLLVMs — closed-form PG updates, natural gradients,
stochastic VI", 14 sources cited (of 30 in the notebook), 61 numbered citations.
**Provenance:** this is a NotebookLM-synthesized answer over a curated corpus —
triage, not authority. Every claim below is tagged THEORETICAL or BENCHMARKED
(from the corpus) or **[ANALYST SYNTHESIS]** (my own bridging inference, not a
corpus claim — flagged so it is never mistaken for sourced evidence). Source
identifications range from CONFIRMED (title printed verbatim in the extracted
snippet) to UNVERIFIED (identified by content only, or unresolved). See the
**Source key** at the bottom before treating any attribution as load-bearing.
Raw NotebookLM answer + full 61-citation JSON are not preserved on disk beyond
this digest, per the librarian brief; re-query NotebookLM if verbatim text is
needed.

---

## TL;DR

1. **Structured covariance** is an *approximation* in general (diagonal
   restriction costs a small but nonzero accuracy penalty, and dramatically
   underestimates uncertainty for crossed/high-dimensional designs) — it is
   exact only when the model's own dependency structure already factors along
   the chosen partition. The corpus agrees with Design 106 Prop 2's
   *qualitative* principle but contains no equivalent or stronger iff-theorem
   for GLLVM loading-block structure. Speedups reported: ~2x (diagonal vs.
   unstructured, GLLVM) and ~13x (partial vs. full factorization, GLMM).
2. **YES — a closed-form augmentation exists for PROBIT**, and it is *not* a
   "probit analogue of Pólya-Gamma" — it's the older, simpler Albert–Chib-style
   truncated-Gaussian auxiliary-variable construction, proved at the GLLVM
   level (binary *and* ordinal cumulative-probit) in the paper the `gllvm`
   package itself implements. See §2 — this is the decision-critical finding.
3. **Staged/warm-start (diagonal-`S`-first) is NOT addressed anywhere in this
   corpus.** Stated gap, not a weak answer — see §3.
4. Per-observation scaling: alternating profile-out (AIRWLS), SVI mini-batching,
   and natural gradients are all covered, but none of the three is a small tweak
   to fit inside TMB's usual `MakeADFun`-then-optimize architecture. The
   closed-form probit substitution in §2 *does* fit that architecture cleanly.
5. GHQ cost is confirmed exponential in latent dimension (tensor-product grid);
   every implementation in the corpus avoids it via closed-form VA or Laplace
   (= adaptive quadrature at a single point), never by a cheaper quadrature rule.

---

## 1. Structured variational covariance

**What's restricted, and the reported speed-up.**
- GLLVM VA restricts each observation's variational covariance `A_i` (their
  notation for our `S`) to diagonal form, vs. unstructured. **Benchmarked**
  table (Hui et al. — see source key #1) of mean computation times gives
  **61.46 s (diagonal) vs. 126.90 s (unstructured)** at one cell (their
  `m=40,n=200`-scale grid) — **~2x**. Their own gloss: "the VA method assuming
  a diagonal matrix for `A_i` was slightly faster than the Laplace
  approximation, with both... substantially quicker than the VA method
  assuming an unstructured [form]." **[BENCHMARKED]**
- In high-dimensional GLMMs with crossed random effects, unfactorized
  coordinate-ascent VI scales **cubically, `O(p^3)`**, in the number of
  variational parameters `p` (Cholesky factor of `W_C^T W_C + P_C` is dense
  for crossed designs) (source key #3). **[THEORETICAL]** A **partially
  factorized** family — mean-field independence imposed only *across*
  crossed/non-nested effects, fixed effects and main effects kept joint —
  reduces this to **linear** cost per iteration (source key #3, Section 6).
  **[THEORETICAL, proved]**. On a real deep election-turnout model (their
  "Model 9"), partial factorization took **~1.5 min vs. ~20 min** unfactorized
  — **~13x**. **[BENCHMARKED]**

**Exact reformulation, or lossy approximation?** Lossy, **in general** —
both corpus sources that address this are explicit and neither found the
free lunch:
- Hui et al.: "the VA method assuming an unstructured form for `A_i`
  performed slightly better than... diagonal form, although... the
  differences in mean Procrustes error... were minor." A real, nonzero,
  benchmarked accuracy cost — small in their setting, but not zero.
  **[BENCHMARKED]**
- Goplerud et al. (source key #3): **proves** that fully-factorized
  (diagonal/independent) mean-field VI **"dramatically underestimates
  posterior uncertainty"** in high-dimensional / crossed-effect designs
  (their Theorem 2). **[THEORETICAL, proved]** They then identify *when* the
  loss vanishes: designs with **no crossed factors** (nested/multilevel) admit
  a naturally sparse (banded/tree) Cholesky factor, and the cubic-to-linear
  reduction there holds **"without further approximation."** More generally,
  their Theorem 3 ties the accuracy of a partially-factorized family to the
  **spectral gap / connectivity of the co-occurrence graph** among the factors
  left un-factorized — good connectivity (i.e., the retained block already
  captures the real dependence) is sufficient for the partial factorization to
  perform well. **[THEORETICAL, proved]**

**Comparison to Design 106 Proposition 2** (your proof: a zero off-diagonal
block of `S` is *exactly* optimal iff every observation's loading is
supported inside one group AND the prior precision is block-diagonal on the
same partition, via Fischer's inequality): **the corpus agrees with the
qualitative shape of this claim — approximation in general, exactness exactly
when the model's own dependency structure already factors along the chosen
partition — but contains no equivalent or stronger theorem for this specific
(loading-support, prior-precision) iff-condition.** Hui et al.'s evidence is
purely empirical (no exactness conditions stated at all — strictly weaker).
Goplerud et al. prove a real exactness/no-further-approximation result, but
for *mixed-model design nesting* (crossed vs. non-crossed grouping factors),
not for *GLLVM factor-loading support* — a structurally analogous but distinct
object. Net: **no source in this corpus contradicts Prop 2, and none subsumes
it; Prop 2 appears to be a sharper, GLLVM-specific instance of a principle the
literature independently reaches for mixed models.**

---

## 2. Closed-form updates (Pólya-Gamma and relatives) — **PROBIT: headline answer below**

**Pólya-Gamma (PG) is logit-specific, not probit.** PG augmentation
(Polson–Scott–Windle 2013) expresses the *logistic* function as a Gaussian
scale-mixture with a PG-distributed mixing variable. This is what the PG
literature in this corpus uses throughout: binary/Bernoulli **logit**
regression and negative-binomial (overdispersed count) models become
conditionally conjugate, giving exact closed-form CAVI updates (Klami 2015,
confirmed title; Rai/Hu/Harding/Carin tensor factorization, confirmed title;
a hierarchical-logistic-model CAVI paper with Scheme I/II/III
full/partial/limited factorization, title unresolved — source key #6).
**[THEORETICAL, all three]** PG-based GP classification (Wenzel et al., AAAI
2019, confirmed title) reports **up to ~2 orders of magnitude faster**, and a
companion natural-gradient PG paper reports closed-form natural-gradient
updates that equal block-coordinate-ascent at learning rate 1.
**[BENCHMARKED + THEORETICAL]** None of this is probit — it is all logit- or
logistic-mixture-shaped.

**DIRECT ANSWER — does a closed-form augmentation exist for PROBIT?**
**Yes.** Source key #1 (Hui, Warton, Ormerod, Haapaniemi & Taskinen — the
paper the `gllvm` R package's VA engine implements) derives one **explicitly
at the GLLVM level**, for exactly your target model class:

- Setup (quoted): *"we assume a Bernoulli distribution and use the probit
  link function. Equivalently, we introduce an auxiliary variable, `z_ij`,
  which is normally distributed with mean `η_ij` and unit variance, and set
  `y_ij = 1` if `z_ij ≥ 0` and `y_ij = 0` otherwise."* This is the classical
  **Albert & Chib (1993)**-style auxiliary-Gaussian probit augmentation,
  applied here directly to the GLLVM linear predictor `η_ij = τ_i + β_0j +
  x_i^T β_j + a_i^T λ_j` (i.e. the latent-factor term is already inside `η`).
  ["Albert–Chib" is my naming of the mechanism for clarity, not a term printed
  in the extracted snippet — the mechanism itself is quoted directly above.]
- Their **Lemma 2**: the optimal `q(z_ij)` is a **truncated normal**
  (location `η̃_ij`, scale 1, truncated to `(−∞,0)` if `y=0` / `(0,∞)` if
  `y=1`).
- Their **Theorem 1**: combined with Gaussian `q(u_i)`, this yields a
  **fully closed-form VA log-likelihood for the Bernoulli-probit GLLVM** —
  `Σ Σ [y_ij·log Φ(η̃_ij) + (1−y_ij)·log(1−Φ(η̃_ij))] − (1/2)Σλ_j^T A_iλ_j + ...`
  — no numerical integration anywhere.
- Their **Theorem 3** extends the *identical* construction to **cumulative
  probit ordinal GLLVMs** (multiple thresholds `ζ_jk`), also fully closed
  form.
- Direct quote on the contrast with a link that lacks this: *"log-likelihood
  would involve a term `E_q[log{1+exp(η_ij)}]`, and therefore would involve
  numerical integration to calculate and optimize. By contrast, using a
  probit link and thus Lemma 2 offers a fully closed form VA
  log-likelihood."* — i.e., **probit is the link that buys you the closed
  form here; nothing PG-shaped is needed or used.**

**[THEORETICAL, derivation]**, and it is **[BENCHMARKED]** downstream: the
TMB implementation of this same VA/Laplace machinery (Niku et al., PLOS ONE —
confirmed via DOI `10.1371/journal.pone.0216129` printed in the snippet) is
reported to be "clearly faster" than non-TMB alternatives across an extensive
simulation study.

**Why this is not "a probit analogue of Pólya-Gamma," and why that's good
news, not a lesser result:** PG needs an auxiliary PG-distributed variable
with a nontrivial mixing density (infinite alternating-series normalizing
constant, `E[ω] = (b/2c)tanh(c/2)`-type expectations — see source key #6).
The probit route needs only a **truncated-normal auxiliary variable** — its
sufficient statistics are plain Gaussian-CDF/PDF ratios (`Φ`, `φ`). This is
structurally *simpler* than PG, not a weaker substitute for it.
**[ANALYST SYNTHESIS]** `Φ`/`φ` are smooth, already-differentiable, standard
TMB atomic functions — this closed form is a direct drop-in objective-function
term, not an architectural change (contrast with §4's AIRWLS/SVI/natural-
gradient options, none of which fit TMB's standard `MakeADFun` pattern
cleanly). Whether gllvmTMB's current probit-VA path already exploits this
closed form, or is instead routing probit through generic GH quadrature, is
a question for the code, not the literature — but if it is the latter, this
is the single most direct, literature-grounded lever available.

---

## 3. Staged / warm-start schedules

**Not addressed in this corpus.** The specific technique asked about —
fitting a diagonal `S` first, then relaxing to block-diagonal/unstructured —
does not appear in any of the 14 cited sources returned for this question.
This is a **stated gap**, not a weak search: NotebookLM's own answer says so
directly rather than padding around it.

The corpus does cover a *different* kind of warm-start — **initial-value**
construction (not covariance-structure staging): fit univariate GLMs per
response, then factor-analyze the Dunn–Smyth residuals to seed the latent
scores and loadings (Niku et al., PLOS ONE — same source as §2's TMB
benchmark). Reported as the best-performing default (`res`/`res3` variants)
against `zero`/`random` starts, and shipped as `gllvm`'s default starting-value
method. **[BENCHMARKED]** This addresses a different failure mode
(multimodality / bad local optima at the start of optimization), not the
per-iteration cost that diagonal-`S`-first staging targets — do not treat it
as covering the same ground.

---

## 4. Per-observation variational parameters at scale

Three techniques, all present in the corpus:

- **Alternating profile-out (AIRWLS).** Treat `u_i` as fixed (≈ Penalized
  Quasi-Likelihood), decoupling the GLLVM into `n` row-specific and `m`
  column-specific GLMs, solved by Iteratively Reweighted Least Squares.
  Kidziński, Hui, Warton & Hastie ("Generalized Matrix Factorization" —
  author line printed verbatim; AIRWLS + quasi-Newton with diagonal
  Hessians). The `n` row-updates are **embarrassingly parallel** and
  independent. **[THEORETICAL]** **Benchmarked** on a large simulated sweep
  and on a real ecological co-occurrence dataset (~48,000 sites × ~2,000+
  species): at `p=10, n=500, m=300`, `gllvm` took **~2.5 days**, AIRWLS
  **~40 s**, with *better* deviance explained. **[BENCHMARKED — this specific
  number is directly quoted]**. The answer text's separate claim of "**3
  hours**" convergence on the full 48,331×2,211 dataset is **NOT verified
  in the returned snippets** — the quoted text for the full-dataset run says
  only that fitting `gllvm` to the full data "would take at least 2 weeks
  (if it converged at all)" and that they declined to attempt it; the
  specific "3 hours" figure for AIRWLS on the full dataset was not present in
  any snippet I was given. Treat "3 hours" as **UNVERIFIED** pending a direct
  check of the source paper; the qualitative claim (huge speedup, full
  dataset intractable for `gllvm`) is solid.
- **Stochastic VI (SVI).** Subsample a mini-batch of size `S << n` per step;
  optimize local parameters only for the sampled observations; weighted-
  average update of global parameters; per-iteration cost independent of `n`.
  **[THEORETICAL]** Benchmarked (PG-augmented GP classification, Wenzel et
  al.) on datasets up to **11 million points**, "up to two orders of
  magnitude faster than state-of-the-art." **[BENCHMARKED]**
- **Natural gradients.** Preconditioning by the Fisher Information Matrix is
  equivalent to a full coordinate-ascent step at learning rate 1
  (Hoffman-et-al.-cluster of sources — see source key #7, content strongly
  matches the well-known Hoffman/Blei/Wang/Paisley SVI paper plus 1-2
  companion sources, individual titles unresolved). Naively inverting the FIM
  costs `O(d^6)`; under the exponential-family expectation parameterization
  this is avoided entirely (source key #8, section header "Understanding
  Stochastic Natural Gradient Variational Inference," title/author
  unresolved). **[THEORETICAL]** That source also proves an `O(1/T)`
  non-asymptotic convergence rate for conjugate likelihoods.
  **[THEORETICAL, proved]**

**TMB/autodiff compatibility — [ANALYST SYNTHESIS, not a corpus claim]:**
AIRWLS replaces TMB's joint-AD objective with alternating closed-form GLM
fits outside the AD graph — a different architecture, not a drop-in. SVI
mini-batching would need the AD tape rebuilt (or maintained) per mini-batch,
which fights TMB's usual "tape once via `MakeADFun`, then optimize" pattern.
Natural-gradient updates replace TMB's generic quasi-Newton optimizer loop
(`nlminb`/`optim` over the AD gradient) with custom coordinate-style updates —
also not a drop-in. None of the three is impossible in TMB, but none is
small. By contrast, §2's closed-form probit substitution *is* a drop-in: it's
just a different closed-form expression inside the same AD-differentiated
objective, no architectural change.

---

## 5. Gauss-Hermite quadrature (GHQ) cost

**Why it dominates.** The GLLVM marginal likelihood requires integrating out
`d` latent variables per observation; direct numerical integration "can not
be expressed in closed form ... except for the special case where all
responses are Gaussian and the identity link is used" (source key #5), and
quadrature methods "scale poorly with the number of latent variables"
(source key #5, #9 — both directly quoted on this point). **[THEORETICAL]**
The answer's `O(Q^d)` notation (Q nodes per dimension, tensor-product grid
over `d` dimensions) is the standard textbook restatement of this — correct,
but not literal text from any single returned snippet; the underlying
qualitative claim (exponential blow-up with latent dimension) *is* directly
quoted.

**How implementations avoid it.** Two routes, both confirmed:
- **Closed-form VA** (§2's probit/logit constructions) replaces the integral
  with an analytic expression entirely.
- **Laplace approximation**, explicitly described as *"considered as a
  special case of adaptive quadrature with only one quadrature point"*
  (source key #9, directly quoted) — i.e., Laplace is GHQ collapsed to `Q=1`
  node with adaptive centering, not a different integration family.

**Benchmarked:** Niku et al. (PLOS ONE, TMB) and Hui et al. (JCGS) both show
closed-form VA / Laplace-in-TMB running far faster than GH-quadrature-based
alternatives, with the gap growing in the number of responses `m` and latent
dimensions `d`. **[BENCHMARKED]** No source in this corpus reports a route
that keeps GHQ but makes it cheap (adaptive node reduction, precomputation,
sparse grids) — every speed-up found here is "don't do GHQ at all," not
"do GHQ faster." Treat "cheaper GHQ via adaptive/sparse nodes" as a gap in
this corpus if that route matters to you — it was not addressed.

---

## Gaps — stated plainly, not padded

- **§3 (staged diagonal-then-relax schedule): not addressed at all.** No
  source in the returned 14 discusses this technique in any form.
- **§5, cheaper-GHQ-without-abandoning-it:** not addressed; every corpus
  source that speeds up the integral does so by replacing it with a
  closed-form alternative, not by making the quadrature itself cheaper.
- **The "3 hours" full-dataset AIRWLS figure (§4):** asserted in the
  synthesized answer, not present verbatim in any snippet returned to me.
  Flagged UNVERIFIED above — re-check against the Kidziński/Hui/Warton/Hastie
  paper directly if it matters to a claim you make.
- **Source #6 (33937d71-...) and the three-way SVI/natural-gradient cluster
  (#7) and #8:** content is solidly extracted and directly quoted, but exact
  paper titles/authors/years were not resolved from the returned citation
  text. Do not cite these as named papers without independent verification;
  cite them by the quoted content instead, or re-query NotebookLM for
  `source_describe` on these specific source_ids if a formal citation is
  needed.

---

## Source key

| # | source_id | Identification | Confidence |
|---|---|---|---|
| 1 | `b4bdcc66-d82a-4154-92f0-efa878501507` | Hui, Warton, Ormerod, Haapaniemi & Taskinen — "Variational approximations for generalized linear latent variable models" (the GLLVM-VA foundational paper; `gllvm`'s VA engine implements this). Lemma 1/2, Theorem 1/3, `q(u_i)=N(a_i,A_i)` notation. | HIGH (content/notation match; title not literally printed in snippets, identified from distinctive theorem numbering + GLLVM formalism) |
| 2 | `6f45af84-db47-4839-a6ec-cfee10eac9cf` | `gllvm` R package documentation / help text — VA covariance-structure arguments (`Ab.struct`, `Ar.struc`, `colMat`, `Ab.struct.rank`, `corExp`). | HIGH (argument names are gllvm-specific, e.g. `colMat` for phylogenetic/spatial input) |
| 3 | `b4df36a8-0c99-4da7-92a2-c124ce6a8154` | Goplerud (+coauthors) — "Partially factorized variational inference for high-dimensional mixed models," R package `vglmer`, voter-turnout MRP application. | HIGH (running header "M. Goplerud et al.", package name, application printed verbatim) |
| 4 | `a127759e-1cdc-4f58-bffe-1f2a5f10b8ef` | Klami, A. (2015) — "Polya-gamma augmentations for factor models," ACML, PMLR 39:112–128. | CONFIRMED (title/author/venue printed verbatim) |
| 5 | `c289c14f-7dc4-48a9-8a5b-8e830952c9e6` | Rai, Hu, Harding & Carin — "Scalable Probabilistic Tensor Factorization for Binary and Count Data" (Duke University). | CONFIRMED (title/authors/affiliation printed verbatim) |
| 6 | `33937d71-e681-4db1-a73c-bbf7e7b5a5e0` | UNRESOLVED title/author. Content: hierarchical logistic/binomial CAVI, PG augmentation, Scheme I ("full")/II ("partial")/III ("limited") factorization; "turns inference into iteratively performing weighted ridge regression." Distinct source_id from #3 despite similar factorization terminology — likely a different (possibly earlier/companion) paper, not confirmed. | UNVERIFIED |
| 7a–c | `2209aa7d-...`, `86269845-...`, `90158d61-...` | Cluster of 3 distinct sources on SVI/natural-gradient mechanics (data subsampling, "Algorithm 3"/"Figure 4", section header "2.4 Stochastic Variational Inference"). Content strongly resembles Hoffman, Blei, Wang & Paisley (2013) "Stochastic Variational Inference," JMLR, possibly plus 1–2 companion tutorial sources. | CONTENT HIGH; per-source_id title attribution UNVERIFIED |
| 8 | `93acf071-29ec-49ab-8568-86f1ab202003` | UNRESOLVED title/author. Recent theory paper on stochastic natural-gradient VI: `O(1/T)` convergence for conjugate likelihoods, avoids `O(d^6)` FIM inversion, section header "Understanding Stochastic Natural Gradient Variational Inference," cites Domke (2020/2023), Kim et al. (2023), Raskutti & Mukherjee (2015). | UNVERIFIED |
| 9 | `cf616a4b-26d5-4d3d-a52b-87a108064e5c` | Niku, Brooks, Herliansyah, Hui, Taskinen & Warton (2019) — "Efficient estimation of generalized linear latent variable models," PLOS ONE 14(5):e0216129. TMB-based VA/Laplace; `gllvm` starting-value methods (`res`, `res3`, `zero`, `random`). | CONFIRMED via DOI `10.1371/journal.pone.0216129` printed verbatim in snippet |
| 10 | `650af36e-db9b-4e4b-9359-9b6f6b9b8986` | Kidziński, Hui, Warton & Hastie — "Generalized Matrix Factorization" (AIRWLS + quasi-Newton for large-scale GLLVMs; plant-coexistence dataset ~48,000×2,000+). | HIGH (running header + author line printed verbatim; specific venue/year not confirmed in snippets) |
| 11 | `69e964ac-aabc-4e48-ad28-157aabe60fbb` | Wenzel, Galy-Fajou, Donner, Kloft & Opper — "Efficient Gaussian Process Classification Using Pólya-Gamma Data Augmentation," AAAI 2019. | CONFIRMED (title/authors/affiliations/emails printed verbatim) |
| 12 | `6eabfac4-8355-440b-aa82-c13db64eba49` | "Easy Variational Inference for Categorical Models via an Independent Binary Approximation" (IB-CAVI; 44–1,110x faster than NUTS on Glass-identification data). | TITLE CONFIRMED (printed verbatim as running header); authors UNVERIFIED |

**Minor QC note:** one bracket-citation in the raw NotebookLM answer (its
`[10]`) pointed at a sub-quote of source #3 that doesn't itself contain the
word "dramatically," while a *different* sub-quote of the same source (its
`[12]`) does. Same paper either way — not a fabrication, just an imprecise
bracket-to-quote mapping in the tool's synthesis. Flagged for completeness;
does not affect any claim above.
