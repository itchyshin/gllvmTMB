# Request → whoever takes D3: the ridge's `τ = 2` is scale-dependent, ON by default, and undisclosed

Date: 2026-07-30. From: Claude, the VA/VGH lane (`claude/vgh-pluralism-20260730`, merged as #840).
Routed via Shinichi. **This is a request to take work, not a report of work done** — D3 is your
lane's surface and I have deliberately not touched it.

---

## The ask, in one line

**Please take D3 from your own audit, and take it as a CLASS rather than a single constant** — I
found a second instance of the same defect on a different surface the same day, which makes it a
pattern worth one sweep instead of two separate fixes.

## Why this is more urgent than its "recorded" status suggests

Your `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md` files D1 and D2 as issues
but leaves **D3 and D4 "recorded here pending a decision."** Nobody owns that decision, so it will
sit. Three facts from your own audit make it a live user-facing risk rather than a note:

1. **It is ON by default.** `R/fit-multi.R:5255`, with the comment at `:5369` — *"Default tau = 2 —
   ON whenever AGHQ is on."*
2. **It is net-harmful or inert across your entire measured range.** Your D3 table, median σ by true
   `lam_sd`:

   | true `lam_sd` | 0.5 | 1 | 3 |
   |---|---|---|---|
   | laplace | 1.030 | 0.993 | 0.959 |
   | laplace + ridge | 1.028 | 0.993 | **0.920** |
   | aghq | 1.052 | 1.019 | 1.000 |
   | aghq + ridge | 1.054 | 1.016 | **0.976** |

   At `lam_sd = 3` it makes **both** engines worse; at 0.5 and 1 it does nothing. So across the
   three scales you measured, the default never helps and sometimes hurts.
3. **🔴 D3 composes with D4 into something worse than either.** D4 is *"penalised-fit disclosure is
   partial and sometimes false."* Together: a user can receive a **silently penalised fit** — a MAP
   rather than an MLE — with no reliable disclosure that a penalty was applied, in a regime where
   the penalty degrades the estimate. That composition is not stated in the audit and is, I think,
   the strongest argument for acting.

I am not proposing what the fix is — that is your call and your evidence. I am arguing the decision
should be *made* rather than left pending.

## The second instance — the same defect on my surface

`loading_absolute_thresh = 6` in the Heywood gate (`R/diagnose.R:440`) has the identical structure.
Its justification is explicitly **link-scale**: *"the latent scores are standard normal by
identification, so a binomial loading IS the trait's latent SD in link units"* (`:530-533`). Two
consequences I measured:

- It is **binomial-gated** — the row `return(NULL)`s unless `family_id == 1L` rows exist
  (`:464-471`), verified by running `check_gllvmTMB()` on a gaussian fit: 13 rows, no such row. So
  there is currently **no absolute-loading criterion for gaussian at all.**
- On identity link the constant is **not scale-free**: **multiplying `Y` by 10 lifts every loading
  past 6** with no pathology and no new warning. Adversarial fits reached raw `max|Λ̂| = 32.64` on
  scale-heterogeneous and t₂-contaminated data, all healthy and all converged.

**Your `τ = 2` encodes "loadings are about 2." My `6` encodes "loadings are about 6 in logit
units." Same defect family: a hardcoded magnitude constant standing in for a scale the data
actually determines.** Two lanes, two constants, one day.

## What I'd suggest the work is — your evidence, your call

1. **Decide D3.** On your own numbers the default never helps. Minimum viable: warn when the ridge
   is active *and* `τ` is likely to bind (compare `τ` to the fitted loading scale). Stronger: make
   the default conditional, or scale-relative.
2. **Make the constants scale-relative rather than absolute.** A scale-free reformulation exists on
   my side and may transfer: across **59 gaussian fits** I found `max|Λ̂|` stayed **below that
   dataset's own largest trait SD** in every one (max ratio 0.961). The data's second moments are
   the natural yardstick — `log|Σ|` pins Λ to them (the gaussian marginal likelihood is coercive in
   Λ: measured −592.8 → −1352.3 under `Λ → 1000Λ`). A ratio to typical loadings or to trait SDs is
   scale-free where a bare constant is not.
3. **Sweep for the rest of the class.** Grep the diagnostic and penalty surfaces for hardcoded
   magnitude constants and ask of each: *what scale does this assume, and what happens if the data
   is 10× that?* Cheap now, and cheaper than finding each one separately over six months. I have
   **not** run this — it spans your surface and mine and wants one owner.
4. **Fix the gaussian gap or declare it out of scope.** Either give gaussian an absolute-loading
   criterion, or state that the gate is binomial-only by design. Right now it is ambiguous, and I
   tripped over it: I published a claim comparing a gaussian quantity to that threshold and had to
   withdraw it.

## Two questions back, if cheap

1. Was the binomial gating of `loading_absolute_thresh` **deliberate** (gate is binomial-only by
   design) or **incidental** (it happens to live inside the binomial row)? That determines whether
   item 4 is a gap or a non-issue.
2. Does `aghq_ridge` have any **gaussian** test coverage? My lane's finding is that gaussian has no
   loading-runaway tail for either engine — so gaussian ridge cells may be measuring nothing.

## What I already did, so you don't redo it

- Full cross-lane brief with all four of my findings and the convergence analysis:
  `docs/dev-log/handover/2026-07-30-to-la-aghq-ridge-lane-gaussian-findings.md` (on `main` via #840).
- Nothing in `R/`, `src/`, `NEWS.md` or `check_gllvmTMB()` was changed by my lane —
  `git diff --stat -- R/ src/` against `main` is empty.
- The withdrawn claim and its reason are recorded, so the error is not inherited.

No reply needed on the questions if they are not to hand. The **ask** is item 1: make the D3
decision rather than leaving it pending.
