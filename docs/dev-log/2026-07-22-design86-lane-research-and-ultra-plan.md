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
| S2 | Read gllvm's actual TMB source (`src/gllvm.cpp`, `R/gllvm.TMB.R`) — confirm no `random=`, covariance parameterisation, LA/VA/EVA switch, optimiser | Ranga | Sonnet / medium | Agent | — | **DONE** — read at `JenniNiku/gllvm@50a2bcc4`. No `random=` under VA/EVA confirmed from code; one template with `DATA_INTEGER(method)`; default covariance is full log-Cholesky, not mean-field; SEs via Schur complement of the joint Hessian + CMSEP. Folded into Design 86 §7.8 |
| S3 | Audit notebook `9b5e85d7-…` — enumerate sources; confirm or retire the `q >= 4` claim | Ebbinghaus | Sonnet / low | Agent | — | **DONE** — 66 sources enumerated (registry row 29 stale on both title and count). `q >= 4` traces to **exactly one** source: a `markdown` entry with `url: null` and no bibliographic identity. **RETIRED.** Folded into Design 86 §1.4 |
| S4 | Recover the Phase-1 prototype from `claude/va-phase1-proof` via `git show`; inventory Design 85's quadrature code | Recon | Sonnet / low | Agent | — | **DONE** — Phase-1 at `claude/va-phase1-proof` tip `8bf1a11e`, unmerged, `random=` absent (confirmed in the source comment). **Correction: Design 85's R3 quadrature prototype is MERGED on `origin/main`**, not parked in a worktree. `method=` surface confirmed ABSENT on main |
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
each defaulting to NOT-DONE, composition 2 build + 1 ceiling.

---

## D-43 completion panel — outcomes

### Lens 1: SCOPE — **NOT-DONE** (3 blocking items, all accepted and fixed)

Passed: the Gate-0 exclusion list holds under an adversarial sweep (every excluded term appears
only in §10 prohibitions, §13 not-covered, or the §14 fence — never in an admitting role); the
sparse-binary scope is genuinely independent of Design 85 rather than its extension; **§14's
deletion test passes** (zero references to §14 anywhere outside itself, and §13.2 already carries
the structured-prior boundary on its own terms); no 0.6 leak (the only reference to this document
anywhere in the repo is its own dev-log entry); and the write fence holds at exactly two paths.

**BLOCK 1 — Gate 3's tolerances were a Design 85 receipt relabelled.** The `0.05` / `0.10` / `0.25`
values were carried over and called a "fresh predeclaration" with **no commitment to re-derive**,
unlike §7.6's adjacent treatment of the optimiser gate — and Gate 3's own NO-GO list never named
tolerance exceedance as a failure trigger at all. *Fixed:* re-derivation is now binding before
Gate 3 is scored, the values are labelled placeholders until then, tolerance exceedance is added to
the NO-GO list, and it is elevated to a **third precondition** in the Approval section.

**BLOCK 2 — the contract claimed CONFIRMED where the lane's own tracker said PENDING.** §7.8 and
§1.4 report completed work while the slice table above still marked S2/S3 as `PENDING`. The
reviewer could not verify the external evidence from inside the worktree and correctly refused to
assume. *Fixed:* the slice table now records S2/S3/S4 as DONE with their findings.

**BLOCK 3 — a factual error in the document's first paragraph, inherited from Amendment 3 itself.**
The contract asserted that `LOOP/decision-queue.md` records Design 86 as `NOT YET OPEN`. It does
not: that row reads **`CUT 2026-07-21`**. Amendment 3 (`LOOP/GOAL.md:245`) makes the same incorrect
claim about the repo's own ledger, and this document propagated it. *Fixed:* the discrepancy is now
reported in place rather than repeated, noting that both readings agree Design 86 is not approved,
so nothing turns on it. **Correcting the ledger row is outside this lane's fence and remains a
maintainer action.**

### Lens 2: FALSIFIABILITY — **NOT-DONE** (7 blocking items)

> **PANEL OUTCOME: ≥2 NOT-DONE. THE COMPLETION CLAIM IS WITHHELD.** The Design 86 draft is **not**
> complete and **not** approvable in its current form. Items below are brought to the maintainer,
> not patched around.

**The lead finding, and it is fatal to Gate 4 as written: the CUT cannot fire.**

Gate 4 admits EVA if **some contiguous region** of the ladder has coverage ≥ 0.900 AND beats
Laplace by ≥ 0.02. No minimum region length is specified, so **one rung suffices**. Applying
Korhonen's already-published Fig. 3 numbers:

| n | Laplace | EVA | margin | ≥ 0.900? | margin ≥ 0.02? |
|---|---|---|---|---|---|
| 50 | 0.81 | 0.968 | **+0.158** | yes | **yes** |
| 120 | 0.91 | 0.940 | **+0.030** | yes | **yes** |
| 190 | 0.925 | 0.925 | 0.000 | yes | no |
| 260 | 0.94 | 0.910 | −0.030 | yes | no |

The ladder's lowest rung, `n = 100`, sits essentially on Korhonen's `n = 120` anchor, where **both
criteria are already satisfied by 3.0 percentage points** — before a single new simulation runs.
Since any single qualifying region admits, EVA is admitted **regardless of what happens at
`n = 600` or `n = 1200`** — the exact regime §1.3 says the contract exists to probe.

**This is the mirror image of the flaw Fisher's S6 review fixed.** Fisher removed a rule that bit
only at the largest `n`, where EVA loses; the replacement can be satisfied only at the smallest `n`,
where EVA's win is already in print. Both versions are decided in advance — in opposite directions.

**Other blocking items, most severe first:**

2. **The "second ladder" in `T` or `z` has no content whatsoever** — no grid, no replicate count,
   no floor, no margin, no pass/fail rule. Yet the contract itself argues that because `H_i` does
   not depend on `n`, the `n`-ladder alone can only confirm a foregone conclusion, making the second
   ladder *the* test of the real question. The load-bearing test is entirely unquantified.
3. **`R = 200` cannot measure a `0.02` margin.** MCSE near `p = 0.90` at `R = 200` is
   `√(0.9·0.1/200) = 0.0212` — **larger than the threshold itself**. The two-arm difference SE is
   ≈ `0.0271`. Three of four rungs, including the `n = 260` Korhonen replication anchor, are
   underpowered for the quantity they gate; the anchor runs ~2.9× coarser than Korhonen's own
   `R = 1000`, and "approximately reproduce 0.910" has no stated numerical tolerance.
4. **Gate 2's "recovery failure" has no number at all** — a regression from Design 85's analogous
   gate, which specified `0.05` absolute and a 5% axis-collapse rate.
5. **The "no shared runner / denominator / output directory" cure has no NO-GO trigger and no
   verification mechanism** — unlike the parameter-file checksum sitting beside it. It is therefore
   enforced exactly as Design 85's failed separation was: prose stating an intention. This is the
   reform aimed at Design 85's *actual* cause of failure.
6. **An arithmetic error in the floor's two-sided defence.** Nominal error is `0.05`. Coverage
   `0.900` → error `0.10` = **doubled**; coverage `0.85` → error `0.15` = **tripled**. §11 calls
   `0.900` "the error rate doubles line" *and* says `0.85` "licenses a doubled error rate" in the
   same paragraph. Both cannot be right; the `0.85` label is wrong.
7. **`β` and `Σ_B` are called co-equal in §9.3 but the boxed rule in §11 does not require both to
   satisfy the joint condition in the same region** — leaving room for a `β`-favourable,
   `Σ_B`-unfavourable result to be reported as a clean GO, which §9.3 itself warns against.

**What the lens credited, having verified it independently:** the §2.4 sparsity/information table is
arithmetically correct throughout (0.36×, 0.19×, 0.078×, and the 5.3× headline); the `q >= 4`
retirement is well-evidenced; the all-attempts denominator rule is a real fix correctly targeted;
and the `R = 1000` MCSE arithmetic (3.5 SE separation, `R ≈ 3300` to resolve 0.91 from 0.90) checks
out exactly.

### Lens 3: CLAIMS (ceiling) — **NOT-DONE** (5 blocking, 6 further)

**PANEL RESULT: 3 of 3 NOT-DONE, unanimous. The completion claim is WITHHELD.**

**The bound property is now DERIVED, and §5.3 was right and understated.** The reviewer did not
merely check the reasoning — it produced the result. Writing `ℓ(u) = log f(y_i|u)`, the EVA
substitution is *exactly*

```
ell_EVA = L_exact − E_q[R],   R(u) = ℓ(u) − [ℓ(a) + g'(u−a) + ½(u−a)'H(u−a)]
```

so `ell_EVA <= log p(y)` holds only if `E_q[R] >= 0`. Concavity is **not** sufficient: pointwise
`R >= 0` would need `p(1−p)|_η <= p(1−p)|_{η_a}` for all `η`, true only at `p = 1/2`. Under a
symmetric `q` the third-order term vanishes and the leading contribution is fourth order:

```
s''''(η) = p(1−p)(1 − 6p + 6p²),   roots at p ≈ 0.2113 and 0.7887
E_q[R] ≈ −(1/8) Σ_t s''''(η_t) v_t²
```

- **Balanced** (`0.211 < p < 0.789`): `s'''' < 0` ⇒ `E_q[R] > 0` ⇒ the bound **holds**.
- **Sparse** (`p < 0.211`): `s'''' > 0` ⇒ `E_q[R] < 0` ⇒ **`ell_EVA > L_exact`** — the objective
  **overshoots the exact ELBO, precisely in the `z ∈ [0.90, 0.97]` regime this contract targets.**

And the optimiser maximises the surrogate, so it is *actively rewarded* for configurations where
the overshoot is large. Declining the bound property was correct; the contract was too generous to
Korhonen's prose. **This is a Gate-1 deliverable now largely discharged in advance.**

**BLOCKING 1 — §5.1 and §5.2 are on different additive scales by `+N·q/2`, and Gate 3 differences
them.** The exact `−KL(N(a,A)‖N(0,I))` is `0.5[log det A − a'a − tr A **+ q**]`. §5.2's `L_H` KL
term carries the `q`; §5.1's `ell_EVA` KL term **omits it** (following Korhonen, who drops
parameter-independent constants — harmless within EVA alone, fatal when differencing against
`L_H`). At `n = 1200`, `q = 2` the spurious offset in the reported `L_H − ell_EVA` diagnostic is
**+1200 nats**, which would read as "`ell_EVA` sits below the GH ELBO" — the bound property
re-entering through a units error, in the one quantity §5.3 took trouble to neutralise. **Gate 1's
own NO-GO names "omitted constants", so the contract's stated objective fails the contract's own
Gate 1.**

**BLOCKING 2 — §10 drops Design 85 §10's cross-method-objective prohibition** (85:329-330). §10
forbids signed statements about `ell_EVA` versus the *marginal log-likelihood*, but nothing forbids
"`ell_EVA` is higher than the Laplace objective, therefore better fit" — while Gate 4 runs a
Laplace arm on byte-identical data at every rung, creating exactly that temptation.

**BLOCKING 3 — Gate 4's headline claim is not tied to a defined interval.** "Two-sided 95 % Wald
interval coverage" never names its covariance estimator, though §7.8's own source reading
establishes that under VA/EVA the **Schur-complement correction** is required and that naive
variational intervals are anti-conservative. The two constructions give materially different
coverage. A coverage number from an unspecified interval does not earn "EVA attains ≥ 0.900".

**BLOCKING 4 — §13 has no item confining a pass to the studied zero fraction**, `T`, or achieved
`I_unit` — the parameters that define the experiment.

**BLOCKING 5 — §1.4's own citations do not meet §1.4's standard:** two quotes introduced as "two
further sources" carry one citation, and Niku et al. 2017 is absent from §12's evidence register.

**Further (non-blocking):** `n` is never defined in §2.1; §9.2 calls the GH reference "an ELBO"
without establishing it in-document; §10's inverse-Hessian prohibition is conditionalised on
evidence Gate 4 itself supplies (self-licensing); Gate 1's NO-GO omits "bound question unresolved";
and §14's "would still stand **complete**" is the file's only self-completeness assertion.

**The reviewer's closing observation, which is the honest verdict on the milestone:** the artifact
is "unusually honest … and on the central question it is mathematically right", but *"complete and
approvable"* **is asserted by the milestone and denied by the artifact** — the parameter-file
checksum does not exist because the file does not exist, and the Korhonen calibration carries a
live dependency that may require §11 to be re-authored.

---

## PANEL CONSOLIDATION

| Lens | Model | Verdict |
|---|---|---|
| Scope | Sonnet / high | **NOT-DONE** (3 blocking — all fixed) |
| Falsifiability | Sonnet / high | **NOT-DONE** (7 blocking — brought, not patched) |
| Claims (ceiling) | Opus / high | **NOT-DONE** (5 blocking + 6 — brought, not patched) |

**3/3 NOT-DONE. The completion claim is WITHHELD.** Design 86 is a **draft with known defects**, not
a complete or approvable contract. The two structural defects a successor must fix before anything
else are: **Gate 4's admission rule can be satisfied at `n = 100` from already-published numbers**
(falsifiability lens), and **the `+N·q/2` scale mismatch between the two objectives** (claims lens).
