# EVA / VA programme — authoritative record

**Date of record:** 2026-07-25
**Scope:** every gllvmTMB design lane that touched variational estimation (EVA, VA, Jaakkola–Jordan,
exact-reference work) — Designs 72, 85, 86, 87, 89–103.
**Status vocabulary:** **DECIDED** = a maintainer or a signed contract says so in a file.
**PROPOSED** = written in a design/plan but not approved. **UNKNOWN** = the corpus does not answer it.

Every factual claim below carries a `branch:path` citation. Where two files disagree, both are quoted
and the disagreement is named, not smoothed.

---

## 1. Bottom line

**Nothing about EVA (or VA, or the Jaakkola–Jordan bound) is admitted into gllvmTMB.** No package
source, public API, NAMESPACE, NEWS, roxygen, or validation-register row has ever changed as a result
of any lane in this record; `src/gllvmTMB.cpp` is byte-unchanged against `origin/main` throughout
(e.g. `origin/codex/design95-free-jj-variational-20260723:docs/dev-log/after-task/2026-07-23-design95-free-jj-prototype.md`
empty-diff guard). **DECIDED:** EVA is cut from the 0.6 release, which ships Laplace-only
(`origin/main:LOOP/GOAL.md`, Maintainer Amendment 1, 2026-07-21); a *design-only* 0.7 EVA lane was
authorised the next day (`origin/main:LOOP/GOAL.md`, Maintainer Amendment 3, 2026-07-22), covering
**Gates 0–3 only** (`origin/codex/design86-arc2r-20260723:docs/design/86-eva-sparse-binary-admission-contract.md`,
Status header: "APPROVED by the maintainer, 2026-07-22 (chat)").

**Where the gate sequence actually stopped: at Gate 2.** The Design-86 correctness anchor failed its
own frozen health threshold twice — once historically (seed 86200001, four starts, final
max|gradient| 0.159 / 0.027 / 0.365 / 8.43 against a 1e-4 threshold) and once on a signed re-admission
re-run (seed 86200002: 0.0337 / 0.1038 / 0.0722 / 0.1050) — and the lane was then formally retired at
verdict `HISTORICAL_MECHANISM_UNOBSERVABLE`, committed by the maintainer as `f805bd5a`
"docs(86): retire historical admission path" (2026-07-23). **Gate 3 was never scored; Gate 4 compute
authorisation was never granted.** Everything numbered 90–103 is a *different* privately-scoped
successor investigation — upstream-`gllvm` health atlases, VA/JJ prototypes, recovery envelopes, exact-
reference work — and the deepest of those (Design 102, the only lane that ran a full DRAC campaign)
returned a **negative** result: rotation-invariant loading-covariance relative error stayed at roughly
0.67–3.36 at N=240
(`origin/codex/design102-recovery-envelope-20260724:docs/dev-log/after-task/2026-07-24-design102-recovery-envelope.md`).

A reader who stops here should conclude: **the variational programme has produced correct algebra, a
working prototype, and a body of honest negative results — and no admissible estimator.**

---

## 2. Decision timeline

