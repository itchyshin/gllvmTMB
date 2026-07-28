# Audit of the O3 AGHQ spike and the q=2 transfer test

**Scope:** read-only audit of `/private/tmp/gllvmtmb-va-wiring-20260726` (PR #798,
not touched). No R/, src/, inst/, tests/, NAMESPACE, DESCRIPTION edited anywhere.
No long fits run; all numbers below are re-derived from existing CSVs and code,
plus one `Rscript -e` aggregation (`read.csv`/`mean`/`sd` only, <1s).

Files inventoried in `dev/` (aghq-* set): `aghq-crux-q1-ladder.{R,log}`,
`aghq-crux-q1-main.csv`, `aghq-crux-q1-nladder.csv`, `aghq-crux-q1-probe.R(.fns)`,
`aghq-crux-q1-tladder.csv`, `aghq-crux-q2-transfer-v1-slow.R`,
`aghq-crux-q2-transfer.R`, `aghq-crux-q2-transfer.csv`,
`aghq-o3-gllvmtmb-unit-hook.R`, `aghq-o3-q2-coupled-spike.R`,
`aghq-o3-scalar-spike.R`, `aghq-q2-seed1{1..5}.{csv,log}`,
`aghq-scope-accuracy-crux.md`, `aghq-scope-cost-node-ratio.R(.rds)`,
`aghq-scope-cost-timing.R(.log,.rds)`, `aghq-scope-cost.md`, `aghq-scope-gap.md`,
`aghq-verify-cost.md`, `aghq-verify-gap.md`. Corresponding canonical helper and
tests live under `tests/testthat/`: `helper-aghq-o3.R`,
`test-aghq-o3-gllvmtmb-unit-hook.R`, `test-aghq-o3-q2-coupled-spike.R`,
`test-aghq-o3-scalar-spike.R`, `test-aghq-r2-reference-harness.R`.

---

## 1. What the "O3 spike" is, and what the 1.4e-9 number means

**It is code**, not prose: `tests/testthat/helper-aghq-o3.R` (the canonical
home, per `aghq-scope-gap.md:9`), with `dev/aghq-o3-*.R` as one-line local
runners that just `source()` it. Three tiers: `.o3_*` (scalar/q=1 groups),
`.o3_q2_*` (coupled q=2), `.o3_r2_*` (a fixed-coordinate reference harness
that adds permutation invariance and posterior-moment checks).

What it computes, confirmed by reading the code (`helper-aghq-o3.R:95-174`):

1. Fit the real production model once via ordinary Laplace
   (`gllvmTMB() → TMB::MakeADFun(..., random="z_B") → nlminb`), to convergence.
2. Extract, **at that one converged optimum only**, `b_fix` and `Lambda_B`
   (`.o3_hook_extract`/`.o3_q2_extract`, lines 107-113, 148-153).
3. Hand-write the per-unit conditional binomial-logit log-density in plain R
   (`.o3_hook_mode`/`.o3_q2_mode`), find its mode by `optimize()`/`optim`, and
   get its curvature from a **hand-derived closed-form formula**
   (`sum(loading^2*n*p*(1-p))+1` at q=1; a 2x2 `crossprod(...) + diag(2)` at
   q=2) — not from TMB's AD tape.
4. Place `nodes^q` Gauss-Hermite nodes around that mode
   (`u = mode + sqrt(2)*R^{-1}x`), evaluate the hand-written density at each,
   combine by log-sum-exp, sum over units.
5. Compare the total to `fit$opt$objective` (the TMB joint Laplace marginal
   NLL). **This comparison is done at `nodes = 1` only** — the actual
   assertions are `o3_gllvm_unit_hook_self_test` (`helper-aghq-o3.R:129-130`,
   q=1) and `o3_q2_gllvm_unit_self_test` (lines 169-170, q=2):
   `abs(one - fit$opt$objective) > 1e-6` → stop. `aghq-scope-gap.md:32` reports
   the achieved agreement as `1.4e-9` (q=1) / `9.8e-8` (q=2), both **at one
   node**.

