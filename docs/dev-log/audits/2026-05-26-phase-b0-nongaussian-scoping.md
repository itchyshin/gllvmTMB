# Phase B0 non-Gaussian × structural-slope scoping audit

**Maintained by:** Fisher (identifiability + inference policy),
Noether (math: family × structural-slope composition), Curie
(simulation fixtures), Rose (scope honesty + per-cell
applicability), Shannon (cross-team coordination).
**Lead author:** Claude/Shannon on Ada's authorisation 2026-05-26
to produce docs/audit-only parallel work while Codex/Ada implements
Phase 56.1.
**Status:** Audit-only scoping reference for Design 55 Phase B.
Lists which (structural × keyword × family) combinations are
identifiable vs degenerate, before Phase B0's empirical scoping
audit lands. No engine code, no test code, no register edit.

## 1. Purpose

Design 55 §B0 specifies a scoping audit before Phase B opens. This
audit's job: enumerate per-cell identifiability + degeneracy notes
for the (structural family × keyword × non-Gaussian family) matrix
so Phase B1-B4 PRs don't waste compute on combinations that are
mathematically degenerate.

Per the 2026-05-26 Explore audit + Design 56 §6: gllvmTMB's TMB
template handles structural-block priors **family-agnostically** at
the prior level; family enters only at the response-likelihood node
*after* the linear predictor `eta` accumulates random-effect
contributions. `link_residual_per_trait()` at
`R/extract-sigma.R:99-280` is post-hoc only. So in principle, every
(structural × keyword × family) combination "just works" once Phase
A engine state is stable.

In *practice*, some combinations are degenerate by parameter
identification (not by engine bug). This memo enumerates the known
degenerate combinations + the borderline ones that need empirical
verification before any recovery test claim moves to `covered`.

## 2. Family scope for Phase B

Per Design 55 §B1-§B4:

| Family | B-slice | Why important | Identification baseline |
|---|---|---|---|
| `binomial(logit / probit / cloglog)` | B1 | JSDM, IRT, occupancy | latent residual fixed by link (π²/3 logit, 1 probit, π²/6 cloglog) |
| `nbinom2` | B2 | abundance counts with overdispersion | overdispersion `phi` is estimable; per-row OLRE has legitimate identification per Design 42 |
| `ordinal_probit` | B3 | behavioural, social-science | fixed σ² = 1 by construction; cutpoints estimated; no bootstrap support (Design 50 §6 family-ID 14 guard) |
| mixed-family (`family = list(...)`) | B4 | Phase 5.5 cross-domain | hardest combination; link-residual machinery must compose with structural-slope LHS |

## 3. Per-cell identifiability table

For each (structural family × keyword × non-Gaussian family) cell,
verdict on identifiability. Verdicts: **OK** (identifiable, expected
to recover), **BORDERLINE** (identifiable in principle but
small-sample fragile; needs empirical n-sweep in B0), **BLOCKED**
(degenerate; document as not-applicable).

### 3.1 binomial × structural-slope (B1; 16 cells)

| Family | Keyword | Verdict | Reasoning |
|---|---|---|---|
| binomial × phylo / animal / spatial / relmat × **unique** | | **OK** | Latent residual π²/3 fixes the scale; bivariate Σ_b identifiable from response variance + correlation residuals |
| × × × **latent(d=K)** | | **BORDERLINE** at d ≥ 2 | Factor-analytic + binomial liability is known borderline; need n_sp ≥ 80 + n_obs ≥ 1500 typically. Use cloglog or probit link for tighter identification when d=2+. |
| × × × **indep** | | **OK** | Diagonal Σ_b is the easiest binomial case; map-pinned ρ removes the borderline correlation |
| × × × **dep** | | **BORDERLINE** at small T | Full 2T × 2T unstructured on binomial may give boundary correlations near ±1 for sparse traits. n_sp ≥ 80 + T ≤ 4 recommended |

Notes:
- Logit link is most common; probit/cloglog also identifiable but tolerance bands shift (probit gives larger SE on σ² because latent variance is 1, not π²/3 ≈ 3.3).
- Multi-trial binomial (`cbind(succ, fail)`) and single-trial (0/1) both work; multi-trial has tighter identification.

### 3.2 nbinom2 × structural-slope (B2; 16 cells)

| Family | Keyword | Verdict | Reasoning |
|---|---|---|---|
| nbinom2 × phylo / animal / spatial / relmat × **unique** | | **OK** | Overdispersion `phi` is estimable in addition to Σ_b. Design 42 binomial-`psi` lesson does NOT apply because nbinom2 has a legitimate scale parameter beyond π²/3. |
| × × × **latent(d=K)** | | **BORDERLINE** at large `phi` | When `phi` is large (low overdispersion), the model is near-Poisson and identifies cleanly. When `phi` is small (high overdispersion), the ψ↔φ trade-off Noether documented may surface; small-`phi` cells need n_sp ≥ 80 + careful starting values |
| × × × **indep** | | **OK** | Diagonal + overdispersion is the safest count case |
| × × × **dep** | | **BORDERLINE** | Full unstructured 2T × 2T + estimated `phi` + structural matrix is the cross-product of borderline cases. Empirical verification required. |

### 3.3 ordinal_probit × structural-slope (B3; 16 cells, but with caveats)

Ordinal-probit has fixed σ² = 1 by construction (latent residual is
standard normal). This interacts with the bivariate Σ_b in specific
ways:

| Family | Keyword | Verdict | Reasoning |
|---|---|---|---|
| ordinal_probit × any × **unique** | | **BORDERLINE** | The 2×2 Σ_b adds to the fixed σ² = 1 latent baseline. For the slope variance σ²_β to be identifiable, `var(x)` must be substantial (>> 0.1) — otherwise the slope contribution is dominated by the latent residual and σ²_β is unidentifiable. |
| × × **latent(d ≥ 2)** | | **BLOCKED** at d=3 | Per Design 55 §B0 edge-case list: spatial × ordinal-probit × d=3 may be unidentified; same reasoning applies to other families × latent × d=3 in combination with ordinal_probit. Recommend B3 caps at d=2 for ordinal_probit. |
| × × **indep** | | **OK** | Diagonal Σ_b + fixed σ²=1 is the cleanest ordinal case |
| × × **dep** | | **BLOCKED** at T ≥ 4 | Full 2T × 2T unstructured + ordinal saturates the identifiable parameter count. Cap T ≤ 3 or document as not-applicable. |

Plus: bootstrap CI unsupported for ordinal_probit (Design 50 §6
family-ID 14 guard). Use profile / Wald CI only in recovery tests.

### 3.4 Mixed-family × structural-slope (B4; per-row family)

Hardest combination per Design 55 §B4. Mixed-family fits use a
per-row `family_var` column; the link residual is added per-row
during `link_residual_per_trait()`.

| Mixed combination | Verdict | Reasoning |
|---|---|---|
| Gaussian + binomial mixed traits + `unique` | **OK** | Most common combination (e.g. morphometric + behavioural traits); link-residual composes additively at extract time |
| Gaussian + nbinom2 mixed + `unique` | **OK** | Same as above; nbinom2 latent is `log(1 + 1/μ_t)` per-row |
| Gaussian + ordinal_probit mixed + `unique` | **BORDERLINE** | Cutpoint estimation interacts with Σ_b; verify cutpoints are stable before declaring σ²_β recovery |
| binomial + nbinom2 mixed + any keyword | **BLOCKED** for `dep` | Different link scales (logit / log) on per-row family don't admit a single unstructured 2T × 2T Σ_b on the latent scale — cross-family Σ_b is on different scales |
| Any × `latent(d ≥ 2)` mixed | **BORDERLINE** | Per Phase A: mixed-family × `latent(d ≥ 2)` is borderline because the latent factor structure isn't family-aware; recovery may need fixed-d=1 first |
| Any combination involving delta/hurdle families | **BLOCKED** | MIX-10 in validation-debt register; latent-scale correlation undefined for delta families (two-scales problem) |

## 4. Identification edge cases worth empirical n-sweep in B0

For each BORDERLINE cell, an empirical n-sweep before declaring
"OK" in Phase B1-B4:

| Cell | n-sweep range | Pass criterion |
|---|---|---|
| binomial × latent(d=2) × phylo | n_sp ∈ {40, 60, 80, 120} | σ² recovery within 25 % at n_sp ≥ 80 |
| nbinom2 × dep × small-T | T ∈ {2, 3, 4} | full 2T × 2T Cholesky recovers within 30 % at T = 3 |
| ordinal_probit × any × small-var(x) | var(x) ∈ {0.1, 0.5, 1.0} | σ²_β identifiable when var(x) ≥ 0.5 |
| Mixed × ordinal_probit cutpoints | n_obs ∈ {500, 1000, 2000} | cutpoint SE finite at n_obs ≥ 1000 |

Each n-sweep produces 1 plot + 1 row in the Phase B0 results table.
Wall-clock: ~20-40 min per sweep on local laptop.

## 5. Phase B sequencing implications

Given the identifiability table:

1. **B1 (binomial)** should land first because the largest fraction
   of cells are **OK** and the borderline cells (latent at d ≥ 2)
   have clean n-sweep recovery paths.
2. **B2 (nbinom2)** second: overdispersion adds one degree of freedom
   but mostly cells stay OK.
3. **B3 (ordinal_probit)** third: smallest surface (cap at d=2,
   T ≤ 3); BLOCKED cells documented.
4. **B4 (mixed-family)** last: hardest; depends on B1-B3 evidence
   per family.

This matches Design 55 §B0-§B4 ordering already.

## 6. What this memo does NOT decide

- Phase B opening date — gated on Phase A close (Design 55 §A7).
- Specific R = 200 promotion thresholds — Design 50 §5 controls
  those.
- Whether non-Gaussian × structural-slope warrants its own
  validation-debt register row — Phase 56.6 / B5 decides.
- Family-pair specific cross-link residual identifiability — that's
  the empirical work of B0 itself.

## 7. Cross-references

- [Design 55 §B0](../../design/55-structural-slope-grammar.md) —
  Phase B0 scoping audit deliverable (this memo is a pre-stage).
- [Design 56 §6](../../design/56-augmented-lhs-engine-stage3.md) —
  family-agnostic prior; cross-family generalisation.
- [Design 50 §5](../../design/50-m3-3b-surface-admission.md) — r200
  promotion thresholds (≥ 0.94 coverage on `Sigma_unit_diag`).
- [Design 42](../../design/42-m3-dgp-grid.md) — binomial-`psi` rule
  (referenced for the nbinom2 / binomial scale distinction).
- [Design 35 row MIX-10](../../design/35-validation-debt-register.md)
  — delta-family two-scales blocked status.
- [Design 35 rows CI-08, CI-10](../../design/35-validation-debt-register.md)
  — current `partial` status; Phase B may move these per cell.

— Fisher + Noether + Curie + Rose (lenses), Shannon (drafting),
Claude (composer). Audit-only; the Phase B0 PR will replace this
memo's verdicts with empirical n-sweep evidence.
