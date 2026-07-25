# VA TRAP MAP

**Purpose.** Stop you repeating a documented failure. This is not a history and not a status page.

**Standing fence, read first.** Nothing about a variational engine in this repository is admitted.
There is no VA result, no VA capability, no VA claim, and nothing "close". Every prior lane closed
without a positive recovery result: Design 85 closed `NO-GO`, Design 86 Gate 2 failed its frozen
gate on both smokes it ran, Design 102's frozen covariance-recovery threshold was not met, Design
103 closed `TECHNICAL_PARTIAL`, Design 99 closed `INFRASTRUCTURE_INCOMPLETE`. This document must
not become the place where any of that is quietly upgraded. If you find yourself citing this file
as evidence that VA works, you have misused it.

**Provenance of the quotes.** The quoted lines below were extracted by five independent forensic
readers of the corpus (Design 85 R3, Design 86 Gate 2, Design 102/103, the two-prototype
comparison, the AGHQ oracle lane). Citations are given as `path:line` exactly as those readers
recorded them. I re-verified in this worktree only the citations that live on this branch
(`R/va-r3-proto.R`, `inst/tmb/gllvmTMB_va_r3.cpp` — the `n_trials >= 2` guard, the `1e-4`/`1e-6`
constants, and the health/admission rule; all confirmed). Citations to other branches
(`origin/codex/design86-arc2r-20260723`, `origin/codex/design102-recovery-envelope-20260724`,
`origin/codex/design103-covariance-mechanism-20260724`, `origin/codex/design99-exact-reference-20260724`)
and to `docs/dev-log/**` audits were **not** independently re-opened by me. Line numbers in those
files may have drifted; the quoted text is what to grep for.

**Where two lanes disagree, this document says so** rather than picking the tidier reading. See
Traps 4 and 8, and §5.

---

## 1. The traps

Ordered by how expensive it is to hit them *late* — trap 1 costs you an entire finished campaign,
trap 16 costs you a paragraph.

---

### Trap 1 — A clean health gate is compatible with catastrophic recovery error

**The trap.** You run a multi-start fit, every start returns optimizer code 0 with a tiny gradient,
you conclude the fit is good, and you report recovery. Convergence of the *surrogate* objective
certifies a stationary point of that surrogate — nothing about the distance between the fitted
estimand and truth.

**Evidence it is real.** Design 102 ran 2,304 immutable start attempts (32 seeds × 3 N × 2 loading
regimes × 12 attempts). The gate, `dev/design102-recovery-envelope/R/core.R:14`:

```r
ok<-p2$convergence==0&&is.finite(g)&&g<1e-3&&all(is.finite(p2$par))
```

`PLAN.md:19-21`: *"A selected endpoint is healthy iff its optimizer code is zero, all
coordinates/objective are finite, and max absolute AD gradient is below `1e-3`."*
**2,304/2,304 attempts passed.** And:

> *"The all-attempt health gate passed. Mean beta and probability error decline with N, but the
> rotation-invariant loading covariance relative error remains large at N=240 (roughly 0.67--3.36
> across cells)."*
> — `docs/dev-log/after-task/2026-07-24-design102-recovery-envelope.md:38-40`

> *"The originally frozen covariance-recovery threshold is therefore not met."*
> — same file, line 43

**Detect early.** Before any campaign, on ONE small cell, compute the recovery metric you actually
care about (rotation-invariant `ΣΛ = ΛΛᵀ` Frobenius relative error) alongside the gradient. If the
gradient is ~1e-8 and `sigma_rel` is ~1, you have reproduced Design 102's finding in five minutes
instead of after 2,304 fits.

**Do instead.** Treat the health gate as an *exclusion* criterion only, never as evidence. Predeclare
a separate recovery criterion on the estimand, with an all-attempt denominator, before fitting. See
§4 for the full "beyond convergence" list.

---

### Trap 2 — Running the rank-selection experiment and calling it the fixed-rank experiment

**The trap.** Your runner selects `q` by ML/BIC and then fits VA at the selected rank. That is a
*different* experiment from fitting VA at the *planted* rank. If your contract has a fixed-rank
gate upstream of a rank-selection gate, one runner cannot serve both, and the upstream gate is
simply never run.

**Evidence it is real.** This is the documented cause of the Design 85 `NO-GO`:

> *"The runner selected rank by ML before fitting VA"*
> — `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:39-43`

> *"That is the Gate-4 hand-off design, not the required fixed-rank Gate-3 known-DGP comparison"*
> — same file, line 54

Selection frequencies: planted q1 → ML picked q0/q1/q2 in 1/20/4 datasets; planted q2 → ML picked
q1/q2/q3 in 4/20/1. Only 18 (q1) and 15 (q2) rows were rank-matched and therefore scoreable at all.
The contract is explicit that this cannot be patched afterwards:

> *"These conditional descriptives do not replace the missing all-attempt fixed-rank denominator."*
> — same file, line 53

> *"A later gate cannot compensate for a failed earlier gate"*
> — `docs/design/85-highdim-nongaussian-va-formal-contract.md:356-357`

**Detect early.** Read your runner's control flow and answer one question in writing: *at the moment
the VA fit is constructed, where did `q` come from — the fixture, or a preceding model selection?*
If the answer is "a preceding model selection", you are not running a fixed-rank experiment.

