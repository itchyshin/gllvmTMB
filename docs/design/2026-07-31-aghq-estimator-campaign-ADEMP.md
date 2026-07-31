# ADEMP design — does AGHQ produce better point estimates than Laplace, and where?

**gllvmTMB · AGHQ estimator-validation lane · 2026-07-31 · Claude (Fable 5)**
**Status: DESIGN, PRE-REGISTERED. Nothing has been run against it. 🔴 Not approved.**

Framework: **ADEMP** (Morris, White & Crowther 2019, *Stat Med* 38:2074–2102).
Reporting: the **11 transparent-reporting items** of Williams et al. (2024), *MEE*
15:1926–1939 (self-audit table at the end).

This is the design the lane exists to produce. Per the lane brief, **the design is the
work**; the compute is ~8.9 wall-clock hours and is the easy part.

---

## 0 · Why the existing evidence cannot answer the question

Stated first because it determines almost every choice below.

1. **No test anywhere compares an AGHQ point estimate to a known truth** (#842). Six
   independent checks confirm the *integrator*; zero address the *estimator*.
2. **The `aghq` arm of every existing campaign is single-start and optimiser-limited.**
   Established 2026-07-31 (#843, PR #870): on 16/40 seeds at n=100 the catastrophic
   runaway is **not** the MLE — 16/16 — and a truth-free multi-start recovers it,
   taking catastrophic fits 16/40 → 1/40. **So any campaign that runs only the shipped
   single-start AGHQ arm measures the START, not the ESTIMATOR.** This is why arm
   `aghq_ms` below is not optional.
3. **The ridge is ON by default whenever AGHQ is on.** A campaign that ignores it
   measures AGHQ+ridge, not AGHQ. The comparison must be like-for-like on the penalty.
4. **`aghq_used = TRUE` does not mean the quadrature moved the answer**
   (`decisions.md:1927-1938`) — for gaussian (89.6%) and poisson (74.0%) AGHQ returns the
   Laplace answer bit-for-bit. Apparent agreement is not statistical agreement, and the
   design must be able to tell them apart.
5. **AGHQ Stage 1a is loadings-only**, so the campaign runs on the **non-default**
   grammar `latent(..., unique = FALSE)`. Nothing it produces can speak to the default
   grammar (#842 §5a, §7 item 6). This is a scope limit, not a caveat to bury.

---

## A · Aims (Williams item 1)

**Primary aim.** Determine whether, and in which regimes, AGHQ yields more accurate
point estimates of the latent trait-correlation structure than the Laplace approximation
in stacked-trait GLLVMs, **holding the loading penalty and the start rule fixed** so the
quadrature is the only thing that varies.

**Secondary aims.**

- **S1.** Separate the estimator effect from the optimiser effect, by running AGHQ under
  both the shipped single start and a truth-free multi-start (the #843 finding).
- **S2.** Establish where the quadrature *does anything at all* — the fraction of fits on
  which AGHQ moves the parameter vector away from the Laplace optimum (`par_shift`), by
  family. A family where it never moves needs no accuracy claim either way.
- **S3.** Quantify the cost: convergence failures, runaway/Heywood rate, and wall time.
- **S4.** Test the audit's mechanism hypothesis that the driver is **‖Λ‖**, not traits
  per unit — by varying ‖Λ‖ directly (§3 of #842; the O(1/T) hypothesis was retracted).

**Explicitly NOT an aim.** Interval coverage. It is a different and far more expensive
question, and mixing it in is how this campaign becomes unfinishable. Deferred by name.

---

## D · Data-generating mechanism (Williams item 2)

### D.1 The model, as math

For unit (site) $s = 1,\dots,n$ and trait $t = 1,\dots,p$, with $q$ latent dimensions:

$$
\mathbf{z}_s \sim \mathcal{N}(\mathbf{0}, \mathbf{I}_q), \qquad
\eta_{st} = b_t + \boldsymbol{\lambda}_t^{\top}\mathbf{z}_s, \qquad
y_{st} \mid \mathbf{z}_s \sim \mathcal{F}\big(g^{-1}(\eta_{st}), \phi\big)
$$

with loadings $\boldsymbol{\Lambda} = [\boldsymbol{\lambda}_1,\dots,\boldsymbol{\lambda}_p]^{\top} \in \mathbb{R}^{p\times q}$,
generated as $\Lambda_{tk} \sim \mathcal{N}(0, \sigma_\lambda^2)$, and intercepts
$b_t \sim \mathcal{N}(0.3, 0.4^2)$.

The induced latent covariance and correlation among traits are

$$
\boldsymbol{\Sigma}_B = \boldsymbol{\Lambda}\boldsymbol{\Lambda}^{\top}, \qquad
\mathbf{R}_B = \mathbf{D}^{-1/2}\boldsymbol{\Sigma}_B\mathbf{D}^{-1/2}, \quad \mathbf{D} = \operatorname{diag}(\boldsymbol{\Sigma}_B).
$$

**This DGP is byte-identical to `mk()` in `18-shipped-engine-campaign.R` / `22` / `23`**,
deliberately, so the campaign is continuous with the existing evidence base rather than a
fresh island. It is the well-specified case: the fitted model is the generating model.
Misspecification is a separate study and is **not** in scope (justified in §M.4).

### D.2 Levels varied

| factor | levels | why |
|---|---|---|
| $n$ (units) | **100, 400, 1600** | the crossover regime; #842 §6 puts the σ crossover between 400 and 1600 |
| family | **binomial** (Stage 1); **gaussian, poisson** (Stage 2) | binomial is where AGHQ demonstrably does work; the other two are the *does-it-move-at-all* controls (S2) |
| $\sigma_\lambda$ | **1, 3** (Stage 1) | ‖Λ‖ is the measured driver (#842 §3); 3 is where the ridge starts over-shrinking (#847) |
| arm | **5**, see §M | the like-for-like penalty and start contrasts |
| $p$, $q$ | fixed at **6, 2** | held fixed on purpose — the retracted O(1/T) hypothesis means $p$ is not the driver; varying it would spend compute on a refuted mechanism |

**Fixed across all cells:** $p=6$, $q=2$, `aghq = 9`, grammar
`traits(...) ~ 1 + latent(1 | site, d = 2, unique = FALSE)`, binomial Bernoulli
(`n_trials = 1`).

### D.3 Number of replicates, justified by MCSE (Williams item 2, `2.7.3`)

**Not chosen by habit.** Computed from a real pilot: the 40 seeds already run in #843
(`22-truthstart.csv`), same cell.

The design is **paired within replicate** — every arm is fitted to the *same* simulated
dataset — so the primary contrast is a within-replicate difference and its MCSE uses the
SD of the paired differences, not of the arms:

| quantity (pilot, n=40, binomial n=100) | value |
|---|---|
| SD of the arm-level ρ-MAE | 0.1386 / 0.1362 |
| **SD of the paired difference** | **0.0624** |
| precision gain from pairing | **2.2×** |

Required replicates so that $3 \times \mathrm{MCSE} < \delta$ on the paired ρ-MAE
difference:

| δ (practical threshold) | 0.05 | 0.03 | **0.02** | 0.01 |
|---|---|---|---|---|
| $n_{\text{sim}}$ needed | 15 | 39 | **88** | 351 |

**Decision: $n_{\text{sim}} = 400$ per cell (Stage 1), 200 (Stage 2).**

Justification: 400 gives $3\times\mathrm{MCSE} = 0.0094$ on the paired ρ-MAE difference —
comfortably below the pre-registered practical threshold $\delta = 0.02$ (§P.3) — and
$\mathrm{MCSE} \le 0.025$ on any proportion (runaway, convergence), which are the
secondary measures and need only be resolved to a few percent. Stage 2's 200 gives
$\mathrm{MCSE} \le 0.035$ on a proportion, adequate for S2, which is a near-0/near-1
question.

### D.4 Seeds and reproducibility (Williams items 6–8)

Master seed fixed at the top of the runner; per-replicate seeds derived once via
`sample.int(.Machine$integer.max, n_sim * n_cells)` and **stored in the output**, so any
single fit is independently reproducible. `sessionInfo()` written next to the results.
Output is **per-cell incremental CSV/RDS** so a kill leaves usable rows (the existing
convention in `dev/aghq-evidence/`).

---

## E · Estimands and targets (Williams item 3)

**Λ is identified only up to a $q\times q$ orthogonal rotation.** Any elementwise estimand
on Λ is therefore meaningless without a Procrustes alignment, and alignment introduces its
own choices. The design avoids the problem instead of managing it.

**Primary estimand: the off-diagonal of the latent trait-correlation matrix** $\mathbf{R}_B$
— the $p(p-1)/2 = 15$ unique entries $\rho_{tt'}$. It is **rotation-invariant** by
construction, it is the quantity JSDM users actually publish, and it is already the
`rho_absd` column of the existing evidence base, so the campaign extends rather than
replaces.

- *true value*: $\rho_{tt'}$ computed from the realised $\boldsymbol{\Lambda}$ of that replicate
  (replicate-specific truth, stored per replicate).
- *estimator output*: the same functional of $\hat{\boldsymbol{\Lambda}} = $
  `fit$report$Lambda_B`.

**Secondary estimands.**

| estimand | true value | why secondary |
|---|---|---|
| latent SD ratio $\sigma$ | $\sqrt{\operatorname{diag}(\boldsymbol{\Sigma}_B)}$ | scale, not structure; rotation-invariant; continuity with #842 §6 |
| Frobenius ratio $\lVert\hat{\boldsymbol\Lambda}\rVert_F / \lVert\boldsymbol\Lambda\rVert_F$ | 1 | the runaway detector used throughout the evidence base |
| intercepts $b_t$ | generated $b_t$ | identified without rotation; a cheap sanity channel |

---

## M · Methods / arms (Williams item 4)

Five arms, fitted to **the same data** in every replicate. The set is deliberately small
and each entry earns its place.

| # | arm | control | what it isolates |
|---|---|---|---|
| 1 | `laplace` | `gllvmTMBcontrol()` | the incumbent default |
| 2 | `laplace_ridge` | `gllvmTMBcontrol(aghq_ridge = 2)` | **the fair control.** The penalty without the quadrature |
| 3 | `aghq` | `gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)` | the shipped AGHQ arm — **single-start, known optimiser-limited** |
| 4 | `aghq_ms` | as 3, both starts run to convergence, better final objective kept | **AGHQ as an estimator**, with the #843 optimiser artefact removed |
| 5 | `aghq_ridge` | `gllvmTMBcontrol(aghq = 9)` | the shipped AGHQ default (ridge on) |

**The contrasts that carry the aims — like-for-like on the penalty, always:**

- **Primary:** `aghq_ms` − `laplace` (no penalty either side) → *does the quadrature help?*
- **Primary, penalised:** `aghq_ridge` − `laplace_ridge` → *does it help when both are penalised?*
- **S1:** `aghq_ms` − `aghq` → *how much of the shipped AGHQ arm's behaviour is the start?*
- **Never** `aghq_ridge` − `laplace`. That is the confound #842 named, and it is banned
  from the analysis by pre-registration.

Arm 4 requires the `control$aghq_start_par` hook (PR #870). **If the maintainer ungates
the start selection under `aghq_ridge = Inf` (#843), arm 4 becomes the shipped behaviour
and arm 3 becomes the historical control — the design is unchanged either way.** This is
deliberate: the campaign does not depend on that decision.

**Literature anchor** (Williams item 4). The repo's own verified prior-art notes are the
anchor, and they carry explicit `UNVERIFIED` flags:
`dev/aghq-evidence/07-prior-art-crossover.md` (Laplace/AGHQ crossover in small-sample
loading recovery) and `17-regularization-prior-art.md` (priors on loadings in the IRT
tradition). Standard methodological references for the approximations themselves — Naylor
& Smith (1982), Liu & Pierce (1994), Pinheiro & Bates (1995) for adaptive Gauss–Hermite;
Breslow & Lin (1995) and Joe (2008) for the small-sample bias of Laplace-type
approximations; Hui et al. (2017) and Niku et al. (2019) for GLLVM estimation. **Each must
be re-verified against a primary source before it appears in any manuscript** — the repo's
own convention, and the reason those two notes flag `UNVERIFIED` inline.

---

## P · Performance measures (Williams item 5)

All computed per replicate, then aggregated with MCSE (item 11). $B$ = replicates.

### P.1 Primary

Per replicate $b$, over the 15 off-diagonal entries indexed by $e$:

$$
\mathrm{MAE}_b^{(\text{arm})} = \frac{1}{15}\sum_{e}\big|\hat\rho_{b,e} - \rho_{b,e}\big|
$$

**The headline is the paired difference**, e.g. for the primary contrast

$$
\Delta_b = \mathrm{MAE}_b^{(\text{laplace})} - \mathrm{MAE}_b^{(\text{aghq\_ms})},
\qquad
\bar\Delta = \frac{1}{B}\sum_b \Delta_b,
\qquad
\mathrm{MCSE}(\bar\Delta) = \frac{\mathrm{sd}(\Delta_b)}{\sqrt{B}}
$$

$\bar\Delta > 0$ means **AGHQ is more accurate**. Reported with a 95% interval
$\bar\Delta \pm 1.96\,\mathrm{MCSE}$.

Also reported per arm, for the full performance table: bias
$\frac{1}{B}\sum_b(\hat\rho_{b,e}-\rho_{b,e})$ averaged over $e$, and
$\mathrm{RMSE} = \sqrt{\frac{1}{B}\sum_b(\hat\rho_{b,e}-\rho_{b,e})^2}$, each with MCSE
(`sd/√B`; RMSE by bootstrap, as the closed form is awkward — skill's own note).

### P.2 Secondary

| measure | formula | MCSE |
|---|---|---|
| σ accuracy | $\lvert\operatorname{median}_t(\hat\sigma_t/\sigma_t) - 1\rvert$ | bootstrap |
| **runaway rate** | $\Pr(\lVert\hat{\boldsymbol\Lambda}\rVert_F/\lVert\boldsymbol\Lambda\rVert_F > 2)$ | $\sqrt{p(1-p)/B}$ |
| **catastrophic rate** | same at $>5$ | $\sqrt{p(1-p)/B}$ |
| convergence | $\Pr(\texttt{opt\$convergence} = 0)$ | $\sqrt{p(1-p)/B}$ |
| **quadrature-moved rate** (S2) | $\Pr(\max\lvert\hat\theta_{\text{aghq}} - \hat\theta_{\text{laplace}}\rvert > 10^{-6})$ | $\sqrt{p(1-p)/B}$ |
| wall time | median seconds/fit | bootstrap |

**`quadrature-moved rate` is not optional.** It is the measure that prevents the
gaussian/poisson error of reporting a bit-for-bit-identical answer as statistical
agreement (`decisions.md:1927-1938`).

### P.3 🔴 Acceptance rule, fixed in advance

Practical threshold **δ = 0.02** on the paired ρ-MAE difference. Justification: observed
ρ-MAE is ≈ 0.28–0.31 in the pilot, so δ is ≈ 7% of the quantity — a difference smaller
than that would not change any user's conclusion; and $n_{\text{sim}}=400$ resolves it at
$3\times\mathrm{MCSE} = 0.0094$, comfortably finer.

Per cell, per contrast, exactly one verdict:

| verdict | condition |
|---|---|
| **AGHQ HELPS** | $\bar\Delta > \delta$ **and** the 95% interval excludes $\delta$ |
| **AGHQ HURTS** | $\bar\Delta < -\delta$ **and** the interval excludes $-\delta$ |
| **NO PRACTICAL DIFFERENCE** | the whole 95% interval lies inside $(-\delta, +\delta)$ — an **equivalence** conclusion, not a failed test |
| **INCONCLUSIVE** | anything else |

**Pre-registered predictions** (so the campaign can be wrong, per the repo's own
convention in scripts 12 and 18):

- **P1.** Binomial, $n=100$: `aghq_ms` − `laplace` will be **much closer to zero** than
  the existing single-start comparison implies. The 73%-vs-47% runaway gap is largely an
  optimiser artefact (#843).
- **P2.** Binomial, $n=1600$: **AGHQ HELPS** on both primary contrasts.
- **P3.** Gaussian and poisson: **quadrature-moved rate near 0**, hence **NO PRACTICAL
  DIFFERENCE** — and the correct report is "the optimisation did not move", not
  "the methods agree".
- **P4.** The `laplace_ridge` − `laplace` contrast will show the ridge trading σ accuracy
  for runaway control at $\sigma_\lambda = 3$ (#847's table), independent of engine.

If **P2 fails**, the honest headline is *"AGHQ does not demonstrably improve point
estimates anywhere we measured"* — and that is a publishable, lane-closing result, not a
failure of the campaign.

### P.3b 🔴 AMENDMENT, made after the 10-seed smoke test and before any campaign run

Recorded in the open rather than quietly applied. The smoke test (1 cell, 10 replicates,
50 fits) invalidated two things in the design above, both about **measurement validity**,
neither about the direction of any answer. The grid had not been run.

**Amendment 1 — convergence must be read from `aghq$stop_reason`, not `opt$convergence`.**
On the AGHQ path `opt$convergence` is nlminb's code for the **per-pass iteration cap** set
by the continuation schedule; it returns 1 ("iteration limit reached") on a healthy fit.
The original design would have measured the cap and called it non-convergence. The engine's
own verdict is `aghq$stop_reason`, and the only value meaning converged begins
`"converged (adaptation mode fixed; gradient below tolerance)"`.

**Amendment 2 — convergence becomes a PRIMARY OUTCOME, not a gate.** With the correct
field, the smoke shows the AGHQ adaptation loop reports clean convergence in **3/30 fits**:

| stop reason | n/30 |
|---|---|
| `stalled (no honest descent at cap 1 after backtracking)` | **20** |
| `stopped: … max \|grad\| = 1.0e-4 … 2.2e-4 exceeds the tolerance` | 7 |
| `converged (adaptation mode fixed; gradient below tolerance)` | **3** |

The original 90% convergence gate would therefore mark **every AGHQ cell INCONCLUSIVE**
and the campaign could not answer its own question. Lowering the gate to fit the data
would be exactly the post-hoc tuning pre-registration exists to prevent. So the gate is
**removed and replaced by reporting**:

- Convergence rate per arm per cell, with MCSE, is a **headline performance measure**.
- The accuracy contrasts run on **three explicitly reported populations**: (i) all fits
  — primary; (ii) converged-only, by the engine's own criterion; (iii) non-runaway.
  Disagreement between them is reported, never resolved silently.
- A cell whose AGHQ arm converges in < 50% of fits carries the tag **`OPTIMISER-LIMITED`**
  on its verdict — because there the contrast is between Laplace *at its optimum* and
  AGHQ *somewhere*, which is a weaker claim and must not be stated as an estimator result.

**This is itself a finding, and arguably outranks the accuracy question.** Two observations
worth separating, both needing the campaign to size properly:

- The 7 near-misses sit at max\|grad\| = 1.03e-4 – 2.2e-4 against `aghq_grad_tol = 1e-4` —
  a factor of 1–2.2. Either the tolerance is slightly tight for this regime or the gradient
  is not scale-normalised. Cheap to check; not this lane's job to fix.
- The dominant mode (20/30) is `stalled at cap 1`, a continuation-schedule behaviour, and
  its message does **not** report the gradient — so a stall cannot currently be told apart
  from a legitimate local-optimum stop. **Recommend the engine report `max |grad|` on the
  stalled branch too**; without it this distinction is unmeasurable from the outside.

### P.4 🔴 Failed and pathological fits — no quiet dropping (Williams item 10b)

- Fits that **error** are recorded with reason and counted; they are never silently absent.
- **The primary analysis includes all converged fits, runaways included.** Excluding
  runaways would delete the exact failure mode under study.
- A **pre-registered sensitivity analysis** repeats the primary contrast on non-runaway
  fits only. If the two disagree, *both* are reported and the headline names the
  discrepancy.
- Cells with < 90% convergence in any arm are **flagged in the results table** and their
  verdict is downgraded to INCONCLUSIVE regardless of the interval.

---

## Compute (Williams item 6)

**Totoro** (`snakagaw@totoro.biology.ualberta.ca`, 384 cores, ≤100 by courtesy), via the
existing ControlMaster socket. Budget from **measured** per-fit times in
`18-shipped.csv` (n=400 interpolated and flagged as such; `aghq_ms` costed at 2× `aghq`):

| stage | fits | core-hours | wall-clock @100 cores |
|---|---|---|---|
| 1 — binomial, 3 n × 2 σ_λ × 5 arms × 400 | 12,000 | 640 | **6.4 h** |
| 2 — gaussian + poisson, 2 n × 5 arms × 200 | 4,000 | 252 | **2.5 h** |
| **total** | **16,000** | **893** | **~8.9 h** |

**Smoke-first, and abort on garbage:** run one cell (binomial, n=100, σ_λ=1, all 5 arms,
10 seeds), read it, confirm non-empty valid output and that arm 4 differs from arm 3,
*before* launching the grid. Results stay **LOCAL** — never GitHub Actions artifacts
(D-50).

---

## Williams et al. (2024) 11-item self-audit

| # | Item | Status | Where addressed |
|---|---|---|---|
| 1 | Aims | ✅ | §A — one primary, four secondary, one explicitly excluded |
| 2 | DGP + n_sim justified | ✅ | §D — math in D.1, levels in D.2, **n_sim from a real pilot** in D.3 |
| 3 | Estimand / target | ✅ | §E — rotation-invariant primary, replicate-specific truth |
| 4 | Methods literature cited | ⚠️ | §M — anchored on the repo's two verified prior-art notes; **external citations must be re-verified before manuscript use** |
| 5 | Performance measures (formulas) | ✅ | §P.1–P.2, formulas explicit; `quadrature-moved rate` defined as the less-known measure |
| 6 | Software / packages / versions | ⚠️ | `sessionInfo()` planned next to results; **the runner must also record the installed gllvmTMB build date** (see below) |
| 7 | Code for DGP available | ✅ | committed to `dev/aghq-evidence/`, DGP byte-identical to `18`/`22`/`23` |
| 8 | Code for performance measures | ✅ | same scripts; incremental per-cell output |
| 9 | Worked-example case study | ❌ | **not in this design.** Needed before any manuscript; named as a gap, not silently omitted |
| 10 | Full performance table | ✅ | §P — one row per cell × arm, convergence and runaway included |
| 11 | MCSE reported alongside | ✅ | §P — every aggregate carries its MCSE; pairing chosen *because* it tightens it 2.2× |

Two items are honestly short (4, 6) and one is absent (9). They are listed as such rather
than marked green.

---

## 🔴 Decisions the maintainer must make before this runs

1. **Approve or amend the primary estimand.** ρ-MAE on the trait correlation is
   rotation-invariant and is what users publish, but Σ_unit is what the coverage
   certificate lane uses. One primary, and it should be yours.
2. **Approve δ = 0.02** as the practical threshold. Everything in P.3 keys off it.
3. **#843's ungating decision** — not a blocker (the design works either way), but it
   changes which arm is "the shipped one".
4. **Confirm the scope limit is acceptable:** this campaign runs on the **non-default**
   grammar and can say nothing about `latent()` with Ψ. If a claim about the default
   grammar is wanted, that needs the factorised Stage-1a extension described in #842 §5a,
   which is **not built** and is a separate project.

## What this design deliberately does NOT cover

Interval coverage · 13 of 16 families · the default grammar · misspecified DGPs · $q > 2$
· varying $p$ (the O(1/T) mechanism was retracted) · anything about flipping the `aghq`
default, which is fenced out of this lane by the brief.

**Any claim arising must name its regime.** "AGHQ improves trait-correlation recovery"
is not a permitted sentence; "in binomial stacked-trait GLLVMs at n = 1600, p = 6, q = 2,
‖Λ‖ moderate, on the loadings-only grammar, with multi-start and no ridge" is.
