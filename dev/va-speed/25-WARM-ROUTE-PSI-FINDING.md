# The warm route's variance-recovery claim was never measured — and there is a mechanism for it failing

**Status: OPEN FINDING, 2026-08-03 (lane 2).** The 3-seed confirmation at the arc's own regime
was still running when this was written; §4 carries whatever it returned. §§1–3 do not depend on it.

## 1. The claim

The 2026-08-03 handover, §4, and the lane-2 GOAL both state:

> Because the route **ends on GH**, it inherits GH's variance recovery and therefore
> **avoids §3's defect entirely.** That is why this is the answer and AC-alone is not.

This is the load-bearing reason the warm route — not AC alone — is the arc's recommended answer.

## 2. It was never measured, and the DGP could not have measured it

The warm route's entire evidence base is `dev/va-speed/13-warmstart-gh.R` (claim 15: 36.8 vs
138.6 iterations, 5 seeds). Two facts about it:

**(a) The DGP plants no ψ.** Line 32:

```r
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
```

There is **no `u` term**. Compare `23-warm-route-confirm.R`, which builds
`u <- matrix(rnorm(N0*T0, 0, PSI), N0, T0)` and adds `+ u` with `PSI = 0.6`.
The script's own header (lines 5–6) says it uses *"the DGP of `dev/va-speed/10-seed-cell.R`"* —
which is **claim 8's DGP**.

**(b) But the fit still carries the ψ tier.** Line 78: `unique = TRUE`.

So the warm route was validated by fitting a ψ tier to data containing no ψ. That is precisely
claim 8's setup, which claim 13 refuted: *"Measured on a DGP planting ψ = 0 — AC's single most
favourable corner, since AC's known failure is collapsing ψ."*

**(c) ψ was never in the output.** `13-warmstart-log.txt` columns are
`seed · arm · objective · rel_frob · iterations · fn_evals · convergence · max_grad`.
**No ψ column.** Variance recovery was not measured, and on that data there was nothing to recover:
collapsing ψ to zero *was the correct answer*, so the failure mode is invisible by construction.

**This is the arc's own recorded process lesson repeating on the very next result.** The ledger
already says: *"A gate passed on a favourable DGP is not a gate passed… State the regime with the
result, every time."*

## 3. A mechanism for why "ends on GH" does not rescue it

This is not merely unmeasured — the route's construction predicts the opposite.

`.va_r3_fit_warm()` (`R/va-r3-proto.R:1337-1379`):

1. Stage 1 fits with `eval_method = "ac"`, `n_starts` **forced to 1** (`:1348`).
2. Stage 2 builds the GH objective and calls
   `nlminb(start = ac$best$par, ...)` (`:1369`) — handing GH **AC's entire parameter vector**,
   `log_sd_tier` (the ψ parameters) included. There is no multi-start at stage 2 either.

`nlminb` is a **local** optimiser. If AC has collapsed ψ, stage 2 *begins inside the collapsed
basin*. Ending on GH changes the objective; it does not change the starting point.

And the collapsed point is unusually sticky, because ψ is parameterised on the log scale:

> ∂f/∂(log σ) = (∂f/∂σ) · σ

The gradient carries a factor of σ itself. At σ ≈ 2e-4 the gradient in that coordinate is
scaled to ≈ 0, so the direction looks flat and the optimiser has almost no pull to climb back
out. **ψ → 0 is an attracting boundary in log coordinates.**

By contrast, cold GH starts from the default `log_sd_tier <- rep(log(0.3), n_sd)`
(`R/va-r3-proto.R:1096`, `:1878`) — a healthy ψ = 0.3, well away from the boundary — which is
exactly why cold GH recovers ψ where the warm route need not.

**Prediction:** the warm route inherits AC's ψ collapse whenever AC collapses ψ, i.e. at low
`n_trials` — the regime claim 13 identified. Cold GH is unaffected.

## 4. Evidence so far

**Smoke, 1 seed, N=60 T=8 q=1 n_trials=6 ψ=0.6** (Totoro, load ~1; `24-totoro-smoke.R`):

| arm | objective | rel_frob | ψ (truth 0.6) |
|---|---|---|---|
| cold GH | **863.20** | 0.43276 | **0.5264** |
| warm | 879.15 | 0.38538 | **0.0007** |

The warm route collapsed ψ and reached a **worse** objective — relative difference 1.9e-2, so
the two arms did **not** find the same optimum, contradicting the "same optimum" property too.
Note `rel_frob` was *better* for warm (0.385 vs 0.433): with ψ collapsed, variance is absorbed
into the loadings, which can flatter the loadings metric while the variance decomposition is
wrong. **This is the "identified but biased" hazard — a confident zero for a variance that is
really there — and a loadings-only score cannot see it.**

**One seed at a cell smaller than any the arc has tested is NOT a refutation, and none is
claimed.** It was a red flag with a mechanism attached. The confirmation below is the test that
matters.

### 4b. THE CONFIRMATION — 3 seeds, the arc's own regime, quiet machine

