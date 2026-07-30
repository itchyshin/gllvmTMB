# Scope — VGH degeneracy at scale: a measurement to size an engine investment

Date: 2026-07-30. Author: Claude (Ada, scoping role). Lane:
`claude/vgh-pluralism-20260730`, worktree `/private/tmp/gllvmtmb-vgh-pluralism`.
Predecessor brief: `docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md`.
Status: **SCOPE ONLY — nothing launched, nothing promoted, no package change.**

---

## 🔴 READ FIRST — the premise of this campaign is already partly refuted

The campaign was framed as *"VGH is 0/148 degenerate; does that survive at
scale?"* **I measured 10 fits at the corner the design would extend into, and it
does not survive.** This is not a projection; it is measured, reproducible across
seeds, and it re-aims the campaign.

`.vgh_fit()`, binomial-logit, `Q = 15`, the 148-fit DGP, seeds 1–4
(scratch script `probe_corner2.R`, this session, macOS arm64, single core):

| cell | seed | secs | sweeps | `converged` | `rel_frob` | `atten_F` | `max|Λ|` | verdict |
|---|---|---|---|---|---|---|---|---|
| n=40, p=80, q=4 | 1 | 9.0 | 82 | **TRUE** | **10.671** | 3.15 | **12.53** | DEGENERATE (both defs) |
| n=40, p=80, q=4 | 2 | 6.8 | 71 | **TRUE** | 4.542 | 2.21 | **9.88** | degenerate (atten + absolute) |
| n=40, p=80, q=4 | 3 | 10.8 | 98 | **TRUE** | **10.449** | 3.17 | **11.60** | DEGENERATE (both defs) |
| n=40, p=80, q=4 | 4 | 4.6 | 53 | **TRUE** | 5.107 | 2.22 | **8.53** | degenerate (atten + absolute) |
| n=40, p=40, q=4 | 1–3 | 2.8–3.3 | 52–57 | **TRUE** | 4.66–5.34 | 2.17–2.35 | **7.46–8.46** | degenerate (atten + absolute) |
| n=40, p=80, q=2 | 1–3 | 1.8–3.2 | 30–46 | **TRUE** | 1.75–2.44 | 1.51–1.73 | 4.77–6.74 | borderline |

Three things follow, and they are the reason to run the campaign rather than not:

1. **The `0/148` claim is confined to three axes at once, not one.** The 148-fit
   result is n ≥ 60, **p ≤ 12**, **and q = 2** — `q` is a module-level scalar at
   `dev/heywood/vgh-vs-laplace-degeneracy.R:30`, never a grid column. At q = 4
   with n = 40, **2 of 4 seeds exceed `rel_frob > 10` and 4 of 4 exceed
   `atten_F > 2`**. `q`, not `p`, is the primary driver.
2. **VGH's `converged` flag is silent in exactly the way Laplace's is.** All ten
   fits above report `converged = TRUE`. This is structural, not luck:
   `R/va-vgh.R:603` sets `converged = (outer < maxit)` — "did not hit the cap."
   It is TRUE for 150/150 rows of the existing CSV (verified). **VGH must not be
   described as self-diagnosing.**
3. **`max|Λ|` reaches 8.5–12.5 against the shipped `loading_absolute_thresh = 6`**
   (`R/diagnose.R:537-538`). The Heywood gate that just shipped for Laplace would
   fire on these VGH fits. That is the single most decision-relevant number here.

**The campaign is still worth running, re-aimed.** The question is no longer
"does the advantage survive" (no) but **"where is the boundary, and is the
advantage large enough inside the regimes users actually occupy to justify a
multi-day engine investment?"** That is answerable, cheap (§6), and it is the
measurement that sizes the investment.

**A second finding that may pre-empt the investment entirely (§3, §10-D4):** the
**already-shipped** VA route `gtmb_jj` is **0/320 degenerate under _both_
definitions** in the published grid, where VGH is 10/148 under the second one. If
the shipped VA already delivers the degeneracy benefit, the marginal case for a
VGH engine is much weaker than the brief assumes.

---

## 1. The question, and the decision it informs

**This is a measurement to size an investment, not the investment.** No engine is
built, no route is promoted, no public or package-facing claim is produced. The
deliverable is a table of degeneracy rates and costs across a wide binomial
regime, per arm, scored against known truth — enough for the maintainer to decide
whether a production VGH estimator route (multi-day: exported entry point,
`model_selection_comparable` semantics, `summary()`/`predict()` integration,
documentation, tests) is worth building, or whether the pluralist story is better
served by the Laplace + Heywood-gate + `gtmb_jj` surface that already ships. The
campaign is explicitly designed to be able to return **"do not build it"** —
and after the probes in the banner above, that is now a live outcome rather than
a formality.

---

## 2. What is already known — do NOT re-derive

Re-deriving any of this is waste. Each line is cited; where a recorded number is
wrong, the correction is carried with it.

### 2.1 The load-bearing 148-fit result, and its exact regime

`dev/heywood/vgh-vs-laplace-degeneracy.csv`, re-verified from the CSV this
session (150 rows written, 148 usable after the `is.finite` filter at
`dev/heywood/vgh-vs-laplace-degeneracy.R:109`):

| | degenerate (`rel_frob > 10`) | of which self-reported clean |
|---|---|---|
| Laplace | **50 / 148 (33.8%)** | **49** |
| VGH | **0 / 148 (0.0%)** | — |
| at the looser `rel_frob ≥ 5` bar | Laplace 50 | VGH 4 |

**The regime, stated in full because the claim does not travel outside it:**
n ∈ {60, 100, 200}; **p ∈ {6, 12}**; **q = 2 only**
(`vgh-vs-laplace-degeneracy.R:30`, a module scalar); seeds 1:25; binomial-logit,
single-trial Bernoulli; DGP `Λ ~ N(0, 0.7)`, `B ~ N(0, 0.3)`; arms paired on
identical data; matched parameter count (p intercepts + p·q loadings on both
sides — the brief establishes 17 = 17 at p=6, q=2, and binomial carries no
dispersion so the gaussian `phi_j` confound does not apply).

**Laplace degeneracy structure inside that regime** (computed this session):

| `rel_frob > 10` rate | p = 6 | p = 12 |
|---|---|---|
| n = 60 | 0.48 | **0.87** |
| n = 100 | 0.16 | 0.44 |
| n = 200 | 0.04 | 0.08 |

Driven by **small n and large p** jointly — which is precisely why extending p
and adding n = 40 is the right design, and why the corner is the informative
region rather than the mean.

### 2.2 VGH was NEVER in the Totoro grid — the 0%-vs-12% headline is a different arm

Confirmed by the recon and not in dispute: `grep -ric vgh` over `run-grid.R`,
`analyse-grid.R`, `RESULTS.md`, `grid.log` → **0, 0, 0, 0**. The grid landed
`c5af7068` (2026-07-26); `R/va-vgh.R` landed `9bf1dcf9` (2026-07-29) — the grid
**predates the engine by three days**. The `va_r3` route does not secretly reach
VGH (`grep -n vgh R/approximation-engine.R R/va-r3-proto.R` → 0 hits). The grid's
0%-degenerate VA arms are **`gtmb_jj` (0/320) and `gllvm_va` (0/600)**, against
`gtmb_laplace` **70/601 (12%), 59 silent**. Any sentence attributing the grid's
0% to VGH is wrong.

### 2.3 The two-lane gaussian convergence — why this campaign is binomial-weighted

