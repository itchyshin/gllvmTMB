# Claude → Claude handover — gaussian arm MERGED; transition to a new lane for the degeneracy-at-scale campaign

Date: 2026-07-30. Author: Claude. Target: **Claude** (same platform).
Supersedes: `2026-07-30-claude-handover-gaussian-arm-closed.md` (written before the merge).
Predecessor arc: `2026-07-30-claude-handover.md` — **its resume command is defective; see Gotcha 1.**
Lane map: `2026-07-25-active-lane-split.md` (updated by this handover).

**You are Claude, picking up after a completed and MERGED arc.** Nothing is blocked on compute.
The next arc is chosen and scoped; your job is to open a new lane and ultra-plan it there.

## Mission control

| item | state |
|---|---|
| **`main`** | `7ed3f238` — **PR #840 MERGED** (21 commits, 20 files, +2189/−15) |
| **this lane** | `claude/vgh-pluralism-20260730` — **merged and CLOSED.** Do not add to it. |
| **worktree** | `/private/tmp/gllvmtmb-vgh-pluralism` — merged, idle, safe to remove |
| **checks** | `rcmdcheck --as-cran` **0E / 0W / 1N** (New submission) on the settled tree; tests OK 216s; CI ubuntu-release **SUCCESS**. Log retained at `dev/vgh/checks/2026-07-30-as-cran-gaussian-arm.log` |
| **next arc** | **CHOSEN by Shinichi**: VGH degeneracy at scale on the non-gaussian grid. Scope at `docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md` |
| **your first act** | **open a NEW lane** (fresh branch + worktree), then **ultra-plan the campaign there** |
| **fenced** | every other lane on the split board — Codex `codex/va-*`, `codex/hvt1-*`, `codex/design86-*`, the eta lane; the 0.6 release lane; Profile/Tier-2a; and the **LA + AGHQ + ridge lane** |

## Goals / mission

`gllvmTMB` is the multivariate stacked-trait GLLVM package; first CRAN release is **0.6.0**, and
1.0 is reserved for the capability-maturity milestone. This lane's durable question is **Q4** of the
brain note's taxonomy — *is a variational engine the better estimator for gllvmTMB?* — pursued
because Laplace has a **33.8% catastrophic, 98% silent** failure tail on binomial that VA does not
appear to have. The strategic prize is **both engines plus an honest gate saying which to trust**,
which neither `gllvm` nor gllvmTMB ships.

## Critical context — what this arc settled, do NOT re-derive

**The gaussian question is CLOSED, and the answer is that it was the wrong question.** On gaussian,
Laplace is exact and the VGH ELBO is exact, so **both engines optimise the same objective**
(`dev/vgh/vgh-bench.R:2-3`). Two consequences:

1. **"Which estimator is more accurate" is not well-posed on gaussian** — same objective ⇒ same
   MLE. Measured: matched at 60 free parameters, `d_ll` collapses from a median 9.96 to a max of
   **8.3e-07** across 24 cells; the arms agree on recovery (0.1130 both), residual SD (0.9971 both,
   max diff 1.9e-06) and `Σ̂` (~5e-05 relative).
2. **VGH's anti-degeneracy mechanism is switched OFF on gaussian.** The ELBO is `logLik − KL`; a
   tight bound means `KL = 0`, so the regulariser credited for VA's zero-degeneracy record
   contributes nothing there.

**The reported log-likelihood "advantage" was degrees of freedom.** Nested models, homoscedastic
DGP, both log-liks exact ⇒ `2·d_ll ~ χ²₁₉`. Observed mean 9.396 (n=200) / 9.268 (n=800) against a
null mean of 9.5; 0 of 24 cells significant; KS p = 0.810 / 0.901. The bench's apparent growth with
n was an artifact of redrawing the truth per n — **excluded** at power 0.962.

**Gaussian has no loading-runaway tail for either engine**, on scale-free evidence: across 59
gaussian fits `max|Λ̂|` stayed below each dataset's own largest trait SD (max ratio 0.961). Mechanism
**derived**: the gaussian marginal log-likelihood is coercive in Λ (`log|ΛΛ' + diag(ψ)| → ∞`;
measured −592.8 → −1352.3 under `Λ → 1000Λ`, against a separated logistic going −6.27 → 0).