`23-warm-route-confirm.R`, N=100 T=10 q=1 n_trials=6 **ψ=0.6 planted**, interleaved and
order-rotated, run on **Totoro** (load median 1.1, range 1.0–1.2, **0 other R processes**;
the script's own verdict line reads `USABLE`). This desktop cannot produce a comparable number —
its baseline load is ~12–15 from Firefox/WindowServer/Cursor/Defender with CPU only ~50% idle.

| seed | arm | secs | iters | objective | rel_frob | **ψ (truth 0.6)** |
|---|---|---|---|---|---|---|
| 1 | cold | 192.5 | NA | **1838.44** | 0.32442 | **0.6207** |
| 1 | warm | 12.0 | 158 | 1890.30 | 0.33526 | **0.0001** |
| 2 | warm | 14.4 | 218 | 1734.82 | 0.61454 | **0.2427** |
| 2 | cold | 177.0 | 2 | **1715.90** | 0.67755 | **0.5023** |
| 3 | cold | 192.2 | 2 | **1810.82** | 0.37740 | **0.5074** |
| 3 | warm | 13.4 | 137 | 1862.54 | 0.34539 | **0.0000** |

**Medians — cold: 192.19 s, rel_frob 0.37740, ψ 0.5074. Warm: 13.40 s, rel_frob 0.34539,
ψ 0.000118.**

**Four findings, in order of importance:**

1. **The ψ collapse is confirmed, 3 seeds of 3.** Warm returns ψ = 0.0001, 0.2427, 0.0000
   against a planted 0.6; cold GH recovers 0.6207, 0.5023, 0.5074 on the same data.
   Seed 1's pair — warm 0.0001, cold 0.6207 — reproduces **claim 13's AC-vs-GH numbers exactly**.
   The warm route behaves like **AC**, not like GH. The claim in §1 is **REFUTED**.

2. **The arms never reach the same optimum, and warm is always worse.** 1890.30 vs 1838.44;
   1734.82 vs 1715.90; 1862.54 vs 1810.82 — warm higher (worse) in every seed, by 19–52 nats.
   Claim 15's "same optimum to 4–5 s.f." does **not** survive ψ > 0.

3. **`rel_frob` is slightly BETTER for warm** (median 0.345 vs 0.377) — and this is the trap,
   not a mitigation. With ψ collapsed, the variance is absorbed into the loadings, flattering
   the loadings metric while the variance decomposition is wrong. **A loadings-only score cannot
   see this failure** — which is exactly why the original evidence, whose log had no ψ column,
   reported success.

4. **The 14.34× median speedup is real, and not quotable as a speed result.** The arms solve
   different optimisation problems (claim 24: the warm route silently cannot profile the
   variational block) and land on different optima. A 14× speedup to a collapsed variance is not
   a speedup. It also supersedes the "~3× whole-fit" arithmetic, which was never an end-to-end
   measurement.

**Also worth recording:** at this regime **neither arm meets the accuracy gate** of
`rel_frob ≤ 0.298` (cold 0.377, warm 0.345). The gate was set on a different regime and does not
hold at ψ = 0.6, n_trials = 6.

## 5. What follows regardless of the confirm

- **Claim 15's iteration result stands, narrowed:** it is real *for ψ = 0*. The "same optimum
  to 4–5 s.f." property was also only ever established at ψ = 0.
- **The variance-recovery corollary is unmeasured** and must not be quoted (ledger claim 22).
- **Any future warm-route measurement must plant ψ > 0 and report ψ**, or it repeats the error.
- The collapse replicated, so the hypothesised fix was tested. **It works — see §6.**

## 6. THE REPAIR — tested, and it recovers the route

`26-warm-reset-probe.R`, same regime and discipline as §4b (3 seeds, interleaved, order rotated
per seed, Totoro, 0 competing R jobs). Three arms: cold, warm as-was, and `warm_reset` — which
keeps the warm loadings, fixed effects and variational block and resets **only** `log_sd_tier`
to its ordinary default of log(0.3).

| arm | median secs | median objective | median rel_frob | median ψ (truth 0.6) |
|---|---|---|---|---|
| cold | 192.4 | 1810.82 | 0.377405 | **0.5074** |
| warm (as-was) | 13.3 | 1862.54 | 0.345388 | **0.0001** |
| **warm_reset** | **15.7** | **1810.82** | **0.377406** | **0.5074** |

Per seed, `warm_reset` matches cold to 4–5 significant figures on **objective, rel_frob and ψ
simultaneously** — 1838.44/0.32442/0.6207, 1715.90/0.67755/0.5023, 1810.82/0.37741/0.5074 — and
is **12.3× faster**. The mechanism in §3 is therefore confirmed: the collapse was a *boundary
start*, not a property of ending on GH.

**Shipped** in `43341784` with a regression test (`tests/testthat/test-va-r3-warm-psi.R`, 4/4)
that plants ψ > 0 and asserts recovery — the check the original evidence could not perform.
**Full VA suite green afterwards: 966 pass, 0 fail, 0 warn** (`results-lane2/vatests.log`).

**What this does NOT cover** (ledger claim 28): one cell, three seeds. Other `n_trials`, other
N/T, q > 1, and the structured tiers are untested, and whether 12.3× holds elsewhere is unknown.
Nothing is promoted; `default_tier` is still `"gh"` and the integration fence is shut.

**The honest headline:** the arc's "best result" was wrong in the way that mattered, and is now
right — 12.3× at *identical* accuracy and variance recovery, rather than 14.5× at a collapsed
variance. It was found only because this run planted ψ > 0 and printed it.