Two independent lanes converged this week and jointly close gaussian:

- **This lane:** gaussian has **no degeneracy tail for either engine**, and both
  optimise the same objective there
  (`docs/dev-log/2026-07-30-gaussian-has-no-degeneracy-tail.md`,
  `2026-07-30-gaussian-arm-rescope.md`).
- **The AGHQ/ridge audit:** `aghq = k` returns the Laplace warm start
  **bit-for-bit 89.6%** of the time on gaussian, and AGHQ "helps binomial only,
  and only at large n." Poisson bit-for-bit rate **0.740**.
- The Totoro grid found **all arms equivalent on poisson**.

**Therefore: binomial is where the action is; gaussian is CLOSED and gets no
cells; poisson is a cheap control, not a focus.** Note the gaussian closure is
also why the `phi_j` parameter-count confound is irrelevant to this campaign.

### 2.4 Arm-fairness caveats that must be carried forward, not re-tripped

**(a) `gtmb_laplace`'s link-implicit residual — quoted three times in the grid**
(`RESULTS.md:32`, `run-grid.R:126-129`, and per-row in the `note` column):
*"`gtmb_laplace` Sigma_B may carry a link-implicit residual on its diagonal, so
its column is indicative, NOT like-for-like with the VA arms."*
**This campaign sidesteps the caveat entirely rather than resolving it** — it
scores Laplace from `fit$report$Lambda_B` via `tcrossprod(L)`, the route
`vgh-vs-laplace-degeneracy.R:69-71` already uses, which is a pure loadings outer
product and structurally identical to VGH's `tcrossprod(vg$Lambda)`. Do **not**
use `extract_Sigma_B()`. (The recon's code-read inference that the caveat
over-states the risk is plausible but was explicitly marked AGENT-INFERRED and
unverified by any fit; sidestepping is cheaper than adjudicating.)

**(b) The `gllvm_eva` scoring problem — a real published error.** The 372-line
audit `docs/dev-log/2026-07-27-gllvm-comparison-fairness-audit.md` found
`analyse-grid.R:100`'s `clean <- grepl("pdHessTRUE|healthy|converged", s$status)`
is an **unanchored substring match**, and `"not_converged"` **contains**
`"converged"`. All 43 honestly-labelled `not_converged` EVA fits were scored as
"reported OK anyway". **`RESULTS.md:117`'s `203` should be `160`** (160/203 =
78.8%, not 100%), and the audit says so must be corrected "before this claim is
used in any external or public-facing context." The bug is
**unidirectional against `gllvm_eva`** and inert for the other four arms. The
`67.7%` degenerate rate itself **survives** (truth-based, identical criterion).
Two consequences bind this campaign:

- **`gllvm_eva` is excluded from the design** (§4) and its 68% figure must not be
  cited. There is also no same-link VGH-vs-`gllvm` binomial comparison available
  at all: `gllvm`'s VA is **probit-only** for binary while `.vgh_fit()` **rejects
  probit** (`R/va-vgh.R:396-400`) — any such comparison would be cross-link.
- **The new arm's status vocabulary must contain no success token as a substring
  of a failure label** (never `not_converged`), and the `clean` test must be
  exact-match. This is a hard requirement in §7, not advice.

**(c) `analyse-grid.R:85` pools rel_frob over ALL finite rows with no status
filter**, while `gtmb_gh` was `healthy` in only **106/640 (17%)** and
`failed_health_gate` in 441 (69%) — measured by the recon, **not disclosed in
RESULTS.md**. So the grid's published rel_frob columns are *not* "recovery
conditional on a healthy fit." §5 therefore specifies both an unconditional and a
status-conditioned view.

**(d) `setTimeLimit` HANGS — do not reach for it.** `dev/scale/SCALE.md:164-167`
records that `setTimeLimit(elapsed = 900)` failed to bite because R's elapsed
check is **cooperative** (checked only when control returns to R); workers sat at
99% CPU **over an hour** past the cap. Any fit budget must be a killable
subprocess. Note this **contra-indicates** `phase0-matched-recovery.R`'s
`run_arm()`, which is built on `setTimeLimit` (`dev/vgh/phase0-matched-recovery.R:115`).

### 2.5 Settled elsewhere — do not re-litigate

- **The warm-start route is REFUTED** for the analogous Laplace problem: ridged
  warm start rescued 0/7 runaways where the ridge itself rescued 7/7, because
  **the runaway IS the maximum-likelihood solution** (`R/fit-multi.R:5297-5303`;
  refitting from the TRUE parameters ties the objective 40/40 and walks back
  out). Three independent confirmations.
- **Our JJ engine IS `gllvm`'s VA algebra**: median relative difference 2.69e-07,
  100% agreeing under 1%; GH sits above JJ in 100% of 320 cells (correct bound
  ordering).
- **The VGH screen refutation was OVER-SCOPED** and is corrected in
  `docs/dev-log/2026-07-29-vgh-phase3-screen-result.md`.
- **The `d = 1` crash at `check-log.md:47085` is STALE** — guards are present at
  `dev/vgh/vgh-engine.R:206-207, :271-272, :275-276` and `d = 1` runs clean.
  `after-task/2026-07-30-gaussian-arm-vgh-pluralism.md:90` is the accurate entry.

---

## 3. Engine choice, with the transferability cost stated

**The campaign runs `.vgh_fit()` — `R/va-vgh.R:492-611`, the in-package engine.
The choice is forced, not a preference.**

### 3.1 Why the dev prototype is not a candidate

