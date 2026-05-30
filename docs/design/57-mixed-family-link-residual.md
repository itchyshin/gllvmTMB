# Design 57: Two-Scales Link-Residual for Mixed-Family × Structural-Slope Fits

**Status**: design memo (planning / decision-record).
**Date**: 2026-05-26 evening.
**Author**: Claude Grue (Shannon perspective; Noether + Fisher + Curie + Boole + Rose contributions named below).
**Phase**: B-mix-0 (per `~/.claude/plans/please-have-a-robust-elephant.md`, 2026-05-26 evening revision).
**Supersedes**: nothing; companion to `docs/design/02-family-registry.md` (current `check_auto_residual()` deferral) and `docs/design/56-augmented-lhs-engine-stage3.md` (augmented-LHS engine surface).

## 1. Context and the problem

When a `gllvmTMB` fit mixes families with different residual-scale semantics — for example:

- Trait 1 Gaussian (σ²_d is a free parameter)
- Trait 2 `binomial(link = "probit")` (σ²_d = 1, exact)
- Trait 3 `Poisson` (σ²_d is mean-dependent via the delta method)

what should `extract_correlations(scale = "latent")` report, particularly when the augmented LHS path of Design 56 §5.2 is in use (`phylo_unique(1 + x | id, ...)` and friends)?

This memo is needed now because:

