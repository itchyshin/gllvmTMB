# Claude → Claude handover — VA-in-0.6 lane, closed and ready to hand off

Date: 2026-07-31. Author: Claude. Target: **Claude** (same platform), fresh lane.
Branch `claude/va-in-06-20260730`, **pushed**. Worktree `/private/tmp/gllvmtmb-va-in-06`.
Commit list: `git log --oneline origin/main..origin/claude/va-in-06-20260730`.

## The position, settled

**Laplace stays the default, with AGHQ for accuracy. VA and EVA are opt-in.** (Maintainer,
2026-07-31.) That framing is what the evidence supports and it changes the bar: an opt-in route
does not have to *beat* Laplace, it has to work correctly and be honestly fenced. Gate 3's rule —
*no more than 0.05 worse than ML* — is exactly that shape.

## What landed

| | |
|---|---|
| **0.6 reversal** | recorded, and swept across **every live surface**, not the first one found |
| **Gates 0, 1, 2** | **ALL PASS**, measured (352 + 1,469 tests, `NOT_CRAN=true`) |
| **Gate 3** | pre-registered, frozen, harness built and smoked. **NOT RUN** |
| **separation guard** | landed — closed a real gap on `main` |
| **`integration=` API** | built, fenced, documented, tested. **Not yet routed** |
| **EVA** | ours ≡ gllvm's; the catastrophe is genuine, not our bug |
| **Estimator (GH vs JJ)** | still open — Gate 3 is designed to settle it |

## 🔴 The one thing the next lane must do first

**Route `integration=` through the fit path.** `gllvmTMBcontrol(integration = c("laplace","va","eva"))`
exists, the fence errors correctly outside the evidenced region, and `gllvmTMB()` **aborts
explicitly** rather than silently returning a Laplace fit. What is missing is the translation layer:
`.approximation_engine_fit()` takes long-format vectors (`y, n_trials, X, unit_id, trait_id, q`)
while `gllvmTMB()` takes a formula. That plus extractor/class compatibility is the work.

It is deliberately **not** half-wired. A partly-routed argument that sometimes ignores itself is the
exact failure `gllvmTMBcontrol()`'s own comments record for arguments `...` used to swallow.

## What the EVA investigation concluded — read this before re-litigating it

**It is not our bug.** The reconstruction in `run-grid.R:109-110` is byte-identical to gllvm's own
`getLoadings()`; the link is live and correct; `num.lv` and the intercept structure match the DGP.
**Restarts make it worse**, because gllvm picks the restart with the best EVA objective and the
degenerate mode *has* the best EVA objective. Same shape as this repo's earlier Laplace finding that
*"the runaway IS the maximum-likelihood solution"* — **do not re-litigate it with more starts.**

**But the headline number was mis-framed, by me.** `median(attenuation) = 4.8e7` is a **mixture
statistic over a bimodal distribution** — a **67.7% degenerate-mode rate** crossed with an
otherwise-ordinary estimator. It is *not* a seven-orders-of-magnitude point-estimate error. Never
quote it as one.

**And one defect is genuinely ours:** we discarded gllvm's own degeneracy signal — `fit$sd` collapses
to the scalar `FALSE` on these fits and nothing flagged it. Any future gllvm arm must read it.

**The literature confirms direction, not magnitude.** An independent paper on the identical
Bernoulli-logit model finds EVA's `ΛΛᵀ` error above 100% relative with coverage as low as 39% while
`B` stays well-calibrated. So "EVA's covariance recovery is unreliable here" is supported; the
seven-orders figure is not. The EVA paper never compared EVA against standard VA on Bernoulli-logit
at all, because closed-form VA is excluded for logit — so our EVA-slower-than-VA timing has no
precedent either way. gllvm's own vignette already recommends multiple `n.init` and shows loadings
at −21 to +37 when Hessian diagnostics flag non-convergence: the mode is documented upstream.

**Right frame: Heywood-case / boundary-solution theory**, not ordinary estimator bias — which is the
frame this package's degeneracy work already uses.

### The mechanism, derived — and it dovetails with Polya

EVA's only variance penalty is `0.5·b''(η)·V`, and `b''` decays like `exp(−|η|)`. Along a scaling
ray that penalty rises to 4.8e7 and then **collapses to 24.7** — a barrier the optimiser tunnels
through into a spurious mode. Scored under **EVA's own objective**: runaway **−327.4**, VA solution
−467.5, **true parameters −618.6**. *EVA prefers the runaway to the truth by 291 nats.* Under the JJ
bound the ordering reverses. **VA rejects the runaway; EVA rewards it.**