`dev/vgh/vgh-engine.R:385 vgh_fit()` **cannot run weighted binomial at all — it
crashes.** It has no `n_trials` argument anywhere in the file; its binomial warm
start hardcodes the Bernoulli denominator (`stats::qlogis((Y + 0.5) / 2)` at
`:360`), which returns `NaN` for any y ≥ 2, and the run dies in `vgh_init` →
`eigen`: *"infinite or missing values in 'x'"* (measured by the recon at
n=200, T=10, q=2, n_trials=20; production fitted the same data fine,
`rel_frob` 0.162). Its ELBO also **omits the `n_trials` multiplier** on the
cumulant (`:122` vs production's `:180`), so patching the init alone would
optimise the wrong objective. It is two coordinated changes to an engine that is
`.Rbuildignore`d (`^dev$`, line 21), has **no `$converged` field**, and uses the
loose relative stopping rule (`:417`) that `.vgh_fit()` was written to fix.
**Do not spend effort on it.** (Bernoulli-only cells are the sole case where it
would run — and there it is redundant, per §3.3.)

### 3.2 The transferability cost of the choice — small, and stated

`.vgh_fit()` is the **right** engine but carries two fences:

- **`research_only = TRUE`, `model_selection_comparable = FALSE`**
  (`R/va-vgh.R:606-607`). Self-declared. **Every claim this campaign produces
  must carry that fence**, and the ELBO is **not** comparable across arms for
  model selection — so no cross-arm objective/IC comparison is in scope (§9).
- **Not exported** (`grep -c -i vgh NAMESPACE` = 0) and not an estimator route.

Against that, the transferability is genuinely good and worth stating: it is in
`R/`, exercised by `tests/testthat/test-vgh-oracle.R` (27 assertions), and
**live in the shipped code path** — `R/fit-multi.R:4096-4142` calls
`.vgh_build_warm_start()` → `.vgh_fit()` under the opt-in `control$vgh_warm_start`.
**Results therefore describe code a shipped feature actually runs**, which is the
whole point of preferring it.

### 3.3 The recorded cross-check between the two engines — and what it does NOT cover

The recon established, by direct matched-settings comparison (Q=15, n_inner=2,
maxit=400, tol=0, `accelerate=FALSE`, identical Bernoulli data) — as far as can
be found, the **first** direct `.vgh_fit()` vs `vgh_fit()` binomial comparison:

| cell | ELBO rel. diff | `ΛΛ′` rel. Frobenius diff |
|---|---|---|
| n=120, T=8, q=2 | **0.000e+00** | **0.000e+00** |
| n=200, T=10, q=2 | 1.75e-15 | **0.000e+00** |
| n=150, T=6, q=3 | 1.95e-16 | **0.000e+00** |

Under each engine's **own defaults** they differ by 4.6e-08–2.9e-07 in ELBO and
0.3–1.4% in `ΛΛ′` — **entirely the stopping rule** (dev's relative tol stops
early; production's per-observation tol + SQUAREM does not). So for Bernoulli the
two implement the **same algebra**, and there is **no second opinion to be had**
from running both.

**The pre-existing recorded cross-check is a different claim and must not be
cited as engine-vs-engine agreement.** `dev/vgh/crosscheck-va-r3.csv` (written up
at `docs/dev-log/2026-07-29-vgh-report.md:104-118`) reports max relative
difference **4.74e-15** over 46 comparisons — but those compare
`dev/vgh/vgh-engine.R`'s **primitives** against the compiled
`inst/tmb/gllvmTMB_va_r3.cpp`, at **fixed parameters, never at optima**, and never
`obj$gr` (the report states both caveats itself at `:127-129`). Critically,
`crosscheck-va-r3.R:150-151` says outright that `vgh_elbo()` *"has no n_trials
argument"*, so the harness **re-implements the weighted term itself** and reaches
the dev driver only through a `Ymat/Nmat` + `phi = 1/n_by_trait`
reparameterisation. **That 4.74e-15 validates shared primitives, not the dev
driver's ability to fit weighted binomial data.**

### 3.4 Eligibility — the design in §4 is inside the admitted surface, verified

`.vgh_fit()` admits exactly **three** families (`.vgh_family`, `R/va-vgh.R:67-92`):
`gaussian_anchor` (identity, exact), `poisson` (log, exact), `binomial` (logit,
GH quadrature). Checked against the §4 design:

| constraint | file:line | §4 design | OK |
|---|---|---|---|
| binomial **logit only** (probit/cloglog rejected) | `:396-400` | logit only | ✅ |
| poisson-log admitted | `:67-92` | control arm only | ✅ |
| `q ∈ 1..6` **and** `q ≤ T` | `:351`, `:374` | q ∈ {2,4}, p ≥ 6 | ✅ |
| **balanced grid required**, re-checked after reshape | `:387-391`, `:445-448` | complete by construction | ✅ |
| **no per-trait covariates** — X constant within unit | `:455` | intercept-only X | ✅ |
| no Psi / structured / provider / lv / missing | `:380` | `unique = FALSE` | ✅ |
| `Q ∈ 1..201` | `.vgh_gh_rule():45` | Q = 9 (§4.4) | ✅ |
| N, T ≥ 1, **no upper bound** | `:372` | n ≤ 400, p ≤ 80 | ✅ |

**There is no large-p wall** — the framing's central fear is measured false.
`.vgh_fit()` reached n=400, p=80, q=4 in **5.58 s** and n=40, p=80, q=4 in
**8.91 s**, converged, monotone ELBO, no NaN (this session). The q ≥ 4 `chol()`
fallback in `.vgh_batch_inv` (`:140-146`, closed-form only for q ≤ 3) costs
almost nothing (0.30 vs 0.27 s per sweep at q=4 vs q=2, same n/T).

**Neither engine has a settable starting point or multi-start.** Verified by
`formals()`: no `start`/`init`/`theta0` in either; both inits are **deterministic
eigendecompositions** with no RNG (`.vgh_init:466-485`), and fits under
`set.seed(999)` vs `set.seed(1)` are `identical()`. Consequence in §9/§10-D5.

---

## 4. The design

Three grids. Every axis is justified from a measured number, and the eligibility
limits of §3.4 are respected rather than silently dropped.

### 4.1 Arms — three, and why each earns its cells

| arm | invocation | rationale |
|---|---|---|
| **`vgh`** | `.vgh_fit(yv, rep(1L,·), matrix(1,·,1), un, tr, q=q, family="binomial", link="logit", Q=9)` — graft `vgh-vs-laplace-degeneracy.R:76-89` | the subject |
| **`laplace`** | public `gllvmTMB(y ~ 0 + trait + latent(0 + trait \| site, d=q, unique=FALSE), family=binomial(), unit="site")`, Σ from `report$Lambda_B` | the incumbent; the arm the Heywood gate was built for |
| **`jj`** | `gllvmTMB:::.approximation_engine_fit(engine="va_r3", …, H=15L, eval_method="jj")` — `run-grid.R:89-95` | **the shipped VA.** 0/320 degenerate under *both* definitions and 0/320 on the absolute gate in the published grid. If it matches VGH everywhere, **the engine investment is unnecessary** — this arm can kill the project cheaply, which is the highest-value cell in the design. |

**Excluded, with reasons:** `gtmb_gh` — ate **31.15 of the 50.67 CPU-hours (61%)**
of the published grid for a bound that JJ already brackets; the single biggest
cost lever and the VGH question does not need it. `gllvm_va` / `gllvm_eva` — the
fairness audit (§2.4b) plus the **probit-vs-logit link mismatch** make any
comparison cross-link and unciteable. The **dev `vgh_fit()`** — §3.1.

### 4.2 Grid A — the main binomial grid (DGP-A)

- **family:** binomial-logit, single-trial Bernoulli
- **n ∈ {40, 60, 100, 200, 400}** — 5 levels. `40` and `400` from the Totoro grid
  (`run-grid.R:33`); `60, 100, 200` are the 148-fit levels, so the existing
  result's rows are a nested subset. **n = 40 is the load-bearing addition**: the
  banner probes break there, and the grid's own Laplace degeneracy at n=40, q=4
  runs **0.95 / 1.00 / 0.75 / 0.25** across p = 8/20/40/80.
- **p ∈ {6, 12, 20, 40, 80}** — 5 levels. `6, 12` bridge to the 148-fit result;
  `20, 40, 80` are the extension. p = 80 is reachable (§3.4) and is where
  `max|Λ|` blew past the shipped threshold.
- **q ∈ {2, 4}** — 2 levels, and **this is the axis the 148-fit result never
  had.** q = 4 is where VGH degenerates (banner). Non-negotiable.
- **seeds 1:25** — matches the 148-fit seed count, so the bridge cells are
  directly comparable rather than merely similar.
- 5 × 5 × 2 × 25 = **1250 cells**. `q ≤ p` is satisfied everywhere (min p = 6 >
  max q = 4), so no filter drops anything — stated explicitly because
  `run-grid.R:39`'s equivalent filter removes nothing and has misled before.
- **arms:** `vgh` + `laplace` on all 1250; **`jj` on seeds 1:10 only** (5×5×2×10
  = 500 cells) — it is a confirmatory arm at 53.4 s/fit mean, and 10 seeds is
  ample to detect a departure from its published 0/320.

**Fits: 1250 + 1250 + 500 = 3000.**

**DGP-A = the Totoro grid's** (`run-grid.R:51-58`): `Λ ~ N(0, 0.6)`,
`b ~ N(0.3, 0.3)`, `u ~ N(0, I)`, `η = uΛ′ + b`, `Σ_true = ΛΛ′`.
**This is a deliberate change from the 148-fit DGP and it is the single most
consequential design decision — it is a 10× cost decision, not a cosmetic one.**
Measured this session: under the 148-fit DGP (`N(0,0.7)`, `B ~ N(0,0.3)`),
Laplace at n=400, p=80, q=4 took **724.8 s** (long grammar; the wide grammar
exceeded 14 min on the same cell before I killed it), and Laplace **hard-fails at
n=40 with p ≥ 20** — `"All 1 restarts failed."` at n=40/p=20/q=2 in **both**
grammars, while n=60/p=20 and n=40/p=12 fit fine. Under DGP-A the published grid
records a **73.42 s median** at that same corner and a **98.7 s maximum across
all 640 Laplace fits**, with n=40 medians of 0.90–3.13 s and no mass failures.
Stronger loadings produce more degeneracy, and **degenerate fits are the slow
fits.** DGP-A keeps the Laplace arm fittable and paired across the whole design —
without which the paired comparison simply does not exist at the corner — and
makes the campaign directly comparable to the published grid whose Laplace
numbers (70/601, 59 silent) are this lane's cited evidence base. See §10-D2.

### 4.3 Grid B — the bridge grid (DGP-B), so the 148-fit result is not orphaned

DGP-A is the right main choice, but switching it alone would leave the existing
148-fit headline unextended. Grid B re-runs the **148-fit DGP** (`Λ ~ N(0, 0.7)`,
`B ~ N(0, 0.3)`) on the subset where it is cheap and Laplace still fits:

- n ∈ {60, 100, 200} (3) — **n = 40 excluded: Laplace hard-fails there under
  DGP-B, measured.** Recorded as a design constraint, not silently dropped.
- p ∈ {6, 12, 20} (3) — **p ≥ 40 excluded: the DGP-B corner costs 725+ s/fit.**
- q = 2 (1) — the 148-fit regime exactly
- seeds 1:25
- 3 × 3 × 1 × 25 = **225 cells** × 2 arms (`vgh`, `laplace`) = **450 fits**

The 9 cells at n ∈ {60,100,200} × p ∈ {6,12} **reproduce the existing 148-fit
result** and act as the campaign's regression check (§8). The p = 20 column is
the new information: it isolates **signal strength** from **dimension**, which no
existing run does.

### 4.4 Grid C — the poisson control

Poisson is a control, not a focus (§2.3: the grid found all arms equivalent on
poisson; bit-for-bit rate 0.740). `.vgh_fit()` admits poisson-log exactly
(`R/va-vgh.R:67-92`), so the control is feasible.

- n ∈ {40, 100, 400} (3), p ∈ {12, 80} (2), q = 2 (1), seeds 1:10
- 3 × 2 × 1 × 10 = **60 cells** × 2 arms (`vgh`, `laplace`; `jj` is
  **binomial-only** by construction — `run-grid.R:90` skips it for poisson) =
  **120 fits**

### 4.5 Settings and totals

**`Q = 9`, not the default 15** — a free 34% saving. Measured at
(n=400, p=80, q=4, n_trials=20): Q=9 → 8.65 s, Q=15 → 13.17 s, Q=21 → 17.49 s,
with **identical ELBO (−360662.1565) and identical `rel_frob` (0.1474) across all
three**. Runtime is linear in Q (binomial is the only quadrature family), and
`R/va-vgh.R:39-41` already records Q=9 as sufficient for recovery.

**Single-trial Bernoulli throughout.** Weighted binomial (`n_trials > 1`) is
reachable in `.vgh_fit()` (15.99 s at the largest corner) but is **out of scope**:
it would double the design for an axis the 148-fit claim never touched, and it is
the axis on which the dev engine crashes, so no cross-engine check exists there.
Named in §9.

| grid | cells | arms | fits |
|---|---|---|---|
| A — main binomial, DGP-A | 1250 | vgh, laplace (all); jj (500) | 3000 |
| B — bridge, DGP-B | 225 | vgh, laplace | 450 |
| C — poisson control | 60 | vgh, laplace | 120 |
| | | **TOTAL** | **3,570** |

---

## 5. Metrics and the health definition

### 5.1 Recovery against known truth is health. Convergence is NOT.

This is the standing rule and it is **implemented, not asserted**. The evidence
that it must be: **49 of 50** degenerate Laplace fits in the 148-fit run reported
`convergence == 0 && pdHess` (verified this session), and **59 of 70** in the
published grid (`RESULTS.md` §4). And per the banner, **VGH is no better** — all
ten degenerate corner fits reported `converged = TRUE`, structurally, because
`R/va-vgh.R:603` sets `converged = (outer < maxit)`.

**Convergence is recorded on every row — as a datum to be cross-tabulated against
the truth verdict, never as a filter.** The silent-failure count is a headline
output, not a diagnostic.

### 5.2 Both definitions in circulation, reported side by side

They disagree, so both ship. **`atten_F` is algebraically the stored `sigma`
column** — `atten_F = √(tr(Λ̂Λ̂′)/tr(Λ₀Λ₀′)) = ‖Λ̂‖_F/‖Λ₀‖_F` — which let me
cross-tabulate them on the existing 148 fits without a re-run:

| definition | source | Laplace | VGH |
|---|---|---|---|
| **D1:** `rel_frob > 10` | `analyse-grid.R:94,99`; `vgh-vs-laplace-degeneracy.R:113` | 50 / 148 | **0 / 148** |
| **D2:** `atten_F > 2` or `< 0.2` | `phase0-matched-recovery.R:97` | 50 / 148 | **10 / 148** |

**On Laplace the two agree perfectly — 98/50, zero disagreement cells. On VGH
they disagree on 10 fits.** So **even inside the 148-fit regime, VGH's "0" is
definition-dependent**: D1 says 0, D2 says 10 (6.8%). Reporting only D1 overstates
the VGH advantage. Both go in every table, and any headline states which it uses.

A related finding worth carrying: **VGH's median `atten_F` on the 148 fits is
1.30** (range 0.863–2.524; **0 fits below 0.2, 10 above 2**). VGH systematically
**inflates** loadings by ~30% and never deflates — i.e. its error is in the **same
direction** as Laplace's runaway, differing in magnitude, not in kind. The lane
brief's "the two engines fail in **disjoint** ways" is true of *magnitude and
silence*, but **not of direction**, and should be qualified.

### 5.3 The truth-normalisation trap, and the absolute guard

**Both D1 and D2 are normalised by the truth** — D1 by `‖Λ₀Λ₀′‖_F`, D2 by
`tr(Λ₀Λ₀′)`. When the drawn `Λ₀` is small, both **false-positive**: a modest
absolute error becomes a large relative one. This is a live risk here because
`Λ₀` is redrawn every seed from `N(0, 0.6)` (DGP-A), so small-`Λ₀` draws occur by
construction. **Therefore absolute loading magnitude is recorded on every row and
reported alongside**, reproducing the shipped gate's own statistics:

- **`max_loading_unit = max(apply(L, 1L, max))`** — note **signed** row max, not
  `max(abs())`, matching `R/diagnose.R:403`.
- **`extreme_magnitude = max_loading_unit >= 6`** — the shipped
  `loading_absolute_thresh` (`R/diagnose.R:537-538`).
- **`relative_loading = max_loading / denom`, `denom = max(median, mad(constant=1))`**
  over per-trait maxima (`R/diagnose.R:369-378`), and
  `runaway_loading = relative_loading >= loading_runaway_thresh`
  (`R/diagnose.R:525`).

**Keep these constants byte-identical to the shipped gate**, or the campaign
scores a different instrument than the one that ships. They must be
**re-implemented, not called**: `check_gllvmTMB()`'s statistics read
`fit$report$Lambda_B/W/phy` and gate on `family_id` rows
(`R/diagnose.R:328-430`), and `.vgh_find_lambdas()` (`R/vgh-verify.R:111-131`)
**errors outright** on an object lacking `$report$Lambda_*` — a `vgh_fit` object
cannot be passed to the shipped gate. ~15 lines (§7).

The absolute guard is already earning its place: at n=40, p=80, q=4 the banner
fits carry `max|Λ|` of 8.53–12.53 against the threshold of 6, so the **absolute**
criterion confirms the corner degeneracy **independently of any truth
normalisation**. That is the strongest form of the finding.

### 5.4 The status-conditioned view — a question no existing run answers

Per §2.4c, existing tables pool all finite-`rel_frob` rows with **no status
filter**, while `gtmb_gh` was `healthy` in only 106/640 rows. **"Degeneracy among
fits the engine calls good" is a different question** and is the one that matters
for a shipped gate. Every table is therefore produced twice:

1. **Unconditional** — all rows with finite `rel_frob` (comparable to the
   published grid).
2. **Status-conditioned** — restricted to fits the arm self-reports as good, with
   an **exact-match** `clean` test, never `grepl`:
   `clean <- status %in% c("vgh_converged", "jj_healthy") | status == "laplace_conv0_pdHessTRUE"`,
   plus an explicit assertion that no `conv1_*` label is admitted.

### 5.5 The recorded row

Per fit, one row, always: `grid, dgp, family, n, p, q, seed, arm, status, conv,
seconds, sweeps, rel_frob, atten_F, atten_tr, max_loading_unit, max_abs_loading,
relative_loading, extreme_magnitude, runaway_loading, degenerate_D1,
degenerate_D2, objective, note`.

**`atten_tr = atten_F²` exactly** — the identity documented at
`phase0-matched-recovery.R:17-23`, which resolves the 0.668-vs-0.817
comparability trap. Record both so neither doc's numbers need re-deriving.

### 5.6 Failure accounting — an error is a ROW, never a hole

`run-grid.R:66` states the contract: *"a failure is a ROW, never a silent
omission."* Two mechanisms in the reuse candidates violate it and **both must be
fixed** (§7):

- **`vgh-vs-laplace-degeneracy.R:100,106`** — an R error returns `NULL`, then
  `res[vapply(res, is.data.frame, ...)]` silently drops it. At 150 fits you notice
  2 missing; at 3,570 you do not.
- **`vgh-vs-laplace-degeneracy.R:109`'s `is.finite` filter** — this is the
  dangerous one, and it is **not** the same mechanism the recon flagged. It runs
  *after* the CSV write and drops non-finite rows from the analysis. Under DGP-B
  Laplace hard-fails systematically at n=40/p≥20 (measured), so **the filter
  would discard Laplace's hard failures and bias its degeneracy rate DOWNWARD —
  flattering Laplace, the arm under indictment.** Replace with explicit status
  accounting: `ERROR` / `TIMEOUT` / `no_estimate` are **reported categories with
  counts**, and every rate carries its denominator and the excluded count.

---

## 6. Cost estimate and compute target

### 6.1 Measured per-fit costs

| arm | source | per-fit |
|---|---|---|
| `vgh` | this session, `.vgh_fit()` Q=15, binomial | 0.6 s (n=60,p=6) → 5.58 s (n=400,p=80,q=4) → 8.91 s (n=40,p=80,q=4, 82 sweeps). Q=9 is 34% cheaper. **Mean ≈ 3 s** |
| `laplace` (DGP-A) | `grid.csv`, 320 bernoulli fits | **mean 9.35 s**, median-by-cell 0.46–73.42 s, **max 98.7 s over all 640** |
| `laplace` (DGP-B) | this session | 0.26–1.5 s at p ≤ 12; **724.8 s** at n=400,p=80,q=4 — hence Grid B stops at p=20 |
| `jj` | `grid.csv`, 17,079.3 s / 320 | **mean 53.4 s** |

Cost model for VGH, useful for any re-scoping: **≈1e-5 s per (unit × trait ×
sweep)**, 20–100 sweeps typical.

### 6.2 Projected campaign cost

| component | fits | s/fit | CPU-h |
|---|---|---|---|
| `vgh` (A+B+C) | 1535 | ~3 | **1.3** |
| `laplace` A | 1250 | ~12 | **4.2** |
| `laplace` B (p ≤ 20) | 225 | ~4 | 0.3 |
| `laplace` C (poisson) | 60 | ~10 | 0.2 |
| `jj` A | 500 | 53.4 | **7.4** |
| | **3,570** | | **≈13.5** |

**Budget 20–25 CPU-hours** to absorb the timeout tail and the fact that
degenerate fits are the slow fits (§4.2).

**Wall clock: 30–60 minutes on 96 workers**, budgeting **2 hours**. The
projection is deliberately conservative because the published grid's effective
speedup was only **33.7×, not 64×** — one cell (poisson n=400/p=80/q=4/seed=6)
took **4350.4 s of a 5418.9 s wall, i.e. 80%**. **The wall clock is long-pole
bound, so more workers is not the lever**; the levers are the per-fit cap and
excluding `gtmb_gh` (§4.1), both already applied.

### 6.3 Compute target: Totoro, 96 workers

**Totoro**, `snakagaw@totoro.biology.ualberta.ca`, at **96 workers** — inside the
standing **≤100-core cap** on a shared box.

Reasons: **384 cores, no queue**, and measured **idle** (load average 0.16/0.08/0.03,
409 GB available) — the documented "~90+ cores busy" baseline does not currently
hold. **R 4.5.3** with **gllvmTMB, TMB, gllvm, mirai, Matrix** already in the
default library. **No Duo** — pure key auth, via the existing ControlMaster socket
under the standing 2026-07-16 authority. And **this exact grid already ran there**.
DRAC is **not** needed: single node, well under 100 cores, ~2 h wall. It would
become preferable only at >100 cores, multi-node, or a >6–8 h projected wall, in
which case the documented pattern is a job array `--array=1-1250%100` with tasks
kept ≤3 h to ride the test nodes.

**Honest caveat: at ~13.5 CPU-h this campaign does not *need* 96 cores** — it
would run overnight on the laptop. Totoro is chosen because it is already
provisioned, keeps the corner cells off the workstation, and leaves headroom to
**widen seeds** (the best use of spare capacity, per §10-D3) rather than because
the design is compute-bound.

**Operational requirements**, each from a recorded failure:

- **`OPENBLAS_NUM_THREADS=OMP_NUM_THREADS=MKL_NUM_THREADS="1"` inside every
  worker** (`run-grid.R:44-45`) — else 96 procs × BLAS pool = 400+ threads.
- **Per-fit budget via a killable subprocess.** `FITSEC` in `run-grid.R` is
  **dead code** (declared `:28`, passed `:153`, accepted `:43`, **never
  referenced**) — which is how one fit reached 3742.7 s. And
  **`setTimeLimit` HANGS** (§2.4d). Use `dev/scale/run-scale.R`'s
  `callr::r_session` route with `status="TIMEOUT"` rows. **Cap: 900 s.**
- **Per-cell persistence.** `run-grid.R` writes **nothing** until `mirai_map()`
  returns (`:156-160`); a run that dies at hour 49 of 50 loses everything. Use
  `dev/scale/run-scale.R:303`'s immediate per-cell `saveRDS` plus a
  resume-by-file-existence filter.
- **Grid shuffling** (`run-scale.R:94-95`) so the TMB compile penalty lands
  randomly rather than on the corner cells.
- **A fresh output directory** — e.g. `~/gllvmtmb_vgh_degeneracy_20260730/`.
  **Do NOT write into `~/gllvm_work/`**: `run-grid.R:24` targets
  `~/gllvm_work/results` and lines 158-160 write `grid.rds`/`grid.csv`
  unconditionally, which would **clobber the 2026-07-26 640-cell results this
  campaign compares against**. Also avoid `~/gllvmtmb_design9*` and
  `~/staged-eta-*` — **Codex-owned lanes** that CLAUDE.md fences off.
- **Results stay LOCAL (D-50).** Campaign outputs are **never** GitHub artifacts
  and never run on GitHub Actions. Totoro → local disk.

### 6.4 🔴 Blocker: Totoro's installed gllvmTMB does not contain the VGH engine

`exists(".vgh_fit", asNamespace("gllvmTMB"), inherits = FALSE)` → **FALSE** on
Totoro, while `.approximation_engine_fit` and `.va_r3_fit` → TRUE. And
`find /home/snakagaw -maxdepth 5 -name va-vgh.R` returns **nothing** — no source
tree on the box has it.

The timing rules out the easy explanation: `R/va-vgh.R` reached `main` in PR #819
(merge `063bbbe2`, 2026-07-29 **16:36 UTC**) and the Totoro package was built
2026-07-29 **19:11 UTC** — **2.5 h later**. So the install was **not built from
`main`**; it came from another tree. **VGH presence cannot be inferred from the
version string (`0.6.0`) or the build date.**

**A source push + package reinstall on Totoro is a precondition.** That is a
**write** to a shared box and needs maintainer sign-off (§10-D1). Without it the
VGH arm errors 3,570 times minus the Laplace/jj rows. The §8 smoke plan aborts on
exactly this.

Note also: this worktree is **17 commits behind `origin/main`**
(`git rev-list --left-right --count origin/main...HEAD` → `17 0`, working tree
clean). Rebase before building the Totoro payload, or local harness and remote
install will disagree about "current".

---

## 7. Reuse plan

**Nothing needs to be written from scratch.** The recon's verdict holds and I
confirm it: every component exists across three files. The work is **assembly
plus the Totoro package refresh**, not authorship.

**Base the driver on `dev/heywood/vgh-vs-laplace-degeneracy.R`**, not
`run-grid.R`. The recon supports this and so does the measurement: it already
targets the **in-package** `.vgh_fit()`, its Σ extraction is provably like-for-like
(§2.4a), its design is 6 lines, and its seed derivation extends without breaking
existing cells. `run-grid.R` contributes the shell.

### 7.1 Verbatim — no edits

From `dev/heywood/vgh-vs-laplace-degeneracy.R`:
- **The VGH arm, `:76-89`** — the `.vgh_fit()` call, timing, and
  `tcrossprod(as.matrix(vg$Lambda))` scoring. The single highest-value transplant;
  it targets the shipped engine.
- **The Laplace Σ extraction, `:69-71`** — `L <- la$report$Lambda_B`, then
  `norm(tcrossprod(L) - G_true, "F") / nG`. **Sidesteps the link-implicit-residual
  caveat entirely** (§2.4a).
- **The long-format index convention, `:52-54`** — `yv <- as.numeric(t(Y))`,
  `tr <- rep(seq_len(p), times = n)`, `un <- rep(seq_len(n), each = p)`. Unit-major,
  matches `run-grid.R:59-61`. **Do not re-derive**: the row-major version silently
  transposes and fits the wrong dataset (documented `R/va-vgh.R:436-441`, caught
  only by the gaussian-exactness oracle).
- **The seed derivation, `:44`** — `set.seed(cl$seed * 4021L + cl$n * 19L + cl$p)`.
  **n- and p-dependent, with no `q` term.** Reuse **exactly as-is**: adding new
  n/p levels leaves every existing cell byte-reproducible. **Do not add a `q`
  term** — that would re-seed all existing cells and destroy the Grid B
  regression check (§8).
- **The silent-failure cross-tab, `:113-125`** — "of which reported clean", the
  discipline made executable.
- **`%||%`, `:38`.**

From `dev/totoro-grid/run-grid.R`:
- **`row()` and `timed()`, `:66-86`** — the failure-is-a-row contract plus
  warning-muffling error→`cell_error` conversion.
- **Thread pinning, `:44-45`.**
- **`OUT <- file.path(Sys.getenv("HOME"), …)` + `GRID_SMOKE`/`GRID_WORKERS` env
  knobs, `:24-28`** — HOME-relative, Totoro-native (change the leaf dir, §6.3).
- **The mirai driver, `:146-153`** — `daemons(NWORK, dispatcher = TRUE)`,
  `mirai_map(cells, run_cell)[.progress]`, `on.exit(daemons(0))`.
- **The `jj` arm invocation, `:89-95`** (with `eval_method = "jj"`).

From `dev/scale/run-scale.R`:
- **Per-cell persistence, `:303`** (+ `cell_id` at `:85`), the **`callr::r_session`
  fit budget** with `status="TIMEOUT"` rows (`:248-281`), **grid shuffling**
  (`:94-95`), and **warm-up cells** (`:317+`).

From `dev/vgh/phase0-matched-recovery.R`:
- **`metrics()`, `:88-100`** — verbatim **as metrics only**: pure linear algebra
  with dimension/finiteness guards, and the `atten_tr = atten_F²` identity
  (`:17-23`). **Its `degenerate` field is definition D2** — keep it *labelled* as
  D2, never as "the" definition (§5.2).
- **`blank_row()`, `:102-108`** — extend the column set per §5.5.

From `tests/testthat/test-vgh-oracle.R`:
- **`.vgh_test_long(Y, NT, X)`, `:9-33`** — the column-major-correct long packer.

### 7.2 Re-parameterised

- **The design block**, `vgh-vs-laplace-degeneracy.R:31-36` → the three grids of
  §4. This is the only design statement in the file.
- **`q` from module scalar to grid column** — `:30` moves into `expand.grid`, read
  as `cl$q` at `:46, :61, :79`. **4 line edits.** (Keep it out of the seed
  formula, §7.1.)
- **`dgp` as a new factor** (A/B, §4.2–4.3) selecting the `Λ`/`B` draw scale.
- **`mc.cores = 6` (`:105`) → mirai `daemons(96)`** — replace `mclapply` with the
  `run-grid.R:146-153` driver so cells are isolated and progress is visible.
- **`analyse-grid.R`'s `ARMS` vector, `:14-16`** — adding `vgh` is a one-line
  change and the §3/§5 table generators (`:72-90`, `:107-138`) pick it up. Its
  `reshape()`-to-wide + `pair()` agreement helper and bound-ordering block with
  the sign-inversion alarm (`:41-69`) apply directly to "does VGH agree with jj on
  the same data".

### 7.3 Written new — five items, all small

1. **The degeneracy scorer, ~15 lines** — §5.3. `max_loading_unit` (**signed**
   row max), `relative_loading` with `denom = max(median, mad(constant=1))`,
   `extreme_magnitude`, `runaway_loading`. Constants byte-identical to
   `R/diagnose.R`. **Must be re-implemented, not called** — `check_gllvmTMB()` and
   `.vgh_find_lambdas()` both reject a `vgh_fit` object.
2. **A status vocabulary for the VGH arm** — it has none (`.vgh_fit()` returns
   `$converged` logical, **no `$status` string**). Requirement, from the audit
   bug: **no success token may appear as a substring of a failure label.** Use
   `vgh_converged` / `vgh_hit_maxit` / `vgh_error` / `vgh_timeout` — never
   `not_converged`.
3. **An exact-match `clean` test** replacing `analyse-grid.R:100`'s unanchored
   `grepl` (§5.4), with an assertion that no `conv1_*` label is admitted.
4. **The status-conditioned table pass** (§5.4) — does not exist anywhere.
5. **Explicit status accounting replacing the `is.finite` drop** (§5.6) — the
   fix that stops the harness flattering Laplace.

### 7.4 Explicitly NOT reused

- **`dev/vgh/vgh-engine.R` and anything calling it** — §3.1. In particular
  `phase0-matched-recovery.R`'s `arm_vgh()` (`:142-150`) calls the **prototype**;
  repoint or discard.
- **`phase0-matched-recovery.R` as a driver.** Line 31
  `repo <- "/private/tmp/gllvmtmb-vgh"` — **that directory does not exist**;
  `RUN_DIR`, `SCRIPT`, both `source()` calls (`:213-214`), the output CSV (`:266`)
  and markdown (`:373`) all derive from it, so it fails at the first `source()`.
  Line 191's `BUILD_CACHE` points into **another Claude session's scratchpad**
  (`faeb944c-…`, not this session) and caches a **macOS** `.so` — worthless on
  Linux Totoro, and `prime_va_r3_dll()` fails **silently**
  (`return(invisible(FALSE))`). Its `T_TRAITS`/`Q_LATENT` are module constants, so
  p and q are not sweepable, and `analyse()` (`:273-377`) is hardwired to literal
  arm names with no p or q aggregation. **Take `metrics()` and `blank_row()`;
  leave the driver.**
- **`phase0`'s `run_arm()` timeout** — built on `setTimeLimit`, which hangs
  (§2.4d). Use the `callr` route instead.
- **`extract_Sigma_B()`** — §2.4a.
- **`gllvm_va` / `gllvm_eva` arms** — §4.1.

---

## 8. Smoke plan

**Nothing launches until a 6-cell smoke passes.** Cells: one per arm per family
at the cheapest corner, plus the regression cell and the expensive corner.

| # | cell | arm(s) | must produce |
|---|---|---|---|
| S1 | n=60, p=6, q=2, seed=1, DGP-B | vgh, laplace | **the regression check** — `rel_frob` for both arms **exactly equal** to the stored row in `dev/heywood/vgh-vs-laplace-degeneracy.csv` |
| S2 | n=40, p=80, q=4, seed=1, DGP-B | vgh | reproduces the banner: `rel_frob ≈ 10.671`, `atten_F ≈ 3.15`, `max|Λ| ≈ 12.53`, `converged = TRUE` |
| S3 | n=400, p=80, q=4, seed=1, DGP-A | vgh, laplace, jj | all three return a row; Laplace **under the 900 s cap** |
| S4 | n=40, p=20, q=2, seed=1, DGP-B | laplace | an **`ERROR` row** with `"All 1 restarts failed."` in `note` — proving failures are recorded, not dropped |
| S5 | n=100, p=12, q=2, seed=1, DGP-A | vgh, jj | poisson-family sibling runs; `jj` returns `status` |
| S6 | n=40, p=12, q=2, seed=1, DGP-A, poisson | vgh, laplace | poisson-log admitted by `.vgh_fit()` |

**Validity assertions on the smoke CSV**, all of which must hold:

1. **Non-empty**, and **row count exactly equals** `cells × arms` requested — no
   holes (§5.6).
2. **All columns of §5.5 present**, none entirely `NA`.
3. `rel_frob` **finite and > 0** in every non-ERROR row; `atten_F` **finite and in
   (0, 20)**; `atten_tr` equals `atten_F²` to 1e-12 (the §5.5 identity).
4. `degenerate_D1` and `degenerate_D2` both present and **not identical columns**
   (they must be able to disagree, §5.2).
5. `max_loading_unit`, `relative_loading`, `extreme_magnitude` present; the
   thresholds used equal `R/diagnose.R`'s (assert the constants, don't trust them).
6. Every `status` value matches the **exact-match** `clean` vocabulary; **assert no
   status string contains another status string as a substring** — the mechanical
   guard against the audit bug.
7. S1 reproduces the stored `rel_frob` **exactly** for both arms.

**Abort conditions — any one stops the launch:**

- **`exists(".vgh_fit", asNamespace("gllvmTMB"), inherits = FALSE)` is FALSE on the
  compute host.** The §6.4 blocker. Check this **first, on Totoro, before any
  cell** — it is the single most likely failure and it would silently void every
  VGH row.
- Any `stop()` from `.vgh_validate_data()` / `.vgh_long_to_wide()` — means an
  eligibility limit in §3.4 was violated by the design; **fix the design, do not
  loosen the validator.**
- S1 does **not** reproduce the stored `rel_frob` — the DGP, seed derivation, or
  index convention has drifted. **Do not proceed with a "close enough" match.**
- S4 produces **no row** (rather than an ERROR row) — the failure-accounting fix
  (§5.6/§7.3-5) is not working, and the campaign would flatter Laplace.
- S3's Laplace exceeds **900 s** — the budget is mis-set or the DGP-A assumption
  of §4.2 is wrong; **re-cost before launching 3,570 fits.**
- Any smoke fit returns `rel_frob = NA` with `status` reporting success — a
  scorer/extractor mismatch.
- Totoro load average > ~50 or another lane's process is visible in
  `~/gllvm_work/` — a **foreign lane may be active**; surface it, do not proceed
  (§10-D1).

---

## 9. What this campaign will NOT establish

The negative space, explicitly. This campaign **does NOT cover**:

- **Any claim that VGH is a production estimator.** `.vgh_fit()` is self-fenced
  `research_only = TRUE, model_selection_comparable = FALSE`
  (`R/va-vgh.R:606-607`). Every output carries that fence.
- **Model selection, AIC/BIC, or any cross-arm objective comparison.** The ELBO
  is not comparable across arms by the engine's own declaration. Objectives are
  recorded for provenance only.
- **Inference: standard errors, coverage, confidence intervals, or p-values.**
  Recovery of `ΛΛ′` against known truth, only.
- **The default user-facing model.** Every fit uses
  `latent(..., unique = FALSE)` — **loadings-only, Psi SUPPRESSED**. Ordinary
  `latent()` has carried a diagonal Psi **by default since 2026-06-18**, so these
  are **not** fits of the grammar users get by default. A Psi-carrying degeneracy
  question is separate and untouched.
- **Non-logit binomial links.** `probit` and `cloglog` are rejected
  (`R/va-vgh.R:396-400`).
- **Weighted binomial (`n_trials > 1`).** Reachable but out of scope (§4.5) — and
  the axis on which the dev engine crashes, so no cross-engine check exists there.
- **Unbalanced grids, missing cells, per-trait covariates, `q > 6`, or any
  non-`unit` tier** — all rejected by `.vgh_validate_data()` (§3.4). Phylo,
  spatial, animal, kernel, and `dep`/`scalar` structure are entirely outside it.
- **Gaussian.** Deliberately closed (§2.3).
- **Any head-to-head against `gllvm`.** Its VA is probit-only for binary while
  `.vgh_fit()` is logit-only, so a same-link comparison is **impossible**; and
  the `gllvm_eva` scoring problem (§2.4b) makes the published figure unciteable.
- **Whether a bad fit is a bad optimum or a bad basin.** **Neither engine has a
  settable start or multi-start** (§3.4), so "the optimiser found a bad basin"
  cannot be separated from "the likelihood's maximum IS bad". Note the warm-start
  route is already **refuted** for the analogous Laplace problem (§2.5), so this
  may be a non-issue by design — but it is an explicit limitation, not an
  unexamined gap.
- **Arm-fairness parity on multi-start.** `jj`/`va_r3` runs its production
  multi-start health gate (`n_starts = 4`) while **VGH and Laplace are
  single-start** — the asymmetry recorded at
  `phase0-matched-recovery.R:277-279`. Any VGH-vs-`jj` degeneracy comparison
  inherits it and must say so.
- **Byte-comparability with the published 640-cell grid.** Grid A shares that
  grid's DGP and n/p/q envelope but changes the arm set, adds `p = 6, 12` and
  `n = 60`, uses `Q = 9`, and scores Laplace from `report$Lambda_B`. It is
  **comparable in design, not a re-run.**
- **A decision.** The campaign produces the table that sizes the investment. The
  build/don't-build call is the maintainer's.

---

## 10. Open decisions for the maintainer

**D1 — 🔴 Authorise the Totoro package refresh (blocking).**
The installed `gllvmTMB 0.6.0` on Totoro **does not contain `.vgh_fit`**, and no
source tree on the box has `va-vgh.R` (§6.4). The campaign cannot run a VGH arm
until current source is pushed and the package reinstalled — a **write to a
shared box**, adjacent to Codex-owned lane material (`~/gllvmtmb_design9*`,
`~/staged-eta-*`, and live files in `~/gllvm_work/`).
**Recommendation: authorise, into a fresh `~/gllvmtmb_vgh_degeneracy_20260730/`
with its own `R_LIBS` private library**, leaving the existing
`/home/snakagaw/R/lib/gllvmTMB` untouched so no Codex lane's install changes
under it. Rebase this worktree (17 commits behind `origin/main`) first.

**D2 — Which DGP is primary.**
This is a **10× cost decision and a fit/no-fit decision**, not cosmetic (§4.2).
DGP-B (`N(0,0.7)`, the 148-fit DGP) makes Laplace **hard-fail at n=40/p≥20** and
costs **724.8 s** at the corner; DGP-A (`N(0,0.6)`, the Totoro DGP) keeps Laplace
fittable everywhere at a **73.42 s** median there.
**Recommendation: DGP-A primary (Grid A), DGP-B retained on the cheap subset
(Grid B) so the 148-fit result is extended rather than orphaned.** The cost is
that the headline is no longer byte-comparable to the existing 148 fits — which
Grid B's 9 overlapping cells mitigate by acting as the regression check.

**D3 — Seed count: 25, or spend the spare capacity?**
At ~13.5 CPU-h the campaign uses a small fraction of a 96-core box for an hour.
**Recommendation: launch at 25 seeds, and if the smoke and first quartile look
clean, widen the binomial seeds to 50** — the corner rates are the load-bearing
numbers and 25 seeds gives them a ±10pp MCSE, which is loose for a rate near 50%.
Widening seeds is a better use of Totoro than widening n or p.

**D4 — Does `gtmb_jj` being clean end the project?**
The shipped VA route is **0/320 degenerate under both D1 and D2 and 0/320 on the
absolute gate** in the published grid, where VGH is **10/148 under D2**. If Grid A
confirms `jj` clean where VGH is not, **the case for a VGH engine investment is
largely gone** — the pluralist story would be "Laplace + Heywood gate + the
existing `va_r3` JJ route", needing no new engine.
**Recommendation: treat this as the campaign's primary decision axis, not a side
arm.** It is the cheapest path to a "do not build it" answer, and it is why `jj`
is in the design at all.

**D5 — Accept single-start, or fund a `start` argument?**
Neither engine has one (§3.4); adding it is real code (a new argument threaded to
`.vgh_init`, or an `assignInNamespace` shim), and it would also remove the
`n_starts = 4` asymmetry against `jj` (§9).
**Recommendation: accept single-start for this campaign and record the limitation.**
The warm-start route is already refuted for the analogous Laplace problem (§2.5),
so the expected information gain is low relative to the cost.

**D6 — Which definition leads the write-up?**
D1 (`rel_frob > 10`) and D2 (`atten_F` outside [0.2, 2]) **agree perfectly on
Laplace but disagree on 10 of 148 VGH fits** (§5.2), so the choice materially
changes the VGH headline (0% vs 6.8%).
**Recommendation: lead with D1 for continuity with the published grid, report D2
in the same table, and lead the *VGH-specific* claim with the absolute
`max_loading_unit >= 6` gate** — it is truth-normalisation-free, it is the
statistic that actually ships, and it independently confirms the corner
degeneracy (`max|Λ|` 8.53–12.53 against a threshold of 6).

**D7 — Correct `RESULTS.md:117` before anything cites it?**
The fairness audit found the published `203` should be **160** and says so must be
fixed "before this claim is used in any external or public-facing context"
(§2.4b). This campaign does not depend on that number.
**Recommendation: fix it as a separate one-line doc commit, not inside this
campaign** — it is a published-number correction and deserves its own visible
change rather than being buried in a campaign diff.

---

## Provenance of the numbers in this scope

- **Measured by me this session** (macOS arm64, R 4.6.0, single core; repo left
  clean; scratch in this session's scratchpad): the 10 corner probes in the
  banner; the D1-vs-D2 cross-tabulation and VGH `atten_F` distribution on the 148
  fits; the Laplace degeneracy rate by (n,p); Laplace's `"All 1 restarts failed."`
  boundary at n=40/p≥20 in **both** grammars; long-grammar 724.8 s and
  wide-grammar >14 min at n=400/p=80/q=4 under DGP-B; the DGP-A Laplace
  median/max/mean and per-(n,p) degeneracy from `grid.csv`; `jj`'s 0/320 under
  both definitions and 53.4 s/fit mean.
  **Caveat: the corner probes are single-seed, unpaired (no Laplace arm at
  n=40/p=80/q=4 under DGP-B, which errors), and on a laptop.** They are sufficient
  to refute "0% everywhere" and to locate the corner; they are **not** a rate
  estimate. That is what the campaign is for.
- **From the recon, not re-derived by me:** `.vgh_fit()`'s validator surface and
  the `Q = 9` equivalence; the dev-engine `n_trials` crash; the matched-settings
  engine agreement table (§3.3); Totoro's state and the missing `.vgh_fit`;
  per-arm CPU shares of the published grid.
- **Not established anywhere, and flagged rather than invented:** whether the long
  and wide Laplace grammars are **numerically equivalent** (only cost was probed,
  and only at one cell); whether DGP-A's Laplace failure profile at n=40 matches
  DGP-B's; the exact wall clock at 96 workers.
