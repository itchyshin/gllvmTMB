# Cross-repo FYI (from the drmTMB session, 2026-07-18): the two-lever fix for small-cluster non-Gaussian variance bias

> **This is an informational cross-repo note, not an instruction to act.** It records a finding
> from the drmTMB coverage programme that bears directly on gllvmTMB's *active* interval-coverage
> certification lane (`2026-07-18-interval-coverage-certification-ultra-plan.md`,
> `2026-07-17-sigma-coverage-earn-vs-defer-memo.md`). Decide for yourselves whether/how to use it.

## The finding (MEASURED on drmTMB, validated against glmmTMB/glmer/lme4 oracles)

A small-cluster random-effect SD under ML-Laplace is biased low by **two stacked, orthogonal** effects,
and this is likely *why* non-Gaussian coverage cells under-cover:

1. **Laplace integral error** (1-point-at-the-mode). Fixed by **AGHQ** (k-point adaptive Gauss–Hermite).
   Shrinks with per-group n.
2. **ML finite-cluster variance-component bias** — present even under *exact* integration. Fixed only by a
   **restricted likelihood**: exact REML (Gaussian) or the **Cox–Reid adjusted profile likelihood**
   (non-Gaussian). Shrinks with number of clusters M.

Worked decomposition (drmTMB cumulative_logit, M=40, n_each=15, true SD 0.5, 40 seeds):
Laplace **−7.3%** → +AGHQ **−5.0%** → +Cox–Reid **−0.9% (≈ nominal)**. Cox–Reid is the *bigger* lever
(~1.7× AGHQ). An AGHQ node-sweep converges by ~5 nodes then plateaus dead-flat at −5.0% — **more nodes
cannot cross the variance-bias floor; only the restricted likelihood drops it.** drmTMB Laplace == glmmTMB
ML *exactly* (it is not a bug; ordinal is just the lowest-information family).

## gllvmTMB's status (SOURCE-CONFIRMED, 2026-07-18) — same starting point as drmTMB

- **Non-Gaussian REML: not available.** `reml_bridge()` aborts for any non-Gaussian response row
  ("Gaussian-only", `R/reml-bridge.R:106`). So the *bigger* lever is absent for the families your coverage
  cells care about.
- **AGHQ: not present** anywhere in src/R (the latent block is 1-point Laplace).
- **You already detect the problem:** `check-consistency.R` (score non-centring) flags when the Laplace
  approximation is unreliable — a diagnostic drmTMB lacked. Plus you have profile CIs.

## Implication for your coverage lane

If a non-Gaussian gllvmTMB cell under-covers, this decomposition says it is likely the ML-variance-bias
floor, **not** an interval-construction problem AGHQ or profiling alone can fix — the durable remedy is the
restricted likelihood. Two gllvmTMB-specific caveats: (1) the REML lever's *shape* must respect GLLVM
identifiability — variance lives in the loadings Λ + Ψ, not a scalar RE-SD, so a magnitude probe is a
**multi-dim-latent** build, not the scalar-RE one-liner drmTMB used; (2) your `check-consistency` score test
is a natural companion — a cell that trips it is a cell where this bias is biting.

## Sources
- drmTMB evidence: `drmTMB/docs/dev-log/2026-07-18-cumlogit-laplace-diagnosis-and-aghq-next-arc.md` + the
  `simulation-artifacts/2026-07-18-cumlogit-laplace-vs-aghq/` TSVs.
- Cross-repo map (vault): `~/shinichi-brain/memory/Two-lever fix for small-cluster non-Gaussian
  variance-component bias (AGHQ + Cox-Reid REML) — cross-repo map.md`.
- Companion: your own `[[Small-sample variance-component interval corrections — cross-repo map]]`.

---

## UPDATE (later same day, 2026-07-18) — drmTMB has now BUILT + VALIDATED the arc, and it maps onto YOUR live lane

*Still FYI, still your call.* Since the note above (which was scoping-only), drmTMB built both levers end to
end and is running a coverage campaign. Reading your Mission Control board, the fit is tighter than we
realised — you have **independently arrived at the same diagnosis**, so this is less "new idea" and more
"here is a working template for two items already on your roadmap."

**Where your board already agrees with the two-lever picture (your words):**
- Your binomial coverage is fenced because the profile is **"too-narrow at the psi=0 boundary — the Laplace
  signature."** That *is* lever 1 (the Laplace integral error). Your Phase-B/1.0 backlog item **"AGHQ
  integration for BINOMIAL/psi=0-boundary coverage"** is exactly the fix drmTMB just implemented.