That is the exact complement of Polya's result: JJ's objective is **coercive** in `‖Λ‖` so it cannot
run away; EVA's penalty **vanishes** at large `|η|` so it can. Two engines, opposite failure modes,
one mechanism.

**And the corrected characterisation, which supersedes every "7 orders of magnitude" line:**
degenerate-mode rate **67.7%** (203/300), strongly regime-dependent — **100% at p=8, 10% at
p=40/q=2** — while median attenuation over the **non-degenerate 32.3% is 1.2111**, comparable to
`gtmb_laplace` (1.10) and `gtmb_gh` (1.45). **EVA is an ordinary estimator with a mode-selection
failure**, not a broken one.

**Use `is.list(fit$sd)` as the degeneracy guard** — 6/6 correct, including a degenerate fit gllvm
reports as converged. `convergence` is useless here (257 "converged" rows, median attenuation 7.6e6).
We muffled the good signal at `run-grid.R:82`.

**Do not try more restarts.** On `n=100 p=20 q=2` the default fit is *good* (1.16); `n.init=5` finds
a *better EVA optimum* at 3.8e8 and `n.init=10` at 6.3e8. The standard remedy destroys the estimate.

**So EVA's next work is family coverage, not algorithm repair.** `.eva_fit()` accepts only
`binomial`, `poisson`, `gaussian_anchor` — precisely the families where VA is already exact or
tractable. Tweedie, beta, `betaH`, `orderedBeta`, ordinal — the families EVA exists for — are
unimplemented. That is 0.7 work, and Design 105 §10 records the architecture breaks for multinomial
and zero-inflated.

## Gate 3 — frozen, unblocked, unrun

3 truths × `q ∈ {1,2,4}` × `p ∈ {8,20,80}` × `n ∈ {100,400}` × 40 seeds × 3 arms = **6,480 fits**.
Bernoulli with the separation guard live; rank fixed at planted `q`; every attempted fit in the
denominator; both VA arms so the campaign also settles the estimator. ~5 h to 2 days locally; Totoro
would need a source push and reinstall first — a shared-box write, so the maintainer's call.

**`q ≤ 4` ships only if the q=4 cells pass on their own terms.** A pass at q ∈ {1,2} does not
license it.

## Traps — every one cost something

1. **`NOT_CRAN=true` or Gate 1 silently skips.** The same file reports "183 passed, 8 skipped" and
   looks clean; those 8 skips *are* Gate 1.
2. **Never filter on `status`/`admitted`.** The `max_projected_variance <= 4` guard rejects GH
   **14.5%** and JJ **0.0%**; on 84/320 matched cells GH is flagged where JJ is healthy on identical
   data. And at `n_starts = 1`, `admitted` can never be `TRUE`.
3. **gllvm's top-level `link=` is a silent no-op** for binomial — use `family = binomial(link=)`.
4. **Convergence is never health.** 56/79 gllvm fits reporting `convergence=TRUE` are beta-exploded;
   our Laplace reaches κ = 1.5 million with `pdHess = TRUE`.
5. **Recompute before citing, and check the gradient a pooled summary pools over.** Nine claims were
   withdrawn this arc; the estimator inversion was hidden by a median pooled over `p`.
6. **Don't add q to the truths loop.** Nested `truth × q × p` order means inserting a q shifts the
   RNG stream and rewrites frozen truths. Append under a separate seed; the code asserts this.

## Still open for the maintainer

1. The **estimator** — GH or JJ. Gate 3 decides; neither arm is clean (GH inflates and is caught, JJ
   contracts and was not being caught).
2. **Compute target** for the 6,480 fits — local, or authorise the Totoro push.
3. Whether **`"eva"`** stays a fenced value making no claim, or is dropped from `integration` until
   its own evidence exists.
4. Long-open, unrelated: `test-start-method-residual.R:156` fails the nightly under
   `GLLVMTMB_HEAVY_TESTS=1`; recorded as maintainer's call on 2026-07-27, never resolved.

## Resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git fetch && \
  git worktree add /private/tmp/gllvmtmb-va-next claude/va-in-06-20260730
```

Read: this file → `2026-07-31-gate0-scope-extension-and-s11-departure.md` →
`2026-07-30-gate3-preregistration.md` → `2026-07-31-eva-misuse-probe.md`.
