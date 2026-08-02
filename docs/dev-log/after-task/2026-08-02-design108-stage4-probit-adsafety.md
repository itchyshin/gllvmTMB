# After-task — Design 108 Gate A Stage 4: tail-safe `log Φ` + binomial-probit

**Date:** 2026-08-02 · **Platform:** Claude Code (read from `tools/session_ownership.sh`)
**Branch:** `claude/design108-stage4-probit` (worktree `/private/tmp/gllvmtmb-design108-stage4`),
cut from `origin/main` `910ebd54`. **Not committed at time of writing.**

## 1. Goal

Land Design 108 Gate A **Stage 4** as a fenced research spike — a tail-safe log-scale normal CDF
plus binomial-probit in the VA R3 template — and answer the question §6 says the stage exists to
answer: **is the log-scale `log Φ` route AD-safe at the actual quadrature reach?** If not, the
Gate-A programme becomes EVA-only for both probit families — a different programme with different
claims. A negative answer was defined *in advance* as a success of the arc.

Chosen by the maintainer at a Gate-0 checkpoint over Stage 3 (lognormal, 0.5 d, EXACT) and Stage 6
(tiers, closes Gate A), on §6's reasoning: *"Stage 1 is certain, and certainty is not information."*
That argument transfers verbatim to Stage 3.

## 2. Implemented

**Mathematical contract — no public API, grammar, family, or likelihood change.** Nothing is
exported; `integration = "va"` still **refuses** binomial-probit at the admission fence. The change
is internal to the VA R3 research engine and the Laplace→VA translation layer.

New primitive `log Φ(x)`, tail-safe for arbitrarily negative `x`:

- `log(1 − Φ)` is **never formed**. The `(n − y)` term is written `log Φ(−η)` by symmetry, so one
  primitive covers both tails and Design 105 §6.3's cancellation-prone CDF difference never arises.
- For `x < −10`, the Laplace **continued fraction** for the Mills ratio,
  `Φ(−z)/φ(z) = 1/(z + 1/(z + 2/(z + …)))`, backward-recurred 20 terms, gives
  `log Φ = −z²/2 − ½ log 2π − log(z + c)`; the inverse Mills ratio is the CF denominator `z + c`
  read off directly, so nothing is divided by an underflowed probability. This is a *convergent*
  expansion, not the asymptotic series the shipped engine uses.
- Above `−10` it is `log(pnorm(x))`. AD-safety comes from clamping each branch's **input**
  (`max(-x, 10)`, `max(x, -10)`), never its output.