**⇒ The pluralist route is a NON-GAUSSIAN proposition.** Build VGH for binomial/Poisson. **Do not
build VGH for gaussian** — that work has no target.

**Two lanes converged independently, which is the strongest result of the day.** The AGHQ/ridge
audit (#842, `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md`) found across
**432,000 fits** that `aghq = k` returns the Laplace warm start **bit-for-bit 89.6%** of the time on
gaussian (poisson 0.740, binomial 0.000), and that AGHQ *"helps binomial only, and only at large
n."* Two unrelated alternatives to Laplace, same verdict, neither lane aware of the other. Treat
their 432k fits as the load-bearing version.

## Two claims RETRACTED this arc — do not resurrect

1. **"max |Λ̂| = 2.77 against the shipped absolute threshold of 6."** Invalid.
   `loading_absolute_thresh` is **binomial-gated** — the row `return(NULL)`s unless
   `family_id == 1L` rows exist (`R/diagnose.R:464-471`), verified by running `check_gllvmTMB()` on
   a gaussian fit (13 rows, no such row). And 6 is trivially exceeded on identity: **multiplying `Y`
   by 10** lifts every loading past it; adversarial fits reached 32.64 with no pathology.
2. **My charge that the 2026-07-29 docs committed a "category error."** Wrong — they were correct on
   every point and even named this slice as the missing run. The stale "+6.2 to +10.0" range was
   accurate when written (n=2000/4000 had not completed).

Also corrected: the **C-exact figure is 3.76e-13**, not 1.3e-12 — the old number was 70% stale-ELBO
artifact. Always quote it with its tolerance.

## Current working state

**WORKING / MERGED:** everything above, on `main` at `7ed3f238`.
**IN PROGRESS:** the campaign **scope document** was being generated by a workflow
(`wf_a3dfc0c5-ee1`) as this handover was written. If
`docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md` is absent on `main`, **regenerate or
re-scope before planning** — do not plan the campaign without it, and see Next Steps 1.
**BLOCKED:** nothing.
**CARRIED-OVER:** the D3 request to another lane (below) — drafted, awaiting Shinichi to route.

## Next immediate steps

1. **Confirm the scope document exists and is sound.** Path
   `docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md`. It should carry: the grid design, the
   engine choice with its transferability cost, measured per-fit runtimes, the cost estimate, the
   compute target, the reuse plan, the smoke plan, and an explicit "does NOT cover". **If it is
   missing or thin, re-scope first** — the whole point is to size the investment before making it.
2. **Open a NEW lane.** Fresh branch off `main` (`claude/vgh-degeneracy-at-scale-<date>`) and a
   fresh worktree. Do **not** continue on `claude/vgh-pluralism-20260730` — it is merged.
3. **Ultra-plan the campaign in that lane.** It genuinely wants the method: real compute, a
   grid, parallel slices, an adversarial gate on the claim. **Fire the adversarial gate BEFORE
   publishing any result, not after** — see Gotcha 8.
4. **Compute → Totoro** (≤100 cores, no queue). Results stay **LOCAL (D-50)** — never GitHub
   artifacts. Escalate to DRAC only for >100 cores or multi-node.
5. **Then, and only then**, the decision this campaign informs: whether to "implement VGH properly"
   (unify the two half-implementations — `docs/design/108-va-parity-programme.md:194` scopes part at
   2–3 days).

## The campaign's question, in one paragraph

VGH's low-degeneracy claim rests on **one narrow regime**: 148 paired binomial fits at p ∈ {6,12},
q = 2, n ∈ {60,100,200}, giving VGH **0/148** against Laplace **50/148** (49 silent). And
**VGH was never in the Totoro grid at all** — that grid's 0%-vs-12% headline belongs to `gtmb_jj`
and `gllvm_va`; the grid predates `R/va-vgh.R`. So the load-bearing evidence for a multi-day engine
investment is a single regime. Does it survive n 40–400, p 8–80, q 2/4? **Binomial-weighted** —
gaussian is closed, and poisson is a cheap control (all arms were equivalent there).

## Blockers / open questions for Shinichi

1. **🔴 D3 needs an owner.** The AGHQ/ridge audit leaves D3 and D4 *"recorded pending a decision"*
   with nobody assigned. D3: the ridge's `τ = 2` is **on by default whenever AGHQ is on, with no
   warning** (`R/fit-multi.R:5255`) and is **net-harmful or inert across every scale they measured**
   (worse for both engines at `lam_sd = 3`). **It composes with their D4** ("penalised-fit
   disclosure is partial and sometimes false") into a user receiving a silently penalised MAP-not-MLE
   fit. A request brief is drafted for Shinichi to route to that lane.
2. **The scale-dependent-constants class needs one owner.** Their `τ = 2` and my
   `loading_absolute_thresh = 6` are the same defect family — a hardcoded magnitude constant
   standing in for a scale the data determines. Two lanes, two constants, one day. A single sweep
   beats two separate fixes; it spans both surfaces so it falls between lanes by default.
3. **Worktree cleanup** — `/private/tmp/gllvmtmb-vgh-pluralism` is merged and idle.

## Gotchas / failed approaches

1. **🔴 A resume command is executable instruction, not prose.** `2026-07-30-claude-handover.md:126`
   said *"note VGH FIXES rather than estimates the residual SD"*. True of
   `R/va-vgh.R::.vgh_fit()` (family `"gaussian_anchor"`), **false** of
   `dev/vgh/vgh-engine.R::vgh_fit()` (family `"gaussian"`), which **estimates** per-trait `φ_j`. Its
   own predecessor said `gaussian_anchor` correctly; compressing it to "VGH" inverted the fact, and
   the next session acted on it before reading the evidence. **Name engines exactly.**
2. **`test-vgh-oracle.R` REQUIRES `devtools::load_all()`.** Against the installed package it errors
   **11 of 12** tests with `could not find function ".vgh_fit"` (internals unexported). Reads as a
   test failure and is not one.
3. **The "obvious" stale-ELBO fix is a trap.** Moving `prev <- e$value` above the break test makes
   the predicate compare a value to itself → **every fit breaks at sweep 1**, `tol` inert, ~70 ELBO
   units lost. And `Beta` still matches to 2e-16 on an intercept-only fixture, so a spot check passes
   it.
4. **A metadata flag proves nothing about the math.** `expect_true(fit$phi_pool)` survived a
   deliberate break that inverted the behaviour it names. Assert values.
5. **Never analyse a driver's console log for precision.** `gaussian-collapse.R` prints
   `d_ll_pooled` with `%+9.5f`, rounding a real ~1e-7 residual to `-0.00000`. Use
   `dev/vgh/gaussian-collapse-analyse.R`, which reads the CSV and documents the trap.
6. **When a ratio metric flags degeneracy, check the absolute magnitude.** `rel_frob` and `atten_F`
   both normalise by the truth, so a near-null Λ inflates them while the fit stays small — the
   "degenerate" fits here had loadings *half* the size of the healthy ones.
7. **Seed on every design axis.** Two defects in this arc's own scripts:
   `gaussian-collapse.R:69` does not seed on `n` (24 cells → 12 truths), and
   `gaussian-degeneracy-reachability.R:29` does not seed on regime (36 fits → 6 streams reused six
   ways). **The campaign design must seed on every axis.**
8. **Fire the adversarial gate BEFORE publishing.** The one real process drift of this arc: the gate
   was scheduled before the results were relied on, but both result docs were written, committed
   **and pushed** first — and the gate then refuted one headline. A wrong number reached another
   lane's message bus in the interim. For a lane whose output *is* a claim, treat "committed" and
   "adversarially gated" as one gate.
9. **`vgh_fit()` cannot be multi-started** (no start argument, deterministic eigendecomposition
   init) and has **no input validation and no `$converged` field** — NA/Inf in `Y` makes its
   per-unit guards refuse every step silently.
10. **`ψ_j → 0` is unexplored** and is the real gaussian Heywood boundary — the likelihood is *not*
    coercive in ψ. Every reachability fit used `unique = FALSE`, so no per-trait ψ existed to
    collapse. Only relevant if a gaussian degeneracy claim is ever needed.

## Files created / modified this session

All merged in #840. New: `docs/dev-log/2026-07-30-gaussian-{arm-rescope,has-no-degeneracy-tail,collapse-test-result}.md`;
`docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`;
`docs/dev-log/plan-actual/2026-07-30-gaussian-arm.md`;
`docs/dev-log/handover/2026-07-30-{claude-handover-gaussian-arm-closed,to-la-aghq-ridge-lane-gaussian-findings}.md`;
`dev/vgh/gaussian-collapse{,-analyse}.R`, `dev/vgh/gaussian-collapse{,-smoke}.csv`,
`dev/vgh/gaussian-degeneracy-reachability.{R,csv}`, `dev/vgh/checks/2026-07-30-as-cran-gaussian-arm.log`,
`tests/testthat/test-vgh-pooled-phi.R`.
Modified: `dev/vgh/vgh-engine.R` (`phi_pool` + `phi_floor`; the `d=1` fix; the stale-`$elbo` fix),
`tests/testthat/test-vgh-oracle.R` (q=1 coverage, purely additive), `dev/vgh/vgh-bench.R` (comment
only), `docs/dev-log/2026-07-29-vgh-{report,variational-speed-probe}.md`,
`docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md`,
`docs/dev-log/handover/2026-07-30-claude-handover.md`, `docs/dev-log/check-log.md`.
Brain: `~/shinichi-brain/memory/VGH in gllvmTMB — the settled position….md` (the KL gaussian scope limit).
**Untouched:** `R/`, `src/`, `NEWS.md`, `check_gllvmTMB()` — `git diff --stat -- R/ src/` vs `main` is empty.
This handover adds: this file + the lane-split board update.

## Plans / roadmap beyond the next arc

Carried forward from the lane-split board so this handover does not narrow the menu:

- **EVA — standing interest (Shinichi, 2026-07-25):** *"I am still interested in EVA stuff too —
  please remember."* Cut from 0.6 to **0.7**, **Codex-owned** (`design90`–`design98` + the eta
  lane). Picking it up is a **lane reassignment + Gate-0 scope freeze decision**, not agent
  initiative. **Keep it on the menu; raise it with him.**
- **⚠ `claude/va-implementation-20260725` is DO-NOT-MERGE** pending Shinichi's Design-85 §10
  decision (new formal contract / revert / park).
- **0.6 release lane** — rung remains **NOT READY**; its real blocker is the one-by-one docs review
  *with Shinichi*, not more engineering.
- **Profile / Tier-2a**, **HVT-1** (`ORACLE_NOT_CERTIFIED`, `<= 4` gate frozen), **Design-103**
  (closed `TECHNICAL_PARTIAL`), **docs-infra** — all per the board.
- Toward 1.0: Julia parity, the methods paper, the full coverage campaign.

## How to resume

Read this doc, then the after-task report (`docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`
— it carries the full negative space in §12 and what went wrong in §9), then the campaign scope, then
the lane-split board. Spawn a fresh adversarial lens **before** any claim.

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git pull && claude "Rehydrate from docs/dev-log/handover/2026-07-30-claude-handover-lane-transition.md plus the CLAUDE.md snapshot and docs/dev-log/handover/2026-07-25-active-lane-split.md. The gaussian arm is MERGED and CLOSED — do not re-derive it; on gaussian both engines optimise the SAME objective so accuracy is not a well-posed question there. Open a NEW lane (fresh branch + worktree off main), then ultra-plan the VGH degeneracy-at-scale campaign from docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md. Binomial-weighted; compute on Totoro at <=100 cores; results LOCAL per D-50; seed on every design axis; and fire the adversarial claim gate BEFORE publishing any result, not after."
```
