# Design 86 lane — literature digest + ultra-plan (2026-07-22)

**Lane:** Design 86 (EVA scientific-admission contract), authorised by `LOOP/GOAL.md`
Maintainer Amendment 3 (2026-07-22). **Design-only. Does NOT gate 0.6.**
**Platform:** Claude Code (read from runtime). **Branch:** `claude/design86-eva-contract-20260722`.
**Worktree:** `~/local-scratch/worktrees/gllvmtmb-design86` (outside Dropbox; D-69/D-77).
**Write fence:** `docs/design/86-*.md` + this dev-log entry. Nothing else.

---

## 🎯 GOAL (paste-ready)

```
Solo platform: Claude Code. Deliverable: docs/design/86-<name>.md — a written, approvable
contract for a narrow EVA scientific-admission experiment. A design document; NOT an
implementation, NOT a campaign, NOT a public API.

HEADLINE: the admission criterion is binary-logit coverage under Laplace failure, grounded in
Korhonen et al. (2023) Fig. 3 — NOT an integer threshold in q (no such threshold is citable).

IN PARALLEL (cheap): gllvm source read (free, public); Design 72 TO-VERIFY closeout; the
scope-freeze table.

DEFER (fenced): any compute, any R/src/tests edit, any method= surface, any 0.6 claim.

DISCIPLINE: verify by reading the artifact, never an exit code or a negative grep. No merge,
tag, submission, or readiness claim. Compute needs separate approval AFTER the contract is
approved. Design 85 is a closed NO-GO and READ-ONLY — supersede with a dated note, never amend.
```

---

## Phase 0.25 — prior-work sweep receipt

