# gllvmTMB ≡ glmmTMB (free dispersion) — empirical equivalence

**Date:** 2026-05-25
**Author:** Shannon (cross-team coordination), with Curie
(simulation fidelity) and Fisher (inference policy) lenses.
**Status:** Audit memo only. No design doc, validation-debt
register row, or article was edited by this slice.
**Relates to:** Phase 5.5 cross-package validation evidence;
[Design 04 §"Where the packages overlap"](../../design/04-sister-package-scope.md).

## 1. Why this memo

A separate report (Santi, Nakagawa-lab repo `GLLVM_overview`)
compared a behavioural-syndromes Gaussian gllvmTMB fit against
the same model in glmmTMB and found a large discrepancy
(ΔAIC = 3045 favouring gllvmTMB; glmmTMB repeatability ≈ 1 for
every trait; total variance under-estimated). The discrepancy was
traced to glmmTMB's `dispformula = ~ 0` argument, which **fixes
`σ = 1` rather than zeroing the residual** (the R-formula
notation `~ 0` removes the intercept on the log scale, so
`log(σ) = 0` → `σ = exp(0) = 1`).

The report's §5 proposed a refit *without* `dispformula = ~ 0`,
letting glmmTMB estimate σ freely. This memo records the
**empirical equivalence test** that confirmed §5 works and that
gllvmTMB and glmmTMB-with-free-dispersion are equivalent up to
the parameterisation on this model class.

## 2. The model class

Behavioural-syndromes-style multivariate Gaussian fit:

- `value ~ 0 + trait + rr(0 + trait | ID_rr, d = 2) +
  diag(0 + trait | ID_diag) + diag(0 + trait | obs_ID)` (glmmTMB
  surface)
- `value ~ 0 + trait + latent(0 + trait | ID, d = 2) +
  unique(0 + trait | ID) + unique(0 + trait | obs_ID)` (gllvmTMB
  surface)
- 100 subjects × 9 records × 14 z-scored traits = 12 600 long-format rows.

## 3. Three configurations tested