**Do instead.** Build the fixed-rank experiment as a separate executable runner mode, not a prose
label inside one runner. Ada's own recorded lesson: *"sequential gates need separate executable
fixtures, not merely prose labels in one runner"* (`2026-07-20-va-r3-prototype-no-go.md` §11).

---

### Trap 3 — Excluding failed fits from the denominator

**The trap.** You drop unhealthy fits and report recovery over the survivors. This inflates every
number and is an explicit predeclared NO-GO trigger, not a stylistic preference.

**Evidence it is real.** Design 85's Gate 3 names it as a NO-GO trigger directly — *"success is
declared from convergence rate alone, failed fits are excluded from denominators"*
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:422-423`). The Gate-3 admission bar
itself is stated over all attempts:

> *"VA's `Sigma_B` relative Frobenius RMSE is no more than `0.05` worse in absolute terms than ML
> and no planted axis collapses in more than 5%… of otherwise healthy, non-separated replicates"*
> — same file, lines 417-421

Team learning recorded afterwards: *"all-attempt denominators and planted-rank targets must be
decided before fitting. Conditional healthy-fit recovery cannot repair a missing experimental
cell."* — `docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md` §11.

**Detect early.** Write the denominator into the plan file as an integer before you run anything.
After the run, check that `nrow(scored) == n_attempts`. If it doesn't, you owe an explicit,
predeclared exclusion rule — not a post-hoc filter.

**Do instead.** Report all attempts. A failed fit has coverage zero and counts as collapsed; it is
never silently replaced (Design 86's frozen rule, `docs/design/86-gate2-build-brief.md:44`).

---

### Trap 4 — Importing another objective's optimizer thresholds

**The trap.** You reuse `max|grad| < 1e-4` and `agreement < 1e-6` because they are "the project's
constants". They are not constants of the project; they were calibrated on one objective with known
geometry and have no derivation for yours.

**Evidence it is real.** The requirement, stated in the contract itself:

> *"The optimiser gate must be re-derived for `ell_EVA`. Design 85 §7.6's constants (code zero,
> `max |grad| < 1e-4`, agreement of at least three of four deterministic starts within `1e-6`,
> bounded polishing) were calibrated on a bound with known geometry. `ell_EVA` may not be a bound"*
> — `docs/design/86-eva-sparse-binary-admission-contract.md:545-547`

The observed consequence — both Design 86 Gate-2 smokes, zero healthy starts each:

> *"Maximum absolute gradients were 0.1589847, 0.0274503, 0.3654799, and 8.4345128, all above `1e-4`"*
> — `docs/dev-log/after-task/2026-07-22-design86-arc2-gate2-smoke-stop.md:50-51`

> *"All four starts converged by code but failed the frozen gradient threshold: 0.0337028,
> 0.1037681, 0.0722319, and 0.1050105 exceed `1e-4`. There is no accepted winner or interval;
> collapsed = true."*
> — `docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md:84-86`

The same corpus shows the threshold is not a physical constant: `1e-4` for the EVA arm, `1e-2` for
the live-Laplace comparator in the *same frozen JSON*
(`86-eva-gate2-anchor-parameters.json:590` vs `:605` — 100× looser), and `1e-3` in Design 102
(`core.R:14`).

**LANE DISAGREEMENT — do not resolve it silently.** The Design-86 forensic lane states the
re-derivation was *required but never performed*, and that "the frozen Gate-2 JSON used the
unmodified `1e-4`/`1e-6` pair anyway". The two-prototype lane instead describes the EVA gate as
*"the same form as (a)'s gate, explicitly re-derived for `ell_EVA` because it 'may not be a bound'"*.
These readings are incompatible. The contract sentence quoted above is a **requirement** ("must be
re-derived"), which supports the first reading, but I did not open the frozen JSON to confirm what
was actually used. **Verify this yourself before reusing any threshold**, and do not repeat either
claim as settled.

**Detect early.** For each constant in your health rule, write one line stating where the number
came from and on what objective it was calibrated. Any line you cannot write is an unvalidated
threshold.

**Do instead.** Derive the tolerance for *your* objective (scale of the objective, conditioning of
your parameterization, finite-difference noise floor) before freezing it. Freeze it before running.
Then never move it (Trap 5).

---

### Trap 5 — Tuning the gate after seeing the result

**The trap.** The smoke comes back red at `0.10` against a `1e-4` bar, and the obvious move is to
"re-derive" the threshold to `0.2`. That converts a failed experiment into a fabricated pass.

**Evidence it is real.**

> *"tolerances cannot be widened after seeing the result"*
> — `docs/design/85-highdim-nongaussian-va-formal-contract.md:356-357`

> *"do not tune the frozen gates after observing this pilot"*
> — `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:74`

> *"Rejected: a fifth/replacement start, threshold relaxation, redraw, re-score, Laplace arm, or
> campaign follow-up."*
> — `docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md` (arc3 decisions)

**Detect early.** If the justification for a threshold change contains any observed number from the
run you are trying to pass, it is post-hoc.

**Do instead.** Derive and freeze before the run (Trap 4). If the frozen gate fails, the honest
outputs are: report the failure, or write a *new* predeclared design with a *new* derivation, run
fresh, and report both.

---

### Trap 6 — Failing without capturing the state needed to diagnose the failure

**The trap.** You run a smoke, it goes red, you record four final gradient values, and then you
spend three further arcs unable to say *why* — because the discriminating state was never retained
and the run cannot be re-observed.

**Evidence it is real.** This is exactly what happened to Design 86, and the corpus has a name for
the outcome that means *the evidence cannot distinguish the candidates*, not *a mechanism was
found*:

> *"`HISTORICAL_MECHANISM_UNOBSERVABLE` applies because integrity and cross-links pass while
> necessary discriminating state is absent. The other categories do not apply: no required hash/link
> fact failed; no retained shared signature identifies a mechanism; and no retained contradiction
> excludes one."*
> — `docs/dev-log/forensic/2026-07-23-design86-arc8-historical-observability.md:32`

> *"The immutable records establish valid, comparable frozen-health failures. They do not retain the
> common labelled numerical state required to identify or exclude an optimizer, coordinate,
> derivative, separation, or geometry mechanism. The historical mechanism is therefore unobservable
> from this evidence; this is neither a causal diagnosis nor evidence that no mechanism exists."*
> — same file, line 34

The missing state is itemised as *"full labelled trajectory, directions/steps, line-search state,
termination messages, and complete gradients at each evaluation"* (arc8, "Optimizer semantics" row).
Arcs 5/6/7 built controlled probes to recover the mechanism afterwards and all closed
`PARK`/`INCONCLUSIVE` — *"raw-loading scaling was nondiscriminating"*
(`docs/dev-log/after-task/…arc5-gate-a-diagnosis.md`) — because they probed a *different* objective.

**Detect early.** Before the first real fit, ask: *if this returns red, what file will tell me why?*
If the answer is "the four final gradients", you have already lost.

**Do instead.** Instrument from the first run: per-iteration objective, full gradient vector, step
and line-search state, termination message, the realized response array, and the parameter
transform map — at matched coordinates so an independent finite-difference check can be run later
against the *same* point.

---

### Trap 7 — Trusting a reference/oracle because it also converged

**The trap.** You validate the VA fit against an "exact" marginal-likelihood computation, that
computation returns code 0, and you treat it as truth.

**Evidence it is real.** Design 103's own GH61-based reference computation converged (code 0) and
was itself pathological:

> *"Thus a zero optimizer code was not accepted as a health certificate"*
> — `dev/design103-covariance-mechanism/AFTER-TASK.md`, after a GH61 refit that converged with
> **beta RMSE up to 846 and relative covariance error up to 3.58e8**.

**Detect early.** Run the oracle on a case where the answer is known in closed form (a Gaussian
cell, where quadrature and the analytic marginal must agree to machine precision) before pointing it
at anything you cannot check.

**Do instead.** An oracle needs its own admission evidence — agreement with a *separately coded*
computation, and a node-ladder stabilization check — before it is allowed to adjudicate anything.
See §3.

---

### Trap 8 — Reference "truth" that does not match the fitted parameterization

**The trap.** Your DGP draws latent scores with non-unit scale, you store `Σ = ΛΛᵀ` from the
unscaled `Λ`, and the model you fit assumes `u_i ~ N(0, I)`. Every recovery number is then wrong
against a silently wrong target, and nothing in the health gate notices.

**Evidence it is real.** Design 85's R2 closure gate had to fix exactly this: the DGP drew scaled
latent scores (`0.7` at q=1; `0.7, 0.45` at q=2) but stored `Sigma_B = Lambda_B Lambda_B^T` under a
live model assuming `u_i ~ N(0, I)` — fixed by folding the scales into `Lambda_B`
(`docs/dev-log/audits/2026-07-20-va-r2-mathematical-closure-gate.md`, item 1).

**Detect early.** Write the alignment table first: for each symbol in the DGP, the symbol in the
objective, and the identity that makes them equal. Then check numerically — simulate at large N with
the *true* parameters held fixed and confirm the empirical `cov(u)` and the empirical `ΛΛᵀ` match
your stored reference to Monte-Carlo error.

**Do instead.** Re-verify any inherited fixture against this identity explicitly. Do not assume a
fixture is correct because it predates your work — this one didn't.

**Note.** The corpus records this fix inside Design 85's R2 gate. I did not find a corresponding
verification for Design 102's or Design 99's fixtures; absence of a recorded bug there is not
evidence they were checked.

---

### Trap 9 — Comparing across mismatched rank, or across method variants, on a common scale

**The trap (a), rank.** Computing `ΣΛ` error or "axis collapse" when the fitted rank ≠ the planted
rank. **The trap (b), method.** Selecting among VA variants by their native objective values.

**Evidence it is real.**

> *"A collapse comparison is undefined across different ranks"*
> — `docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md` §11 (Noether lens); the final code
> records `rank_matches_truth` and reports collapse as `NA` on mismatch
> (`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:55-56`).

> *"do not compare objectives between methods"*
> — `dev/design102-recovery-envelope/PLAN.md:22` — different bounds (direct-GH vs Jaakkola–Jordan,
> diagonal vs full local covariance) are not on a common scale.

**Detect early.** Any comparison function should take the two ranks as arguments and hard-error on
mismatch rather than silently reshaping. Any cross-method selection should be by an *external*
criterion, never by the native objective.

**Do instead.** Carry `rank_matches_truth` on every row and return `NA` on mismatch. Score variants
against the estimand, not against each other's bounds.

---

### Trap 10 — `convergence == 0` read as "converged"

**The trap.** Treating the optimizer's return code as a health signal.

**Evidence it is real.** In Design 86's two smokes, **all four starts returned code 0** while
`max_abs_gradient` sat 3–4 orders of magnitude above the bar (up to **8.4345128**):

> *"Code zero is consequently not a health pass under this contract"*
> — `docs/dev-log/audits/…arc4-forensic-decision.md:60`

And the standing prohibition:

> claiming *"variance-component, interval, coverage, rank-selection, or high-dimensional accuracy
> from optimizer convergence alone"*
> — `docs/design/85-highdim-nongaussian-va-formal-contract.md:331-332` (§10)

**Detect early.** Print the gradient norm next to every convergence code, always. If your logging
shows one without the other, fix the logging first.

**Do instead.** Code 0 is necessary, never sufficient. And even code 0 + tiny gradient is not
evidence of recovery — see Trap 1.

---

### Trap 11 — Assuming the va-r3 binomial path covers sparse binary

**The trap.** Reusing `.va_r3_fit` for a Bernoulli (`n_it = 1`) target. It hard-rejects it.

**Evidence it is real (verified in this worktree).**

`R/va-r3-proto.R:209-212`:
```r
        any(n_trials != as.integer(n_trials)) || any(n_trials < 2L) ||
        any(y < 0L) || any(y > n_trials)) {
      stop("Binomial R3 data require integer n_trials >= 2 and integer 0 <= y <= n_trials.",
```
`inst/tmb/gllvmTMB_va_r3.cpp:145-147`:
```cpp
      if (nd < 2.0 || std::floor(nd) != nd || yd < 0.0 || yd > nd ||
          std::floor(yd) != yd)
        error("gllvmTMB_va_r3: binomial cells require integer n >= 2 and 0 <= y <= n");
```
And the target is precisely the excluded case: *"0.7's EVA should target sparse binary first"*
(`docs/dev-log/2026-07-21-eva-cut-to-0.7.md`, decision line 1), with admission regime
`p̄ ∈ [0.03, 0.10]`.

**Detect early.** Try one Bernoulli row through `.va_r3_fit` before planning anything around it. It
will `stop()`.

**Do instead.** If you extend the GH-quadrature ELBO to `n = 1`, you must **re-verify quadrature
accuracy at that boundary** — the corpus contains no evidence either way about how H61 GH behaves
there (see §5).

---

### Trap 12 — Assuming larger N rescues covariance recovery

**The trap.** "The error is large at N=80 but it's a small-sample effect; run N=1000."

**Evidence it is real.** Design 102's beta and marginal-probability error *did* decline with N; the
rotation-invariant loading-covariance error did not close by N=240 — *"roughly 0.67--3.36 across
cells"* at the largest N tested (`2026-07-24-design102-recovery-envelope.md:38-40`). Whether it
closes at larger N is unrecorded, and the campaign was explicitly closed:

> *"Do not extend this campaign. Any follow-up needs a separately approved design targeting the
> covariance-recovery failure mechanism."* — same file, lines 47-48

**Detect early.** Plot the recovery metric against N on a log scale on your pilot. If the beta curve
declines and the covariance curve is flat, you have reproduced the Design 102 signature and more N is
not the fix.

**Do instead.** Treat a flat covariance-vs-N curve as a structural signal (approximation bias,
information, or identifiability) — and note the corpus never resolved which (§5).

---

### Trap 13 — Budgeting an "exact reference" as a cheap validation step

**The trap.** "We'll just check against the true likelihood." That check is the most expensive and
most fragile component in the entire corpus.

**Evidence it is real.** Design 99's strict independent-oracle stage:

> *"terminal receipt after a bounded 2,700-second run… the strict independent-integration stage ran
> silently until the 2,700-second operator cutoff and was interrupted. It produced no terminal
> receipt. It was not rerun."*
> — `docs/dev-log/after-task/2026-07-24-design99-exact-reference.md:117,162-164`

Terminal JSON (`dev/design99-exact-reference/results/non-evidence/gate3-infrastructure-incomplete.json`):
`"terminal_outcome": "INFRASTRUCTURE_INCOMPLETE"`, attempt 1 `"outcome": "LAUNCH_ERROR"`, attempt 2
`"outcome": "OPERATOR_INTERRUPTED"`, `"elapsed_cutoff_seconds": 2700`, `"receipt_created": false`.

The cost driver is in the code: `d99_oracle_nested_pattern()` runs **19 components, each a doubly
nested `stats::integrate()`** over `(-Inf,∞)²` at `rel.tol = 1e-11`, `subdivisions = 1000L`
(`R/independent-oracle.R:367-368,383-384`), alongside `cubature::hcubature()` over a 19-dimensional
integrand at `tol = 1e-11`, `absError = 1e-13`, `maxEval = 5e6` (`:274,276`) — for **every observed
response pattern at every one of 8 coordinate settings**. Separately, Design 103 hit repeated
OOM/timeout at GH101 (8–16 GB, 1-hour walls).

**Detect early.** Time the oracle on ONE pattern at ONE coordinate and multiply. Add a per-pattern
heartbeat before the first long run — Design 99's run produced *zero* observable output for 45
minutes, which is why nobody can say whether it was near completion (§5).

**Do instead.** Cost the oracle explicitly in the plan; give it a progress log; and note that the
45-minute cutoff that killed Design 99 was itself not a calibrated budget:

> *"The contract defined the 45-minute threshold for routing a projected real run, not for the
> mechanical gate itself; using it as an operator cutoff was an adaptive safety decision and is
> recorded as a plan deviation."* — after-task, lines 241-243

---

### Trap 14 — Misclassifying healthy starts by using a stricter rule than the frozen one

**The trap.** The frozen rule is *best three of four sorted objectives agree within `1e-6`*. Testing
"all healthy starts agree" is strictly harder and throws away admissible fits.

**Evidence it is real.** The original Design 85 pilot classifier *"compared the range of all healthy
starts"* against the threshold
(`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:23-24`), misclassifying at least q1 seed 8,
whose best-three span was `3.50e-7` — below `1e-6`. Because no recovery summary was stored for it,
it *"cannot be retroactively used as positive recovery evidence"* (same file, lines 25-30). The
corrected rule as implemented (verified in this worktree, `R/va-r3-proto.R:557-563`):

```r
  if (length(healthy_id) >= 3L) {
    agreement_range <- .va_r3_best_three_range(objectives[healthy_id])
  }
  agreement <- length(healthy_id) >= 3L && agreement_range <= 1e-6
  admitted <- length(healthy_id) >= 3L && agreement
```

**Detect early.** Unit-test the classifier against hand-constructed objective vectors before running
any campaign.

**Do instead.** Store the full per-start record *and* the recovery summary for every fit, so a
classifier bug found later can be re-scored rather than forcing a re-run. Design 85's could not be.

**Note the arithmetic when you read the pilot table.** q1: 22/24 healthy; q2: 19/25 healthy; the
audit reports *"Eight applicable fits fail the predeclared optimiser gate"* (2 + 6 = 8), which spans
both cells. One forensic reader flagged this line as easy to misread as a single-cell count.

---

### Trap 15 — Calling your objective an ELBO (or a marginal likelihood) without checking which estimator it is

**The trap.** Two structurally different objects were both loosely called "EVA" in earlier planning,
and the whole of §3 of the cut memo exists to undo that.

**Evidence it is real.** They are different term-by-term.

- va-r3 evaluates the **expectation by quadrature**:
  `weighted_sum += gh_weights(h) * va_r3_softplus(mu + scale*gh_nodes(h))`
  (`inst/tmb/gllvmTMB_va_r3.cpp:69-71`, H61, verified present in this worktree at line ~72).
- EVA evaluates a **closed-form second-order Taylor term**: `y·mu - softplus(mu) - 0.5·p(1-p)·v`
  (`inst/tmb/gllvmTMB_eva.cpp:132-134`), and self-labels it:
  `attr(obj, "eva_provenance")$objective_type <- "EVA_TAYLOR2"` (`R/eva-proto.R:164`).
- Design 93's independent algebra: *"This is a second-order Taylor surrogate for E{ℓ(y;η)}, not the
  exact Gaussian expectation and not a claim about the full upstream covariance construction."*
  (`docs/design/93-eva-scalar-algebra.md:24-26`)
- And the bound property is not shared: *"REFUTED IN THE TARGET REGIME"* —
  `ell_EVA <= log p(y)` is **not** guaranteed; the sign of the 4th-order remainder flips at
  `p ≈ 0.211` (`docs/design/86-eva-sparse-binary-admission-contract.md` §5.3, ~lines 460-500).

**Detect early.** Write down the one line your objective computes for the expected log-likelihood.
If it contains a quadrature sum, it is a quadrature ELBO. If it contains `0.5·p(1-p)·v`, it is a
second-order Taylor surrogate and Jensen does not give you a bound.

**Do instead.** Name the estimator precisely in the code, the plan, and every report. Both
Gaussian branches are "exact" only because the Taylor expansion of a quadratic is exact — that is an
algebra anchor, not evidence about non-Gaussian approximation quality
(`85-…contract.md` Gate 1 text: *"This is an algebra/geometry anchor, not evidence about
non-Gaussian approximation quality"*, ~line 391).

---

### Trap 16 — Citing the retired `q >= 4` crossover claim

**The trap.** Justifying VA work by "VA wins above q=4".

**Evidence it is real.** *"The `q >= 4` claim is retired: it may not be cited by any gate or claim
under this contract"* — `docs/design/86-eva-sparse-binary-admission-contract.md` §1.4. It was traced
to a single uncited, unattributed corpus entry with `url: null`.

**Detect early / do instead.** Grep your own plan for `q >= 4`, `q>=4`, "crossover". Delete.

---

### Trap 17 — Assuming the underlying records still exist

**The trap.** Planning to re-analyse Design 102's per-cell numbers, or to re-score Design 85's
pilot. Most of it is not in the repository.

**Evidence it is real.** Preservation commit `c1ce419d`: *"The immutable record set lives on DRAC
and is not in this repository."* Only the summary range (`0.67--3.36`) survives in prose. Likewise
Design 85's raw pilot receipts (`/private/tmp/va-r3-pilot-0e9b3b56/pilot`) are local-only under
D-50 and the per-seed identity of the eight gate failures is not in any markdown doc.

**Detect early / do instead.** Assume you cannot re-derive any prior lane's numbers. Design your own
run so *its* records survive: commit the summary tables (not the raw payloads) to the repo, and keep
the adjudicator script in version control — Design 102's adjudicator is not on its branch (§5).

---

## 2. Which prototype to build from

**Recommendation: reuse va-r3's *engineering pattern*, write a new objective for the actual target;
do not extend `eva-proto.R` in place.** This is the recommendation of the two-prototype forensic
lane, and I am passing it through with its reasoning, not endorsing any result.

**Why va-r3 (`R/va-r3-proto.R` + `inst/tmb/gllvmTMB_va_r3.cpp`, on this branch) is the better base:**

- It has a real entry point that takes raw long-format data —
  `.va_r3_fit(y, n_trials, X, unit_id, trait_id, q, N=, T=, family=, link=, …)`
  (`R/va-r3-proto.R:424`) — not a fixture loader.
- It has a real multi-start / health-gate / report structure, with the health block
  (`admitted`, `healthy_starts`, `gradient_tolerance`, `agreement_tolerance`,
  `max_projected_variance`, `projected_variance_limit`) at `R/va-r3-proto.R:582-624`.
- Its numerical machinery is worth reusing: stabilized softplus/invlogit, the H61 Gauss–Hermite
  path with a heat-kernel Taylor branch below `v <= 1e-6`
  (`inst/tmb/gllvmTMB_va_r3.cpp:36-79`), the pack/unpack coordinate map.
- Its Gates 0–2 (freeze / algebra / O3 reference agreement) passed, and the audit's own reading is
  that the objective is coherent: *"the ELBO, coordinate map, Gaussian anchor, O3 comparisons, and
  quadrature checks are coherent. The classifier and rank-mismatch defects were real
  implementation/reporting defects; correcting them does not supply the missing experiment"*
  (`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:66-69`).

**Why it is nevertheless not usable as-is:** it hard-rejects `n_trials < 2` in both R and C++
(Trap 11), and the 0.7 target is sparse binary. Its objective does not compile against the target
family.

**Why `eva-proto.R` is not the base:** `.eva_make_objective(fixture = c("bernoulli","bernoulli_q2",
"gaussian","d3_marginal_probe"), …)` (`R/eva-proto.R:148`) only loads one of four hardcoded frozen
JSON fixtures. There is no analogue of `.va_r3_fit`; all multi-start and health-gate machinery for
real replicates lives outside it in `dev/design86-gate2-eva-runner.R`. Its one live Gate-2 attempt
failed the frozen gate by 2–3 orders of magnitude on all four starts (Trap 4). Its Taylor form is
still the estimator the sparse-binary contract is written around, so its **algebra** remains
relevant reading (`docs/design/93-eva-scalar-algebra.md`) even though its **code** is fixture-locked.

**Important qualifications on this recommendation.**

- "Better base" means better-instrumented and honestly scoped. **Neither prototype has a positive
  result.** va-r3's pilot closed *"NO-GO; retain Laplace"*
  (`docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md:29-30`); EVA's smoke closed
  *"VALID_RECEIPT / one-seed frozen-health failure; not Gate-2 admission"*
  (`…2026-07-23-design86-arc3-g2r-v1-eva-smoke.md:6`).
- Design 85's own reopening condition applies to any new engine work: *"Reconsider an engine arc only
  if a genuinely new evidence source identifies a tractable alternative and the maintainer approves a
  new formal contract"* (`…va-r3-pilot-no-go.md:75-76`). Reusing va-r3's *code* does not exempt new
  work from a new approved contract.
- The choice between "extend the GH ELBO to Bernoulli" and "adopt the Taylor form per the
  sparse-binary contract" is **not settled by the corpus**. Extending GH to `n = 1` has no evidence
  either way (§5); the Taylor form is proven not to be a bound in the target regime (Trap 15).
- Cost is unknown: *"The sparse-binary target is UNESTIMATED"*
  (`docs/dev-log/2026-07-21-eva-cut-to-0.7.md` §3, "Cost").

---

## 3. Is AGHQ usable as an oracle?

**Not today. With work — and the work is substantial and partly fenced off.**

**What exists, and its actual validation status:**

| Artifact | Validation | Limit |
|---|---|---|
| `tests/testthat/helper-aghq-o3.R` (2026-07-19, TMB-hooked) at **q=1** | Cross-checked against an **external** package: `lme4::glmer(nAGQ=1)` and `nAGQ=25`, tolerance `1e-3` (`o3_scalar_self_test`) | binomial/Bernoulli only |
| same helper at **q=2** (`o3_q2_gllvm_unit_self_test`) | **No external comparator.** Internal self-consistency only: 1-node reconstruction vs the fit's own TMB Laplace objective (`< 1e-6`), node-ladder 7 vs 9 nodes (`< 1e-4`), Hessian condition-number guard (reject `> 1e8`) | weaker than "independently certified" |
| `dev/design99-exact-reference/R/aghq.R` (2026-07-24, from scratch) | **Never certified.** Terminal `INFRASTRUCTURE_INCOMPLETE`; the only positive terminal label, `BOUNDED_ORACLE_PASS`, was never reached | hard-coded T=6, q=2, intercept-only Bernoulli, no covariates/offsets/weights |

**The verdict wording, verbatim:**

> *"Design 99 is terminal as `INFRASTRUCTURE_INCOMPLETE`. The branch contains a substantial private
> pure-R q=2 adaptive Gaussian--Hermite implementation and passing bounded synthetic tests, but the
> strict independent-oracle mechanical gate did not produce its required terminal receipt. Therefore
> no exact reference was admitted."*
> — `docs/dev-log/handover/2026-07-24-codex-handover-design99.md:12`

> *"The only positive terminal label is `BOUNDED_ORACLE_PASS`."*
> — `docs/design/99-exact-q2-reference-stabilization.md` (never reached)

**The fence you must respect:**

> *"Do not rerun or repair Design 99… Any changed oracle execution, timeout, progress schema,
> fixture, start, chart, node order, optimizer, or question requires a separately approved Design
> 100."* — handover, line 18

**What "with work" concretely means:**

1. **An approved new design.** Design 99 cannot be resumed or patched; a new oracle effort needs its
   own approved contract (handover line 18).
2. **Fix the cost problem, not just the code.** Replace or bound the doubly-nested `stats::integrate`
   at `rel.tol=1e-11` (Trap 13), and add a per-pattern heartbeat. Note the corpus records **no**
   reasoning that a cheaper comparator is impossible — the one-shot discipline was a choice, not a
   technical conclusion (after-task §3a).
3. **Generalize the frozen shapes.** `d99_validate_parameters` hard-codes `length(beta) != 6L`,
   `dim(Lambda) != c(6L, 2L)` (`R/numerics.R:182,187`). The O3 helper is welded to binomial/Bernoulli,
   reduced-rank `latent(..., unique = FALSE)`, one family, one RE block per unit
   (`.o3_r2_extract`/`.o3_q2_extract` assert `inherits(fit,"gllvmTMB_multi")`, `use$rr_B`,
   `d_B %in% 1:2`, `!use$diag_B`). Neither can be pointed at Poisson (`dbinom` throughout) or at any
   `unique=TRUE` / structured-Psi fit without rewriting the likelihood kernel.
4. **Get an external comparator at q=2.** The q=1 branch has one (`lme4`); q=2 has none. Until it
   does, q=2 AGHQ is self-consistency, not certification.
5. **Validate on the fixture you will actually use.** Design 99's only "passing" numerical comparison
   ran on *"a deliberately different small deterministic fixture, never the approved fixture seed"*
   (`scripts/run-mechanical-gates.R`, comment ~line 35). Passing there does not transfer.
6. **Do not reuse the launcher pattern unfixed.** A `dQuote()`/curly-quote bug in the spawned
   `Rscript` expression silently produced zero receipt on attempt 1 (handover "Gotchas"). Shell-escape
   explicitly.
7. **Apply Trap 7 to the oracle itself.** A converged reference is not a correct reference.

**Bottom line for planning:** if your validation plan depends on an exact AGHQ reference existing,
the plan currently has an unbuilt dependency with an unknown cost and a fenced-off predecessor. Cost
and schedule it as a first-class arc, not a checkbox.

---

## 4. The healthy-but-wrong problem

Design 102 is the single most important result in this corpus for an implementer, because it removes
the tool you would most naturally have trusted. **2,304 of 2,304 attempts passed
`convergence == 0 && max|AD grad| < 1e-3 && all finite`**, and at the largest N tested the
rotation-invariant loading-covariance relative error was still *"roughly 0.67--3.36 across cells"*
(`docs/dev-log/after-task/2026-07-24-design102-recovery-envelope.md:38-40`).

Why: the gradient is taken of the **variational surrogate**, whose parameters include the per-unit
local variational quantities (`mean`, `chol_free`) optimized jointly with the global parameters.
A stationary point of that surrogate says nothing about (a) how tight the surrogate is against the
true marginal likelihood, or (b) whether `Λ` is identified at that N.

**Which mechanism? The corpus does not say.** Design 102 declined to diagnose — *"This is a private
recovery envelope, not an estimator ranking, general reliability result, package capability claim,
or EVA result."* (lines 41-43). The follow-on Design 103 lane closed:

> *"Selection: **Not supported materially** at the two tested N=240 coordinates… Approximation:
> **Not adjudicable**… Information: **Not adjudicable**… Chart/scale: **Not adjudicable**"*
> — `dev/design103-covariance-mechanism/ADJUDICATION.md`

> *"Status: TECHNICAL_PARTIAL — mechanism diagnosis closed without a recovery or capability claim."*
> — same file

So: start-selection is ruled out *at two coordinates only*; approximation bias, information, and
chart/scale are **unresolved**, not excluded — and they were unresolved for resource/pathology
reasons, not because they were tested and cleared.

### What you must check beyond convergence

Predeclare all of these *before* fitting, with all-attempt denominators (Trap 3):

1. **The estimand itself, rotation-invariantly.** `ΣΛ = ΛΛᵀ` Frobenius relative error against the
   planted `ΛΛᵀ`, computed through a rotation-fixing chart (Design 102 used a positive
   lower-triangular loading chart). `Λ` alone is not identified; comparing `Λ` is meaningless.
2. **Per-axis collapse**, at matched rank only, `NA` on rank mismatch (Trap 9).
3. **Beta and integrated trait probabilities separately from covariance.** Design 102's signature is
   precisely that these improve with N while covariance does not — if you only track beta you will
   conclude the fit is fine.
4. **The N-trajectory of each metric.** A flat covariance-vs-N curve is the diagnostic signal (Trap 12).
5. **A comparator at the same rank** — Laplace/ML at the planted rank — so "VA is worse by X" is
   measurable rather than "VA converged".
6. **Tightness of the bound, or an explicit statement that you cannot measure it.** This is what the
   AGHQ oracle would have supplied and does not (§3). If you cannot measure it, say so in the report;
   do not substitute the health gate.
7. **Whether the objective is a bound at all** for your family and regime (Trap 15) — for the Taylor
   surrogate in the sparse-binary regime it is proven not to be.
8. **Separation / degeneracy of the realized responses**, retained per replicate. Design 86 could not
   exclude separation as a mechanism because the realized response arrays and a predeclared
   separation signature were never stored (Trap 6).
9. **An independent derivative check** (finite differences vs AD) at a matched, stored coordinate —
   again, unavailable retrospectively in Design 86.
10. **Conditioning of the parameterization** — a Hessian condition-number guard exists in the AGHQ
    helper (`> 1e8` rejected) and is a cheap thing to record.

If items 1–5 are not in your output schema before the first fit, do not start the campaign.

---

## 5. What the corpus does not record

Do not assume an answer exists for any of these. Each is a genuine, searched-for gap.

**About the failures themselves**

- **Why Design 86's four starts landed at those gradient magnitudes is not established.** Optimizer
  behavior, coordinate conditioning, AD fidelity, ridge/rank geometry, and response separation are
  each recorded as *"Neither identified nor excluded"* (arc8 observability matrix). This is a
  statement about missing evidence, not a finding.
- **Whether re-deriving the `1e-4`/`1e-6` gate for EVA would have produced a green smoke is untested.**
  No re-derived threshold was ever computed. There is also **no sensitivity analysis on the threshold**
  — nothing says whether `8.43` is near a plausible re-derived bar or off by orders of magnitude.
- **No Laplace-arm comparator exists for either Design 86 smoke.** Arc 2's Laplace run was stopped
  when EVA went red and never produced a receipt, so there is no baseline to compare the failure to.
- **The Design 102 mechanism (approximation bias vs local optima vs non-identifiability) is
  unresolved** — see §4.
- **Design 85 has no clean fixed-rank Gate-3 result.** The required experiment was never executed;
  there is no fixed-rank-only recovery table anywhere in the audit, either after-task report, the
  contract's §13 receipt, or the symbolic map.
- **Gate 5's practical-advantage margins** (10-pp success-rate, 25%/wall-time) were never reached, so
  there is **no data at all** on whether VA has any practical advantage at q4/q6.

**About the numbers you might want to re-analyse**

- **Design 102's per-cell `sigma_rel` values do not exist in the repository** — only the prose range
  `0.67--3.36`. The record set is on DRAC (commit `c1ce419d`).
- **Design 102's adjudicator script is not on its branch**, despite `PLAN.md:30` stating *"A private
  local adjudicator is the only component permitted to create summaries"*. The 768 selected endpoints
  cannot be re-derived from the repo.
- **The numeric value of Design 102's "originally frozen covariance-recovery threshold" is never
  stated.** It is asserted as not met; the document that froze it was not located. `PLAN.md` gives the
  `1e-3` gradient gate but no covariance pass/fail bound.
- **The per-seed identity of Design 85's eight optimizer-gate failures** (which seeds, which starts,
  what gradients) is in no markdown doc — only the aggregates 22/24 and 19/25.

**About the oracle**

- **How close Design 99's nested-integration stage was to finishing is unknown.** It was killed with
  no partial output; there is no runtime distribution, only "nothing observable in 45 minutes".
- **Whether the `BOUNDED_ORACLE_PASS` thresholds are achievable at reasonable cost is unknown.** They
  are defined prospectively in code (loglik `<1e-8`, chart-score `<5e-6`, per-pattern `<1e-7`, tail
  bound `<5e-7`) but were never evaluated on the approved fixture.
- **No cheaper comparator was tried or reasoned about** after the timeout — a deliberate one-shot
  discipline choice, not a technical conclusion.
- **No document explains why Design 99 rewrote from zero** instead of hardening the O3/R2 harness.
  `prior-work-sweep.md` and `borrowed-pattern-provenance.md` track the VA/JJ lineage (72, 85, 94–98),
  not the AGHQ-oracle lineage.

**About the path forward**

- **No evidence exists either way on how the H61 GH quadrature behaves at Bernoulli (`n_trials = 1`).**
  The exclusion is a validation guard, never an experiment. This is an open question, not a decided one.
- **Cost of a from-scratch sparse-binary implementation is explicitly unknown:** *"The sparse-binary
  target is UNESTIMATED"* (`docs/dev-log/2026-07-21-eva-cut-to-0.7.md` §3).

**Where the readers disagree**

- **Was the EVA optimizer gate re-derived, or reused unchanged?** Two lanes give incompatible
  readings — see Trap 4. Unresolved here; verify against the frozen JSON before relying on either.
- One reader also flagged that the Design 85 pilot's *"Eight applicable fits fail"* line is easy to
  misread as a single-cell count when it spans both cells (Trap 14).

---

*Final reminder: every one of the labels quoted in this document is a negative or a
non-result. If a later document cites this trap map as support for a VA capability claim, that
citation is wrong.*
