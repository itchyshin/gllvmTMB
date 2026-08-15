# Design 117 — Separation as estimability: what Design 88 discharges, and the programme that remains

**Maintained by:** Fisher (inference / estimability), Warton (ecological statistics),
Curie (validation), Jason (literature scout).
**Status:** Programme document. Authorised by Shinichi 2026-08-08 as a capability plan in the
vault (`projects/gllvmTMB/separation-capability-plan.md`, `status: ready-to-execute`), and
landed here 2026-08-10. Decides the **research** arcs; it does **not** re-specify the
estimator, which Design 88 owns.

**Numbering note — read this, it is the point.** The vault plan said "copy into the repo as
`docs/design/NN-separation.md`". `main`'s highest was **87**, so **88** looked free. It was not:
`88-binary-mspl-estimator.md` was already allocated on the live branch
`codex/lane-b-mspl-reconcile-951` ([PR #952](https://github.com/itchyshin/gllvmTMB/pull/952)).
This document was then numbered **89** — **and that was wrong too**: `89-upstream-reference-eva.md`
exists on another ref (`8f8251a4`). It is now Design **117**.

**The general fact, measured 2026-08-10:** `main` held slots up to 87, but across **all refs** the
highest is **116**, and **15 numbers are already duplicated** (2, 3, 4, 59, 66, 73, 74, 86, 87, 88,
89, 94, 109, 110, 111 — slot 86 alone has **twelve** distinct files). **Reading `main` under-counts
the ledger by construction**, because a slot claimed on a branch is invisible from the checkout.

**A design-doc number is a shared sequential ledger, exactly like `DECISIONS.md`'s `D-` numbers:
read-then-append is a race, not an allocation — claim the number by committing it.** This is now
mechanised: `tools/lane_preflight.sh` scans **all refs plus untracked files** and prints the true
next-free slot. Run it before allocating a number; do not read the directory listing and guess.

**Lane note (D-87/D-88).** PR #952 is a **live Codex lane** on this subject. This document
deliberately touches **no file that PR touches** — it is additive, and it is written to
*reconcile with* Design 88 rather than restate it. Where the two overlap, Design 88 wins on
the estimator and this document defers. Ownership of the remaining arcs is Shinichi's call,
not this document's.

---

## 0. Verification ledger

Every claim below about what already exists was checked against the branch, not assumed.
This matters because the vault plan was written on 2026-08-08 and the Codex lane landed its
implementation on 2026-08-09 — **the plan is one day older than the code it plans to write.**

| Claim | How checked | Result |
|---|---|---|
| `88-binary-mspl-estimator.md` exists | `git ls-tree FETCH_HEAD -- docs/design/` | **Yes**, on `codex/lane-b-mspl-reconcile-951` |
| Separation screening is implemented | `git show FETCH_HEAD:R/screen-separation.R` | **Yes**, `R/screen-separation.R` |
| It routes to an existing solver | grep for `detectseparation` | **Yes** — `detectseparation::detect_separation()` with `detect_separation_control()` |
| It distinguishes the two grades | grep `quasi_complete` / `complete` | **Yes** — `status ∈ {complete, quasi_complete}` |
| It names the offending terms | grep `infinite_terms` | **Yes** — `infinite_terms`, plus `structural_zero_terms`, `pinned_zero_terms` |
| It screens the **fixed** design only | `.screen_separation_table(prep, ...)` uses `prep$X` | **Yes** — consistent with constraint 5 below |
| Highest design number on `main` | `git ls-tree origin/main -- docs/design/` | **87** |

**Consequence:** Arc 1 of the vault plan is **substantially already built**, and built the way
the plan asked for (route to `detectseparation`, do not write a simplex). This document does
not re-plan it. What follows is what is *not* built.

---

## 1. Executive summary

A species with very few presences can have **no finite MLE** for its own parameters. In a
GLLVM that species still contributes to the shared latent structure, so its non-existent
estimate propagates: loadings rail, the parameter covariance goes ill-conditioned, refits
become bimodal, and results become sensitive to the **order of the species columns** — every
one of which Zuur & Ieno (2025) documented in `gllvm` without naming a cause.

`aghq_ridge` already ships and makes estimates finite (measured 47% → 0% runaway). Design 88
adds `estimator = "mspl"` with fixed-design B0 screening and point-only inference fences.
**Detection and a remedy now exist. What does not exist is the evidence that the mechanism is
the one we think it is** — and that is the only part that decides whether there is a paper.

Three things remain:

- **§6.1 — penalty-sensitivity reporting** (Arc 2 of the vault plan). Not in Design 88.
- **§6.2 — interval construction under a penalty** (Arc 3). Design 88 fences intervals off
  rather than solving them; the fence is correct and the problem is still open.
- **§6.3 — the simulation that decides the hypothesis** (Arc 4). Not built. This is the one
  that matters scientifically.

Plus **§7**, the open research question that no paper in the corpus asks.

---

## 2. Separation is symmetric — both tails, not one

**This is the correction most likely to be lost, so it is stated before the design.** Complete
separation is a statement about a **perfect split**, not about scarcity. A species present at
**every** site is separated exactly as a species present at almost **none**: the estimate runs
to **+∞** instead of −∞, the likelihood is equally flat, the Hessian is equally
ill-conditioned. **Prevalence → 1 is as pathological as prevalence → 0.**

Consequences:

- **The detector needs no change.** The LP tests for a separating hyperplane and does not care
  which side the points fall on — `detectseparation` is symmetric by construction, so
  Design 88's screening inherits this for free. **Just never filter candidates by "rare".**
- **§6.3's simulation must sweep the FULL prevalence range** — down to a handful of presences
  *and up to a handful of absences*. A grid that stops at 0.5 finds half the effect and reports
  it as the whole. This is the single most likely way to get the study wrong.
- **The ecology framing hides this.** "Rare species" is the standard phrase and points at one
  tail only; the statistics is about **information content at either extreme**. Say so plainly
  in any write-up — it is the kind of thing a reviewer notices.
- `AGENT-INFERRED`, worth testing: ubiquitous species may be *more* damaging than rare ones in
  a GLLVM, because a species present everywhere still carries full weight in the **shared**
  latent structure while contributing almost no information to it.

---

## 3. What `gllvm` already provides — measure before building

Asked directly what `gllvm` offers at prevalence extremes, the corpus returned real machinery.
**This is not a greenfield.**

- **`beta0com = TRUE`** — species intercepts collapsed to a single common value, offered
  explicitly to stabilise models on highly sparse data. The closest existing thing to a
  rare-species device, and a blunt one: it detects nothing, and removes per-species intercepts
  *globally* rather than for the species that need it.
- **Starting values:** `starting.val = "res"` (default), `n.init` / `n.init.max` /
  `jitter.var`, `start.lvs` / `start.fit`.
- **Convergence diagnostics:** `gradient.check = TRUE` (flags any parameter gradient > 0.01
  even when the optimiser claims success), `fit$TMBfn$gr()`, `reltol` (default `1e-10`),
  `sd.errors` (flags Hessian inversion failure or extreme SEs).
- Also: `disp.formula`, `setMap`.

**What none of it does: decide whether an MLE *exists*.** Every item is a *mitigation* — better
starts, tighter tolerances, a flag when a gradient is large, a global reparameterisation for
sparse data. **Not one is a test.** The `gllvm` authors have clearly met this phenomenon
repeatedly and built machinery around its **symptoms**; the missing piece is the **diagnosis**.
That is a more accurate and more defensible framing than "nothing exists".

---

## 4. Standing constraints — read before writing code

1. **`brglm2` / `detectseparation` already exist**, descending from Konis (2007). Route to
   them; do not write a simplex. Design 88 does this correctly. *(Assuming a remedy was
   hypothetical when it had in fact shipped happened twice in one day on this topic — with
   `aghq_ridge` and again here. Check the branch before planning.)*
2. **A penalised fit is a MAP, not an MLE.** Unadjusted AIC/BIC comparisons across penalised
   and unpenalised fits are invalid.
3. **Kosmidis & Firth (2021): finiteness guarantees Wald CIs under-cover at some parameter
   values** — such intervals *"will fail to cover regardless of the nominal level."* No arc may
   ship "penalty on + Wald CIs". **⚠️ VERIFY AGAINST THE PRIMARY BEFORE DESIGNING §6.2.** The
   corpus harvest reports the warning holding **even when profiled**. If that is right, "just
   use profile intervals" is **not** a fix and interval construction becomes a first-class
   design problem. We hold the PDF; check it rather than trusting the notebook answer.
4. **Counts are not solved by the literature.** The corpus is binary-only. Poisson/NB/Tweedie
   separation needs its own derivation — do not fold it into the binomial test. Design 88 is
   correctly scoped to Bernoulli.
5. **The latent wrinkle is real and unclaimed.** In a GLLVM the design includes *estimated*
   latent variables, so separation is not a fixed property of the data. Every primary assumes a
   fixed design. Screening therefore tests the **fixed part only** — which is exactly what
   Design 88 implements — and the LV-dependence is an **open research question** (§7), not an
   implementation detail.

---

## 5. What Design 88 discharges

Recorded so no future lane rebuilds it (see §0 for how each was verified):

- Per-block screening on the fixed design, before fitting, via `detectseparation`.
- `status ∈ {complete, quasi_complete}` with severity, plus `infinite_terms`,
  `structural_zero_terms`, `pinned_zero_terms`, rank and active-column counts.
- Opt-in `estimator = "mspl"`; ML remains the default and is unchanged.
- Guarded logit / probit / cloglog Laplace point estimation.
- **Point-only inference fences** — intervals are refused rather than reported wrongly. Given
  constraint 3, refusing is the correct behaviour and is *not* a placeholder to be removed
  casually; see §6.2.

**Gate still owed on Design 88's own screening** (per *"a guard proven only by passing has not
been shown to guard anything"*): a hand-built separated species that the detector **must**
flag, and a well-behaved species it must **not** — at **both** prevalence tails, and made to
fail on purpose twice. If Design 88's test suite already covers the ubiquitous tail, record it
here and close this line.

---

## 6. The remaining arcs

### 6.1 Penalty-sensitivity reporting

**Deliverable.** When a penalty is active, every affected estimate is flagged as
**penalty-determined rather than data-determined** — per estimate, not as a global footnote —
carrying a **sensitivity number**: how far the estimate moves under a different penalty.

Rainey (2016) shows Jeffreys and Cauchy(0, 2.5) give substantively different magnitudes on the
same data, because in the separated direction the likelihood is flat and **the answer is the
prior**. Screening tells you *which* species are affected; this tells you *how much the number
is yours rather than the data's*.

**This is the arc that makes a penalty safe to leave on**, and it is worth shipping whatever
§6.3 concludes.

### 6.2 Interval construction under a penalty

**Deliverable.** Either a defensible interval for penalised estimates, or a documented refusal.

Design 88's point-only fence is the honest interim answer. Do **not** start by assuming profile
intervals fix the coverage problem — verify constraint 3 against the Kosmidis & Firth PDF
first. If the caveat holds under profiling, the honest options narrow to:

- simulation-calibrated intervals,
- a bootstrap with the penalty applied **inside** each resample, or
- **reporting the estimate without an interval and saying why** — a legitimate answer, and
  better than a confident wrong one.

Lands on the already-open CI-08 / CI-10 interval-calibration weak spot.

### 6.3 The simulation that decides the hypothesis

**This is the arc that decides whether there is a paper.**

**Design.** Full prevalence sweep, **both tails** (§2). Arms: **none / `aghq_ridge` / MSPL
(Firth-type)**. Seeded and repeated — Zuur & Ieno's bad mode appeared in a *minority* of 10–25
refits, so a single run proves nothing.

**Record per run:** the LP flag · per-species loading and CI width · **parameter-covariance
condition number** · **max-|gradient| parameter name** · **sensitivity to permuting species
columns**.

**Predictions, registered before running:**

| # | Prediction | If it fails |
|---|---|---|
| a | Species flagged by the LP test are the species whose loadings/CIs misbehave in the no-penalty arm — **at BOTH prevalence extremes** | Hypothesis dead — the instability has another cause, and we have eliminated the most plausible one |
| b | Condition number degrades with the *number* of flagged species | Mechanism is per-species, not aggregate |
| c | **Column-order sensitivity disappears under the penalty that addresses the mechanism** | The remedy is cosmetic, not mechanistic |

**(c) is the sharpest test.** Species-order sensitivity is the one symptom nobody has
explained; a remedy that removes it is doing something real. This design also **doubles as the
permutation-invariance test** gllvmTMB wants anyway — one simulation, two questions.

**A negative result is publishable and must be reported as such.** Prediction (a) failing
eliminates the most plausible mechanism for a documented instability; that is a result, not a
failed project. Register these predictions before running so the outcome cannot be
reinterpreted afterwards.

**Compute:** a seeded multi-arm grid — a **Totoro** job under the standing authorisation
(≤150 cores), not a laptop job. Coordinate with the B2 campaign machinery already in PR #952
rather than building a second harness.

---

## 7. The open research question — separation in a latent design

Every primary in the corpus assumes a **fixed** design. A GLLVM's design contains **estimated
latent variables**, so:

> What does separation *mean* when the separating direction is partly an estimated latent
> variable — and can a species be separated in the fitted design but not in the fixed design,
> or the reverse?

No paper in the corpus asks this. Screening the fixed part (Design 88's choice) is the correct
conservative implementation, but it is a **scope decision, not an answer**: it can miss
separation that only exists once the LVs are estimated, and it can flag species that the full
design would identify. Quantifying that gap is a research contribution in its own right and is
cheap to start — the fitted LVs are already available post-fit, so re-running the same LP on
the augmented design is a small experiment with a real answer.

---

## 8. What would make it a paper

The claim is **not** "nobody has noticed rare-species pathology in GLLVMs" — that is weak and
easy to rebut. It is that **the observations are already in print under domain-specific names
and have never been connected to the statistical theory that explains them**:

- van der Veen et al. (2021) report quadratic optima **diverging to ±∞** for near-linear
  species;
- van der Veen et al. (2023) report **boundary-estimated** LV-error-scale parameters.

Infinite and boundary estimates, in the `gllvm` authors' own methods papers, with no reference
to MLE non-existence. Meanwhile the separation literature has never treated a design containing
an **estimated latent variable**. **The gap is symmetric, and the contribution is the bridge.**

The paper is §6.3's result either way, plus §7.

---

## 9. Evidence base, and what it cannot support

**Notebook:** `7c2f311f-61ee-49e8-91a7-20f86c10a0ba` — *"Separation and rare species in JSDMs —
estimability, detection, remedies (gllvmTMB)"*.
Synthesis: `dr32-separation-rare-species-jsdm-distilled`.

**8 sources, each verified by character count, not by `status: ready`:**

| Source | Chars | Role |
|---|---|---|
| Kosmidis & Firth 2021 (arXiv PDF) | 57,361 | finiteness theorem + the coverage caveat |
| Rainey 2016 | 73,342 | consequences of the *choice* of penalty |
| van der Veen et al. 2023 — concurrent ordination | 97,049 | GLLVM estimation behaviour |
| van der Veen et al. 2021 — unequal niche widths | 86,511 | GLLVM estimation behaviour |
| Niku et al. 2019 (*PLoS ONE*) | 94,753 | GLLVM estimation behaviour |
| Konis 2007 — ORA **landing page only** | 9,527 | ⚠️ thesis body NOT in corpus |
| `detectseparation` / `brglm2` CRAN pages | 6,366 / 9,120 | documentation pointers |

**Missing, deliberately or unavoidably — read before trusting a corpus answer:**

- **Konis 2007's thesis body** is not in the notebook (ORA PDF add was quota-blocked). It *is*
  distilled in the vault's `ENGINEERING-NOTEBOOK` from the local PDF, so the knowledge exists —
  but the notebook cannot ground on it.
- **Korhonen et al. 2025 (gllvm 2.0, PeerJ)** — PeerJ blocks the fetcher, including its own PDF
  endpoint.
- **Mi et al. 2020 (rare species in JSDMs)** — PMC returned a reCAPTCHA page reporting
  `status: ready` while holding 450 characters. Caught by character count; deleted.
- **Albert & Anderson 1984**, **Heinze & Schemper 2002** — subscription PDFs, deliberately not
  uploaded; both distilled in the vault.

**The limitation that matters.** The corpus is strong on **separation theory and remedies** and
on **GLLVM ordination**, and **weak on the rare-species-in-JSDM half — which is exactly the
connection under test.** So **silence from this corpus about that connection is not evidence
the literature is silent.** That claim rests on a separate access-and-coverage audit, not on
the notebook.

---

## Related

- `docs/design/88-binary-mspl-estimator.md` — the estimator; owns everything in §5.
- [PR #952](https://github.com/itchyshin/gllvmTMB/pull/952) — the live lane implementing it.
- Vault: `projects/gllvmTMB/separation-capability-plan.md` (the authorised plan this refines),
  `Separation in JSDMs is an unclaimed gap — and it may be what Zuur and Ieno actually found`,
  `dr32-separation-rare-species-jsdm-distilled`, `ENGINEERING-NOTEBOOK` § *Separation in binary
  GLMs*, `Zuur and Ieno GLLVM volume`.