Test reproducer:
[`GLLVM_overview/Rscripts/test-dispformula-section5.R`](https://github.com/Santiago-0rtega/GLLVM_overview/blob/main/Rscripts/test-dispformula-section5.R)
(commit `30f2ea3`).

| Config | `dispformula` | `obs_ID`? | logLik | σ | mean `obs_ID` variance |
|---|---|---|---:|---:|---:|
| **A** Original report | `~ 0` | yes | −15891.7 | 0.999 (fixed at 1) | ≈ 4×10⁻¹⁰ (collapsed) |
| **B** §5 fix | default (free) | yes | **−14369.2** | **0.141** | **0.445** |
| **C** Alternative | default (free) | **no** | −14602.5 | 0.682 | n/a |

Comparable gllvmTMB fit (same DGP, same `d_B = 2`): logLik
**−14369** (matches config B to the unit) and per-trait
`within_variance` 0.276 – 0.748 (matches config B's
`obs_ID_var_t + σ²` to four decimals across all 14 traits).

## 4. Why the two engines agree

The free dispersion in config B absorbs a small **scalar
baseline** σ² = 0.141² ≈ 0.020 that is constant across traits.
The per-trait `obs_ID` random effect then carries the
**trait-specific remainder**:

```
obs_ID_var_t + σ²  ≈  gllvmTMB within_variance_t   (four decimals)
```

The two engines are landing at the same likelihood maximum; the
parameterisation just distributes within-individual variance into
(scalar σ²) + (trait-specific `obs_ID`) on the glmmTMB side, and
into (auto-suppressed `sigma_eps`) + (trait-specific
`unique(... | obs_ID)`) on the gllvmTMB side. The point estimates
on every estimand of interest (repeatability, communality,
between-individual correlations, total variance) are identical.

## 5. Why gllvmTMB is the cleaner engine for this class

Two structural differences favour gllvmTMB:

1. **Auto-suppression of `sigma_eps`.** When
   `unique(... | obs_ID)` is at per-row resolution for a
   Gaussian family, gllvmTMB pins `sigma_eps` near 10⁻⁶
   internally (validation-debt row **RE-07**, design doc
   `04-random-effects.md`). The likelihood is then **fully
   identified** because σ² and the per-row `obs_ID` no longer
   compete for the same variance.

2. **glmmTMB's free dispersion is identifiability-borderline.**
   In two consecutive runs of the §5 fit:
   - Run 1: optimizer converged to the same point estimates but
     reported a **non-positive-definite Hessian** (`Model
     convergence problem; non-positive-definite Hessian
     matrix`). `sdreport` failed; `logLik` returned `NA`.
   - Run 2: converged cleanly with no warning; PD Hessian;
     logLik = −14369.2.

   Different `start_method = list(method = "res", jitter.sd =
   0.05)` trajectories land in slightly different basins along a
   near-flat σ² ↔ `obs_ID` likelihood ridge. **Point estimates
   are reproducible; standard errors are run-sensitive.**

   gllvmTMB sidesteps this by design.

## 6. Implications for Design 04 (sister-package scope)

`Design 04 §"gllvmTMB vs glmmTMB"` currently says: *"Rule:
single-response models live in `glmmTMB`. Even if you plan to
add more responses later, the gllvmTMB path requires a real
(`unit`, `trait`) row layout from the start."*

This memo **supports that rule** with one additional
quantitative claim worth folding into Design 04 when the next
sister-package-scope review opens:

> For multi-trait models that include both a between-individual
> latent term and a per-row OLRE-style within-individual term
> (`rr() + diag(...) + diag(... | obs_ID)` in glmmTMB,
> `latent + unique + unique(... | obs_ID)` in gllvmTMB), the two
> engines give **identical point estimates** up to a constant
> scalar baseline absorbed by glmmTMB's residual σ. gllvmTMB is
> the cleaner engine because its auto-suppression of `sigma_eps`
> avoids the σ²-vs-OLRE identifiability ridge that glmmTMB has
> to navigate via free dispersion.

The Design 04 edit is deferred to a future PR — the next
maintainer-driven sister-package-scope refresh — rather than
folded into this slice. This memo is the supporting evidence.

## 7. Implications for the validation-debt register

No row movement claimed in this memo. Forward-looking
observations:

- **Phase 5.5 cross-package validation evidence**: this is a
  concrete *equivalence* finding (point estimates match across
  two engines on a Gaussian multi-trait fit with reduced-rank
  between-individual + per-row within-individual structure).
  Phase 5.5's cross-package-agreement deliverable can cite this
  fixture + result as one of its anchor rows. The fixture is
  `Data/example_1.csv` in the `GLLVM_overview` repo; the
  reproducer is the same script.
- **RE-07** (`sigma_eps` auto-suppression for OLRE,
  currently `covered`): this memo provides *cross-package*
  evidence that the auto-suppression isn't just a numerical
  convenience — it's the structural difference that makes
  gllvmTMB's identifiability cleaner than glmmTMB's on the same
  model class.
- **MIX-01** (engine accepts `family = list(...)`,
  `covered`): not exercised by this test (single-family
  Gaussian), but the equivalence pattern is the same model
  family.

## 8. Honesty boundary

This memo:

- Is **not** a generalised gllvmTMB-beats-glmmTMB claim. The two
  engines agree on point estimates in this model class.
- Is **not** a claim about non-Gaussian families. The test was
  Gaussian-only.
- Is **not** a claim about random-slope models, mixed-family
  fits, phylogenetic structure, spatial structure, or
  meta-analytic V. The model class tested is narrow:
  `Gaussian, latent + unique + per-row unique`.
- Is **not** a register edit. No row in
  `35-validation-debt-register.md` moves status because of this
  memo.

## 9. Cross-references

- [`Design 04 §"gllvmTMB vs glmmTMB"`](../../design/04-sister-package-scope.md)
  — sister-package scope, gllvmTMB-vs-glmmTMB rule.
- [`Design 35 row RE-07`](../../design/35-validation-debt-register.md)
  — `sigma_eps` auto-suppression for OLRE.
- [`Design 04 §"Random-effects design"`](../../design/04-random-effects.md)
  — `unique(... | obs_ID)` per-row Gaussian behaviour.
- External reproducer:
  [`GLLVM_overview/Rscripts/test-dispformula-section5.R`](https://github.com/Santiago-0rtega/GLLVM_overview/blob/main/Rscripts/test-dispformula-section5.R)
  at commit `30f2ea3`.
- External summary memo:
  [`GLLVM_overview/Rdata/summaries/gllvmtmb_vs_glmmtmb/dispformula-test-summary.md`](https://github.com/Santiago-0rtega/GLLVM_overview/blob/main/Rdata/summaries/gllvmtmb_vs_glmmtmb/dispformula-test-summary.md).

— Shannon (drafter), with Curie + Fisher lenses.
