# Lane brief — VGH as an estimator, and the pluralist route

Date: 2026-07-30. Author: Claude. Lane: `claude/vgh-pluralism-20260730`,
worktree `/private/tmp/gllvmtmb-vgh-pluralism`, based on `main` @ `a51ca881`.
Predecessor: `docs/dev-log/handover/2026-07-30-claude-handover-heywood-gate-landed.md`.

## The gate is lifted

The Heywood-gate goal fenced *"any VGH campaign — it is gated behind Arc B and
must not run first."* **Arc B is complete and merged (#838), so the fence is
lifted.** Two decisions were taken at that close and should not be re-opened:

1. **The Heywood gate ships with ONE new statistic**, not two. Six candidates
   were measured; only `loading_absolute_thresh` (on `max_loading_unit`) earned
   its place. Maintainer accepted the measured answer on 2026-07-30.
2. **`aghq_ridge` is announced** in `NEWS.md` with both costs stated.

## Why this lane exists

**The Heywood gate is a Laplace-specific patch for a pathology VA does not
have.** That is measured, not argued:

| | degenerate | of which silent |
|---|---|---|
| Laplace, paired binomial (148 fits) | **50 (33.8%)** | **49** |
| VGH, same data | **0 (0.0%)** | — |
| `gtmb_jj` (Totoro grid, 320 fits) | **0** | — |
| `gllvm_va` (Totoro grid, 600 fits) | **0** | — |
| `gtmb_laplace` (Totoro grid, 601 fits) | **70 (12%)** | **59** |

Sources: `dev/heywood/vgh-vs-laplace-degeneracy.csv`,
`dev/totoro-grid/results/RESULTS.md` §4.

**Shinichi's framing, which the evidence supports:** *"VGH does not need to be
better at everything — it can be just good for some things and we can mix it
with LA too. We want to be flexible and innovative."* The two engines fail in
**disjoint** ways, so the route is not "VA replaces LA" but **both engines plus
an honest gate saying which to trust** — which neither `gllvm` nor gllvmTMB
ships today.

## What is already known — do NOT re-derive

- **Our JJ engine IS `gllvm`'s VA algebra**, verified: median relative difference
  **2.69e-07**, 100% agreeing under 1%. GH sits above JJ in 100% of 320 cells
  (correct bound ordering). `dev/vgh/crosscheck-va-r3.csv` matches TMB to ~1e-13.
- **VGH is fast in the right regime**: 11.5x / 8.4x / 14.6x against Laplace at
  n = 200/500/1000 (gaussian, m = 20) — **as interpreted R against compiled C++
  with AD**. But it is **~20–25% SLOWER** at small binomial problems
  (p 6–12, n 60–200). The win comes from Laplace's O(m^3) determinant and
  inner-mode iterations, which bite only at large m and large n. **Always quote
  the regime.**
- **`gllvm`'s VA is NOT faster than its LA** in our measurements: LA 3.3x faster
  at n = 200, m = 50. The received wisdom does not survive.
- **The warm-start route is refuted.** Ridged warm start rescued 0/7 runaway
  fits where the ridge itself rescued 7/7, because **the runaway IS the maximum-
  likelihood solution** (`R/fit-multi.R:5297-5303`: refitting from the TRUE
  parameters ties the objective 40/40 and walks back out). A starting point
  cannot fix a problem whose destination is wrong. Three independent
  confirmations. **Do not re-litigate.**
- **The VGH screen refutation was OVER-SCOPED** and is corrected in
  `docs/dev-log/2026-07-29-vgh-phase3-screen-result.md`. The statistic tested
  (`h`) contains no `Lambda`; the doc calls it *"the worst candidate available"*.
- **`gllvm_eva`'s 68% figure must not be cited** — the fairness audit found the
  arms were not scored on the same fields.

## The one thing blocking a claim

**No equal-accuracy statement exists in either direction.** The speed benchmark
is confounded: Laplace fits **60** parameters and VGH **79** (per-trait `phi_j`
against one shared gaussian `sigma`), so VGH's log-likelihood
advantage is roughly what 19 extra parameters buy on their own.

> **UPDATE 2026-07-30 — "roughly" is now measured, and the range has moved.**
>
> *The range.* This brief said "+6.2 to +10.0", inherited from
> `2026-07-29-vgh-variational-speed-probe.md:125`. That was **correct when
> written** — that doc states at `:133-134` that *"n=2000 and n=4000 did not
> complete in this session."* Those cells have since landed in
> `dev/vgh/vgh-bench-gaussian.csv`, so the actual range is **6.23 to 12.31**.
> Stale, not wrong.
>
> *The quantification.* The confound is testable, because the two models are
> strictly **nested** (Laplace = VGH under `φ_1 = … = φ_m`), the bench DGP is
> **homoscedastic** by construction (`dev/vgh/vgh-bench.R:13`), and both
> log-likelihoods are **exact** (`:2-3`). So `2·d_ll ~ χ²₁₉` under a *true* null:
>
> | n | d_ll | 2·d_ll | p (χ²₁₉) |
> |---|---|---|---|
> | 200 | 6.23 | 12.47 | 0.865 |
> | 500 | 6.67 | 13.33 | 0.821 |
> | 1000 | 9.99 | 19.98 | 0.396 |
> | 2000 | 11.96 | 23.92 | 0.199 |
> | 4000 | 12.31 | 24.61 | 0.174 |
>
> The null **expects** `d_ll = 9.5 ± 3.08`. **0 of 5 cells reach p < 0.05**, and
> two fall *below* the null expectation — VGH gained *less* than 19 free
> parameters typically buy. Effective loading dof is 39 on both sides (Laplace
> constrains the strict upper triangle, `src/gllvmTMB.cpp:875-899`; VGH's Λ is
> unconstrained at 40 raw but only 39 identified), so the gap is exactly the 19
> dispersions.
>
> **Caveat, from adversarial review:** five cells, one seed, single-start, no
> convergence verification, and `sim()` redraws Λ and β at every n — so these are
> five draws from five *different* truths, not replicates at growing n. This
> refutes *"the advantage is real"*; it does not establish *"the advantage is
> exactly 19 dof"*. The collapse test does that properly.