| Date | Event | Authority / file |
|---|---|---|
| 2026-06-03 | **PARKED.** Design 72 VA feasibility audit closes; Phase 1 funded and run, Phases 2–3 explicitly not funded. | `origin/main:docs/design/72-variational-approximation-feasibility.md` ("Decision (maintainer, 2026-06-03): PARKED.") |
| 2026-07-20 | **NO-GO.** Design 85 (full-covariance Gauss–Hermite VA, multi-trial binomial-logit) closed; Gates 0–2 supported a prototype, Gate 3 not established, Gates 4–5 never admitted. | `origin/main:docs/design/85-highdim-nongaussian-va-formal-contract.md` |
| 2026-07-21 | **Maintainer Amendment 1 — EVA CUT from 0.6.** 0.6 ships Laplace-only. Ledger row written the same day: `CUT 2026-07-21`. | `origin/main:LOOP/GOAL.md`; `origin/main:LOOP/decision-queue.md` (commit `25c76789`) |
| 2026-07-22 | **Maintainer Amendment 3 — reversal (partial).** A *design-only* 0.7 EVA lane reopens on a disjoint write scope (`docs/design/86-*.md`): "Design 86 design work starts NOW … in parallel." Does not touch 0.6. | `origin/main:LOOP/GOAL.md`, Amendment 3 (commit `142ff39f`) |
| 2026-07-22 | **Design 86 contract APPROVED, Gates 0–3 only.** Gate-4 compute is "a separate, later maintainer approval … nothing here authorises it". Gate 1 passes (23/23 tests). | `origin/codex/design86-arc2r-20260723:docs/design/86-eva-sparse-binary-admission-contract.md`; `origin/codex/design86-arc1-20260722:docs/dev-log/after-task/2026-07-22-design86-arc1-gate0-gate1.md` |
| 2026-07-23 | **Gate 2 RED (second time).** Gate-2R V1 re-run (seed 86200002), maintainer-signed, fails the same frozen 1e-4 gradient-health threshold. Arcs 5–7 diagnostics each return PARK. | `origin/codex/design86-arc2r-20260723:docs/design/86-gate2r-v1-amendment.md` and the arc5/arc6/arc7 handovers |
| 2026-07-23 | **Design 86 admission path RETIRED.** Arc 8 terminal verdict `HISTORICAL_MECHANISM_UNOBSERVABLE`; maintainer commits `f805bd5a` "docs(86): retire historical admission path". | `origin/codex/design86-arc2r-20260723:docs/dev-log/forensic/2026-07-23-design86-arc8-historical-observability.md` |
| 2026-07-23 → 07-24 | Successor lanes 89–99 open and close privately (upstream reference, atlases, VA/JJ prototypes, recovery smokes, exact reference). None reopens Design 86. | branches `origin/codex/design89…design99` |
| 2026-07-24 | **Design 102** runs the only completed at-scale campaign (DRAC, 2,304 attempts) and returns a negative covariance-recovery result. **Design 103** diagnoses it and closes `TECHNICAL_PARTIAL`. | `origin/codex/design102-recovery-envelope-20260724:…`; `origin/codex/design103-covariance-mechanism-20260724:dev/design103-covariance-mechanism/ADJUDICATION.md` |
| 2026-07-25 | Active-lane-split handover written; it does **not** list the EVA/Design-86 lane. | `origin/main:docs/dev-log/handover/2026-07-25-active-lane-split.md` |

**Net of the reversals:** Amendment 1 (cut from 0.6) has never been rescinded. Amendment 3 did not
un-cut 0.6; it opened a parallel 0.7 *design* lane. That lane then failed at Gate 2 and was retired.
So the current state is: EVA is out of 0.6 **and** the reopened 0.7 admission path is itself closed.

---

## 3. The gate structure

Two distinct gate ladders exist. They are **not** the same ladder and must not be conflated.

### 3a. Design 85 ladder (multi-trial binomial-logit, full-covariance Gaussian VA) — CLOSED NO-GO

Source: `origin/main:docs/design/85-highdim-nongaussian-va-formal-contract.md`. Gates are
**sequential and non-compensating**, with the explicit rule that "tolerances cannot be widened after
seeing the result."

| Gate | Requires | Status |
|---|---|---|
| 0 | Scope / coordinate freeze | done |
| 1 | Algebra + autodiff: scalar Gauss–Hermite to 1e-10; Gaussian anchor exact to 1e-8 | done |
| 2 | Low-dim O3 references (q=1,2); ELBO must not exceed the O3 marginal log-lik by >1e-6 | done |
| 3 | Joint-fit known-DGP recovery at fixed q=1/2; Σ_B RMSE within 0.05 of ML; ≤5% axis collapse | **FAILED — never validly run** |
| 4 | ML rank hand-off; BIC rule frozen pre-hoc; VA never re-selects rank | not admitted |
| 5 | q=4/6 stress; ≥50 seeds/rank; ≥90% optimizer-gate pass; practical advantage over Laplace | not admitted |
| 6 | Claim audit — no public/API/NEWS/register claim follows from Gates 0–5 without a separate maintainer decision | n/a |

The Gate-3 failure is structural, not marginal: the pilot runner **conflated the fixed-rank Gate-3
comparison with the ML-selected-rank Gate-4 hand-off**, so the stored recovery summaries are not the
predeclared experiment. Contract text: "Because the gates are sequential, this is a NO-GO before
q4/q6. Conditional recovery and prediction summaries cannot compensate for the missing fixed-rank gate
or the optimiser failures."

### 3b. Design 86 ladder (sparse binary EVA admission) — APPROVED 0–3, STOPPED AT 2, RETIRED

Source: `origin/codex/design86-arc2r-20260723:docs/design/86-eva-sparse-binary-admission-contract.md`, §11.

