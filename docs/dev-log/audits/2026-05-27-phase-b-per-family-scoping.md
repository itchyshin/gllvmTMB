# Phase B per-family identifiability scoping audit
## (fixed-residual-scale vs mean-dependent split; updates #288)

**Maintained by:** Curie (simulation fixtures + tolerance choice),
Fisher (identifiability + SE behaviour by family), Noether
(family-residual algebra), Rose (scope honesty + per-cell
applicability), Shannon (cross-team coordination).
**Lead author:** Claude/Shannon on the maintainer's 2026-05-26
evening directive (recorded in the Active Plan,
`~/.claude/plans/please-have-a-robust-elephant.md`) to scope
Phase B before B1 opens.
**Status:** Audit-only scoping memo for the anchor cell
`phylo_unique(1 + x | species)` × non-Gaussian families. Updates
the broader-surface memo `2026-05-26-phase-b0-nongaussian-scoping.md`
(PR #288) with a *per-family* recovery contract on the anchor cell
only. No engine code, no parser code, no test code, no R/ edit, no
validation-debt register edit.

## 1. Purpose + scope

When the Phase 56.4 anchor recovery test
(`test-phylo-unique-slope-gaussian.R`, PR #298) is the only
non-Gaussian-ready template in the test suite, Phase B needs a
per-family scoping memo that tells each B-slice PR author:

- which fixture size to start from for that family,
- what σ²_α / σ²_β / ρ recovery tolerance the slice should target,
- which identifiability red flags are family-specific (not the
  generic cross-cell flags in #288 §3),
- how to simulate truth that respects the family's support
  (DGP recipe),
- which `report$...` fields the recovery extractor reads.

This memo splits the eight planned Phase B family slices into two
buckets:

1. **Fixed-residual-scale families** — the latent (link-scale)
   residual variance σ²_d is a known constant that does NOT depend
   on the fitted mean. Identifiability for the (α, β) random-effect
   SDs is cleanest here, and recovery tolerance can match the
   Gaussian anchor (#298's ±20 % on σ², ±0.30 on ρ).

2. **Mean-dependent families** — σ²_d is computed *post-hoc* at
   `link_residual_per_trait()` from the fitted per-trait mean
   (`R/extract-sigma.R:99-330`). The delta-method approximation that
   produces σ²_d introduces additional MCSE on top of the
   random-effect-SD estimates, so recovery tolerance must widen.

The split is also the activation order: B1 → B3 close the
fixed-residual-scale families first; B4 → B7 close the
mean-dependent families afterwards, with the design memo
B-mix-0 running in parallel.

**Hard scope.** This memo is audit-only. It does NOT:

- write or stage any test file,
- edit `R/extract-sigma.R` or any other R source,
- edit the validation-debt register or formula-grammar table,
- promote any cell from `claimed` to `covered`,
- adjust the per-family numbers in #288's Table 3.1–3.4.

The numbers below are *pre-spec defaults* for the corresponding
Phase B slice. Curie / Codex adjust them inside the activation PR
for a given family only if the first recovery fit surfaces an
identifiability or runtime trouble (the same rule as #287 §2).

## 2. Per-family fixture + tolerance table (anchor cell only)

Anchor cell: `phylo_unique(1 + x | species)` per the Phase 56.4
template (PR #298). Each B-slice rebuilds the fixture with the
family swapped; the table columns mirror #287 §2.

**Fixture grid for fixed-residual-scale families** matches the
Gaussian anchor (`n_id = 60`, `T = 3`, `n_rep = 4`, total rows = 720).
**Mean-dependent families** keep the same grid where possible but
widen tolerance per the delta-method MCSE.

### 2.1 Fixed-residual-scale families (B1 → B3)

σ²_d is a constant determined by the link. Latent (α, β) RE SDs
identify cleanly because the model decomposition

```
Var(eta_{ij}) = Var(alpha_sp) + x^2 * Var(beta_sp)
              + 2 * x * Cov(alpha_sp, beta_sp) + sigma_d^2
```

has σ²_d *known* and *constant*, not estimated. The (α, β) SDs
absorb all between-species variation. This is what the maintainer's
"binary stores a fixed number" intuition captures: a binary trait
has a known latent-residual variance baked into the link, and the
fit doesn't have to discover it.

| Family | n_id | T | n_rep | Total rows | σ²_α tol | σ²_β tol | ρ tol | Red flags | DGP one-liner |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| `binomial(link="probit")` (B1) | 60 | 3 | 4 | 720 | ±20 % | ±20 % | ±0.30 | σ²_d = 1 exact; cleanest target — recovery contract matches the Gaussian anchor. Single-trial (0/1) may give thinner Fisher information than multi-trial; if recovery is marginal at `n_id = 60`, bump `n_rep` to 6 before raising `n_id`. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = μ_t + α + β x`; `y ~ Bernoulli(Φ(η))`. |
| `binomial(link="logit")` (B2) | 60 | 3 | 4 | 720 | ±20 % | ±20 % | ±0.30 | σ²_d = π²/3 ≈ 3.29; latent variance is ~3× the probit case, so absolute SD on (α, β) estimates is larger but relative tolerance is the same. Multi-trial (`cbind(succ, fail)`) tightens identification at the same `n_id`. | Same as B1 but `y ~ Bernoulli(plogis(η))`. |
| `binomial(link="cloglog")` (B2-side) | 60 | 3 | 4 | 720 | ±20 % | ±20 % | ±0.30 | σ²_d = π²/6 ≈ 1.64; asymmetric link — for high baseline `μ_t`, β-direction Fisher information is asymmetric (more info for positive shifts than negative). Document but don't widen tolerance unless evidence emerges. | Same as B1 but `y ~ Bernoulli(1 - exp(-exp(η)))`. |
| `ordinal_probit()` (B3) | 60 | 3 | 4 | 720 | ±25 % | ±25 % | ±0.35 | σ²_d = 1 exact (no trigamma involved); cutpoints `c_1 < … < c_{K-1}` are estimated alongside Σ_b. Cap categories at K ≤ 5; K ≥ 6 saturates Fisher information at this fixture size. Cutpoints share information with σ²_α, so SE on σ²_α is wider than B1 at the same `n_id`. Use Wald / profile CI only — bootstrap blocked per Design 50 §6 family-ID 14. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = α + β x`; pick K cutpoints; `y = sum(η + ε > c_k)` with `ε ~ N(0, 1)`. |

**Recovery extractor (B1 → B3).** The Phase 56.4 extractor
applies unchanged:

```r
sd_b   <- fit$report$sd_b      # length 2: SD(α), SD(β)
rho    <- fit$report$cor_b     # scalar: cor(α, β)
sigma2_int_hat   <- sd_b[1]^2
sigma2_slope_hat <- sd_b[2]^2
```

No `link_residual_per_trait()` call required — the latent residual
σ²_d is fixed by the link and does not appear in the (α, β) SD
extraction.

### 2.2 Mean-dependent families (B4 → B7)

σ²_d depends on the fitted per-trait mean `μ_t` (or the dispersion
parameter) and is recovered *post-hoc* via the delta-method formulas
at `R/extract-sigma.R:99-330`. The (α, β) RE SDs still identify on
the link scale, but every downstream extractor that uses σ²_d (e.g.
`extract_omega()`, latent-scale correlation reports) inherits the
delta-method MCSE.

| Family | n_id | T | n_rep | Total rows | σ²_α tol | σ²_β tol | ρ tol | Red flags | DGP one-liner |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| `poisson()` (B4) | 80 | 3 | 4 | 960 | ±25 % | ±30 % | ±0.35 | σ²_d = log(1 + 1/μ_t) (lognormal-Poisson approximation, `R/extract-sigma.R:163-173`). At low fitted mean (μ_t ≤ 0.5), σ²_d is large and ρ may approach ±1 because (α, β) variability is dominated by latent residual. Choose intercepts so `μ_t ∈ [1, 5]`. At high mean (μ_t ≥ 20), σ²_d → 0 and the latent contrast tightens — recovery cleaner. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = log(μ_t) + α + β x` with `μ_t ∈ [1, 5]`; `y ~ Poisson(exp(η))`. |
| `nbinom2()` (B5) | 80 | 3 | 4 | 960 | ±25 % | ±30 % | ±0.35 | σ²_d = trigamma(φ_t) (`R/extract-sigma.R:184-191`). The φ ↔ σ²_α trade-off documented in `2026-05-18-noether-nbinom2-identifiability.md` and PRs #263 / #264 applies: at small φ (high overdispersion), the fit may absorb between-species variation into φ rather than σ²_α; at large φ (low overdispersion), nbinom2 → Poisson and identification matches B4. Choose true φ ∈ [2, 10]; verify φ̂ is not at boundary before declaring σ²_α recovery. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = log(μ_t) + α + β x` with `μ_t ∈ [2, 10]` and `φ ∈ [2, 10]`; `y ~ NB2(exp(η), φ)`. |
| `beta_family()` (B6) | 80 | 3 | 4 | 960 | ±25 % | ±30 % | ±0.35 | σ²_d = trigamma(μ_t·φ) + trigamma((1−μ_t)·φ) (`R/extract-sigma.R:211-234`). μ_t clamping inside `extract-sigma.R:230` is defensive against saturated η; if the fit drives η → ±∞ for any trait, σ²_d is unrecoverable. Choose intercepts so `μ_t ∈ [0.2, 0.8]`. Beta dispersion φ is estimated alongside Σ_b; verify φ̂ finite. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = logit(μ_t) + α + β x` with `μ_t ∈ [0.2, 0.8]`, `φ ∈ [3, 10]`; `y ~ Beta(μ·φ, (1−μ)·φ)`. |
| `Gamma()` (B7) | 80 | 3 | 4 | 960 | ±25 % | ±30 % | ±0.35 | σ²_d = trigamma(ν̂) with ν̂ = 1/σ_eps² (`R/extract-sigma.R:178-183`). The `sigma_eps` reuse for Gamma shape is an approximation valid only for single-family Gamma fits (`R/extract-sigma.R:107-111`) — flagged as a known limitation. For Phase B7, the single-family case applies, so the approximation is fine; document the limitation in the test. Choose true CV ∈ [0.3, 0.7]. | Draw `(α, β) ~ N(0, Σ_b ⊗ A_phy)`; form `η = log(μ_t) + α + β x`; `y ~ Gamma(shape = 1/CV², scale = exp(η)·CV²)`. |

**Recovery extractor (B4 → B7).** The latent (α, β) SDs still come
from `fit$report$sd_b` and `fit$report$cor_b` — the same Phase 56.4
path. The *additional* check the slice should add:

```r
sigma2_d_hat <- gllvmTMB:::link_residual_per_trait(fit)  # per-trait vector
# Verify sigma2_d_hat[t] is finite and within an order of magnitude
# of the family-theoretical value at the chosen mu_t / phi truth.
```

This is the post-hoc latent-residual check. If σ²_d_hat is wildly
off but `fit$report$sd_b` is finite and within tolerance, that's
*not* a recovery failure for the (α, β) RE SDs; it is a delta-method
MCSE issue that should be documented but not fail the slice.

## 3. Why the split matters: the "binary stores a fixed number" intuition

The maintainer's intuition is correct and worth documenting plainly.

**Fixed-residual-scale families** (binomial probit/logit/cloglog,
ordinal_probit): the latent-scale residual variance σ²_d is a known
constant determined entirely by the link function. The link is

```
binomial(probit):    eta = Φ^{-1}(p),    sigma_d^2 = 1
binomial(logit):     eta = log(p/(1-p)), sigma_d^2 = pi^2 / 3
binomial(cloglog):   eta = log(-log(1-p)), sigma_d^2 = pi^2 / 6
ordinal_probit:      eta = Phi^{-1}(c_k), sigma_d^2 = 1 (per Threshold model)
```

No fitted-mean enters the σ²_d formula. The fit's only job is to
estimate (α, β) RE SDs + ρ + intercepts + (for ordinal) cutpoints.
The (α, β) SDs identify cleanly because the latent decomposition
has a *known* nuisance variance — no degree of freedom is consumed
to estimate it.

**Mean-dependent families** (Poisson, nbinom2, beta, gamma): σ²_d
is a function of the fitted per-trait mean μ_t (Poisson, beta,
gamma) or dispersion φ (nbinom2, beta). For example:

```
poisson (log link):  sigma_d^2 = log(1 + 1 / mu_t)   <- depends on mu_t
nbinom2 (log link):  sigma_d^2 = trigamma(phi)        <- depends on phi
beta (logit link):   sigma_d^2 = trigamma(mu*phi) + trigamma((1-mu)*phi)
gamma (log link):    sigma_d^2 = trigamma(1 / sigma_eps^2)
```

The σ²_d formula is a *delta-method approximation* (Nakagawa &
Schielzeth 2010 Table 2; Stoklosa et al. 2022 MEE for nbinom2;
Smithson & Verkuilen 2006 for beta). The approximation introduces
MCSE that downstream extractors (`extract_omega`, latent-scale
correlation reports) inherit. The (α, β) RE SDs themselves still
identify on the link scale — but every subsequent reporting step
that uses σ²_d has additional uncertainty.

This is the key insight: **the engine doesn't change between
fixed-scale and mean-dependent families; the post-hoc latent-residual
machinery does.** Engine-level recovery (σ²_α, σ²_β, ρ from
`fit$report`) is family-agnostic; latent-scale-comparison recovery
(via `link_residual_per_trait`) has family-specific tolerance.

## 4. Cross-family identifiability red flags

These cut across the B1 → B7 matrix and are NOT family-specific
(those go in §2's red-flag column):

1. **ρ near ±1 with finite SE.** Recovery test should:
   - Accept ρ̂ within ±0.30 of truth at `n_id ≥ 60` (fixed-scale)
     or ±0.35 of truth at `n_id ≥ 80` (mean-dependent).
   - **Fail** if ρ̂ = ±0.99 *and* truth is not at boundary — that's
     misidentification, not noise. Same rule as #287 §3.
2. **σ²_α or σ²_β collapsed to zero.** Fixtures should set true
   σ² ∈ [0.2, 0.6] (well-separated from zero, well-separated from
   huge). If σ̂² < 1e-3, that's a boundary collapse, not a recovery.
3. **Non-PD Hessian.** Surface as test failure. The
   `expect_phase56_4_fit_health()` helper in
   `test-phylo-unique-slope-gaussian.R:110-116` checks
   `fit$fit_health$pd_hessian`; reuse it for every B-slice.
4. **Convergence symptoms by family.**
   - Probit / logit: `opt$convergence != 0` with `max_gradient > 1e-2`
     usually indicates `n_id` too small for the chosen ρ — bump `n_id` to 80.
   - cloglog: asymmetric likelihood — `optim` may converge slowly at
     extreme baseline means; verify `max_gradient < 1e-2`.
   - ordinal_probit: cutpoint order can flip near boundary; check
     `fit$report$cutpoints` are monotonic increasing.
   - poisson: at low mean (μ_t < 0.5), σ²_d ≈ log(1 + 2) ≈ 1.1 may
     dominate (α, β) variance — bump mean.
   - nbinom2: φ̂ near boundary (φ̂ < 1 or φ̂ > 50) signals ψ↔σ²
     trade-off — pin φ via `start` if recovery fails repeatedly.
   - beta: η saturation (`max(abs(η)) > 10`) → σ²_d collapses or
     blows up; rejection-sample the fixture to avoid extreme draws.
   - gamma: `sigma_eps` boundary (ν̂ > 1000 or ν̂ < 0.1) signals the
     `sigma_eps` reuse limitation (`R/extract-sigma.R:107-111`).
5. **Bootstrap blocked for ordinal_probit** (B3 only) per Design 50
   §6 family-ID 14. Use Wald / profile CI only.

## 5. Activation sequencing

Phase B opens with fixed-residual-scale families first, in the
order that surfaces the cleanest identifiability story first:

1. **B1: `binomial(link = "probit")`** — σ²_d = 1 exact. Cleanest
   target. Recovery contract is byte-equivalent to Gaussian
   tolerance. Land this first as the second anchor (after #298).
2. **B2: `binomial(link = "logit")`** — σ²_d = π²/3 fixed. Most
   common binomial use case (Darwin's behavioural-ecology lens). Same
   recovery contract as B1.
3. **B3: `ordinal_probit()`** — σ²_d = 1 exact, cutpoints estimated.
   Slightly wider tolerance to absorb cutpoint MCSE. Bootstrap
   blocked. Land third.

Then mean-dependent families, in increasing identifiability
difficulty:

4. **B4: `poisson()`** — single-parameter family; σ²_d depends on
   μ_t only. Land first among mean-dependent.
5. **B5: `nbinom2()`** — adds φ dispersion; ψ↔σ²_α trade-off
   per #263-#264. Land second; expect rejection-sample / start-value
   discipline.
6. **B6: `beta_family()`** — bounded support, two-parameter family;
   μ_t clamp needed. Land third.
7. **B7: `Gamma()`** — positive continuous; `sigma_eps` reuse
   limitation flagged but tolerable in single-family case.

Parallel opportunity: B1, B2, B3 can run as three parallel agents
(no engine interaction; only the test fixture differs). B4 and B5
likewise. B6 and B7 likewise. Phase B-mix-0 design memo can run in
parallel with B1 → B7 (per the Active Plan §B-mix-0).

**Hard gate: B-close (anchor-cell × all families roll-up) only
opens when B1 → B7 are all green AND the B-mix-0 design memo has
been approved by the maintainer.** That gate lives in Phase 56.6,
not in any individual B-slice PR.

## 6. Cross-references

- [PR #287](https://github.com/itchyshin/gllvmTMB/pull/287) —
  Phase 56.5 per-cell scoping; pre-spec defaults pattern + ρ tol
  rule reused here.
- [PR #288](https://github.com/itchyshin/gllvmTMB/pull/288) —
  Phase B0 non-Gaussian × structural-slope scoping; this memo is
  the per-family deepening of #288's Table 3.1-3.4 with the
  fixed-vs-mean-dependent split made explicit.
- [PR #298](https://github.com/itchyshin/gllvmTMB/pull/298) —
  Phase 56.4 anchor cell recovery; the activated template
  `tests/testthat/test-phylo-unique-slope-gaussian.R` is the
  byte-template each B-slice clones.
- `~/.claude/plans/please-have-a-robust-elephant.md` — the Active
  Plan; Phase B0 (this memo) is the §B0 deliverable; B1-B7
  sequencing matches §B1-§B5 + §B6-§B7.
- `R/extract-sigma.R:14-72` — per-family σ²_d formulas (doc block).
- `R/extract-sigma.R:99-330` — `link_residual_per_trait()`
  implementation; mean-dependent families read μ_t / φ / σ_eps
  from `fit$report`.
- [Design 55 §B0-§B4](../../design/55-structural-slope-grammar.md)
  — Phase B0-B4 deliverables.
- [Design 56 §6](../../design/56-augmented-lhs-engine-stage3.md) —
  family-agnostic engine; non-Gaussian random slope requires zero
  C++ change.
- [Design 50 §6 family-ID 14](../../design/50-m3-3b-surface-admission.md)
  — ordinal_probit bootstrap blocked.
- [Design 42](../../design/42-m3-dgp-grid.md) — binomial-ψ rule;
  nbinom2 ψ↔σ²_α trade-off.
- `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`
  — nbinom2-specific identifiability lesson; informs B5.

## 7. What this memo does NOT decide

- **Exact per-slice PR title / branch name** — that lives in each
  B-slice PR's worktree, not here.
- **B-mix design memo content** — Phase B-mix-0 produces
  `docs/design/57-mixed-family-link-residual.md` separately; this
  memo only notes B-mix-0 runs in parallel.
- **Fan-out cell choices beyond anchor** — Phase B-fanout in the
  Active Plan covers relmat / animal / spatial / latent / indep /
  dep × {green families}; out of scope here.
- **Validation-debt register movement** — per Active Plan §56.6,
  register edits happen at the capability close-out gate, not in
  any B1-B7 slice.
- **Power-study cells** — Phase Power runs after Phase 56.6 closes;
  this memo's per-family fixture sizes are recovery-test sizes,
  *not* r200 power-study sample sizes.

— Curie + Fisher + Noether + Rose (lenses), Shannon (drafting),
Claude (composer). Audit-only; reviewers welcome before any Phase
B-slice PR opens. The §2 numbers are pre-spec defaults; adjust
inside the activation PR only if a fit-evidence trigger surfaces.
