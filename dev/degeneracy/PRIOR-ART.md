# Prior-art check: pdHess-insufficiency, Heywood cases, second-estimator cross-checks, starting values

**Role:** Ranganathan (grounded-research librarian). **Method:** NotebookLM CLI (`notebooklm ask`),
notebook `89d8ce4a-ef18-420a-b9ce-ed69c17b3d39` ("Design 94 — robust EVA and variational inference for
Bernoulli GLLVMs"), 17 sources — the `gllvm` CRAN docs/PDF/NEWS, the gllvm 2.0 PMC paper, the PLOS One
efficient-estimation paper, several Polya-gamma/variational-message-passing/VB arXiv papers, a Cauchy-prior
logistic-regression paper, and COMPSTAT/SDS 2022 abstracts. **Auth:** `notebooklm auth check --test --json`
returned `status: ok` with `token_fetch: true` before querying.

**Self-citation guardrail:** checked the source list (`notebooklm source list`) before relying on any
answer. All 17 sources are third-party (gllvm package authors Niku/Hui/et al., PLOS One, arXiv authors on
variational Bayes / Polya-gamma augmentation, COMPSTAT/SDS abstract authors). None are authored by Shinichi
Nakagawa or are gllvmTMB's own docs. No self-citation risk in what follows.

Four questions asked one at a time, each cited to its NotebookLM answer. Full Q&A transcript retained in
this session; only the load-bearing findings are recorded below.

---

## Q1 — Is a positive-definite Hessian ever presented as sufficient? Known-insufficient?

**Finding: pdHess is explicitly documented as INSUFFICIENT, not as a novel claim of ours.**

The `gllvm` literature recommends, as adequacy/convergence diagnostics:
- **Dunn-Smyth (randomized quantile) residuals** — the primary structural-fit check, standard normal
  under correct specification; `plot.gllvm()` produces five residual diagnostic panels from these.
- **Information criteria** (AIC/AICc/BIC) for choosing response family and number of latent variables.
- **Multiple initializations (`n.init`)**, selecting the run with the highest log-likelihood, because the
  GLLVM likelihood is explicitly described as "highly complex and multimodal" — poor starting values can
  trap the optimizer in a local maximum.
- **Gradient checking** (`gradient.check`, flags gradients still > 0.01 after claimed convergence).

The sources state directly that convergence with a valid Hessian only confirms a local maximum and permits
standard-error calculation — it does **not** guarantee the fit is the global optimum or otherwise
trustworthy. This is presented as already-known in the GLLVM literature, not as a novel insight.

## Q2 — Is "converges cleanly to a degenerate solution" documented, and is it a "Heywood case"?

**Finding: the term "Heywood case" does NOT appear anywhere in this corpus (17 sources). NOT FOUND.**

The specific pathology we found — pdHess=TRUE, convergence=0, yet a degenerate single-species/near-zero
loading — is also **not discussed** in this corpus under any name. What the corpus *does* document as
related but distinct failure modes:
- **Data separation → extreme/infinite effect sizes**: `gllvm` docs describe a species observed only when
  a covariate is exactly zero producing "extreme effect sizes"; the Cauchy-prior logistic-regression paper
  extensively covers complete/quasi-complete separation driving MLEs to infinity.
  This is a *different* mechanism (separation in the linear predictor) from our degenerate-loading case.
- **Convergence to "infinity or local maxima"** from poor starting values, as a general warning in `gllvm`
  docs.
- "Degenerate" appears exactly once in the whole corpus, in an unrelated multidimensional-scaling/unfolding
  abstract (COMPSTAT 2022), not factor analysis.

Absence noted plainly: **this corpus does not contain the term "Heywood case," and does not describe our
specific failure mode (clean convergence + pdHess + degenerate single-loading solution) under any name.**
This does not prove no prior art exists in the wider factor-analysis literature (Heywood 1931 and the
classical FA literature on improper/negative-uniqueness solutions is well known outside this notebook's
scope) — only that it is absent from *this* GLLVM-focused corpus, and that gllvm's own materials do not
flag it. Recommend citing the classical Heywood-case literature (outside this notebook) directly if the
writeup wants that connection, since NotebookLM cannot supply it from these 17 sources.

## Q3 — Is running a second, independent estimator as a check on the first established anywhere?

**Finding: NOT FOUND as a diagnostic recommendation. Comparisons across estimators exist only as
methodological benchmarking, not as a per-fit trustworthiness check.**

The corpus does compare VA vs. Laplace vs. MCMC/Gibbs — but strictly to benchmark speed/accuracy/variance
underestimation across simulated designs, not as advice a practitioner should follow to validate an
individual fit. The corpus's actual recommended cross-checks are same-estimator stability checks:
multiple/jittered initializations (`n.init`, `jitter.var`) and gradient checking — not switching estimator
family. **Our practice of running a second estimator (e.g. a different VA family or Laplace) as a
cross-check on a given fit's trustworthiness is not an established recommendation in this corpus** — it
would be a genuine (if simple) contribution, not a known method being re-presented.

## Q4 — Starting-value strategies for GLLVMs; is sensitivity to starting values a documented cause of
degenerate solutions?

**Finding: yes, well established and named.** Sensitivity to starting values causing local-maxima /
infinite-parameter degenerate solutions is explicitly documented. Named strategies:
- `starting.val = "res"` (factor analysis on Dunn-Smyth residuals of per-species univariate GLM fits) —
  the default, data-driven starting point.
- `n.init` — multiple initializations, keep the highest-log-likelihood run.
- `jitter.var` — random jitter added to the data-driven start, paired with `n.init` (e.g.
  `control.start = list(n.init = 3, jitter.var = 0.01)`).
- The PLOS One paper's simulation study found the residual-based start combined with jittered multi-init
  (their "res3") outperformed zero-start or purely random-start alternatives at reaching the global maximum
  and avoiding degenerate fits.

This is squarely established prior art: if the write-up proposes "try better/jittered starting values" as
a mitigation, it should cite this (gllvm docs + the PLOS One paper), not present it as new.

---

## Bottom line for the write-up

1. **"pdHess=TRUE is not sufficient evidence of a trustworthy fit" is known, not novel** — cite the gllvm
   documentation's own multimodality warning and its `gradient.check`/`n.init` diagnostics. Our contribution
   is not the general insight; it is the **measured magnitude** (59/70 gtmb_laplace degenerate fits reporting
   convergence 0 + pdHess TRUE, i.e. a real, quantified failure of the shipping default's own signal) and the
   **at-fit-time-only detector constraint** (no comparison against a known simulated truth).
2. **"Heywood case" as a label: NOT FOUND in this GLLVM-focused corpus.** Fine to use the term by analogy
   to classical factor analysis (external to this notebook), but do not claim the gllvm/GLLVM literature
   itself already names this failure mode that way — it doesn't, in this corpus.
2. **Second-estimator-as-cross-check: NOT FOUND as an established recommendation.** This appears to be a
   genuinely under-explored diagnostic in the corpus surveyed — a legitimate point of novelty for our
   detector design, not a rediscovery.
4. **Starting-value sensitivity and jittering/multi-init: well-established prior art**, directly
   applicable and should be cited, not reinvented or presented as new.

**Novelty scope of "the detector" (our failed_variance_domain / failed_health_gate at-fit-time labels):**
given the above, the specific idea of an at-fit-time (no-ground-truth) health gate that catches the
pdHess-clean-but-degenerate regime is not shown to be pre-existing in this corpus. The closest existing
practice is `gradient.check` (a related but different at-fit-time signal — large residual gradient, not
degenerate-loading detection) and jittered multi-init (a mitigation via re-fitting, not a diagnostic on a
single fit). Neither is the same check. This is consistent with, but not proof beyond, the 17-source corpus
surveyed — a wider literature search (beyond this NotebookLM notebook) was out of scope for this task.