**Slice 1, and it gates everything else: a MATCHED-PARAMETERISATION accuracy
run.** Same parameter count both arms, same data, recovery scored against known
truth.

**UPDATE 2026-07-30, and it halves the slice.** The confound is
**gaussian-specific**: it is per-trait `phi_j` against one shared `sigma`.
**Binomial carries no dispersion parameter at all** — VGH reports `phi = 1`,
fixed — so both engines fit p intercepts + p*q loadings under the same
lower-triangular identifiability constraint. MEASURED at p = 6, q = 2: Laplace
`length(opt$par)` = 17, VGH 6 + 11 = 17. **Matched.**

Therefore the existing 148-fit paired binomial comparison
(`dev/heywood/vgh-vs-laplace-degeneracy.csv`, carried over from the Heywood
lane) **is already a valid matched-parameterisation result**, and the confound
caveat was wrongly carried onto it. It stands:

| median | n = 60 | n = 100 | n = 200 |
|---|---|---|---|
| `abs(sigma-1)` Laplace | 27.56 | **0.179** | **0.113** |
| `abs(sigma-1)` VGH | **0.590** | 0.344 | 0.120 |
| degenerate | Laplace **50/148** (49 silent) | | VGH **0/148** |

**Both halves of that are now sayable:** Laplace has the better median at
n >= 100, and VGH has no catastrophic tail.

**What remains of Slice 1 is the GAUSSIAN arm only** — where the confound
actually lives. Matching it requires either per-trait residual SDs on the
Laplace side or a shared dispersion on the VGH side.

> **CORRECTION 2026-07-30 — this paragraph named the wrong engine.** It
> previously read *"VGH's gaussian route FIXES the residual dispersion rather
> than estimating it (`gaussian_sd`)"*. That is true of a **different engine**.
> There are two, and the distinction is the whole point:
>
> | engine | family | dispersion |
> |---|---|---|
> | `R/va-vgh.R::.vgh_fit()` | `"gaussian_anchor"` | **FIXED** at `gaussian_sd^2` (`:575-576`) |
> | `dev/vgh/vgh-engine.R::vgh_fit()` | `"gaussian"` | **ESTIMATES per-trait φ_j** (`has_phi = TRUE` :67; `vgh_update_phi()` :341, called :402) |
>
> The 60-vs-79 parameter count above comes from **`vgh_fit()`**, which estimates.
> The count is itself the proof: fixed dispersions would not be parameters, and
> the total would be 59, not 79. Verified by running it — on heteroscedastic
> truth φ moves off its initialisation and spreads across traits (range 1.737).
>
> **Provenance of the error, because it is instructive.** The predecessor
> handover stated it correctly —
> `handover/2026-07-29-claude-handover-vgh-heywood-gate.md:110`, *"**`gaussian_anchor`
> FIXES the residual dispersion**"* — as did
> `2026-07-29-vgh-vs-gllvm-headtohead.md:83`. Compressing `gaussian_anchor` to
> "gaussian route" dropped the only word carrying the distinction, and the wrong
> version then propagated into this brief *and* into the resume command at
> `handover/2026-07-30-claude-handover.md:126`, which is how it reached the next
> session as an instruction. **A one-word compression inverted a fact.**
>
> Matching *upward* is also unavailable: `src/gllvmTMB.cpp:568` declares
> `PARAMETER(log_sigma_eps)` — a **scalar** — and per-trait gaussian dispersion is
> an unbuilt roadmap item (`docs/design/108-va-parity-programme.md:194`). So the
> match is downward: pool `vgh_fit()`'s φ to one shared estimated dispersion.

## Candidate slices, after Slice 1

2. **VGH's degeneracy rate at scale**, on the Totoro grid design it postdates
   (n 40–400, p 8–80, q 2/4, 10 seeds). The 0/148 result is one regime.
3. **Compile VGH to C++/TMB.** It is 8–15x faster *as interpreted R*; the
   remaining deficit at small problems is plausibly the interpreter.
4. **Quadrature order.** Q = 15 is current and nothing below it has been tested;
   the error table exists (Q=15 → 2.0e-03 against a Q=80 reference).
5. **The mixed route**: Laplace for the median, the ridge to repair in place,
   VGH as the independent second engine, with `check_gllvmTMB()` saying which to
   trust. This is the deliverable the other slices serve.

## Standing discipline

Healthy is defined by **recovery against known truth, never convergence** —
59/70 recorded degenerate fits reported `convergence = 0`. Every threshold ships
with a measured false-positive rate. Sweep the heterogeneity of whatever sits in
a ratio's denominator; homogeneous truth flatters a ratio every time. Reject a
candidate only on a measurement **as wide as the candidate**. Heavy compute →
Totoro; results stay local (D-50). No self-merge on API changes.

Full background: `~/shinichi-brain/memory/VGH in gllvmTMB — the settled
position, and the three questions that kept getting conflated.md`.