| Gate | Requires | Approved? | Done? | Blocked on |
|---|---|---|---|---|
| 0 | Scope/coordinate freeze; frozen parameter file + checksum; byte-identity of data across arms; non-shared runners between Gate 2 and Gate 4 | yes (2026-07-22) | **PASS** | — |
| 1 | Gaussian identity to 1e-10; Bernoulli-logit objective/KL/gradient to 1e-5/1e-10; §5.3 bound-property derivation reproduced or refuted; q=1 AGHQ probe as a **measurement, not a test** | yes | **PASS** (23/23) | — |
| 2 | Information-rich correctness anchor: β rel. bias <0.05, Σ_B diagonal rel. bias <0.10, 95% Wald coverage in [0.93, 0.97], R=500. Explicitly **not** sparse and **not** satisfied by the parked Design-72 prototype | yes | **FAIL ×2** (smoke never cleared the 1e-4 gradient-health predicate) | mechanism unknown — Arc 8 `HISTORICAL_MECHANISM_UNOBSERVABLE` |
| 3 | EVA-vs-AGHQ reference at fixed coordinates. Inherited Design-85 tolerances (0.05 RMSE; 0.10 median / 0.25 max relative Frobenius) are flagged **PLACEHOLDERS** requiring re-derivation for the sparse regime | yes (scope), but tolerances **not** yet re-derived | **never reached** | Gate 2 |
| 4 | Paired n-ladder (100/260/600/1200, R=1000) **and** a second ladder in T and z; requires **both** ≥0.900 coverage at n=1200 **and** a ≥0.02 paired-coverage margin over Laplace at some rung, for both β and Σ_B, via a named Schur-complement covariance estimator; requires Totoro/DRAC | **NO — compute authorisation explicitly never granted** | no | separate maintainer approval |
| 5 | Claim audit — no public API/NEWS/register promotion follows from Gates 0–4 without a further separate decision | n/a | n/a | — |

**Standing hazard flagged, not fixed (Design 85 §, carried into 86):** Design 04 describes positive
exponentiated loading diagonals, but the live TMB code copies `lam_diag(j)` without `exp()`. The
contract requires prototypes to use the **raw unconstrained live-engine coordinate**, and states that
"Any claim that the live engine already has positive loading diagonals is also a NO-GO until the source
and design prose are reconciled." **UNKNOWN:** whether this discrepancy has since been resolved.

---

## 4. Lane-by-lane table

