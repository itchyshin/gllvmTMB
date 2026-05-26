# Design 55 — A1 closeout: parser-only hypothesis structurally disconfirmed

**Date:** 2026-05-26
**Author:** Claude/Shannon (drafter), with Boole + Gauss + Noether
+ Rose lenses applied per Design 55 §A1 review-roles spec.
**Status:** A1 closed; structurally fails the §8 pass criteria
**before** running any empirical test. Per Design 55 §8 stop
condition: "open issue, close A1 with documented failure memo,
escalate to a Stage 3 design-doc slice **before** continuing
Phase A". This memo + the new `docs/design/56-augmented-lhs-engine-stage3.md`
are the closeout artefacts.

## 1. What was attempted

Design 55 §A1 ("Smallest viable parser-only attempt:
`phylo_unique(1 + x | id)` Gaussian recovery") proposed:

- Modify `.assert_no_augmented_lhs()` (§4.1) to permit `1 + x`
  LHS in structural keywords.
- Modify `parse_covstruct_call()` (§4.2) to extract `lhs_form`.
- R-side wrapper (§4.4) builds a 2-column design matrix
  Z = `[1, x]` for the random-effect block.
- NEW recovery test: σ²_intercept, σ²_slope,
  cov(intercept, slope) on simulated phylo data.
- Byte-identity check: same fit under wide `(1 + x | sp)` and
  long `(0 + trait + (0 + trait):x | sp)` surfaces (§3
  contract).

**Pass criterion** (§8): recovery test passes within tolerance
AND byte-identity check passes → proceed to A2.

**Fail criterion** (§8): recovery fails OR byte-identity fails →
close A1 with failure memo, escalate to Stage 3.

## 2. What the code review found (before running anything)

Three concrete blockers surfaced from a careful read of the
parser, R-side wrapper, and TMB template paths at
`gllvmTMB-a1` worktree HEAD `2e1d586`. Each is sufficient on
its own to fail §8's pass criterion; the three together
guarantee that the parser-only attempt cannot succeed as
specified.

### 2.1 `phylo_unique` does not accept bar-form input today

**Where**: `R/brms-sugar.R:2317-2325`.

```r
if (fn == "phylo_unique") {
  extras <- .pass_through_extras(e, c("tree", "vcv"))
  new_call <- as.call(c(
    list(as.name("phylo_rr"), e[[2L]]),         # ← `e[[2L]]` is expected to be a bare species symbol
    list(.phylo_unique = TRUE),
    extras
  ))
  return(new_call)
}
```

The rewrite path treats `e[[2L]]` as a *bare species name*
(e.g. `sp` in `phylo_unique(sp)`). It does not inspect the
argument for bar-form structure (`lhs | group`). A call
`phylo_unique(1 + x | sp)` would route `1 + x | sp` as the
"species name" position into `phylo_rr`, which would then
fail downstream because `phylo_rr` expects a name, not a bar.

The plan §A1's "permit `1 + x` LHS" wording assumed
`phylo_unique` already accepted bar input. It does not.
Teaching `phylo_unique` to accept bar input is a **public-API
surface change**, not a guard tweak — it requires its own
design doc decision (which keyword shapes accept bar; how
back-compat works; whether `phylo_unique(sp)` and
`phylo_unique(0 + trait | sp)` co-exist or whether the latter
is the canonical form).

### 2.2 The TMB template has a documented silent-collapse bug for augmented LHS

**Where**: documented in
`R/brms-sugar.R:1530-1542` comment block; original Sokal
verification commit `7e90f036` (2026-05-09); engine truncation
sites in `R/fit-multi.R` (nine hardcoded `n_traits` sites per
the audit referenced as "Design 07").

Quoting the guard comment header verbatim:

> Sokal's empirical confirmation (2026-05-09 gating
> verification, commit 7e90f036): two fits with intercept-only
> and augmented LHS produced byte-identical objectives
> (677.4103) and identical T x d_B Lambda_hat instead of
> 2T x d_B. **Engine collapsed at fit time without warning.**

If §A1's parser changes loosen the guard but do not also
extend the TMB template's `n_traits` to `n_lhs_cols`, the
augmented LHS columns are silently dropped at fit time. The
resulting fit reports plausible parameters but for a smaller
model than the user wrote — exactly the silent-collapse
anti-pattern the guard exists to prevent.

**Loosening the guard without fixing the engine is strictly
worse than the current state.** The current state errors
loudly; the loosened state would silently truncate.

### 2.3 Correlated intercept + slope requires a 2 × 2 covariance, which the existing engine block cannot represent

**Where**: `src/gllvmTMB.cpp` `b_phy_slope` block.

The current `b_phy_slope` parameter is a `vector<Type>` of
length `n_aug_phy` — one scalar per species position. The
prior is `b_phy_slope ~ N(0, σ_slope² · A⁻¹_phy)`. The eta
contribution is `eta(o) += b_phy_slope(species_id(o)) * x(o)`.