| Surface | Evidence that it ran | Finding | Call |
|---|---|---|---|
| Repo git state | `git status -sb`; `git branch -a --sort=-committerdate`; `git worktree list`; `git stash list` | Dropbox checkout dirty + quarantined; 34 worktrees; 7 stashes; `origin/main` @ `acf20548` (4 days ahead of the session's start branch) | Fresh worktree from `origin/main`; touch nothing else |
| Prior VA work, this repo | Read `docs/design/72-*.md`; `docs/dev-log/after-task/2026-06-03-va-phase1-proof.md` | **Phase-1 VA prototype BUILT AND RUN** — branch `claude/va-phase1-proof` tip `8bf1a11e` (unmerged): `inst/tmb/gllvmTMB_va.cpp` (mean-field diagonal, closed-form Gaussian+Poisson ELBO, no `random=`), `inst/tmb/gllvmTMB_la_min.cpp`, `R/va-proto.R`, benchmark, CI workflow | ~~REUSE — a validated correctness anchor already exists~~ **WITHDRAWN 2026-07-22 (Fisher, S6 BLOCK B3).** It is a two-random-effect GLMM with **closed-form mean-field VA — not EVA**, no `Λ`, no `Σ_B`, no Taylor surrogate, separate template. It cannot anchor an EVA-for-GLLVM implementation; treating it as one would inherit an artifact's status across a boundary its evidence does not cross — Design 85 §13's own error class. **CONTEXT ONLY.** Gate 2 requires a fresh anchor built in the GLLVM path |
| Design 85 | Read `docs/design/85-*.md` in full | Full-covariance Gaussian VA + 1-D Gauss–Hermite quadrature. Gates 0–2 passed; **Gate 3 never obtained** (pilot conflated fixed-rank Gate 3 with ML-rank Gate 4); 8 applicable q1/q2 fits failed the optimiser gate | **SUPERSEDE, never amend.** Reuse its numerical apparatus (§7), not its verdict |
| Sister repo | brain `search_notes` (`search_all_projects: true`) → hits `160-gaussian-variational-approximation-gate`, `2026-06-04-gva-design-gate` | **drmTMB already designed a GVA gate** with a TMB plug-in point via an `inference_method` flag, `S` parameterisation, `drm_control(inference = "gva")` | **CO-OPT** the flag/dispatch design; do not re-derive |
| Brain | `search_notes` rungs 1 gated intermittently → rung 3 `Read memory/PROJECT-NOTEBOOKS.md` | Row 29: **an unaudited notebook `9b5e85d7-…` "GLLVM approximations — LA vs VA/EVA"** is the recorded source of the LA-vs-VA/EVA synthesis; registry flags its grounding as possibly **LLM artefact, not literature**; status PENDING | **Likely origin of the unsourced `q >= 4` claim.** Audit before citing |
| External prior art | NotebookLM `f329caa6-03fb-40af-b0e2-4c46cf9c60ea` + 6 primary PDFs supplied by the maintainer | See digest below | Literature settles 2 of the 3 lane prerequisites |

**Verdict:** genuinely new work = the *contract document* and its scope freeze. The estimator, the
ELBO algebra, the numerical apparatus, and a correctness anchor all already exist in-repo or in
the literature.

---

## Literature digest — VERIFIED against primary sources

Corpus (maintainer-supplied PDFs, read directly):
Korhonen, Hui, Niku & Taskinen (2023) *Stat Comput* **33**:26, DOI `10.1007/s11222-022-10189-w`;
Hui et al. (2017) *JCGS*; Joe (2008) *CSDA*; Niku et al. (2019) *PLOS ONE*; Blei et al. (2017).

### L1. What EVA is — CONFIRMED, primary

EVA replaces the complete-data log-likelihood by its **second-order Taylor expansion in the latent
variables `u`, expanded about `a` = the mean of the variational distribution** (Korhonen §3, eq. 5):

```
ell_EVA(Psi, xi) = sum_i sum_j { log f(y_ij | a_i, Psi) + 0.5 * Tr( H_i(a_i,Psi) A_i ) }
                 + 0.5 * sum_i { log det(A_i) - a_i' a_i - Tr(A_i) }
```

with `H_i = d^2 sum_j log f(y_ij|u_i,Psi) / du_i du_i'` at `u_i = a_i`.

**Design 72 §3.5's reconstruction was correct.** Its formula
`E_q[log p(y_i|u)] ~ log p(y_i|a) + 0.5 tr(H_i S_i)` matches the published result exactly.
Design 72's TO-VERIFY on this point is now CLOSED as CONFIRMED.

Complexity, stated by the authors: **`O(n p^3 + n m p^2)`** — linear in units `n` and responses `m`,
cubic in latent dimension `p`.

### L2. Design 85 is NOT EVA — settled from its own text

Design 85 §5 specifies a full-covariance Gaussian factor `q_i = N_q(m_i, S_i)`, `S_i = L_i L_i'`,
with the binomial-logit expectation by deterministic 1-D Gauss–Hermite quadrature, and states it
"is a bounded alternative to (not a silent rewrite of) the second-order EVA route recorded in
Design 72" (85:196–198). **Lane prerequisite #1 is RESOLVED**: they are different estimators, and
Design 86 must name EVA explicitly if EVA is what it means.

### L3. Closed-form coverage — CONFIRMED, primary

Standard VA has a fully closed-form bound only for particular response–link pairs. Korhonen §1, §4.2:
Bernoulli with **probit** link is closed-form; the **canonical logit** and complementary log-log are
**not**. Tweedie with log link admits **no** closed-form VA. EVA closes all of these
(Theorem 1: any exponential-family response with a twice-differentiable link).
**Design 72's family list is CONFIRMED.**

### L4. The headline result — Laplace fails badly on binary logit

Korhonen Fig. 3 (binary logit, `m = 48`, `p = 2`), effect of pH:

| n | LA bias | LA RMSE | LA 95% CI coverage | EVA bias | EVA coverage |
|---|---|---|---|---|---|
| 50 | ~ +1.2 | ~31 | **0.81** | ~0 | 0.968 |
| 120 | ~ +4.7 | ~12 | 0.91 | ~0 | 0.940 |
| 190 | ~ +2.5 | ~5 | 0.925 | ~0 | 0.925 |
| 260 | ~ +1.4 | ~3 | 0.94 | ~0 | 0.910 |

This is the user-value case, evidenced in the primary source: **for binary-logit GLLVMs Laplace is
severely biased and under-covers**, while EVA is near-unbiased.

### L5. The counter-signal — EVA coverage DEGRADES as n grows

In the same figure EVA's coverage moves 0.968 → 0.940 → 0.925 → **0.910** as `n` rises. This is
consistent with a **fixed-order** approximation: the Taylor bias does not shrink with `n`, so as
standard errors shrink the fixed bias becomes a larger share of the interval and coverage decays.

**Design implication (load-bearing):** the predeclared CUT criterion must test coverage **as `n`
grows**, not only at small `n`. A small-`n`-only design would show EVA at its best and miss this.
This is the single most important thing the literature adds that our own documents did not have.

### L6. The authors' own stated limitations (§7)

- Accuracy "lies somewhere **between** the standard method of VA (and VA-GH) and ... Laplace".
- "in EVA we **underestimate the latent variable posterior covariances even more than in standard
  VA**" — flagged as requiring careful consideration; bootstrap proposed as future work.
  *Apparent tension with §5's report that EVA's `A_i` traces are LARGER than VA's — unresolved;
  check Appendix C before relying on either statement.*
- **No large-sample theory for EVA yet exists** — "developing general large sample properties
  for EVA for GLLVMs" is listed as future work.
- Higher-order Taylor expansions unexplored.

### L7. The `q >= 4` threshold — NO SUCH CITATION EXISTS

**Every simulation in Korhonen et al. (2023) uses `p = 2`.** The paper offers no evidence at any
higher latent dimension. Its only remark on dimension is that Warton et al. (2015) used `p = 1,2,3`
for ordination while Tobler et al. (2019) suggested larger `p` when the goal is inference on
`beta` — a statement about *modelling goals*, not about Laplace degrading past a threshold.

**Finding: no citable `q >= 4` threshold was found.** Absence is the finding. Combined with the
brain's record that the claim's likely origin is an unaudited notebook, the claim should be
**retired**, not sourced.

**Replacement:** Laplace error for discrete responses is governed by **information per latent unit**
(Joe 2008 is the on-point reference; the classical GLMM result is Breslow & Lin). Design 86 should
predeclare an information floor of the form `T * median(n_it) / q`, not an integer in `q`.

### L8. Implementation — CONFIRMED, primary

Korhonen §3.1, closing paragraph: EVA "was first written in C++, after which it is compiled by TMB,
which employs automatic differentiation, to produce R functions to calculate the negative
log-likelihood, the score, and potentially the Hessian matrix. We then pass these to a generic
optimization procedure such as `optim`". And: "**there are no integrals in `ell_EVA`**, meaning its
maximization can be done using generic optimization approaches."

So both `Psi` (model) and `xi` (variational) are optimised **jointly**;
TMB is used purely as an AD engine; **there is no `random=` block and no inner Laplace step.**
**Design 72 §1.2's TO-VERIFY is CLOSED as CONFIRMED.**

- **SEs:** observed information from the joint `(Psi, xi)` Hessian; the `Psi` sub-block of its
  inverse gives Wald SEs. **CMSEP** (Booth & Hobert) is used for latent-variable prediction regions
  because naive variational covariances ignore parameter uncertainty.
- **Starting values:** the proposal in Niku et al. (2019a) §3.2.
- **Identifiability:** upper triangle of `Lambda` zero, **diagonal positive** — note this differs
  from the live gllvmTMB engine, which copies `lam_diag(j)` without `exp()` (Design 85 §6). Any
  comparison must not silently reconcile that.

### L9. What Shinichi's speed intuition got right

His stated intuition — non-Gaussian responses and many traits make VA/EVA much faster than Laplace
— is **supported for the `m` (traits/species) axis**. Korhonen §5.2: in setting 2, with `n` fixed
and `m` increasing, "the differences in computational times between the three methods are even more
dramatic, with both EVA and standard VA gaining even greater computational efficiency compared to
LA." Fig. 1b: EVA is roughly 5x faster than LA at every `n`, and far faster than VA-GH.

An earlier session note downplayed the trait axis on the grounds that the *integration dimension* is
`n x p`, not `m`. That reasoning is correct about the integral but **wrong as a prediction about
wall-clock**, which the paper measures directly. Recorded so the correction is not lost.

---

## The scientific tension Design 86 must carry

The estimator is **most valuable exactly where it is theoretically weakest**. Sparse binary carries
the user value (L4: Laplace fails there), but a fixed-order Taylor surrogate has its worst bias when
per-unit information is lowest — and L5 shows the bias is already visible as a coverage decay with
`n` at `p = 2` on non-sparse data. State this plainly in the contract and predeclare what result
would CUT it.

**Separate the two experiments** — conflating them invalidated Design 85's Gate 4:

- **Correctness anchor** (easy, information-rich): is the implementation right? Gaussian/Poisson,
  complete data. The Phase-1 prototype already provides this.
- **Admission criterion** (sparse binary): does it beat Laplace where Laplace is weak? Measured by
  coverage and bias **across a growing `n` ladder**, not convergence rate.

---

## Gate-0 scope freeze — why a fresh one is required

Design 85 §2 admits **complete multi-trial binomial**, `n_it >= 2` in every unit-trait cell, with
no masks, offsets, fractional successes, **or single-trial Bernoulli rows**. Sparse binary
(`n_it = 1`, high zero fraction) is therefore **outside** that contract. **Lane prerequisite #3 is
CONFIRMED**: 0.7 needs a new Gate-0 scope freeze, not a `q`-extension of existing evidence.

---

## Ultra-plan — slices

Fan-out budget: checkpoint `design86-2026-07-22` · new children ≤ 6 · scout 0–1 · ceiling 0–1.
**Status: 0 children dispatched — every `Agent` call this session was refused by a
safety-classifier outage.** Slices below are written for dispatch when tools recover; S0/S1 were
executed inline by the orchestrator instead, which is recorded as adaptive, not drift.

| # | Slice | Member | Model/effort | Dispatch | Dep | Status |
|---|---|---|---|---|---|---|
| S0 | Prior-work sweep + receipt | Ada | inline | — | — | **DONE** |
| S1 | Literature digest L1–L9 | Ranga | inline (PDF reads) | — | — | **DONE** |
| S2 | Read gllvm's actual TMB source (`src/gllvm.cpp`, `R/gllvm.TMB.R`) — confirm no `random=`, covariance parameterisation, LA/VA/EVA switch, optimiser | Ranga | Sonnet / medium | Agent | — | PENDING |
| S3 | Audit notebook `9b5e85d7-…` — enumerate sources; confirm or retire the `q >= 4` claim | Ebbinghaus | Haiku / low | Agent | — | PENDING |
| S4 | Recover the Phase-1 prototype from `claude/va-phase1-proof` via `git show`; inventory Design 85's quadrature code | Recon | Sonnet / low | Agent | — | PENDING |
| S5 | **Write `docs/design/86-*.md`** | Ada + Fisher | Fable / high | inline | S1–S4 | BLOCKED on S2–S4 |
| S6 | Adversarial review of the draft contract (does the CUT criterion actually bite?) | Rose | Opus / high | Agent | S5 | PENDING |
| S7 | Reconcile plan vs actual | Melissa | Sonnet / low | Agent | S6 | PENDING |

**Estimate:** S2–S4 ~1 hour wall-clock in parallel; S5 ~2 hours; S6 ~30 min. Fits one session once
tool access is restored.

**LUNA/Haiku suitability:** yes — S3 and S4 are bounded, read-only, mechanical.

---

## Open questions for the maintainer (do not self-answer)

1. **Estimator choice.** The literature favours **EVA** over Design 85's Gauss–Hermite VA for the
   sparse-binary target: EVA is closed-form for logit, ~5x faster than LA, and its accuracy is
   demonstrated on binary logit. Design 85's GH route is more accurate but slower and unproven at
   its own Gate 3. **Recommendation: Design 86 targets EVA, and says so in §1.** Confirm.
2. **Scope of the admission cell.** Sparse binary at what `T`, `n`, `q`, and zero fraction? The
   information floor `T * median(n_it) / q` needs a predeclared numeric value.
3. **Does an optional non-default `method=` contradict Design 04?** Design 04 puts *VA as the
   primary inference engine* out of scope and names `gllvm` as the VA alternative. It does not
   obviously exclude an optional non-default argument — but the document should say so
   deliberately rather than step past it.
4. **What result CUTs it?** Proposed: EVA fails admission if its binary-logit CI coverage falls
   below a predeclared floor **at the largest `n` in the ladder**, given L5's coverage decay.

---

## Provenance and honesty notes

- L1, L3, L4, L5, L6, L8, L9 are **verified against the published paper read directly**.
- L7 is an **absence finding** from the same paper (all simulations at `p = 2`); it is not proof
  that no such result exists anywhere, only that the primary EVA source does not support it and no
  source was ever supplied.
- Joe (2008) and Hui et al. (2017) PDFs are in hand but **not yet read in detail** — L3 rests on
  Korhonen's characterisation of them, not on Hui directly.
- Breslow & Lin bibliographic details remain **UNVERIFIED**.
- NotebookLM notebook `f329caa6-03fb-40af-b0e2-4c46cf9c60ea` holds 10 sources; the 4 maintainer
  PDFs were **not** successfully added (classifier outage) and remain pending.
- Nothing here is an approval. Design 86 is a contract only when Shinichi approves the written
  document; `LOOP/decision-queue.md` records it `NOT YET OPEN`.

---

## S6 plan review — Rose (scope and claims), 2026-07-22

**1 BLOCK, 7 CONCERN, 1 PASS.** Run in parallel with Fisher's method review. Both reviewers
returned findings the single Phase-0.25 sweep gate had missed, which is itself the load-bearing
lesson: **the review layers, not the model tier, are what caught this lane's errors.**

### BLOCK — write-fence integrity. ACCEPTED; partly pre-empted, now fully resolved.

Amendment 3 authorises `docs/design/86-*.md` **and its own dev-log entry — nothing else**, and adds
that the single-writer rule "returns in full the moment the Design 86 lane attempts anything outside
its fence". The ultra-plan nevertheless *directed* three out-of-fence writes:

- `LOOP/checkpoint.md` — and this one is not idle ground: `git log -- LOOP/checkpoint.md` shows it
  is **actively and exclusively owned by the M1 lane**. Writing there would both breach the fence
  and collide with another lane's single-writer file. It is also the concrete channel by which this
  lane's content could reach M1/M3/M4/M5 without an explicit citation — i.e. the literal
  does-not-gate-0.6 leak vector.
- `memory/DECISIONS.md` — outside this repo entirely.
- A *second* dev-log file (`docs/dev-log/plan-actual/…`) plus an after-task report, against a
  singular "its own dev-log entry".

**Disposition:** `LOOP/checkpoint.md` was **never written** — the conflict between the session
GOAL's generic closure line and Amendment 3's fence was resolved in the fence's favour at execution
time, and recorded in the commit message. The plan's directive is now struck rather than left
standing. **Whether "its own dev-log entry" (singular) permits additional closure files is a
maintainer question and is NOT self-granted** — until answered, all closure content lands in this
one file.

Rose also found the plan cited **`protocols/after-task.md`, which does not exist** in this repo;
the real protocol is `docs/design/10-after-task-protocol.md`. Corrected.

And a structural point worth keeping: the plan's own fence check (S7) was scheduled **before** the
steps that would breach it (S9/closure). A verification that runs before the risky step verifies
nothing. **The fence check must run last.**

### Finding A — the worktree did not contain its own authorisation. ACCEPTED; FIXED.

`grep "AMENDMENT 3" LOOP/GOAL.md` in this worktree returned **nothing**: the lane was operating two
commits behind `origin/main`, and Amendment 3 landed in `142ff39f`, after the base. The text was
read from a *different* worktree (the M1 builder), so the content was right — but a lane whose
stated discipline is "verify by reading the artifact" was running on a base that predates its own
authority.

**Fixed:** rebased onto `origin/main` (`509d5792`); Amendment 3 now present at `LOOP/GOAL.md:183`;
branch is exactly one commit ahead with a clean tree.

### CONCERN — the sweep receipt's wrong row had not been propagated. ACCEPTED; FIXED.

Fisher's B3 correction was applied to the ultra-plan but **not to this file**, which still carried
"REUSE — a validated correctness anchor already exists. Do not rebuild" as the artifact of record.
Corrected in place above. This is exactly the failure mode the Rose principle exists for: a fix
applied in one place and not walked to its neighbours.

### CONCERN — Design 85 apparatus-vs-evidence needs a brief-level guard, not just review.

The apparatus/evidence distinction is correct in language throughout, but the Phase-1 error shows a
single gate does not enforce it. Any slice that recovers Design 85 code must be instructed
explicitly: **read for orientation, re-derive independently, never paste as source** — echoing
Design 85 §11 Gate 0. Design 86 §11 Gate 0 already carries the NO-GO; the *brief* must carry it too.

### CONCERN — claims-audit vocabulary. Contract already compliant.

Rose flagged the plan's verification grep (`likelihood, ELBO, REML, AIC, marginal, bound`) as
narrower than Design 85 §10's prohibited vocabulary, missing `BIC`, `logLik`, `LRT`, `Cox–Reid`,
`AI-REML`, `AGHQ`. **The contract itself is not affected** — Design 86 §10 already prohibits all of
them explicitly. The *grep list* is what needs widening before the audit is trusted.

### CONCERN — fan-out ceiling justification.

The two-ceiling exception cites a real precedent but states no falsifiable trigger for when
Sonnet-high would suffice. Rose's sharper point stands on the evidence: three BLOCK-level errors
surfaced in an artifact the ceiling budget was meant to protect, and were caught by **a second
independent pass**, not by the tier. Front-loading quality onto a single expensive pass is the
weaker design; parallel adversarial review is the stronger one.

### PASS — the D3 roadmap fence is concrete and checkable.

Non-binding, not evidence, uncitable by §11, with a reader-executable test ("delete §14 and confirm
the contract still stands") and two named owners.

### Maintainer rulings, 2026-07-22

**ONE FILE.** "Its own dev-log entry" is **singular and literal**. All lane closure content —
the research digest, the ultra-plan, both S6 reviews, the D-43 panel outcome, and the after-task
report — lands in **this file**. No `docs/dev-log/plan-actual/…` file, no separate
`docs/dev-log/after-task/…` file, no `LOOP/checkpoint.md` update, no `memory/DECISIONS.md` write.
Melissa's plan-vs-actual reconciliation, when it runs, appends here.

This resolves Rose's BLOCK: the lane's write scope is now exactly **two paths** —
`docs/design/86-eva-sparse-binary-admission-contract.md` and this file — and any future slice that
wants a third must return to the maintainer, not self-grant.

**Design 86's two preconditions CONFIRMED** (§2.3 zero-fraction band; §2.4 Korhonen calibration
requirement), and recorded in the contract with their epistemic status intact — a confirmed
judgement is still a judgement, and the UNQUANTIFIED fallback remains binding. **This confirmed two
preconditions; it is not approval of the contract**, which remains a separate maintainer act with
`LOOP/decision-queue.md` still recording Design 86 as `NOT YET OPEN`.

**D-43 panel FIRED** — three fresh reviewers, distinct lenses (scope · falsifiability · claims),
each defaulting to NOT-DONE, composition 2 build + 1 ceiling. Outcome recorded below when it lands.
Until then no completeness claim is made for the Design 86 draft.