| Design | Purpose (one line) | Outcome | What it explicitly does NOT claim | Primary evidence |
|---|---|---|---|---|
| **72** | Feasibility audit: would `method = c("LA","VA")` stabilise non-Gaussian augmented-slope cells that honest-skip? | **CLOSED_POSITIVE** (informative; PARKED 2026-06-03) | Does not authorise a shipped VA engine; "Do NOT advertise VA anywhere … until a register row carries VA-vs-LA recovery evidence"; a structured variational covariance is **not** motivated by the collapse finding | `origin/main:docs/design/72-variational-approximation-feasibility.md` |
| **85** | Full-covariance Gaussian VA, complete multi-trial binomial-logit, `latent(unique=FALSE)`, beyond the q≥3 AGHQ reach | **NO_GO** (2026-07-20) | No phylo/animal/spatial/kernel/slope/mixed-family/missing-data admitted; VA does not select rank; not AGHQ, not Cox–Reid, not REML; must not weaken the Gaussian-only REML boundary (Design 43) | `origin/main:docs/design/85-highdim-nongaussian-va-formal-contract.md` |
| **86** | Sparse-binary EVA scientific-admission contract, Gates 0–5 | **TECHNICAL_INCOMPLETE** → retired `HISTORICAL_MECHANISM_UNOBSERVABLE` | No engine/API/NEWS/doc change; Gate-4 compute never authorised; Gate-3 tolerances are placeholders; Arc 8's verdict is **not** a claim that no mechanism exists | `origin/codex/design86-arc2r-20260723:docs/design/86-eva-sparse-binary-admission-contract.md`; commit `f805bd5a` |
| **87** | Branch `origin/codex/design87-eva-parity-admission-20260723` | **UNKNOWN — no distinct design exists** | No document anywhere claims a separate "Design 87" contract, gate, or outcome | branch points at the *identical* commit `f805bd5a` as `design86-arc2r`; the two branch diffs are empty |
| **89** | Does one unmodified upstream CRAN-`gllvm` EVA regression fixture (corWithinLV, kelpforest) run healthily locally? | **CLOSED_POSITIVE** — `UPSTREAM_REFERENCE_PASS`, max\|grad\| = 0.00168 vs a 0.05 bound | Establishes **no** gllvmTMB parity; not a matrix-equivalent q=2 target; not Arc 9 of Design 86; authorises no comparator | `origin/codex/design89-upstream-reference-20260723:docs/design/89-upstream-reference-eva.md` |
| **90** | 72-cell health atlas of released `gllvm` EVA, unconstrained q=2, 16 seeds/cell | **NO_GO** — terminal smoke stop; 0/4 attempts healthy; 10-h campaign never launched | Not a diagnosis of EVA in general, not an explanation of 86–89, not evidence about gllvmTMB | `origin/codex/design90-eva-reliability-atlas-20260723:docs/dev-log/after-task/2026-07-23-design90-gate2-smoke-stop.md` |
| **91** | Row-support-conditioned envelope; paired `method="EVA"` vs `method="VA"` on released `gllvm` | **NO_GO** — EVA healthy 2/4, VA healthy 2/4; atlas not launched | Neither arm is a correctness oracle; not a retry, amendment, or rescore of Design 90; no cause established | `origin/codex/design91-eva-va-envelope-20260723:docs/dev-log/after-task/2026-07-23-design91-gate2-smoke-stop.md` |
| **92** | Private mean-field Gaussian VA baseline (q=1, diagonal q=2), fixed globals, intercept-only Bernoulli-logit | **CLOSED_POSITIVE** — all admission checks PASS | Not a continuation/repair of 86–91; uses no `gllvm` result as evidence; the exposed derivative kernel "is not an EVA objective"; passing permits *planning* an EVA design, not implementing one | `origin/codex/design92-va-foundation-20260723:docs/design/92-va-first-foundation.md` |
| **93** | Map the released `gllvm` 2.0.13 Bernoulli-logit EVA observation term to a standalone scalar comparator | **CLOSED_POSITIVE** — source-map evidence, all 3 checks PASS | A **Taylor surrogate**, not the exact Gaussian expectation; a source match is explicitly **not** inference correctness; no full EVA ELBO or q=2 objective exists | `origin/codex/design93-eva-algebra-20260723:docs/design/93-eva-scalar-algebra.md` |
| **94** | Jaakkola–Jordan (Pólya-Gamma) quadratic logistic **bound** as a TMB prototype, fixed intercepts/loadings, q=2 | **CLOSED_POSITIVE** — deterministic contract passes | "not admission of EVA, VA, or a new estimator"; not EVA, EVA-plus, or upstream parity; no DGP, recovery test, campaign, or package compile run | `origin/codex/design94-jj-va-prototype-20260723:docs/design/94-jj-variational-prototype.md` |
| **95** | Free intercepts + identified loadings under the JJ bound (5-gate arc G0–G4) | **TECHNICAL_PARTIAL** | Establishes no recovery, calibration, robustness, identifiability off-convention, parity, or integration; the lower-triangular chart is a prototype device, not a package parameterisation | `origin/codex/design95-free-jj-variational-20260723:docs/design/95-free-jj-variational-arc.md` |
| **96** | JJ q=2 recovery smoke: does the Design-95 fit produce nontrivial rotation-invariant signal? | **NO_GO** — `SMOKE_STOP`; 5/6 attempts exceed the 1e-4 gradient limit; both fixtures `HEALTH_FAIL` | Does not establish that every JJ fit is bad; does not justify changing thresholds, adding starts, or rerunning; not an EVA/VA revival | `origin/codex/design96-jj-recovery-smoke-20260724:docs/design/96-jj-recovery-smoke.md` |
| **97** | Full-covariance JJ vs a 2D Gauss–Hermite marginal comparator (G0–G4) | **NO_GO** — `SMOKE_STOP / RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD` | The small fixed-global gap improvement (0.001003197932) "cannot be promoted because the free-global discriminator was not recorded"; establishes no recovery, bias, or parity | `origin/codex/design97-fullcov-jj-20260724:docs/design/97-fullcov-jj-discrimination.md` |
| **98** | 2×2 factorial mechanism discriminator (direct-ELBO vs JJ bound × diagonal vs full geometry) | **TECHNICAL_INCOMPLETE** | No mechanism label authorised; the one descriptive QD/QF/JD record "must not be generalized or attributed"; no package surface changed | `origin/codex/design98-factorial-va-jj-20260724:docs/design/98-factorial-va-jj-discriminator.md` |
| **99** | Certified exact q=2 marginal reference via pattern-compressed adaptive Gauss–Hermite | **INFRASTRUCTURE_STOP** (`INFRASTRUCTURE_INCOMPLETE`) | "the numerical reference was never tested to the contract's admission standard"; the positive label `BOUNDED_ORACLE_PASS` exists only prospectively and was never reached | `origin/codex/design99-exact-reference-20260724:docs/design/99-exact-q2-reference-stabilization.md` |
| **100 (B/C/D)** | Progress-aware oracle plumbing + four fixed-coordinate direct-2D pattern-probability calculations | **TECHNICAL_INCOMPLETE** — 100-B terminal `INFRASTRUCTURE_INCOMPLETE` (crash at `worker_input_validation`, `UNHANDLED_ERROR`) | All three manifests set `run_class = NON_EVIDENCE`; even a completed run would not be evidence; not a fixture, UUID, numerical run, or estimate | `origin/codex/design100-progress-oracle-20260724:dev/design100-progress-oracle/…` |
| **101** | Single-fixture q=2 QD/QF/JD/JF comparator (n=24, 12 attempts) scored on a shared GH61 marginal | **CLOSED_POSITIVE** — `complete_with_healthy_endpoints`, 12/12 healthy | EVA deliberately excluded ("lacks a frozen comparable objective"); the best endpoint (QF-B, −87.586408722982) is "a bounded descriptive observation only, not a method ranking or recovery result" | `origin/codex/design100-progress-oracle-20260724:docs/dev-log/after-task/2026-07-24-design101-va-jj-comparator.md` |
| **102** | Replicated recovery envelope: 32 seeds × N∈{24,80,240} × 2 regimes = 192 cells, 2,304 attempts, on DRAC | **NO_GO** — health gate passed 2304/2304; **covariance recovery failed** (rel. error ≈0.67–3.36 at N=240) | Not an estimator ranking, general reliability result, package capability claim, or EVA result; no package file changed | `origin/codex/design102-recovery-envelope-20260724:docs/dev-log/after-task/2026-07-24-design102-recovery-envelope.md` |
| **103** | Mechanism diagnosis of 102's covariance failure (selection / approximation / information / chart-scale) | **TECHNICAL_PARTIAL** — only *selection* adjudicated (ruled out at 2 coordinates); the other three "not adjudicable" | "establishes an execution fact, not a package fact"; must not be relabelled as support for an approximation, information, chart/scale, or EVA claim | `origin/codex/design103-covariance-mechanism-20260724:dev/design103-covariance-mechanism/ADJUDICATION.md` |

