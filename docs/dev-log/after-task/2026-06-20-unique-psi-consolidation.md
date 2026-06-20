# After-task — unique() → ordinary-latent Ψ migration, consolidated onto current main

**Date:** 2026-06-20 · **Author:** Claude (Ada) · **Branch:**
`claude/unique-psi-fold-20260620` (off `origin/main` 92e246b) · **Status:**
HELD PR — engine + grammar change; needs maintainer + Boole/Noether/Rose/Pat
sign-off before merge (highest-risk category per ROADMAP discussion checkpoints).

## Scope

Fold the trait-specific Ψ companion into ordinary `latent()` by default and
soft-deprecate the `unique()` family, as one atomic change (engine + ~445-usage
doc/example cascade + the four pedagogical-article rewrites). This consolidates
prior committed work (`codex/unique-latent-psi-split-20260619`: `d7826f0` engine +
`4a2449a` article cascade + `e2866f7` audit) onto the current `origin/main`, which
had moved ~13 commits (bridge work, coevolution salvage #494/#500) since that
branch's base.

## The canonical Ψ model (maintainer, 2026-06-20)

Σ = ΛΛᵀ + Ψ, where the diagonal trait companion **Ψ = specific (residual) part +
distribution (overdispersion) part**:

- **Gaussian and Poisson** — the distribution/overdispersion part is **0**
  (Gaussian variance is purely residual; Poisson is equidispersed with no free
  dispersion). Ψ is then *only* the explicit specific/residual term, so this is the
  one regime where `unique()` was ever genuinely needed.
- **All other non-Gaussian families** (NB1/2, Beta, Gamma, GP-1, lognormal,
  Tweedie, Student-t, …) — the specific/residual part is **≈0** and the
  distribution/overdispersion part is **already carried by the family's own
  dispersion (φ, r, α, …)**. An explicit Ψ/`unique()` would double-count, so it is
  **redundant**. *Non-Gaussian is the key.*

This is why `unique()` can be deprecated everywhere: the engine already separates
the Gaussian per-row residual (`sigma_eps`) from the trait-specific OLRE/specific
term and is **per-family-aware** — it auto-suppresses `sigma_eps` when no continuous
trait is present and skips the OLRE free parameter for families that already carry
dispersion (the "per-family-aware OLRE selection"). `latent(..., residual = TRUE)`
(the new default) feeds that same machinery; `residual = FALSE` requests the old
Λ-only low-rank subset.

### Decision gates as applied

- **D0** (atomic): engine + cascade + article rewrites land together — yes, single PR.
- **D1** (scope): per the model — specific Ψ where the family does not already carry
  it (Gaussian/Poisson) and where identified; suppressed where the dispersion carries
  it. Ordinary `latent()` carries the default; `*_latent` structured variants keep
  their existing explicit handling.
- **D2** (specific, not "residual"): Ψ is the *specific* variance; it coincides with
  the residual only in the Gaussian case.
- **D3**: `kernel_unique()` stays compatibility syntax (protects the C1 dense-kernel
  phylo-equivalence gate) — the migration's deprecation badge was NOT applied to
  `kernel_unique()` during conflict resolution.
- **D4**: `phylo_unique()` stays canonical (soft-deprecation routes standalone use to
  `phylo_indep()`; paired explicit-Ψ remains compat).
- **D5**: the four pedagogical articles (`covariance-correlation`, `pitfalls`,
  `morphometrics`, `fit-diagnostics`) rewritten to the new default with
  `residual = FALSE` for the no-residual subset.

## Consolidation approach

Cherry-picked `d7826f0` (engine + 29 R/ @examples), `4a2449a` (23-article cascade,
incl. all four D5 articles), `e2866f7` (audit docs) onto a clean `origin/main`
worktree. Four conflicts, all resolved by taking `origin/main` (the migration diff is
the pure migration — bridge-split lineage lives in the unpicked parent `07181cf`):
`R/kernel-keywords.R` (keeps `kernel_unique` compat per D3), `test-julia-bridge.R`
(origin/main's current bridge test), `man/kernel_latent.Rd` (regenerated),
`docs/dev-log/check-log.md` (dev-log). `extract-sigma.R` auto-merged cleanly —
verified the coevolution extractors (#500) survived (8 refs intact).

## Correctness bug found and fixed (auto-Psi marker mismatch)

The careful named-reviewer pass surfaced a latent bug **present in the original
`d7826f0`** (not introduced by the consolidation): the `latent()` desugar emitted the
auto-residual Ψ companion as `diag(..., .latent_psi = TRUE)`, but `fit-multi.R`,
`check-auto-residual.R`, and the deprecation logic all read `extra$.auto_residual`
(the name those files' code + comments document). The markers never matched, so the
auto-Ψ **de-duplication and off-family drop never fired** — paired `latent() +
unique()` double-counted Ψ, silently breaking the byte-identity safety property
(`latent()+unique() == latent()` for Gaussian). The gates that would have caught this
are `GLLVMTMB_HEAVY_TESTS`-gated and skipped in a normal run, so it hid.

Fix (commit `de6f87e`): emit `.auto_residual` (matching the 6+ consumer references +
documented intent), update the one parser test that asserted the old name, and add an
`engine='julia'` auto-drop of the auto-residual Ψ (the RR-only bridge cannot carry it;
explicit `indep()`/`unique()` diag terms still reject). Runtime covstruct inspection
confirmed the parsed marker; the lineage trace confirmed the mismatch was in `d7826f0`.

## Checks

- `devtools::document()` — clean; `man/` + NAMESPACE regenerated (5 `.Rd` refreshed).
- **Post-fix validation `GLLVMTMB_HEAVY_TESTS=1` — FAIL 0 | WARN 2 | SKIP 15 | PASS 538**:
  `julia-bridge` 391 (the 15 prior bridge failures resolved; remaining 15 skip = Julia
  runtime not configured locally), `ordinary-latent-random-regression` 77 **incl. the
  heavy byte-identity gate** (now passes), `re09-latent-unique-unit` 14 (heavy),
  `unique-family-deprecation` 19, `cross-sectional-unique` 9, `mixed-response-unique-nongaussian` 28.
- Pre-fix full `devtools::test()` — PASS 1373 with 16 fails = 15 bridge × auto-Psi
  (now fixed) + 1 environmental (`glmmTMB::equalto` absent from the installed namespace;
  pre-existing, migration-independent — verified `exists("equalto", asNamespace("glmmTMB")) == FALSE`).
- D5 article rewrites — manually reviewed all four: `covariance-correlation.Rmd` title
  "when you need `unique()`" → "when Psi matters", Model A → `latent(..., residual =
  FALSE)`, Model B → plain `latent()`, inflation lesson preserved; `morphometrics`
  (6/6), `fit-diagnostics` (1/1), `pitfalls` (2/2) coherently reframed.
- Recommended before merge: a clean full `devtools::test()` re-run on the fixed tree,
  `R CMD check --as-cran`, `pkgdown::build_articles()`.

## Named-perspective review (Boole / Noether / Rose / Pat / Fisher → Ada)

Ran the standing review panel (maintainer: "be careful, especially roles"). All five
returned BLOCK at the reviewed HEAD; theory unanimously sound (Ψ = specific +
distribution, Gaussian byte-identity, correlation formula, design cascade). Live
findings and resolutions:

1. **Marker mismatch** (unanimous) — fixed `de6f87e` (see above); panel verified the
   fix (bridge 391/0, D2 ordinal 49==49, paired 170==170). Clean full suite FAIL 1
   (environmental only).
2. **`unique()` soft-deprecation never warned in real use** (Boole/Rose/Fisher) —
   `deprecate_soft` is silent for indirect in-package callers. **Maintainer decision
   (2026-06-20): loud fire-on-use** (design-doc §7 "key hazard", locked). Fixed
   `e9f7928`: surfacing env-tracker `cli_warn` for `unique()`/`*_unique()` AND a
   one-shot bare-`latent()` notice ("now carries per-trait Ψ by default; pass
   `residual = FALSE` for the old loadings-only fit"). Both gated by
   `gllvmTMB.quiet_grammar_notes` (default off → users see them; suite sets it on so
   the one-shot warnings do not trip `expect_silent` fits; deprecation test re-enables
   and asserts). `test-unique-family-deprecation.R`: 21/21.
3. **Two D5 articles taught the inverse of the new default** (Pat/Rose) — fixed
   `02b3af2`: `covariance-correlation.Rmd` A-vs-B now uses explicit inline `form_A`
   (`residual = FALSE`) / `form_B` (default) so the inflation lesson holds; removed a
   dangling `+`. `morphometrics.Rmd` callout + decomposition prose reframed to
   "`latent()` carries Ψ by default; `residual = FALSE` ⇒ Ψ = 0".

## Follow-up / held items

- **🔴 Needs maintainer + named-reviewer re-sign-off** before merge (highest-risk).
- **Spelling cascade is partial** (honest): standalone `unique()` → `indep()` across
  other articles (choose-your-model, response-families, pitfalls, functional-biogeography,
  etc.) is not finished. `unique()` still works and now warns, so these are
  preferred-spelling polish, **not** correctness bugs (no Ψ stripped/double-counted) —
  but D0-atomicity of the *spelling* cascade is incomplete. Listed for the next slice.
- **Hardening:** add a non-heavy D2 gate (all-ordinal_probit / all-delta default
  `latent()` param-count == `residual = FALSE`) so a future marker rename is caught in
  routine CI, not only by the heavy byte-identity gates.
- Before merge: clean `R CMD check --as-cran` + `pkgdown::build_articles()` (article
  fixes are prose/code-consistency-verified by reading; not yet rendered).
- Augmented-slope `*_unique(1 + x | g)` fold (Slice 2) and full `unique()` removal
  remain future slices.