- Your probe found **"REML barely moves Σ̂ at n=150, payoff is at n=50."** That *is* lever 2 (the
  finite-cluster ML variance bias): it shrinks with cluster count, so it only bites at small n/M — precisely
  where your gaussian n=50 shortfall and binomial fences live.
- Your route decision (**profile / log-SD-Wald-t-df, not bootstrap**) matches drmTMB's. Good — the levers
  below fix the *estimator/likelihood*, and the profile then reads honest intervals off it.

**What drmTMB built (concrete, reusable):**
- **O2 — binomial non-Gaussian REML by gate-relaxation.** Marginalising the fixed effects via the existing
  Laplace fold IS the joint-Laplace restricted likelihood, and it equals `glmmTMB(REML=TRUE)` to **7.3e-9**.
  For you the analog is: does relaxing `reml_bridge()`'s non-Gaussian abort (`R/reml-bridge.R:106`) + folding
  the fixed effects give a valid restricted likelihood? For a *scalar/independent* variance component, likely
  yes and cheap. This is the "REML small-n" Phase-A item at low cost.
- **O3 — the nominal-coverage estimator (`drmTMB/R/aghq-coxreid.R`, pure R):** adaptive Gauss–Hermite over
  the latent + Cox–Reid over the fixed effects, with a profile CI. On the lowest-information family
  (cumulative_logit, ordinal — worse than your binary), the first campaign cell (M=40, n=15, true SD 0.5,
  N=1200 on Totoro) came back **coverage 0.9515, CI [0.938, 0.963], point bias +0.0%** — i.e. the two levers
  turned a −7.3% Laplace-biased, under-covering cell **nominal**. That is direct evidence the levers earn what
  Laplace-profile alone cannot.

**THE load-bearing architecture finding (this is the one to take):** you cannot compose AGHQ with the REML
fold by adding the latent to `random=`. TMB's `random=` fold does ONE joint Laplace over the whole random set
*including the latent*, whereas AGHQ is an external post-hoc marginalisation of that same latent — the
joint-determinant identity that licenses folding the fixed effects **assumes the latent is Laplace-integrated**.
So the recombination must be **NESTED and EXTERNAL**: AGHQ marginalises the latent → Cox–Reid adjusts the
fixed effects on that AGHQ-marginal. drmTMB's adversarial S1 review caught this before any code; it would
otherwise have been a silent wrong-objective. (Design doc: `drmTMB/docs/design/224-aghq-coxreid-nongaussian-reml-alignment.md`, §2.)

**Why this is HARDER for you (the caveat from the first note, now sharpened):** drmTMB's latent is a **scalar**
RE per cluster, so its AGHQ is a 1-D quadrature. Your latent is the **d-dimensional GLLVM LV vector per site**
(variance in Λ + Ψ, not a scalar SD). AGHQ over a d-dim latent is a **product/sparse grid — curse of
dimensionality**; drmTMB's scalar O3 does **not** drop in. What transfers is (a) the *architecture* (nested,
external, not a joint fold), (b) the binomial-O2 gate-relaxation pattern (cheap, scalar-VC), and (c) the
*certification methodology*, not the estimator itself. For high-d you'd want adaptive/sparse-grid AGHQ or a
different integrator entirely; treat that as the real cost of your Phase-B "un-fence binomial/ordinal" item.

**Certification methodology worth copying** (drmTMB gate-spec `scratchpad/o3-cumlogit-coverage-gate-spec.md`,
S8-reviewed by Fisher+Rose): the **estimation↔inference firewall** (point-bias numbers earn NO coverage
credit); **one-sided finite-profile scoring** for σ̂→0 boundary piles (your psi=0 case — a NA lower root gives
a computable (0, upper] interval that often still covers, so score the one-sided bound, don't drop or auto-miss);
and the honest **χ²₁-pivot caveat** (a plain χ²₁ profile over-covers near the boundary vs the 50:50 χ² mixture —
so over-coverage there is NOT auto-"conservative"). These are exactly the traps at your psi=0 binomial boundary.

**Bottom line:** drmTMB has a working, validated template for your two roadmap items (REML small-n; AGHQ
un-fence). The binomial-O2 half should port cheaply; the multivariate-latent AGHQ half is a genuine build, not
a copy. Nothing here is an instruction — just a paved path where your board already points.

New source: `drmTMB/docs/design/224-aghq-coxreid-nongaussian-reml-alignment.md` (§2 the nested seam, §4 the
review caveats, §6 the build legs) · `drmTMB/R/aghq-coxreid.R` (the estimator) · the gate-spec above.