**Lane disagreement worth naming.** Design 91 found released `gllvm` **VA** healthy in 2/4 cells and
**EVA** healthy in 2/4 — with the two arms failing on *different* cells. Design 89, on an unmodified
upstream fixture, found EVA clean (max|grad| 0.00168). These are not contradictory (different
estimands, different conditioning), but neither is a reliability statement, and Design 91 says
explicitly that a healthy VA receipt does not rescue an unhealthy EVA receipt or vice versa.

---

## 5. What the negative results actually said

### Design 85 — the NO-GO triggers (predeclared, not retrofitted)

Quoted from `origin/main:docs/design/85-highdim-nongaussian-va-formal-contract.md`:

- **Gate 0:** implicit Ψ or a changed loading transform.
- **Gate 1:** clipping needed for finiteness, or a wrong KL sign.
- **Gate 2:** bound violation beyond tolerance, or a one-start-dependent conclusion.
- **Gate 3:** success declared from convergence rate alone; failed fits excluded; bands widened post hoc.
- **Gate 4:** rank chosen by ELBO; an unhealthy ML candidate overridden by VA convergence.
- **Gate 5:** tensor quadrature over ℝ^q; superlinear-in-N storage; silent non-finite retries;
  stress-only convergence presented as inferential validation.

Measured outcome (§13): 25 planted-q1 + 25 planted-q2 seeds at commit `0e9b3b56`; 22/24 applicable q1
fits converged (plus one rank-zero stop), 19/25 q2 fits converged — **8 applicable fits failed the
optimizer gate outright**. The single apparent q2 "axis collapse" was a q3 fit scored against q2 truth
and is "not an admissible fixed-rank collapse event."

**Grid discipline:** the H=15/25/61 Gauss–Hermite node ladder is required and immutable, on a frozen
μ×v grid; failure is a NO-GO and "the grid is not narrowed after a result is seen." The variance domain
fails closed above projected variance 4, and "widening that domain requires a new scalar oracle receipt
before the fit can enter evidence."

### The ELBO-vs-marginal-likelihood caution (Design 85 §10, "Prohibited interpretations")

This is the single most important standing rule in the whole record, and it prohibits:

- calling the objective a marginal / exact / restricted likelihood, REML, AI-REML, Cox–Reid, or AGHQ;
- computing or exposing `logLik`, `AIC`, `BIC`, LRT, or model weights **from the ELBO**;
- selecting rank q by maximised ELBO, or comparing ELBO across ranks as if the approximation gap were equal;
- describing a smaller negative ELBO as a better marginal fit than a Laplace/AGHQ objective;
- treating the inverse VA Hessian as calibrated frequentist uncertainty.