**What 1.4e-9 demonstrates, precisely: at k=1, the AGHQ formula IS Laplace**
(a 1-point adaptive Gauss-Hermite rule with `x=0, w=sqrt(pi)` collapses the
integral to exactly the Laplace approximation evaluated at the mode). So this
number is a check that the from-scratch R reimplementation — its own mode
solve, its own hand-derived curvature, its own node placement and log-sum-exp
— reproduces TMB's C++ joint Laplace objective at that one degenerate case. It
verifies **the plumbing is wired correctly** (mode-finding, curvature formula,
weight/scale bookkeeping all agree with TMB to 9-10 significant figures). **It
demonstrates nothing about the accuracy of the k>1 quadrature** — that is a
completely different, unshared code path (steps 3-4 with `nodes>1`), and
1.4e-9 is silent on whether *that* path is closer to the true integral than
Laplace is. `aghq-scope-gap.md` itself does not overclaim this — it calls the
agreement "the empirical restatement of 'Laplace = AGHQ with one node'"
(line 33), which is the correct, narrow reading. The task brief's framing
("may have been overstated") is not borne out by the source note's own
wording; if it has been overstated, it is in how the number gets *cited*
elsewhere (verbally, in conversation) rather than in this file. The genuine
accuracy claim (AGHQ at k>1 recovers more of `Sigma_B`) rests entirely on the
separate attenuation measurements in §3 below, not on the 1.4e-9 figure.

---

## 2. What the q=2 transfer test (TEST C) ran

Script: `dev/aghq-crux-q2-transfer.R`. Pure R, no gllvmTMB/TMB — a
self-contained AGHQ implementation compared against its own k=1 (=Laplace)
special case, mirroring the q=1 probe's design (`dev/aghq-crux-q1-probe.R`).

- **DGP** (`simulate_cell()`, lines 57-66): `Q=2` latent axes, `T=20` binary
  traits, `n=2000` units. `bet ~ N(0, 0.3^2)` per trait (fixed intercepts).
  `Lam` is `T x Q` lower-triangular (`lam_index`, line 51: `row >= col`, i.e.
  Q=2 loading columns with the standard rank-2 identifiability constraint),
  entries `~ N(0, LAMBDA_SD^2)` with `LAMBDA_SD = 0.7/sqrt(2) ≈ 0.4950`.
  `U ~ N(0, I)` (2000x2 standard normal scores). `eta = U %*% t(Lam) + bet`,
  `Y ~ Bernoulli(plogis(eta))`.
- **Family:** Bernoulli/binomial-logit only (`rbinom(NN*TT, 1L, plogis(eta))`,
  line 64). No other family anywhere in this spike set.
- **q, seeds:** `q=2` fixed; `SEEDS = 11,12,13,14,15` (5 seeds; env-overridable,
  actually run one-seed-at-a-time as `aghq-q2-seed1{1..5}.csv/.log`, plus one
  earlier combined-script attempt in `aghq-crux-q2-transfer.csv`, see §3 flag).
