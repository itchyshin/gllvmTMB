# After-task — Tier-2b item 1: the (π²/6)(I+J) matrix link_residual for multinomial traits

**Date:** 2026-07-17 · **Author:** Claude (Opus 4.8) · **Lane:** `claude/multinomial-tier2b`
(worktree `/private/tmp/gtmb-tier2b`, off `origin/main` `8a6367dd`). **Framed as 0.6, not 1.0.**

## Scope
Apply the softmax observation-scale link residual for a `multinomial()` trait: the (K−1)×(K−1) matrix
`(π²/6)(I+J)` — π²/3 diagonal (each baseline-category contrast is a logit, as binomial-logit), π²/6
off-diagonal (the shared baseline couples the contrasts; McFadden 1974). Reduces to binomial's π²/3 at
K=2. Previously `extract_Sigma()` returned the latent-scale V and warned; `link_residual = "auto"` (the
default) now applies the full-matrix residual. This is brief item 1 of the Tier-2b arc.

## What changed
- `R/extract-sigma.R`
  - `link_residual_per_trait()`: new `fid == 16` branch returns the π²/3 contrast diagonal (no more
    NA/"unavailable" warning for a multinomial trait).
  - new pure helper `.multinomial_link_residual_offdiag(trait_names, multinom_K_per_trait)`: the π²/6
    off-diagonal T×T block, **tier-agnostic** and **multi-block safe** (pseudo-traits grouped by their
    `<base>:` prefix; zero diagonal, zero outside multinomial blocks).
  - `extract_Sigma()` `part == "total"`: adds the off-diagonal block to Σ **only** under
    `link_residual == "auto"`; `"none"`, `part == "shared"`, `part == "unique"` are unchanged (no
    double-count — the diagonal π²/3 comes from the per-trait path, `mn_off` carries the off-diagonal only).
  - roxygen updated ("not yet applied / warns" → "auto applies the full-matrix residual, tier-agnostic");
    notes text surfaces the off-diagonal addition and labels fid 16 as "multinomial".
- `R/extract-omega.R` (**blast-radius fix from Rose review**): `extract_Omega()` previously added only the
  π²/3 **diagonal** for a multinomial, so it silently disagreed with `extract_Sigma()` (which now adds the
  full `(π²/6)(I+J)`), and no longer warned. Now routes the same `.multinomial_link_residual_offdiag()`
  block into Omega, so Omega and the per-tier Sigma agree.
- `man/extract_Sigma.Rd` regenerated.

## How the maintainer's three additions are discharged
- **other structural dependencies** — the block is added to whatever tier Σ `extract_Sigma` builds
  (phylo / spatial / kernel / ordinary latent), because the wiring is at the generic `part=="total"`
  site, not a phylo-specific one.
- **normal random effects** — the block lands only in the multinomial pseudo-columns; a normal/Gaussian
  trait stays diagonal (residual 0) and is now commensurable with the categorical block. Unit-tested.
- **mixed distribution** — unit-tested via synthetic mixed layouts (multinomial + gaussian; two
  multinomials). NOT-COVERED-LIVE: a *fitted* multinomial+gaussian model is still fenced at the parser
  (Tier-2a); opening it is item 2 (Discussion Checkpoint). Stated, not silently skipped.

## Checks
- New `tests/testthat/test-link-residual-multinomial.R`: 21 pass — unit block-builder (mixed +
  two-block + no-multinomial layouts); integration `auto − none == (π²/6)(I+J)`, symmetry,
  `expect_no_warning`, diagonal gains exactly π²/3; `part="shared"` unaffected by `"auto"`; and the
  `extract_Omega` ≈ `extract_Sigma` consistency (blast-radius) test.
- `tests/testthat/test-link-residual-15-family-fixture.R`: +fid-16 case (returns π²/3, no warning); 29 pass.
- `tests/testthat/test-multinomial.R`: stale "warns/latent-scale" comment fixed; 44 pass.
- **Multi-seed** (`/tmp/gtmb-item1-multiseed.R`): 20/20 live phylo-multinomial fits across K∈{3,4,5};
  `auto − none == (π²/6)(I+J)` exactly, symmetric, no "unavailable" warning, 0 errored fits; max abs
  error 4.44e-16.
- Broad `devtools::test()` (pre-fix baseline): 5478 pass, 780 skip, 1 warn, **2 fail** — both in
  `test-plot-visual-snapshots.R` (`dispatcher-communality`, `dispatcher-variance`). **Confirmed
  pre-existing**: they fail IDENTICALLY on the stashed clean base (the fixture is a Gaussian fit my
  change is provably inert on — vdiffr graphics-device drift). Re-run after the extract_Omega fix:
  **5481 pass** (+3 new tests), 780 skip, 1 warn, same 2 pre-existing snapshot fails — zero new
  failures from the fix.
- Adversarial review (Rose, Opus): core `extract_Sigma` change math/gating/alignment/double-counting all
  checked-and-fine; block identification robust; scoping honest. **One CONFIRMED issue** — `extract_Omega`
  silently disagreed with `extract_Sigma` for a multinomial (diagonal only, no warn). **Fixed** (see
  above) + regression test added.
- `devtools::check()`: **1 ERROR, 0 WARNING, 1 NOTE — both attributable to the pre-existing vdiffr drift,
  not this change.** The ERROR is the 2 snapshot failures above (`checking tests`); the NOTE
  (`non-portable file path`) was the `.new.svg` *scratch* those failures wrote — untracked, never in the
  commit, since removed from the worktree. R-code / Rd / examples / examples-with-donttest all OK. My
  change is check-clean.

## Follow-ups (staged this session, not executed)
- Item 2 Discussion Checkpoint memo: `docs/dev-log/2026-07-17-tier2b-item2-discussion-checkpoint.md`
  (parser fence + (K−1)-vector reporting convention; needs maintainer ruling).
- Item 3 recovery ultra-plan: `docs/dev-log/2026-07-17-tier2b-item3-recovery-ultraplan.md`
  (prior + posterior-mean vs MCMCglmm, multi-seed on Totoro; launch on approval).

## Guards honored
Multi-seed always · Rose before covered claim · compute local (no Actions campaign) · reader surfaces
carry no register codes · Discussion Checkpoint reserved for item 2.
