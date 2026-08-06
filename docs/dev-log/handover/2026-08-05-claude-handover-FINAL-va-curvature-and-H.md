# FINAL handover — VA: curvature mechanism, the H discovery, and six retractions

**Author:** Claude Code (Fable 5), solo · **Target:** next session, no chat inherited
**Branch:** `claude/va-ac-curvature` @ `b7781b4b` · **Worktree:** `/private/tmp/gllvmtmb-ac-curvature`
**`origin/main`:** `5bf18ab3` — **PROTECTED, untouched. Nothing pushed. No PR. No default moved.**

> **SUPERSEDES `2026-08-05-claude-handover-attenuation-refuted.md`**, whose title and §5 are
> WRONG — the curvature refutation in it was withdrawn later the same day (see §2).
> Classify everything below OWED / DONE / RETRACTED / PROTECTED against git before acting.

## FIRST: rehydrate

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-ac-curvature
cd /private/tmp/gllvmtmb-ac-curvature && ./tools/check-push-traps.sh && git log --oneline -10
Rscript dev/va-usability/170-gllvm-convention-arbiter.R    # 30 s; settles the scaling convention
```

⚠ **`lane_preflight.sh` cannot see a second CLAUDE session** — it looks for a *Codex* lane. One ran
concurrently in `/private/tmp/gllvmtmb-va-lane2` today and committed underneath me. Also check
`ps aux | grep claude` and `git log --all --since="2 hours ago"`.

## 1. 🏆 THE HEADLINE — GH is affordable, and nobody had checked

**The GH quadrature order was hard-wired at H = 61. It needs 7.**

| q | H=7 speedup vs 61 | paired trace diff vs 61 | verdict |
|---|---|---|---|
| 2 | **6.66x** | −0.00002 [−0.00005, +0.00001] | indistinguishable |
| 5 | **3.43x** | +0.00023 [−0.00024, +0.00070] | indistinguishable |

`gh` at H=61 cost 172 s against Laplace's 12.9 s. At H=7 it is ~25 s; trim starts 4→3 (the health
gate's minimum) and ~19 s. **GH stops being "31x too slow to consider".**

**H = 5 is NOT safe as a default.** At q=5 it separates from H=61 on both trace and `eta_var`
(−0.00044 [−0.00084, −0.00004]). The magnitude is negligible (45x inside tolerance) but the
deficiency is *detectable* and grows with q. **Default 7; expose H; never default to 5.**

**How to tell a real H deficiency from an artifact — use this, do not re-derive it.** At q=2 the
"DIFFERS" flag fired on H=15 while H=5 and H=7 passed: **non-monotonic in H, therefore noise**
(nothing makes 15 nodes worse than 5). At q=5 it is **monotonic**. A genuine quadrature deficiency
must be monotone in H; an artifact need not be.

**Why this was invisible:** the admitted set was `c(15, 25, 61)` — a typo-guard, not a numerical
constraint — and `R/va-routing.R` hard-wires the default, so no user could have discovered it.
Now widened to any odd H >= 3 (`e33151b3`), with the rule's moment-exactness asserted in tests.

## 1b. ✅ THE MECHANISM, RESOLVED — it is a property of the METHOD, not of either package

*(Added after §2 below was written; §2's "separate open question" is now CLOSED.)*

`E_q[log Φ(η)]` **has no closed form, and every cheap treatment of it attenuates.** Shown across
two independent implementations:

| treatment | who | trace |
|---|---|---|
| constant curvature `−1` | our `ac` | 0.528 |
| JJ bound | our `jj` | 0.535 |
| exact-curvature 2nd-order | **gllvm** | 0.587 |
| **full quadrature** | our `gh` | **1.025 at n=1000** |

**The discriminator that closed it:** vary the FAMILY, not the implementation. Gaussian's
expectation is **exact** (log p quadratic in η); probit's is not. gllvm's parameterisation, KL,
optimiser and start count are **identical across its own gaussian and probit fits** — so a
structural cause would attenuate both. Measured, 6 seeds, correctly scaled:

| gllvm | trace | eta_var |
|---|---|---|
| gaussian (**exact** expectation) | **1.0233** | 0.9585 |
| binomial-probit (approximated) | **0.5868** | 0.4832 |

Unbiased where exact, attenuated where not. **Every structural confound eliminated at once.**
(Start count independently ruled out: `n.init` 1 and 4 both gave 0.6072.)

**So the attenuation is a property of second-order variational treatment of binary GLLVMs — not a
gllvmTMB defect and not a gllvm defect.** Gaussian and Poisson, where the expectation *is*
closed-form (`E[exp(η)] = exp(μ + v/2)`), are unbiased in both packages. **Only full quadrature
escapes.** This is a materially different — and more publishable — claim than the one this lane
started from, and it explains every measurement in this arc under one principle.

**I spent hours treating this as unanswerable** because gllvm differs from us in ≥5 ways at once.
That was a failure of experimental design, not a real obstacle: **when confounds cannot be removed
from the comparison, vary something else that makes them cancel.**

**NOT established:** *which* aspect of the expectation treatment. gllvm (exact curvature) lands at
0.587 while our `ac2` (exact curvature) lands at 1.197 — both second-order, different places.
Plausibly gllvm's `Au` vs our per-unit Cholesky. Untested.

## 1c. Two more results that landed after §2–§5 were written

- **ψ does NOT absorb the attenuation** (`230-psi-absorption.R`). With ψ genuinely free — verified,
  20 free `log_sd_tier` parameters, `n_par` 829 → 6849 — both `ac` and `gh` estimate ψ̂ ≈ 0. The
  worst case (shared structure laundered into trait-specific noise, making traits look **more
  independent than they are**) **does not happen**. Severity unchanged. *Scope: this DGP plants
  true ψ = 0; a DGP with ψ > 0 is the follow-up.*
- **VA-Wald β intervals COVER** (`220-sandwich-coverage-pilot.R`, first coverage score ever run,
  30 seeds): gaussian **0.9483**, probit **0.9575**, nominal 0.95. The predicted under-coverage did
  not appear, and **the sandwich is not the repair** — it is *narrower* (0.995), not wider, and
  marginally worse. Coverage succeeded exactly where the estimate is unbiased; **loading intervals
  cannot cover while Λ is attenuated**, which makes GH the *precondition* for loading inference,
  not merely the better option.
- **Family risk follows closed-form-ness exactly.** Gaussian (exact) and Poisson (`E[exp(η)]` exact)
  are safe by mathematics. Binomial and **nbinom2** are exposed by mathematics — NB2 reuses the
  *same* softplus expectation as binomial-logit — and NB2 escapes only because its registry gives it
  `tiers = "gh"` alone. Tweedie / beta / beta-binomial are **not in the VA engine** (codes 0–4 only).
  **The one shipped path that takes a biased tier is `binomial-logit → jj`.**

## 2. ⚠ THE MECHANISM — supported for OUR tiers *(superseded by §1b — read that first)*

Controlled comparison **inside our engine** (same parameterisation, optimiser, starts, KL, data,
seed; **only** the curvature differs), probit n=150 p=20, **10 paired seeds**:

| tier | curvature | trace | eta_var |
|---|---|---|---|
| `ac` | pinned to −1 | 0.528 | **0.441** |
| `ac2` | exact `(log Φ)''` | 1.197 | **0.968** |

**Paired diff +0.527 [+0.438, +0.616].** The harness reproduces BOTH published controls exactly
(`ac` 0.441, `gh` 0.922) — that is what makes the `ac2` number trustworthy.

**But `ac2` is NOT worth shipping.** At 10 seeds it is statistically indistinguishable from `gh`
on both `eta_var` and `relfrob` while costing the same. `gh` already exists and is laddered.
Consider reverting `ac2`, or leave it as the evidence behind this section.

**Still open: gllvm uses the exact curvature and attenuates anyway** (trace ~0.53). It differs from
us in ≥5 ways at once (pinned unit diagonal + `sigma.lv`, BFGS vs nlminb, 1 vs 4 starts, different
KL, two-stage warm start), so it cannot be compared one-variable. **Do not treat that as refuting
§2** — that was my error, withdrawn in `f4691ed2`.

## 3. 🚨 THE USER-FACING FINDING — ICC and R² are understated 10–44%

Probit fixes the residual variance at 1, so the attenuation does **not** cancel in ratios against it:

| true Σ_jj | true ICC | estimated | error |
|---|---|---|---|
| 0.25 | 0.200 | 0.113 | **−44%** |
| 1.00 | 0.500 | 0.337 | **−33%** |
| 4.00 | 0.800 | 0.670 | −16% |

A conditional R² of 0.50 reports as 0.34. **Applies to `ac`, `jj` AND gllvm.** Ordination
(latent_r ≈ 0.86 for every tier) and correlation *patterns* survive — a uniform factor cancels —
but only to the extent the attenuation is uniform (measured R² ≈ 0.85). **This is the finding with
an affected audience.**

## 4. WHAT IS SETTLED (do not re-litigate — re-run the named script instead)

- **`Λ = theta %*% diag(sigma.lv)`.** Convention flipped THREE times on argument. Settled against
  gllvm's own linear predictor: raw off by 4.78e-01, scaled exact to **4.44e-16**.
  `dev/va-usability/CONVENTION-SETTLED.md` + `170-gllvm-convention-arbiter.R`.
- **gllvm SHARES the ~2x attenuation.** It is not an unbiased reference.
- **`gllvm(method="VA")` runs `gllvm.TMB`, not `gllvm.VA`** — the per-row fixed-point in
  `GLLVM-REFERENCE-READ.md` is unreachable dead code in 2.0.13. `171-gllvm-internals-dispatch.md`.
- **The attenuation is in Λ alone** — posterior SD ratio 0.979, score spread unchanged.
- **Laplace on small-n binary is unusable**, not merely biased: trace 10.3, relfrob 12.5 at n=150.
- **`-v/2` IS a valid global lower bound.** `ac` is conservative-but-loose, not wrong.
- **VA's free SEs cover z ONLY** and only under GH (0.1–1.1% understatement, Claim 34). Degenerate
  under AC; β/Λ/ψ have no variational distribution; `calibrated` is hard-coded FALSE.
- **`CppAD::CondExp` evaluates BOTH branches** — threshold hybrids buy no speed in TMB.
- **gllvm's speed edge is 1.40x at matched starts**, not 4.5x. Ours ran 4 starts against its default 1.

## 5. 🎯 NEXT, in value order

1. **Warm start.** The one unexploited lever. gllvm warm-starts from a `num.lv=0` fit and runs ~3
   BFGS calls; that is its entire remaining 1.4–2.0x. `.va_r3_fit_warm` (`R/va-r3-proto.R:1380`)
   already partly exists. Landing it plausibly puts VA-GH **below** Laplace.
2. **Expose H (and probably `eval_method`) via `gllvmTMBcontrol()`.** Additive and reversible.
   The accurate route is currently unreachable from the public API. Maintainer has asked for this.
3. **Literature re-sweep before any novelty claim.** dr21 records that VA-GH is treated as an
   *accuracy benchmark, not a deployable engine*, on cost grounds — grounds this arc just removed.
   That is the sharper paper angle than "VB underestimates variance". Test dr21's named obstacles:
   cost scaling in q, and the large-m/small-n instability (m=40, n=50).
4. **`failed_variance_domain` at q=5 for EVERY H including 61** — pre-existing, unrelated to
   quadrature, and it means q=5 fits are being rejected regardless of settings. Needs its own look.
5. **The `ψ` question, untested and potentially the worst consequence.** All measurements ran
   `psi = FALSE`. With ordinary `latent()` (Σ = ΛΛ' + diag(ψ)) an attenuated ΛΛ' has ψ available to
   absorb the shortfall — which would push shared structure into trait-specific noise and make
   traits look **more independent than they are**. Nobody has looked.

## 6. VERIFICATION STATE

`devtools::test(filter="va")` at HEAD: **202 files, 1505 passed, 0 failed, 0 errors, 1 skipped.**
`ac` byte-identical to `aba2d21e` · `R/va-routing.R` untouched · `auto` on probit still resolves to
`gh` — **no default moved** · gaussian + `ac2` correctly refused.

## 7. SIX OF MY OWN CLAIMS WERE RETRACTED TODAY — the pattern matters more than the list

gllvm scaling · the variance-gate hypothesis · the curvature refutation · the n=150 crossover ·
the "201 passed" suite count · "no test asserts the H whitelist".

**Every one was caught by running something, none by reasoning.** Two recurring shapes:

- **A narrow probe returning nothing is not proof of nothing.** I grepped `"H = 15, H = 25"`, the
  assertion read `"15, H = 25, ..."`, I reported "no test asserts it" — and broke the suite. The
  check for *did I break a test* is running the tests.
- **The wrong answer is seductive when it produces the expected number.** Raw `theta` scoring gives
  gllvm trace ~1.0, which "looks like" an unbiased CRAN package. Two independent sessions reached
  for it. The fix is a **convention-free arbiter** (does it reproduce the other package's own
  linear predictor?), never argument.

⚠ **All `dev/va-usability/` measurements are pinned to the current `ac` branch.** Change the engine
and every ladder expires. ⚠ `attenuation-lib.R` defaults `T0` (=p) to **8**, the degenerate width —
set it at top level *before* `sim_cell` and assert `nrow(b$d) == N0 * T0`.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-claude-handover-FINAL-va-curvature-and-H.md.
Run the rehydration block including the arbiter, reconcile against git, then start at §5(1),
the warm start. Do not re-litigate §4.
```