- **k:** `KK = 9` (env `KK`, default 9) → `k^2 = 81` tensor nodes.
- **Held fixed across seeds:** `Q, T, n, k`, the DGP functional form, and
  `LAMBDA_SD` (chosen, per the script's own comment line 33, "to match
  Lambda'Lambda per axis to the q=1 run" — see the arithmetic caveat in §5).
- **`attenuation`, as implemented** (line 119, `atten <- function(Lh, Lt)
  sum(Lh*Lh)/sum(Lt*Lt)`): `sum(Lambda_hat^2) / sum(Lambda_true^2)`, i.e.
  `trace(Sigma_hat)/trace(Sigma_true)` summed over **both** latent axes and
  all 20 traits — the same rotation-invariant trace ratio used throughout
  `aghq-scope-accuracy-crux.md` (confirmed against that note's §0 definition).
- **`c_full`, as implemented** (line 136): `sqrt(atten_AGHQ / atten_LA)` — the
  implied uniform rescaling of `Lambda` that would turn the Laplace attenuation
  into the AGHQ attenuation. It is a ratio derived from `atten`, not an
  independently-fit quantity.
- **Pre-registered kill rule** (script header, lines 6-11, and verdict block
  lines 154-159): "if q=2 `c_full < 1.01`, the headline does not transfer and
  the proposal is dead regardless of TEST A/B"; `c_full` in `[1.02, 1.04]` was
  the predicted transfer band from the q=1 result (`c_full = 1.0295`); above
  1.04 is coded "TRANSFERS, stronger than predicted."

---

## 3. Reconstructing the headline numbers from the CSVs

Aggregated directly from the five `dev/aghq-q2-seed1{1..5}.csv` files
(`Rscript -e 'rbind(...); mean(...); sd(...)'`, re-run here):

| seed | atten_LA | atten_AGHQ | c_full | t_la (s) | t_ag (s) | cost_ratio |
|---:|---:|---:|---:|---:|---:|---:|
| 11 | 0.9290 | 1.0266 | 1.0512 | 148.0 | 503.5 | 3.40 |
| 12 | 0.9450 | 1.0918 | 1.0749 | 128.2 | 458.1 | 3.57 |
| 13 | 0.8982 | 1.0332 | 1.0725 | 129.3 | 468.3 | 3.62 |
| 14 | 0.9425 | 1.0460 | 1.0534 | 154.1 | 420.4 | 2.73 |
| 15 | 0.8929 | 1.0214 | 1.0695 | 149.7 | 407.6 | 2.72 |
| **mean** | **0.9215** | **1.0438** | **1.0643** | 141.9 | 451.6 | 3.208 |
| **sd** | 0.0245 | 0.0284 | 0.0112 | | | |
| **median cost** | | | | | | **3.40** |

**Every headline number in the task brief reproduces exactly**: mean
attenuation Laplace 0.9215 vs AGHQ 1.0438, mean `c_full` 1.0643 (task states
"1.064"), median cost 3.40x.

**Per-seed spread:** `atten_LA` ranges 0.893–0.945 (spread 5.2 pp), `atten_AGHQ`
ranges 1.021–1.092 (spread 7.0 pp), but the **paired** statistic `c_full` is
tight — 1.051 to 1.075, sd 0.011 — and **directionally unanimous 5/5, all
comfortably above the 1.01 kill threshold** (nearest miss is 5.1% above 1,
not close to the line). Cost ratio is noisier (2.72–3.62, sd ≈0.42) and not
paired/controlled for machine load (no caveat about contention is recorded
for this run, unlike the q=1 timing note in `aghq-scope-accuracy-crux.md`
§4/§6, which explicitly flags a contended machine — that caveat is not
repeated here and should be, since q=2 timing carries the same risk).

**5 seeds is enough to support the sign and rough magnitude of `c_full`**
(narrow sd, unanimous direction, comfortably clear of the kill line) but is
**not enough to pin the point estimate to 3 digits** — same caveat the q=1
note already applies to itself (§7.2 of `aghq-scope-accuracy-crux.md`).

**Discrepancy found, prominently flagged:** `dev/aghq-crux-q2-transfer.csv`
(mtime 18:58) contains a single row for **the same seed 11** with materially
different numbers than `aghq-q2-seed11.csv` (mtime 19:09, 11 minutes later,
same script, same nominal seed/DGP/k):

| source | atten_LA | atten_AGHQ | c_full | t_la | t_ag | cost_ratio |
|---|---:|---:|---:|---:|---:|---:|
| `aghq-crux-q2-transfer.csv` (earlier) | 1.1047 | 1.2692 | 1.0719 | 32.1s | 55s | 1.72 |
| `aghq-q2-seed11.csv` (later, used in the headline) | 0.9290 | 1.0266 | 1.0512 | 148.0s | 503.5s | 3.40 |

The fit times differ by ~4.6x (Laplace) and ~9x (AGHQ), and the attenuation
**levels** differ by 0.18 (LA) and 0.24 (AGHQ) for what the script header
calls the identical seed — while `c_full` (the ratio actually used for the
kill rule) happens to land close in both (1.072 vs 1.051). This is not
explained anywhere in the notes I read, and it is not a trivial re-run
variance: an 18-minute-earlier partial run of the identical script produced a
different attenuation regime and a 4-9x faster runtime. Plausible causes I
cannot rule out from what's on disk: a different `NN`/`KK` env-var setting at
invocation time, an early kill/restart of a non-converged optimiser run (the
short 32s runtime is suspicious for the same BFGS/`reltol=1e-10` settings that
took 148-154s in every other seed), or an interim code edit to
`aghq-crux-q2-transfer.R` between the two runs that was not preserved. **This
earlier file should be treated as stale/superseded, not corroborating
evidence** — the headline in `aghq-scope-accuracy-crux.md` matches only the
five `aghq-q2-seed1X.csv` files, and this audit recommends deleting or
annotating `aghq-crux-q2-transfer.csv` so it cannot be mistaken for a second
data point later.

---

## 4. Family exercised

**One family only, everywhere in this spike set: Bernoulli / binomial-logit.**
Confirmed in every DGP: `dev/aghq-crux-q1-probe.R:34` (`rbinom(n*Tt, 1L,
plogis(eta))`), `dev/aghq-crux-q2-transfer.R:64` (same), and the O3 hook
fixtures in `helper-aghq-o3.R` (`.o3_hook_fixture`/`.o3_q2_fixture`/
`.o3_r2_fixture_data`, all `rbinom(..., n_trials, plogis(eta))`, i.e. binomial
with a logit link, of which Bernoulli is the `n_trials=1` case). `aghq-scope-
accuracy-crux.md` §7.4 states this explicitly and adds the caveat that
Ayumi's real model is probit with phylogeny and missingness, none of which is
touched here. Nothing in this spike exercises Poisson, Gaussian, ordinal,
tweedie, or any other of gllvmTMB's other ~15 families, nor any structured
(phylogenetic/spatial) random effect, nor missing data. The "inherits all 16
families" claim that motivates the whole AGHQ redirection is **not tested by
anything in this file set** — it is tested (in the narrow logit case only) at
the level of "does AGHQ correct Laplace's bias," not "does the machinery run
for family X."

---

## 5. The overshoot / sign flip

q=1 (`aghq-crux-q1-probe.R`, `aghq-scope-accuracy-crux.md` §0): 3 seeds,
mean attenuation Laplace 0.8968 → AGHQ 0.9507 (**still below 1**, i.e. AGHQ
closes about half the deficit but under-shoots the truth).

q=2 (this test): 5 seeds, mean attenuation Laplace 0.9215 → AGHQ 1.0438
(**above 1**, i.e. AGHQ now over-shoots the truth by 4.4 pp, on top of Laplace
itself already sitting closer to the truth at q=2 than at q=1).

This is recorded in the task brief as an unexplained sign flip. From the code
and CSVs, two candidate mechanisms are visible, plus one I could not rule out:

**(a) Estimation-noise inflation, already documented in this repo's own notes
for a different cell, and directionally correct for this one.**
`aghq-scope-accuracy-crux.md` §2a(ii)/§2c(3) derives `E[sum lambda_hat^2] =
sum lambda^2 + sum Var(lambda_hat)` — sampling noise **always inflates** the
trace statistic, and can push attenuation above 1 when the noise term is large
relative to signal. The q=2 DGP has more free loading parameters (39 lower-
triangular entries at `T=20,Q=2` vs 20 at `Q=1`) and only `n=2000` units to
estimate them from, so more noise inflation at q=2 than at q=1 is expected on
this mechanism alone, independent of any q=2-specific quadrature behaviour.
This is consistent with the sign flip but I did not measure `Var(lambda_hat)`
directly to quantify it — **AGENT-INFERRED, not measured here**.

**(b) A DGP-design mismatch that the script's own comment does not fully
deliver.** `aghq-crux-q2-transfer.R:33` sets `LAMBDA_SD = 0.7/sqrt(Q)` "to
match Lambda'Lambda per axis to the q=1 run." Arithmetic check: each loading
entry has variance `LAMBDA_SD^2 = 0.49/Q = 0.245`; expected per-axis
`Lambda'Lambda = T * LAMBDA_SD^2 = 20*0.245 = 4.9`. **That is half of the
q=1 run's per-axis value of 9.8** (`T*0.7^2 = 9.8`), not equal to it — the
comment's stated intent (match *per axis*) is not what the arithmetic
delivers; what actually matches is the **total** signal summed across both
axes (`Q * 4.9 = 9.8`, equal to q=1's single-axis total). So the q=2 run
gives each latent axis **half the per-axis information** q=1 had, while
adding a second axis and cross-terms (`h12` in the 2x2 conditional Hessian,
`nll()` lines 79-82) that q=1 never has. Whether weaker per-axis information,
the added cross-term, or their interaction drives the sign flip is not
separable from what's on disk — **this design choice itself is a candidate
explanation, and it was not flagged as a caveat anywhere in the notes I
read.**

**Cheapest experiments to distinguish, in order of cost:**

1. **Re-run TEST C once with `LAMBDA_SD = 0.7` (unchanged, not divided by
   `sqrt(Q)`)**, so per-axis information matches q=1 exactly rather than the
   total. If the sign flips back toward under-shoot, mechanism (b) dominates;
   if it stays an over-shoot, (b) is not the driver. One extra 5-seed run,
   same cost as the one already done (~15-20 min per seed at k=9).
2. **Re-run one seed at `KK=15` instead of 9** (already-available machinery,
   just change the env var) to check whether `atten_AGHQ` is stable — if the
   over-shoot persists unchanged at denser k, it is a converged quadrature/DGP
   property, not an under-resolved grid; if it drifts further from 1, the k=9
   grid was not yet adequate at q=2. Roughly 1 more AGHQ fit (~7-8 min).
3. **Run the q=2 analogue of the q=1 n-ladder/T-ladder** (§2c/§2d of
   `aghq-scope-accuracy-crux.md`), which is the identification strategy this
   repo already trusts (n-invariance + T-decay ⇒ quadrature error). This
   would settle mechanism (a) vs a genuine q-dependent quadrature effect
   directly, at the same cost structure as the existing q=1 ladders, but has
   not been run at q=2 anywhere in this file set.
4. **Check inner-Newton convergence at q=2.** `nll()`'s per-unit Newton solve
   (lines 75-85) runs a **fixed 12 iterations with no convergence check or
   residual report**, unlike the q=1 `.o3_hook_mode`/`.o3_q2_mode` helpers in
   `helper-aghq-o3.R`, which use `optimize()`/`optim` with explicit
   convergence flags. An under-converged 2x2 Newton solve at some units could
   bias the objective in either direction and has not been ruled out here —
   this is a gap in the diagnostic, not just in the explanation.

None of these were run in this audit slice (all would exceed the ~60s toy-fit
budget for this task); they are the specific, cheap next steps, not a
recommendation to run them now.

---

## Summary for the parent task

- **Path:** `/private/tmp/gllvmtmb-va-wiring-20260726/dev/aghq-scope/` (this
  file is at `/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-scope/03-spike-audit.md`).
- **Headline numbers reproduce exactly** from the 5 seed CSVs: Laplace 0.9215,
  AGHQ 1.0438, `c_full` 1.0643, median cost 3.40x — all match the task brief.
- **Per-seed spread is tight on the decisive statistic** (`c_full` sd 0.011,
  5/5 unanimous, well clear of the 1.01 kill line) but noisier on levels and
  cost; 5 seeds support the sign/rough-magnitude call, not 3-digit precision.
- **One number does NOT reproduce and should be flagged prominently:** an
  earlier partial run (`dev/aghq-crux-q2-transfer.csv`, same nominal seed 11)
  gives a materially different attenuation level and a ~5x faster runtime
  than the file actually used for the headline (`aghq-q2-seed11.csv`). Treat
  the earlier file as stale, not as a second, corroborating data point.
- **Single family exercised: Bernoulli/binomial-logit.** No other family,
  no structured random effect, no missing data anywhere in this spike. The
  "inherits all 16 families" premise is not addressed by anything measured
  here.
- **1.4e-9 (and 9.8e-8 at q=2) is a plumbing-correctness check at k=1, i.e.
  against Laplace itself — it says nothing about the k>1 quadrature's
  accuracy.** The source note (`aghq-scope-gap.md`) states this correctly;
  it should not be cited elsewhere as evidence that AGHQ-at-k>1 is accurate.
  The actual accuracy claim rests solely on the attenuation/`c_full`
  measurements in §3.
- **The q=1→q=2 sign flip (0.951 under-shoot → 1.044 over-shoot) is
  unexplained but not unconstrained:** two candidate mechanisms identified
  (noise inflation from more free parameters; a DGP scaling comment that
  halves per-axis information rather than matching it, per the arithmetic in
  §5), plus an unverified inner-Newton convergence gap. Four cheap,
  specific follow-up experiments are listed in §5, none run here.