For correlated intercept + slope (the lme4 `(1 + x | sp)`
contract — random intercept AND random slope per species,
with their `2 × 2` covariance estimated), the engine needs:

- `b_phy_slope` promoted to a `matrix<Type>` of shape
  `n_aug_phy × 2`.
- A `2 × 2` covariance matrix `Σ_b` per structural family
  (estimated via a `theta_b` vector with `log_sd_b_int`,
  `log_sd_b_slope`, `cor_int_slope` parameters).
- Prior: `b ~ MN(0, Σ_b, A⁻¹_phy)` (matrix-normal).
- Eta contribution: `eta(o) += b(species_id(o), 0) * 1 +
  b(species_id(o), 1) * x(o)`.

None of these template extensions exist. The "iterative
parser-only" path cannot produce the correlated bivariate
contract through parser changes alone.

A weaker fallback — wiring `phylo_unique(1 + x | sp)`
internally to the existing `phylo_unique(0 + trait | sp) +
phylo_slope(x | sp)` paired-keyword path — would represent
the **uncorrelated** case only (cov(intercept, slope) ≡ 0 by
construction). That contradicts the §3 byte-identity contract,
which requires the wide-format `(1 + x | sp)` and the
long-format `(0 + trait + (0 + trait):x | sp)` to produce
**identical** fits including the `2 × 2` covariance. Two
independent components don't reconstruct a correlated bivariate.

## 3. Conclusion

The §8 pass criterion (recovery test passes AND byte-identity
holds) is **structurally unreachable** through parser-only
changes alone, on any of the four structural families. The
plan's iterative "try parser-only first" approach correctly
anticipated this outcome and named the escalation path:

> if A1 fails, open a Stage 3 engine-work design slice — that's
> the moment the planned-but-unwritten "Design 07" actually gets
> written, as the parent design for generalising `n_traits` to
> `n_lhs_cols` in the TMB template. (Design 55 §8 escalation
> path)

Per the plan §8 stop condition, **A1 is closed with this
failure memo**. No parser code change is shipped from A1
because making a parser change without the engine change
would create silent truncation. The path forward is the new
**Design 56**: the Stage 3 engine generalisation design doc
that this memo's escalation triggers.

## 4. What this memo does NOT do

- Does **not** ship any code change to `R/brms-sugar.R`,
  `R/parse-multi-formula.R`, `R/fit-multi.R`,
  `src/gllvmTMB.cpp`, or `tests/testthat/`.
- Does **not** advance validation-debt rows RE-02, FG-15,
  PHY-06, ANI-06, SPA-* — all stay `partial` or `blocked`.
- Does **not** ship the parser-loosening that would create the
  silent-collapse anti-pattern (§2.2).
- Does **not** ship Design 56 yet (separate file in same PR;
  see §6).
- Does **not** restore `phylo_slope()` / `animal_slope()` to
  `covered` status — they remain `partial` and now have an
  explicit "Stage 3 engine work is the unblocker" annotation
  via Design 56.

## 5. Boundaries reconfirmed

- ✓ No r200 dispatch.
- ✓ No engine code change.
- ✓ No parser change (deliberately, per §2.2 silent-collapse
  rationale).
- ✓ No edits to Codex active stack files (Codex was last on
  `codex/psychometrics-irt-figure-scope-2026-05-26`; that PR
  has merged; no current Codex branch).
- ✓ No public article promotion.

## 6. Cross-references

- [Design 55 — Structural-dependence × random-slope grammar
  (Phase A0)](../../design/55-structural-slope-grammar.md)
  — the parent design; §8 stop condition triggers this memo.
- [Design 56 — Augmented-LHS engine generalisation (Stage 3)](../../design/56-augmented-lhs-engine-stage3.md)
  — the new stub design doc this memo escalates to.
  Replaces the previously-conventional shorthand "Design 07"
  in error messages and audit references.
- `R/brms-sugar.R:1530-1576` — `.assert_no_augmented_lhs()` and
  the documented Sokal silent-collapse evidence.
- `R/brms-sugar.R:2317-2325` — `phylo_unique` bare-name
  rewrite that does not accept bar form.
- `src/gllvmTMB.cpp` `b_phy_slope` block — current scalar-per-
  species engine path that needs Stage 3 matrix promotion.
- Validation-debt rows **RE-02** (`partial`), **FG-15**
  (`partial`), **PHY-06** (`partial`), **ANI-06** (`partial`),
  and **SPA-slope** (new row pending) — all blocked behind
  Design 56.

— Claude/Shannon (drafter, coordination lens), Boole (parser
surface §2.1), Gauss (TMB engine §2.2 + §2.3), Noether
(math contract §2.3 bivariate normal), Rose (scope honesty
§3 + §4 + §5).