1. The Phase 56.4 anchor (#298) and the Phase B family activations (B1 binomial-probit, B2 binomial-logit, B3 ordinal_probit, B4 Poisson, B5 nbinom2, B6 beta, B7 Gamma per Active Plan) push the augmented-LHS path through single-family fits cleanly. **Mixed-family** fits with augmented LHS are the natural next combinatorial step.
2. The current runtime guard at `R/families.R` via `check_auto_residual()` (documented in `docs/design/02-family-registry.md:174-191`) **rejects** mixed-family delta/hurdle fits because the single-`σ²_d` latent-scale correlation contract is undefined. The same logic generalises to mixed-family augmented-LHS fits — without a defensible per-family latent-scale convention, `extract_correlations(scale = "latent")` cannot return a coherent number.
3. The maintainer's 2026-05-26 evening directive: include the mixed-family case in the current plan (do NOT defer to post-CRAN). This memo is the design step before any implementation (Phase B-mix-1).

### What the engine currently provides

Per `R/extract-sigma.R:14-72` and Codex's Phase 56.2 classification (#293):

| Family | σ²_d | Treatment |
|---|---|---|
| Gaussian | free parameter | Estimated; reported via `extract_correlations()` |
| binomial(probit) | 1 (exact) | Hardcoded constant |
| binomial(logit) | π²/3 ≈ 3.290 | Hardcoded constant |
| binomial(cloglog) | π²/6 ≈ 1.645 | Hardcoded constant |
| ordinal_probit | 1 (exact, no trigamma) | Hardcoded constant |
| Poisson | depends on `λ`; computed via delta method | Post-hoc in `link_residual_per_trait()` |
| nbinom2 | depends on `μ` and dispersion `ψ`; delta method | Post-hoc; plus the binomial-`ψ` lesson (Design 42 / PRs #263-#264) about identifiability under structural slopes |
| beta | depends on `μ` and `φ`; delta method | Post-hoc |
| Gamma | depends on `μ` and shape; delta method | Post-hoc |
| delta_* (hurdle) | TWO latent scales (binary + positive) | Currently blocked in mixed-family fits per `check_auto_residual()` |

The augmented LHS engine block (`src/gllvmTMB.cpp:780-785`) is **family-agnostic at the contribution step** (the `eta += b_phy_aug * Z_phy_aug` augmentation happens before family dispatch). So the engine accepts any family × structural slope combination at the fit level; the open question is what to **report** at the correlation extraction level for cross-trait pairs spanning multiple families.

## 2. Three candidate approaches

### Approach (a) — Per-trait latent scale (recommended; see §3)

Keep the existing `link_residual_per_trait()` vector intact: each trait carries its own σ²_d. `extract_correlations(scale = "latent")` returns a **per-pair correlation matrix where each off-diagonal entry is computed on the latent scale shared between the two traits in the pair**.

Concretely for the three-trait Gaussian + binomial(probit) + Poisson example:

- `cor[1, 2]` is computed using trait 1's `σ²_{d,1}` (Gaussian free estimate) and trait 2's `σ²_{d,2} = 1` (probit) — the Gaussian-probit latent pair.
- `cor[1, 3]` uses `σ²_{d,1}` (Gaussian) and `σ²_{d,3}(μ̂_3)` (Poisson, computed at the fitted mean trajectory) — the Gaussian-Poisson pair.
- `cor[2, 3]` uses `σ²_{d,2} = 1` (probit) and `σ²_{d,3}(μ̂_3)` (Poisson) — the probit-Poisson pair.

The returned object includes a `scale_per_trait` attribute documenting σ²_d per trait, and an explicit note in the docstring that cross-trait correlations are **not directly comparable across pairs** because each pair has its own latent reference.

**Pros**:
- Closest to current single-family behavior; no transformation infrastructure needed.
- Mathematically well-defined for every family in the registry (no need to project beta or Gamma to a "common" scale).
- Honest about scale heterogeneity — users see σ²_d per trait and can interpret accordingly.
- Minimal implementation cost — extends the existing `link_residual_per_trait()` vector handling to mixed-family compositions.
- Compatible with the augmented-LHS Σ_b reporting from Design 56 §5.2: σ_α / σ_β / ρ_{αβ} are reported on the latent scale per random-effect block, separately from per-trait residual scales.

**Cons**:
- Cross-trait correlations across pairs may not be **directly** comparable on a single number-line. Users must read the `scale_per_trait` attribute and interpret carefully.
- For users coming from a single-family Gaussian background, the heterogeneity may be confusing. The docstring and reference page need a clear note + worked example.

### Approach (b) — Common latent scale via projection

Project each per-trait link residual to a **shared reference scale** (e.g., probit-scale via inverse-link transformation) so all correlations are reported on the same number-line.

For each non-Gaussian trait, define a scale factor `s_t = sqrt(σ²_{d,t}) / sqrt(σ²_{d,ref})`; for fixed-scale families this is a constant, for mean-dependent families it's a function of the fitted mean trajectory. Apply the scale factor to the trait's contribution in the latent-correlation calculation.

**Pros**:
- Cross-trait correlations are directly comparable on the reference scale.
- One number-line for the user.
- Defensible for fixed-scale families (probit: 1; logit: π²/3 → sqrt(π²/3) ≈ 1.814).

**Cons**:
- Mean-dependent families have non-constant `s_t` — the projection depends on the fitted mean trajectory, so the "common scale" is really a fit-conditional average. Documentation burden is high.
- Beta / Gamma per-row residual variances change across rows; a single projection factor per trait is itself an approximation.
- Requires new infrastructure: a "reference scale" parameter, the projection machinery, validation tests across all families.
- The reference scale choice is itself contentious (probit? logit? Gaussian?). Asking the user to pick is honest but increases API complexity.
- Doesn't actually solve the underlying question of "what is `ρ` between a Gaussian trait and a Poisson trait?" — the projection is a coordinate trick, not a unification.

### Approach (c) — Acknowledge limitation publicly

Declare that mixed-family fits return correlations on the link scale **per-trait**; the user gets an attribute (or message) explaining the heterogeneity and a recommendation to either restrict to a single-family subset or interpret pair-by-pair.

**Pros**:
- Most honest about the underlying scale heterogeneity.
- Minimal implementation cost — just docs + an attribute / warning.
- Sets clear user expectations.

**Cons**:
- Less useful in practice — users typically want a single correlation matrix they can interpret.
- Doesn't materially differ from approach (a) in terms of what's actually returned; just frames the same output as a limitation rather than a feature.

## 3. Recommendation

**Approach (a) — Per-trait latent scale.**

Rationale:

1. **Closest to current code paths.** The existing `link_residual_per_trait()` already produces a per-trait σ²_d vector for single-family fits with non-Gaussian responses. Extending it to mixed-family compositions is a straightforward generalisation, not a new mechanism.

2. **No projection infrastructure needed.** Approach (b)'s projection-to-common-scale requires per-family transformation functions, mean-trajectory handling for mean-dependent families, and validation across all families. Approach (a) lets each pair speak on its own latent scale — defensible without new theory.

3. **Honest about scale heterogeneity, not hiding it.** Users see per-trait σ²_d in the `scale_per_trait` attribute and can decide whether to interpret cross-trait correlations directly, restrict to single-family subsets, or use approach (b) downstream if they want a projection. The package doesn't pretend a single reference scale exists when it doesn't.

4. **Compatible with Design 56 §5.2 augmented-LHS Σ_b reporting.** σ_α, σ_β, ρ_{αβ} from the augmented random-effect block are reported on the augmented-LHS latent scale, separately from per-trait residual scales. Approach (a) keeps these separate; approach (b) would entangle them through the projection.

5. **Honest under the "two scales" of delta/hurdle families.** Approach (a) just adds another row to the per-trait scale vector; approach (b) requires reconciling the binary-occurrence latent (σ²_d = 1) with the positive-continuous latent in a way that's not yet defensible (which is precisely why `check_auto_residual()` currently blocks mixed-family delta).

6. **Reversible.** If Phase B1-B7 empirical evidence (per-family fits already in flight: #303 / #304 / next slices) shows that approach (a)'s output is unintelligible or systematically misleading, the package can layer (b) on top as an optional `scale = "common"` argument later. Approach (a) is the conservative first move.

**Recommended `extract_correlations()` API change** (subject to maintainer approval at Phase B-mix-1):

```r
extract_correlations(fit, scale = "latent")
# returns a named list:
#   $cor_matrix : matrix of per-pair latent correlations
#   $scale_per_trait : named vector of σ²_d per trait
#   $note : explicit scale-heterogeneity warning if mixed-family
```

Single-family Gaussian fits are unaffected; their behavior reduces to the current single-σ²_d case.

## 4. Where Phase B1-B7 evidence will inform revision

This memo decides the **default** mixed-family behavior; specific revisions remain open until Phase B-mix-1 (implementation) and Phase B-mix-2 (mixed-family × structural-slope recovery test) provide empirical evidence:

1. **Phase B1 (binomial-probit, PR #303)**: clean recovery of σ_α, σ_β, ρ_{αβ} on the augmented LHS path. Confirms that the augmented Σ_b is reportable separately from σ²_d. Approach (a) preserves this separation.

2. **Phase B2 (binomial-logit, PR #304)**: SKIP-with-finding under default fixture size; σ²_slope upward-biased due to π²/3 residual floor. This is **information**: the latent slope variance under logit is harder to identify, but the per-trait σ²_d = π²/3 is still well-defined. Approach (a)'s pair-by-pair treatment is unaffected.

3. **Phase B3 (ordinal_probit, in flight)**: σ²_d = 1 exact; should mirror B1. Confirms that ordinal_probit slots into the per-trait scale vector cleanly.

4. **Phase B4-B7 (Poisson, nbinom2, beta, Gamma)**: mean-dependent σ²_d via delta method. Phase B-mix-1's `extract_correlations()` implementation needs to plug each into `link_residual_per_trait()`'s per-trait scale evaluation; the existing infrastructure already does this for single-family fits.

5. **Phase B-mix-1 implementation**: extend `R/extract-sigma.R` per approach (a). Specifically:
   - Allow `extract_correlations(scale = "latent")` to accept multi-family fits.
   - Compute the `scale_per_trait` vector by family (constant where σ²_d is fixed; mean-trajectory-evaluated for mean-dependent).
   - Return the `(cor_matrix, scale_per_trait, note)` list.
   - Loosen the `check_auto_residual()` runtime block for non-delta mixed-family fits with augmented LHS (the delta two-scales case stays blocked under approach (a) for now; revisit in a later slice).

6. **Phase B-mix-2 recovery test**: a 3-trait Gaussian + binomial(probit) + Poisson fit with `phylo_unique(1 + x | id)`. Target: recover σ_α, σ_β, ρ_{αβ} from the augmented LHS block on its own latent scale. Verify `scale_per_trait` is reported correctly. Do **not** assert cross-pair correlations are comparable across the three pairs (per approach (a)).

**If empirical evidence in Phase B-mix-2 shows approach (a) is unintelligible** (e.g., the per-pair correlations are wildly inconsistent and there's no useful single-number summary), revisit:

- Approach (b) — add a `scale = "common"` projection layer.
- Approach (c) — strengthen the documentation / warning surface and recommend single-family subsetting.

These are layered options, not replacements. The first move is approach (a).

## 5. Boundaries

This memo does **NOT** decide:

1. **The Phase B-mix-1 implementation slice's exact code structure.** That's the next slice (after this memo is approved). Implementation may discover that the existing `extract_correlations()` API needs more careful refactoring than this memo anticipates.

2. **Whether the `check_auto_residual()` runtime block should be loosened for mixed-family fits**. Approach (a) suggests loosening for non-delta mixed-family augmented-LHS fits; the exact loosening rule is a Phase B-mix-1 decision.

3. **The delta/hurdle two-scales case.** Approach (a) keeps the existing block for mixed-family delta because the binary-occurrence + positive-continuous two-scale collapse remains undefined. A separate future slice can handle that case if/when needed.

4. **Single-family `extract_correlations()` behavior.** Unchanged in this memo. Existing single-family fits keep their current scale handling.

5. **Per-trait σ²_d for ordinal_probit beyond 2 categories.** σ²_d = 1 exact applies to 2-category ordinal_probit (which is binomial-probit). For K > 2 ordinal_probit, the latent-scale residual variance is still σ²_d = 1 by construction (the latent normal model has unit variance per Hadfield-style ordinal regression); this memo assumes that's the design intent (confirmed by `R/families.R:685-759` per the B0 audit memo, #302).

6. **r200 dispatch for mixed-family × structural-slope cells.** Phase Power (post-capability lock per Active Plan).

## 6. Cross-references

- `~/.claude/plans/please-have-a-robust-elephant.md` — Active Plan 2026-05-26 evening revision; Phase B-mix-0 is this memo's target.
- `docs/design/02-family-registry.md:174-191` — current `check_auto_residual()` deferral for delta/hurdle mixed-family.
- `docs/design/55-structural-slope-grammar.md` — augmented-LHS grammar contract (4 × 5 keyword grid).
- `docs/design/56-augmented-lhs-engine-stage3.md` §5.2, §7, §7.3, §9.x — engine shape and validation contract.
- `R/extract-sigma.R:14-72, 99+` — `link_residual_per_trait()` per-family σ²_d constants and post-hoc machinery.
- `R/families.R:685-759` — ordinal_probit family definition.
- `docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md` (#288) — initial non-Gaussian scoping.
- `docs/dev-log/audits/2026-05-27-phase-b-per-family-scoping.md` (#302) — per-family identifiability scoping.
- `docs/dev-log/after-task/2026-05-26-phase-b1-binomial-probit-recovery.md` (#303) — B1 clean recovery evidence.
- `docs/dev-log/after-task/2026-05-26-phase-b2-binomial-logit-recovery.md` (#304) — B2 SKIP-with-finding under logit.
- PR #298 — Phase 56.4 Gaussian anchor (the recovery template).
- PR #301 — Phase 56.5 relmat anchor with sparse-Ainv SKIP-with-finding precedent.

## 7. Persona signoffs (B-mix-0 named-perspective input)

- **Noether (math / engine)**: approach (a) preserves the math: per-pair latent correlations are well-defined for any composition; the engine block remains family-agnostic at the contribution step. No C++ change indicated.
- **Fisher (inference / methodology)**: approach (b)'s projection looks elegant but is fundamentally a coordinate trick that hides scale heterogeneity rather than resolving it. Approach (a) is more honest about what's identifiable.
- **Curie (simulation / recovery)**: Phase B-mix-2 recovery test should fit a 3-trait mixed-family fixture and verify per-pair latent correlations match truth, without forcing comparability across pairs. Tolerances per #287 §2.1; mean-dependent families per the same logit-recovery caution as B2.
- **Boole (parser)**: no parser change needed; the augmented-LHS path already accepts any `family =` argument.
- **Rose (scope honesty)**: approach (a) keeps the `claimed`/`covered` discipline honest. The Phase B-mix-1 implementation slice can move to `claimed`; Phase 56.6 owns the eventual promotion to `covered`.
- **Shannon (coordination)**: design memo + implementation + test = 3 slices. Sequence: this memo (B-mix-0, design-only) → B-mix-1 (implementation in `R/extract-sigma.R`) → B-mix-2 (mixed-family recovery test). Each is its own PR per the standard cadence.

## 8. Decision request

Maintainer (Ada) — please approve approach (a) as the default for mixed-family × structural-slope `extract_correlations(scale = "latent")` behavior, or redirect to (b) or (c) before Phase B-mix-1 begins.

Phase B-mix-1 (the implementation slice) waits for this approval. The runtime guard `check_auto_residual()` stays in place for now; B-mix-1's first task is to determine which mixed-family compositions get the new behavior and which stay blocked.

---

— Claude Grue, 2026-05-26 evening (Phase B-mix-0 design slice; main tip `1630199`).
