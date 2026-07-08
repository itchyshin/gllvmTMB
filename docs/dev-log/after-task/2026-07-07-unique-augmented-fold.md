# After-task — augmented `*_latent(unique = TRUE)` fold (phylo/animal) + process lessons

Date: 2026-07-07
Agent: Claude / Ada (with Rose scope-audit lens)
Merged: `main` @ `81be2ad2` (PR #725)

## Scope

Advance the `*_unique` deprecation by making `*_latent(1 + x | group, unique = TRUE)`
mean what it says at the **augmented** random-regression form. Started as a footgun
guard; converted (maintainer-directed) to the actual fold for the sources whose
companion is additive.

## What landed (`81be2ad2`, PR #725)

- **phylo/animal augmented fold.** `phylo_latent`/`animal_latent(1 + x | grp, unique = TRUE)`
  now desugar to loadings + the augmented `phylo_slope(.phylo_unique_augmented)`
  companion — byte-structurally identical to the explicit pair
  `*_latent(1+x|grp) + *_unique(1+x|grp)`, reusing the Phase-56-proven companion (no new C++).
- Previously `unique = TRUE` was **silently dropped** at the augmented form (only the
  loadings-only slope was fit). `unique = FALSE`/absent and the ordination fold are unchanged.
- Completes the `unique=` fold for **phylo / animal / kernel / ordinary latent**.
- **spatial stays fail-loud by design** — its SPDE companion is a representation switch,
  not additive; the fold needs C++ (see follow-up).
- Files: `R/brms-sugar.R` (phylo+animal augmented branches), `NEWS.md`,
  `vignettes/articles/api-keyword-grid.Rmd`, `docs/design/77-augmented-latent-unique-fold.md`,
  `tests/testthat/test-{phylo,animal}-latent-unique-fold.R`.

## The finding chain (why this took the shape it did)

1. **Honesty check** (mandated): `phylo_latent(lv=~x)` ≠ `phylo_unique(1+x|sp)` — different
   objects (fixed low-rank latent mean vs random-slope covariance). Refuted the naive migration.
2. **Sugar gap, not capability gap:** the augmented capability is fully available via the
   explicit pair; only the folded one-keyword spelling was missing for source-specific latent.
3. **Verified matrix** at the augmented form: `latent`/`kernel` already folded, `spatial`
   fail-loud (engine), `phylo`/`animal` silently dropped → the two to fix.
4. **The augmented fold was a *deliberately deferred* slice** (`docs/design/2026-06-21-
   source-specific-latent-psi-fold.md`: "slice 1 GUARDS the augmented case … augmented fold is
   a later follow-up"). The footgun fix restored the intended guard; this PR implements the slice.

## Checks run (local, live R on the Mac)

- Parser fold tests: `norm(fold) == norm(pair)` for phylo and animal in the
  `*_latent-unique-fold` files.
- `testthat::test_dir(filter = "latent-unique-fold|unique-family-deprecation|canonical-keyword")`
  → FAIL 0 (skips CRAN/INLA-gated).
- `git diff --check` clean.
- #725 CI: `recovery` PASS, `ubuntu-latest (release)` PASS.

## Handoff to Codex (posted in `check-log.md` 2026-07-07)

1. Heavy fold-vs-pair **fit** byte-identity (`GLLVMTMB_HEAVY_TESTS=1`), mirroring the
   ordination-form gate. Parser equivalence proven; fit-level gate is Codex's.
2. **Spatial C++ arc** — starting kit in Design 77 (dormant `fba7e691` scaffolding + the
   `spde_lv_unique` flag already on main). First confirm wired-vs-dormant; do not start from scratch.

## Process lessons (filed to the second brain, cross-linked)

- **Record partial-arc boundaries** — the "unique= arc" (#706) landed ordination + ordinary-latent
  folds but not source-specific augmented; that boundary wasn't findable, causing re-derivation.
  Record the *negative space*, not just "covered/partial".
- **Forest over trees, with exceptions** — standardize the N hand-rolled per-source branches, but
  `spatial` is a real engine exception (representation switch), not drift. Ask before refactoring.
- **Wide historical search at planning** — all-ref sweep + multi-spelling + blocker-notes + pickaxe
  + dormant-flag scan + brain query, *before* concluding "not done" or building. Syntax drift between
  Codex/Claude arcs hides prior work from narrow greps. (Recall found the spatial blocker + the
  dormant SPDE scaffolding, preventing a from-scratch rebuild and an unfittable spatial formula.)

## Follow-up (not this task)

- **Spatial C++ fold** (task 7) — the "fun" arc; kit recorded in Design 77.
- **`*_unique` migration surface** (register annotation + pkgdown rebuild + remaining articles) —
  partially done (NEWS + api-keyword-grid note landed); the register `covers/does-NOT-cover` line
  and a pkgdown rebuild remain.
- **Safe docs** (task 4) — rank-2 coverage append + Model-A doc revision (#14).
- Full-check `#723` (mixed-family M1) stays in Codex's grouped-dispersion area.