Design 72 states the same statistical caveats independently: the ELBO is a lower bound, not the
marginal likelihood (so AIC/LRT/`logLik` are not comparable across LA vs VA); VA variance components
are known to be biased **downward**; VA Hessian-based SEs are **anti-conservative** absent a correction.

### Design 72 — the falsifying consequence

Phase 1 (branch `claude/va-phase1-proof`, PR #431, never merged) showed VA converged on every cell
*including* every cell where the Laplace inner Hessian went non-PD — but the cells where VA's variance
components collapsed are **exactly** the degenerate cells (n=12–24, 4–6 groups). Hence the memo's own
falsifying line: *a richer / structured variational covariance to cure the collapse is not motivated —
the collapse is a property of the likelihood, not of the diagonal q.* Where the model is identifiable
(n≥30) VA matches Laplace to ~2 significant figures. The genuine "structured VA over the exact sparse
phylo A⁻¹ / SPDE Q priors" thesis was **never tested** and remains unfunded.

### Every later lane that closed partial or incomplete, in its own words

- **86 (Arc 8):** `HISTORICAL_MECHANISM_UNOBSERVABLE` — the two smoke records lack the shared labelled
  numerical state needed to identify or exclude optimizer semantics, coordinate conditioning, AD
  fidelity, geometry, or separation. Explicitly "neither a causal diagnosis nor evidence that no
  mechanism exists." Arc 4's forensic memo declines to diagnose a cause and offers three maintainer
  options without choosing. Arcs 5–7 each return PARK: "a bounded controlled result, not a causal
  account of the historical q=2 failures."
- **95:** the one deterministic stability probe produced a covariance distance of **1.236890** from the
  known loading covariance — "sizeable", with "no acceptance threshold", retained specifically to stop
  the result being called recovery or calibration.
- **96:** `SMOKE_STOP`. All six attempts returned optimizer code zero; only strong/A met the <1e-4
  gradient bar (9.588e-05); the rest ran 1.214e-04 – 2.717e-04. All moderate-fixture attempts had
  first-eigenvalue relative error ≈1.8425 against a 0.75 threshold. "the point estimates were closely
  similar across starts" — noted, and explicitly not sufficient.
- **97:** `RUNNER_INTERRUPTED_BEFORE_GATE3_RECORD`. Fixed-global GH gaps: diagonal 0.427110200998 vs
  full-covariance 0.426107003066 (improvement 0.001003197932) — "only the predeclared approximation
  comparison". "The exact cause of the interruption is not established from retained output."
- **98:** `TECHNICAL_INCOMPLETE`. Gate-1 mechanics clean (objective error ≤1.78e-15, relative gradient
  error ≤2.66e-9), but low/high GH references, fixed-global contrasts, and JF were unavailable, so
  **no mechanism label is authorised**. JF's point estimates "looked accurate but every start missed
  its gradient gate."
- **99:** `INFRASTRUCTURE_INCOMPLETE`. A locale-sensitive curly-quote bug killed the first strict
  launch; the retry ran silently for the full 2,700-second cutoff with no pattern-level progress. The
  100 Gate-1 and 24 Gate-3 passing expectations are labelled **NON_EVIDENCE**.
- **100-B:** crashed at `worker_input_validation`, `UNHANDLED_ERROR`, message "theta must be finite
  beta[6] and lambda[6, 2]"; `numerical_evaluation_started = FALSE`. 100-D's own text characterises
  **both** B and C as infrastructure failures.
- **102:** health gate 2304/2304 clean; β and probability error decline with N; **loading-covariance
  relative error stays ≈0.67–3.36 at N=240.** "The originally frozen covariance-recovery threshold is
  therefore not met."
- **103:** GH101 refits OOM'd at 3 GB and 8 GB and timed out at 16 GB (11.75 GB max RSS). The bounded
  GH61 substitute was itself pathological — relative covariance error **3611** in the pilot, and
  1.9e7 / 3.58e8 / 9.39e6 in the early-stopped array (one with optimizer code 0, which was explicitly
  **not** accepted as a health certificate). Only *selection* was adjudicated, and only at two fixed
  coordinates: native-vs-GH101 start-selection gaps all below 8e-05.

**The pattern across 96–103, stated plainly:** the JJ/VA objectives repeatedly reach optimizer code 0
without reaching gradient health, and where they do reach health (102), the loading covariance does not
recover. Whether that is an optimisation problem, an approximation problem, an information problem, or
a parameterisation problem is **UNKNOWN** — Design 103 was built to answer exactly that and could not.

---

## 6. Governance contradictions — the actionable section

Four were found. Three are stale-file defects with a concrete fix; the fourth is a shared gap.

### C1 — `LOOP/decision-queue.md` still records Design 86 as CUT and "never approved"

- **Stale file:** `origin/main:LOOP/decision-queue.md` (last touched by commit `25c76789`, 2026-07-21;
  verified byte-identical on `origin/main`, `origin/codex/design87-eva-parity-admission-20260723`, and
  `origin/codex/design89-upstream-reference-20260723`).
- **What it says:** State = `CUT 2026-07-21`; Recommendation = "Superseded by the maintainer's EVA cut.
  Never written or approved — do not cite as a contract."
- **What is current:** `origin/main:LOOP/GOAL.md` Amendment 3 (2026-07-22) reopened the design lane, and
  `origin/codex/design86-arc2r-20260723:docs/design/86-eva-sparse-binary-admission-contract.md` carries
  "APPROVED by the maintainer, 2026-07-22 (chat)". The contract itself flags the discrepancy in a boxed
  "Ledger discrepancy, reported rather than resolved" note.
- **Exact edit:** replace the Design 86 row's State with
  `CUT from 0.6 (Amendment 1, 2026-07-21); 0.7 design lane APPROVED Gates 0–3 (Amendment 3, 2026-07-22); admission path RETIRED 2026-07-23 (commit f805bd5a, Arc 8 HISTORICAL_MECHANISM_UNOBSERVABLE)`
  and replace the Recommendation with `Do not cite as an admitted capability. Gate 4 compute was never
  authorised. Any resumption requires a new, separately approved design.`

### C2 — Amendment 3 misquotes the ledger it points at

- **Stale file:** `origin/main:LOOP/GOAL.md`, Maintainer Amendment 3 (commit `142ff39f`).
- **What it says:** "LOOP/decision-queue.md records it NOT YET OPEN."
- **What is true:** the queue's Design 86 row literally reads `CUT 2026-07-21`. The exact string
  "NOT YET OPEN" appears in that file only in the unrelated "Release ceremony" row. The Design 86
  contract already corrects this: "Amendment 3 states that LOOP/decision-queue.md 'records it NOT YET
  OPEN.' It does not."
- **Exact edit:** append a dated errata line under Amendment 3 —
  `Errata 2026-07-25: the decision-queue row read "CUT 2026-07-21", not "NOT YET OPEN". The
  substantive intent (this amendment is not itself the approval) stands.` Do not rewrite the
  amendment body; maintainer amendments are historical record.

### C3 — the 2026-07-25 active-lane-split handover omits the EVA lane

- **File:** `origin/main:docs/dev-log/handover/2026-07-25-active-lane-split.md`.
- **What it does:** lists five lanes (0.6 release/M5, Profile/Tier-2a, Eta simulation at
  `design100-progress-oracle`, Design-103 private diagnosis, docs-infra/phylo-column) plus one
  unopened lane. It never names EVA, Design 86, or the design86/87/89–99 branches.
- **Not strictly a contradiction:** the note disclaims itself — "Milestone state is NOT in this note and
  must be re-derived from git" — and is an ownership map, not a progress ledger. But the net effect is
  that **no single file gives a composite EVA status**; reconstructing it requires reading Amendment 3,
  the contract's self-correction, and the unmerged branch tree together.
- **Exact edit:** add one row — `EVA / variational (Designs 86–103) — Codex-owned, remote-only branches,
  NOT merged. Design 86 admission path retired 2026-07-23 (f805bd5a). Successor lanes 89–103 closed
  private. Nothing admitted. See dev/eva-record/EVA-RECORD.md.`

### C4 — `AGENTS.md` and `CLAUDE.md` are silent on EVA entirely

- **Files:** `origin/main:AGENTS.md`, `origin/main:CLAUDE.md`. Neither mentions EVA in any form (the
  only "eva" substring match in each is inside the word "relevant"). `CLAUDE.md`'s Live Phase Snapshot
  names Design-103, the eta-simulation Codex lane, and the profile lane — but never EVA or Design 86.
- **Why it matters:** these are the two files a new session is told to read first. A session reading
  only them would not learn that an EVA lane exists, was approved through Gate 3, failed at Gate 2, and
  is retired — and would therefore be at risk of re-proposing it.
- **Exact edit:** add to the `CLAUDE.md` Live Phase Snapshot —
  `EVA / variational estimation: NOT in gllvmTMB. Cut from 0.6 (Amendment 1, 2026-07-21); the 0.7
  design lane (Design 86) was approved for Gates 0–3 only and RETIRED 2026-07-23. Designs 90–103 are
  closed private research. No capability, NEWS, or register claim exists or may be made. Read
  dev/eva-record/EVA-RECORD.md before proposing any variational work.`

**Bonus finding (not a contradiction, a naming artefact):** `origin/codex/design87-eva-parity-admission-20260723`
and `origin/codex/design86-arc2r-20260723` point at the **identical commit** `f805bd5a`; the log range
between them and the `docs/design/` diff are both empty. There is no `docs/design/87-*.md` anywhere in
the corpus. **UNKNOWN** whether "Design 87" was a planned-but-unwritten number or merely a descriptive
branch name for the Design-86 arc2r closeout. Do not cite Design 87 as a design.

---

## 7. If EVA resumes: the next three concrete steps

These are **PROPOSED**, not authorised. Every prior lane's terminal record forbids replaying, rescoring,
amending, or extending it; each step below therefore requires a *new* design with its own scope freeze.

**Step 1 — Decide whether the question is still worth asking, and on what evidence.**
The corpus has an unresolved gap that is prior to any implementation: Design 102 showed loading-covariance
recovery failing at N=240 with a perfectly clean numerical-health gate, and Design 103 could not
adjudicate approximation vs information vs chart/scale as the cause. Until that is resolved, a new EVA
Gate 2 would likely reproduce the same failure with the same non-diagnosis.
*Blocking approval:* maintainer decision that a mechanism study is worth commissioning at all.
*Named prerequisite from the corpus:* Design 103 §11 — "a newly approved, symbolically reviewed
alternative parameterization or regularized reference objective with its own pilot and health contract."

**Step 2 — Repair the governance ledger before any technical work.**
Apply the C1–C4 edits in §6. Rationale: the Design-86 lane ran three arcs' worth of work while the
top-level ledger said the contract had "never been written or approved" — the failure mode is that a
future session either re-proposes a retired lane or, worse, cites the stale row as authority to skip a
gate. This step is cheap, has no compute cost, and is the only one in this list that is unambiguously
safe to do now.
*Blocking approval:* maintainer sign-off on the wording (these are governance files, not code).

**Step 3 — Only then, a new Gate-0/Gate-1 scope freeze on a genuinely new estimand.**
If Steps 1–2 clear, the new design must: (a) predeclare a fixed-rank recovery experiment that cannot be
conflated with an ML-selected-rank hand-off (the exact defect that killed Design 85 Gate 3); (b) re-derive
Gate-3 tolerances for its own regime rather than inheriting Design 85's placeholders (the exact gap that
Design 86 never closed); (c) carry the Design-85 §10 prohibited-interpretations list verbatim; and
(d) resolve or explicitly quarantine the `lam_diag` exp()-vs-raw discrepancy between Design 04 prose and
`src/gllvmTMB.cpp`.
*Blocking approval:* a written, maintainer-signed contract — and, separately and later, an explicit
Totoro/DRAC compute authorisation, which has **never** been granted for any EVA gate.