Family algebra unchanged: probit is Laplace `family_id 1` with `link_id 1`, mapped to a **new VA
family code 4**. Probit carries **no dispersion parameter** (`log_phi` is nbinom2's, `log_sigma`
gaussian's), so no parameter vector was added.

## 3a. Decisions and Rejected Alternatives

| Decision | Rationale | Rejected alternative |
|---|---|---|
| Probit = **family code 4**, not a new link on code 1 | The template has no link channel — it carries only `DATA_IVECTOR(family)`, and the R side derives the link name *from the code* (`va-routing.R:81-83` hard-codes `"1" = "logit"`). Code determines link in this architecture. | Adding a link dimension to the template: strictly larger change, no gain. |
| `.va_r3_laplace_id_to_code()` made **link-aware**, `lid` **required with no default** | Laplace sends probit as `(1,1)`. A link-blind map plus a widened code-1 gate would fit a **logit model to probit data and report healthy**. A default `lid = 0L` would have left the Stage-2 call untouched — and reopened the trap by omission. | Widening the code-1 link gate: the natural-looking fix, and the silent wrong-model bug. |
| **Fence NOT widened** — probit still refused | Admitting it would be a capability claim with zero recovery evidence. The refusal now comes from the fence rather than the translation layer. | Admitting probit to `.gllvmTMB_integration_fence_limits()`: a claim the evidence does not support. |
| S2 and S4 run as **one agent** | The primitive and its verification are the same derivation; splitting them invites a verifier sharing the author's priors — then a *separate, fresh* adversary reviews both. | Separate build/verify agents at the same seam. |
| Small-v expansion left **first order** for probit | The 4th derivative of `log Φ` is a quartic in λ whose asymptotic cross-check failed to cancel — a correctness risk for a term worth 1e-12. Documented with its error budget. | Deriving the 3rd-order form used for softplus. |

## 4. Files Touched

| File | Change |
|---|---|
| `inst/tmb/gllvmTMB_va_r3.cpp` | `va_r3_mills_cf()`, `va_r3_log_pnorm()`, `va_r3_inv_mills()`, `va_r3_probit_expectation()`; family-code-4 branch; range check; doc comment; JJ counter renamed `n_non_binomial` → `n_non_jj` (probit *is* binomial, but JJ bounds only the logistic term) |
| `R/va-r3-proto.R` | link-aware `.va_r3_laplace_id_to_code(fid, lid)`; code 4 in name/code maps; `{0..4}` validators; link switches; `n_trials` preservation; separation guard; `qnorm` warm start; registry entry |
| `R/va-routing.R` | passes `link_id_vec` to the mapper; gate `(code == 4L && lid == 1L)`; code 4 reports as family `binomial` / link `probit` so the **fence** is what refuses it |
| `R/integration-fence.R` | **comment only** — probit deliberately *not* admitted |
| `tests/testthat/test-va-probit-adsafety.R` | **new**, 114 assertions |
| `tests/testthat/test-va-mixed-family.R`, `test-va-r3-prototype.R` | data-driven registry guards fired as designed on a new family; companion tables extended (3 lines) |
| `docs/design/35-validation-debt-register.md` | **VA-12** row, `partial` |
| `dev/design108-stage4/va-claim-fence.sh` | **new** — reusable VA claim gate |
| `dev/design108-stage8/` | **new** — §0.2 campaign harness + README (separate lane, §12) |

**Status-inventory cascade: nothing else required.** `README.md`, `NEWS.md`, `ROADMAP.md`,
vignettes and `man/*.Rd` deliberately untouched — there is no capability to advertise, and no
roxygen block changed, so no `man/*.Rd` regeneration was due. Verified mechanically, not asserted:
`va-claim-fence.sh` returns 0 leak lines on the working branch.

**Roadmap tick:** Gate A Stage 4 complete (Stages 1–2 merged as #891/#893); Stage 5 is now
dependency-unblocked; Gate A still closes at Stage 6. **No `ROADMAP.md` line moves** — Gate A is a
research programme, not a roadmap deliverable, and nothing here is user-facing.

**pkgdown / documentation:** no updates, deliberately. No export, no `method=` argument, no
NEWS/README/article text.

## 5. Checks Run

| Check | Outcome |
|---|---|
| Stage-2 baseline *before* any edit (`test-va-mixed-family.R`) | **23 pass, 0 fail/error/skip** |
| Full VA regression, 9 files, after the change | **612 pass / 0 fail / 0 warn / 0 skip** |
| `test-va-mixed-family.R` after the change | **23 pass** — exactly the baseline |
| AD-safety suite after six comment corrections | **0 fail, 0 error, 0 skip** |
| Claim fence, `origin/main` and working branch | **0 leak lines**, exit 0 both |
| Fence end-to-end from `gllvmTMB()` | `link="probit"` **refused**, usable message; `cloglog` refused; `logit` accepted (control) |
| Mis-route sweep `(fid 0–6) × (lid 0–2)` | only `(1,0)→1` and `(1,1)→4`; all else errors; `.va_r3_laplace_id_to_code(1L)` errors on missing `lid` |

**AD-safety, the load-bearing result.** Richardson-extrapolated central-difference FD against an R
`pnorm(log.p = TRUE)` integrand, with `dE/dv` from an `is_y_observed = 0` twin so no analytic KL is
trusted:

| | worst `dE/dmu` rel err | worst `dE/dv` rel err |
|---|---|---|
| H=15 (±6.36 SD) | 3.45e-12 | 2.89e-09 |
| H=61 (±14.50 SD) | 3.22e-11 | 3.46e-09 |

Tail cells reach `η = −145.0`; gradients **and** Hessians finite throughout. **VERDICT: AD-SAFE.**

**Independent adversarial verification (fresh context, briefed to refute): ESTABLISHED.** A
3,744-cell break grid — µ ∈ {−1e6 … 1e4} incl. the switch straddle, v ∈ {1e−300 … 1e8}, `(y,n)`
boundary cases, both H — produced **0 non-finite** objective, gradient or Hessian. An *analytic*
re-derivation put true AD error 2–5 orders below the asserted bounds (2.36e-14 / 2.89e-13) and
showed `rel(FD,analytic) ≈ rel(AD,FD)`, confirming the residual is the FD reference's own
conditioning. Regression re-run independently: 612/0.

## 6. Tests of the Tests

Each new assertion was checked for the ability to fail:

- **Tail claims recomputed, not trusted.** Node positions recalculated per cell; the first NaN in
  `dnorm/pnorm` is near x = −38.6. Result: **3 of 5 tail cells reach the NaN region at H=15, 5 of 5
  at H=61** — the file's original blanket comment ("every one but the first two") was **false** and
  has been replaced with a per-cell table.
- **Clamp necessity tested by removal.** A standalone template with the clamp deleted gives, at
  x = −50: `fn 1254.83, gr −50.02` (finite *and correct*) but `he` **NaN**. The clamp protects the
  **Hessian**, not the gradient — so any future check that it is still needed must call `he()`.
- **Probit-vs-logit separation tested against the obvious objection** (is 0.1696 just the ~1.7 scale
  factor?): residuals are sign-mixed and small against Laplace-probit, uniformly negative and
  ≈ log(1.702²) = 1.0636 against Laplace-logit. A logistic branch would do the opposite. Separation
  ratios 5.69 / 6.57 / 4.65 across 3 seeds.
- **Twin trick validated by code path**, not assumed: the masked path zeroes the data term and
  `continue`s; the KL loop never reads `is_y_observed`. Confirmed empirically to 2.9e-13 against a
  reference containing no KL at all.

## 7a. Issue Ledger

None opened, commented, or closed. Two candidates a maintainer may want filed: the Design 105/108
doc corrections (§10), and the `gll_log_pnorm` vs continued-fraction divergence before Stage 5.

## 8. Consistency Audit

- Keyword / notation drift: none — no grammar, keyword, or `Sigma` / `Lambda` / `psi` usage changed.
- Deprecated aliases, `gllvmTMB_wide()`, `meta_known_V`: untouched.
- `man/*.Rd`: not regenerated — no roxygen block changed (no export, no `@param` change).
- Register: VA-12 added. VA-02/03/10/11 left as-is: Stage 4 admits nothing new to the fence, so
  VA-02's admitted set is still correct as written.

## 9. What Did Not Go Smoothly

1. **I mis-stated §6 to the maintainer.** I claimed its heading *"Why that one, and not the cheaper
   Stage 1"* contradicted the handover's "§6 prefers Stage 4". It does not — §6 opens *"The next
   slice I would actually run: Stage 4."* Caught by reading the section myself rather than trusting
   a subagent summary. The Gate-0 decision rested on the corrected reading.
2. **I over-read the ridge as a cheap fix.** A n=60 smoke showed `aghq_ridge = 2` recovering and I
   suggested it might make the programme unnecessary. `R/gllvmTMB.R:909-911` records the opposite:
   *"`aghq_ridge = 2` still runs away in 67% of fits at n = 1600, sigma_lambda = 3."*
3. **The §0.2 campaign was designed on a mild DGP only** (loading SD 0.7) and would very likely have
   concluded "the ridge fixes silent divergence" purely by never visiting the regime where the ridge
   is *already measured* to fail. Caught pre-launch.
4. **A launch bug would have killed all 3,600 cells identically.** Setting `R_LIBS_USER` to the
   private library *replaced* the user library, hiding every dependency (`assertthat` not found).
   Caught only because a single probe ran first.
5. **Two false alarms, both checked before acting.** A subagent reported "unknown writers" in the
   worktree and suspected a Codex lane — it was my own Stage-4 agent. My own preflight reported a
   "stale run" — `pgrep` matching its own command line.
6. **The first claim fence was unusable**: 40 false positives, because `ordinal_probit()` and
   mixed-family *Laplace* are legitimately public and `aghq_ridge` is a Laplace control.

## 10. Known Residuals

**Owed design-doc corrections** (recorded, not applied — outside this arc's write scope):

1. **Design 105 §1.3 / Design 108 §6 state H=61 reaches ±15.7 SD** (max node ~11.09). The package's
   actual H=61 rule has max node **10.2520 → ±14.4985 SD**. Immaterial to the verdict; wrong in doc.
2. **Design 108 §6 says "add `family == 3`"**. Code 3 is already nbinom2; probit is code **4**.
   Following §6 literally would have collided with nbinom2.

**Not covered by this arc:** recovery or accuracy of the probit VA route in any regime;
ordinal_probit (Stage 5); second phylo tier and `unique = TRUE` (Stage 6); VA `mi()`; any export or
public claim.

**The distinction that must not be blurred: AD-safe is established; accurate is not.** Every
derivative check certifies the template differentiates *its own quadrature sum* — the reference is
that same sum on the same nodes. Externally, the H=15 rule is already **3.0e-9** off `integrate()`
on a bulk cell, five orders above the AD error certified, and for deep-tail cells no external truth
exists. Both engines under-recover planted `Σ_B` on the toy seed. That gap is Stage 8's to close.

**Two implementations of `log Φ` now coexist:** shipped `gll_log_pnorm` (`src/gllvmTMB.cpp:71`,
asymptotic, ~9e-11 at its switch) and the new CF (0 ULP). Stage 5 will want them to agree.

## 11. Team Learning

**Gauss** — owned the primitive. The decisive move was structural, not defensive: writing the
`(n−y)` term as `log Φ(−η)` means the cancellation Design 105 §6.3 warns about is never *formed*,
rather than guarded against. Choosing a convergent continued fraction over the shipped asymptotic
series bought 0 ULP where the shipped path carries ~9e-11. Watch next: those two must agree before
Stage 5 reuses this primitive.

**Noether** — the alignment catch of the arc is that the *rationale* for a guard can be wrong while
the guard is right. The comment said the clamp protects the gradient; measurement says the Hessian.
Symbolic claim and implementation behaviour diverged in the documentation layer, which is exactly
where nobody looks. Watch for: any "AD-safe because X" comment never tested by removing the thing it
justifies.

**Rose** — three over-general statements survived into a *verified* test file ("nothing shares code
with the template", "every one but the first two", "continuous across the switch"), each true in the
tested region and false as written. A test's prose is not covered by its own assertions. Watch for:
comments that generalise beyond the loop they sit in.

**Fisher** — the campaign nearly answered a question its design could not support: a DGP that never
visits the documented failure regime cannot adjudicate whether a remedy works. Also, 3 seeds cannot
estimate a rate to compare against 67% — resolution is a design parameter, not a detail. Watch for:
replication chosen under cost uncertainty and never revisited once cost is measured.

**Curie** — the harness-reuse instinct was right (extend `dev/totoro-grid/run-grid.R`, don't
rebuild); the costing instinct was better: measure the dominant cost driver rather than extrapolate
it. Ordinal came in at 235.6s against a ~206s extrapolation — good, but only knowable by measuring.
Watch for: a single anchor extrapolated across two orders of magnitude in `n·p`.

**Ada** — the fan-out budget was exceeded by one ceiling child (the adversarial reviewer). Recorded,
not taken silently: the AD-SAFE verdict decides whether ~26–42 days happen, and letting the author's
own priors grade it is the failure D-43 exists to prevent. That should be the default whenever a
verdict is programme-deciding.

## 12. Cross-Product Coverage

**Cross-cutting flags this arc touched: `engine` (VA R3 template + Laplace→VA translation),
`family` (a new VA family code), `link` (probit as a first-class VA link).**

**What this arc COVERS.** The `engine` flag, for the VA R3 research template only: the log-Φ
primitive, the family-code-4 branch, the AD-safety verification at H ∈ {15, 61}, and the
Laplace→VA `(fid, lid)` translation. The `family`/`link` flags at the *translation and refusal*
layer: `(1,1) → 4` maps correctly and every other `(fid, lid)` pair errors.

**What this arc does NOT cover** — explicitly, per downstream surface and provider:

| Surface / provider | Does NOT cover |
|---|---|
| **VA route, user-facing** | Probit is **not reachable**. `.gllvmTMB_integration_fence_limits()` still admits `binomial = "logit"` only. No export, no `method=` argument, no NEWS/README/vignette text. |
| **Accuracy / recovery, all families** | Does NOT cover accuracy in any regime. The checks certify the template differentiates *its own quadrature sum*; they do NOT establish that the sum approximates the true expectation (H=15 is 3.0e-9 off `integrate()` on a bulk cell). Stage 8 owes this. |
| **Shipped Laplace engine** (`src/gllvmTMB.cpp`) | Does NOT cover `gll_log_pnorm`, which was left untouched and is now strictly less accurate (~9e-11 at its switch vs 0 ULP). No Laplace-path behaviour changed. |
| **ordinal_probit (Stage 5)** | Does NOT cover it. Stage 5 is unblocked by this work but no cutpoint handling, no `logspace_sub`, no ordinal VA path exists. |
| **Tiers / `unique = TRUE` (Stage 6)** | Does NOT cover multiple unstructured tiers or `diag(psi)`; both remain hard-gated (`proto.R:196`). Gate A does not close here. |
| **Missing data under VA** | Does NOT cover VA `mi()`, which stays refused. Stage 1's `is_y_observed` mask is reused, not extended. |
| **GLLVM.jl (R↔Julia twin)** | Does NOT cover any Julia port. No parity obligation is created, because nothing became user-facing. |
| **drmTMB / sister packages** | Does NOT cover them; no coupling. The shared spatial / phylo / meta surface is untouched. |
| **§0.2 campaign (Stage 8)** | Does NOT cover its results. That lane runs against the *shipped Laplace* engine pinned to `origin/main 910ebd54`, deliberately not this branch. Nothing from it is folded into VA-12. |

Detail on the two providers most likely to be misread:

- **GLLVM.jl (the R↔Julia twin)** — no port owed *yet*. The CF-based `log Φ` is a numerical
  technique, not an API change, and GLLVM.jl has no VA probit route to mirror. It becomes relevant
  only if the twin implements probit VA; the CF is the form to copy, not the asymptotic series.
- **Shipped Laplace engine (`src/gllvmTMB.cpp`)** — deliberately untouched this arc, but now carries
  a strictly less accurate `log Φ` than the research template. Flagged above as a Stage-5
  precondition, not silently absorbed.
- **drmTMB / sister packages** — no coupling. Stage 4 touches only the VA R3 template and its
  translation layer; nothing in the shared spatial / phylo / meta surface moved.
- **Design 108 Stage 8 (§0.2 campaign)** — runs in parallel on Totoro against the *shipped Laplace*
  engine only, deliberately pinned to `origin/main 910ebd54` rather than this branch, so its
  measurement is uncontaminated by Stage 4's in-progress edits. Results are LOCAL (D-50) and are
  **not** folded into VA-12; they will be reported separately. Per-campaign Totoro approval was
  given in-session 2026-08-02 (`LOOP/GOAL.md:55` requires it per campaign, not standing).
