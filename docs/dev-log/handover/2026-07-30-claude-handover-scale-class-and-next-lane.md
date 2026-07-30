# Session handover — the scale-constant class, and what the next lane should take

**2026-07-30 · from Claude (Fable 5) · TARGET = Claude or Codex · everything merged, nothing blocked**

## Mission control

| | |
|---|---|
| **state** | **all PRs merged**, no open PRs from this session, all lanes pushed and clean |
| **blocked on** | nothing |
| **compute** | none running |
| **START HERE** | this doc → #851 → #855 → `docs/dev-log/audits/2026-07-30-scale-constant-class-sweep.md` |

## The headline: a defect class, not a bug

Two lanes independently found the same defect shape on the same day, which prompted a sweep. It is
a class — **~10 instances, 10 confirmed by running fits at 1x and 10x/0.01x and watching the answer
change**. The generative mechanism is one reasoning step applied consistently:

> The package's justification prose argues from *"the latent scores are standardised N(0, I)"* and
> then applies a constant to **Λ**. Standardising the latent is exactly what pushes the response
> scale **into** the loadings. Every loading-magnitude constant inherits that error.

That is why fixing them one at a time will keep finding more.

### The worst instance — #851, independently reproduced

`init_rr_theta` starts every loading at a hardcoded `0.5`. Measured, gaussian q=1:

| k | sd(y) | ‖Λ̂‖/k (must be constant) | convergence |
|---|---|---|---|
| 1 | 1.9 | 1.366262 | CONVERGED |
| 1000 | 1854 | 1.368476 | CONVERGED |
| **5000** | **9268** | **0.000325** | **CONVERGED** |

**And it is much worse than the loadings.** The equivariance oracle (`dev/scale-equivariance-check.R`,
#854) shows that at k=5000 **every** reported quantity is violated — Σ, fixed effects, logLik, and
critically **correlations and communality, both rel.err 1**. Those are the headline JSDM outputs
users publish. A ratio computed from a degenerate fit is garbage regardless of its invariance.

## What NOT to redo

- **Do not re-run campaign 12** (the AGHQ T×n crossover). Its pre-registered O(1/T) mechanism is
  **not supported** — the wide factorial's σ-by-p is flat. The measurable driver is **‖Λ‖**, and a
  six-point sweep answered it directly. Reasoning in the AGHQ audit §7.
- **Do not make `start_method = "res"` the default.** Soft-deprecated on 89 fits of evidence. But
  note its deprecation campaign **never varied scale**, so it says nothing about #851's regime.
- **Do not retry "scale Λ alone"** for #851 — it changes the balance of the two variance components
  rather than the scale, and drove `test-getlv-se.R` to a non-PD Hessian.
- **Do not trust `‖Λ‖/k` as an acceptance test.** The WIP fix passed exactly that and review found it
  was *worse than baseline* above 5e4. Use `dev/scale-equivariance-check.R`, both blocks.

## The next lane — recommended order

**1. #851 via #855 (internal standardisation).** The feasibility gate is **complete**:

- Entry is clean — one choke point (`R/fit-multi.R:3609`) plus two direct-`y` consumers
  (`:2759-2804`, `.gllvmTMB_single_trait_warmup()` `:4948-4958`).
- **The exit side is the bulk of the work and all of the risk**: the classified extractor set, plus
  three by-name readers that bypass extractors — `residuals()` reads `tmb_data$y`
  (`R/predictive-diagnostics.R:278`), `predict()` and `simulate()` read `report$eta` /
  `report$sigma_eps` (`R/methods-gllvmTMB.R:1626`, `:1094-1099`).
- `bootstrap_Sigma` **refits internally**, so the rescale must apply inside every draw.
- ⚠️ **No existing test can validate this.** Every recovery test simulates at Λ ≈ O(1), so `s_t ≈ 1`
  and `1^k ≈ 1` for any exponent — they catch a crash, not a wrong back-transform. A two-scale
  recovery test is a **prerequisite**, not a follow-up.

**2. #856 needs a decision before 1 is finished.** `log_sigma_eps` is a **scalar** shared across all
gaussian *and lognormal* rows, while every other family's dispersion is per-trait. Under per-trait
scales one fitted `sigma_eps` back-transforms to T raw values, so `report$sigma_eps`, `simulate()`'s
noise draw and `extract_residual_split()` must become **trait-aware on the way out**. Whether that
is a doc gap or a capability gap changes the design.

**3. #847 + #848 together** (ridge τ scale-relative; penalised-fit disclosure). Same code area, and
they compose: the ridge is on by default under AGHQ, degrades σ above τ, and `logLik()` is silent —
so a user can publish a MAP estimate as an MLE. #838 sharpened this by now *recommending*
`aghq_ridge = 2`.

**4. Then** #843 (AGHQ truth-start — small and decisive), #837 (zeta-scale regression on main),
#844 (`aghq = "auto"` k-ladder is dead code).

## AGHQ, settled this session

**The integrator is correct** — six independent checks (Gaussian exactness at q=1 and q=2, a binomial
k-ladder converging to 3e-06, an independent re-implementation, an `integrate` oracle cross-checked
by Simpson, AD-vs-FD at loading scale ×200). **The estimator is not established** — no test compares
an AGHQ point estimate to a known truth. Matches the repo's own line (`decisions.md:2075`).

Two facts reframe the AGHQ evidence base: every number was measured on the **non-default grammar**
(`unique = FALSE`), and for gaussian (89.6%) and poisson (74.0%) AGHQ returns the Laplace answer
**bit-for-bit** — so poisson's apparent agreement is not statistical agreement.

Where AGHQ helps: **binomial only, large n only.** At n=100 `laplace+ridge` wins on σ by 50×; at
n=1600 `aghq+ridge` wins by 3×. 13 of 16 families have no verification-grade evidence; Gamma has
zero usable fits because its harness used the unsupported default inverse link — cheap to fix.

## The process lesson, recorded because it recurred three times

Three times today I worked from a summary instead of re-deriving from source, and each time it cost
something: a table said eight orphan files when git said nine; I fixed one of three `rep(0.5, rank)`
sites having seen all three in my own grep output; and I promoted a scout's unverified structural
argument into a design document as settled. **The artifact is not the evidence.** Re-derive before
acting, especially when the list is your own.

## Open issues

#813 · #834 · #835 · #836 · #837 · #843 · #844 · #847 · #848 · **#851** · #855 · #856