---

## 8. Open questions for the maintainer

Only questions the corpus genuinely cannot answer.

1. **Is "Design 87" a real design number?** The branch `origin/codex/design87-eva-parity-admission-20260723`
   has zero unique commits and no design document. Was 87 reserved for a parity design that was never
   written, or is the branch name simply descriptive of the Design-86 arc3–arc8 closeout? No further
   reading resolves this.

2. **Did Design 100-C or 100-D ever actually run?** Both carry execution contracts and approval
   manifests (`run_class = NON_EVIDENCE`), but no after-task file and no `check-log.md` entry records a
   completed run for either. 100-D's own text calls both B and C infrastructure failures. This should be
   confirmed directly (likely with Codex, which owns that lane) rather than assumed.

3. **Has the `lam_diag` exp()-vs-raw discrepancy been reconciled?** Design 85 flags that Design 04
   describes positive exponentiated loading diagonals while `src/gllvmTMB.cpp` copies `lam_diag(j)`
   without `exp()`, and makes any claim to the contrary a NO-GO until source and prose agree. Nothing in
   this corpus records a resolution.

4. **Should the unfunded Design-72 Phase 2/3 thesis be retired or kept open?** The one genuinely
   differentiating idea in the whole programme — structured VA over gllvmTMB's *exact sparse* phylo A⁻¹
   / SPDE Q precisions, where the Laplace Hessian goes non-PD for structural reasons at adequate n — has
   never been tested by any lane here. Every failure in Designs 90–103 is in the ordinary dense q=2
   regime, which does not bear on it. It is either the programme's remaining live question or should be
   explicitly closed.

5. **Does the EVA lane get an entry in the release-facing record at all?** Nothing here is admissible as
   a capability, so nothing belongs in NEWS or the register. But a future reader will find nineteen
   branches of variational work and no top-level explanation. Should this document be committed to
   `main`, or stay private alongside the lanes it describes?
