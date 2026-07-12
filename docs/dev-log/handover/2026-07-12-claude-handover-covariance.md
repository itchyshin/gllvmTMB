# gllvmTMB — Claude → Claude handover (2026-07-12, evening)

Meta: 2026-07-12 · from Claude · **supersedes** `2026-07-12-claude-to-claude-handover.md`
for current state. Branch `claude/release-0.5.0`, **tip `5d1125b5`, fully pushed.**
You are the next Claude picking up the **covariance-mode grammar campaign**.

## Critical Context (read or you will go wrong)

1. **This session ran a large covariance-grammar overhaul**, driven live by Shinichi.
   The spine is **Design 79** (`docs/design/79-covariance-mode-taxonomy.md`) — the
   canonical two-axis taxonomy — and **Design 80** (`80-nongaussian-re-evidence-bars.md`)
   — the ML/REML/AGHQ evidence-bar framework (cross-team with drmTMB).
2. **The mode taxonomy is now TWO orthogonal axes:** Axis 1 = mode
   (scalar/indep/dep/latent = the cross-trait covariance); Axis 2 = `|` vs `||`
   (intercept-slope coupling; `mode(1+x||g)` ≡ `mode(1|g)+mode(0+x|g)`).
3. **`indep` = "a set of univariate models × traits"** (Shinichi's framing). The big
   engine change THIS session: `phylo_indep(1+x)` / `animal_indep(1+x)` now fit **T
   independent per-trait (intercept, slope) blocks** (block-diagonal, correlation
   estimated per trait), not the old single shared 2×2 with correlation pinned 0.
   Since 0.5.0 is the FIRST release, this is **not** an external breaking change.
4. **Scalar family is slated for soft-deprecation (Shinichi's decision), but
   DEFERRED.** Plan: add `common =` to the structured `*_indep()` (routing to the
   existing `*_scalar()` engines — cheap, no new engine) and soft-deprecate the whole
   `scalar()` family → **3 modes {indep, dep, latent}** with `scalar = indep(common=TRUE)`.
   Held until `indep` stabilised (it just did). This is the **top next slice.**
5. **The capability widget is Shinichi's mission-control** — show it first, keep it
   current. Live: https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d ;
   source `docs/dev-log/capability-surface.html`. Update recipe: edit source →
   `Artifact(url=<that URL>)` → `cp` is unnecessary (source IS the repo file) → commit.

## What Was Accomplished (this session, all committed + pushed)

| Commit | What |
|---|---|
| `154a22db` | **Design 79** — covariance-mode taxonomy (two orthogonal axes) |
| `45c9fdc9` | **`scalar()`** no-prefix keyword (= `indep(common=TRUE)`), tested |
| `039171c6` | Widget — "tested" tier; census-confirmed amber→tested |
| `b50b5aa6` | Design 61 refresh from S0 census |
| `5a84a18b` | after-task report (scalar arc) |
| `7d840905` | **`kernel_indep`/`kernel_dep`** recovery tests |
| `22c9874a` | Widget — kernel indep/dep → tested |
| `50c32f87` | **`kernel_scalar()`** keyword (theta_rr_phy tie; recovery-tested) |
| `3ca58f76` | Widget — kernel_scalar cell live |
| `9e3ec97b` | **Article `api-keyword-grid` → 5 sources × 3 modes** (scalar/unique as modifiers) |
| `f3d9423a` | **Design 80** — three-bar non-Gaussian RE evidence framework |
| `e6f64b31`/`30376cdc` | Widget — ML/REML/AGHQ estimation matrix |
| **`5d1125b5`** | **`phylo_indep`/`animal_indep`(1+x) → per-trait block-diagonal** + 3 migrated test files |

Also filed: brain note `memory/Non-Gaussian RE evidence bars (three-bar framework).md`.

## Current Working State

- **Working / green:** tree CLEAN, everything committed + pushed to `5d1125b5`.
  Non-heavy suite passes; the 3 migrated heavy tests pass (`GLLVMTMB_HEAVY_TESTS=1`);
  the S2c engine change is recovery-verified.
- **NOT yet run:** a full `--as-cran` / full `devtools::test()` on the final tree
  (do this before any release claim).
- **Held files** (`.Rbuildignore`, `.github/workflows/pkgdown.yaml`, `CONTRIBUTING.md`,
  `ROADMAP.md`): **CARRIED-OVER**, Shinichi's disposition (untouched all session).

## Key Decisions & Rationale

- **indep(1+x) = per-trait (3T), correlation estimated** — Shinichi: "indep is a set
  of univariate models × traits." Old shared-2 was the mislabelled `scalar||`
  (Design 79 §7.1 engine-name shift). Implemented via a block-diagonal `theta_dep_chol`
  pin — **no C++**.
- **Scalar-collapse deferred, not cancelled** — a 3-lens council (Emmy/Darwin/Pat)
  found the only real blocker was "`common=` doesn't exist on structured `*_indep`";
  Shinichi resolved it ("the `*_scalar` engines already exist, so it's just routing").
  Sequencing: finish `indep` first (done), then collapse.
- **Spatial deferred** — the `spde` pin mirrors phylo (logic sound) but can't be fit
  locally (no INLA) and its 2 test files assert the old contract. Held rather than
  migrate blind.
- **Estimation ladder** — REML is a Gaussian-only tool (n/a non-Gaussian); AGHQ is
  n/a for Gaussian (exact), planned + critical for logit/binary (Design 80).

## Files Created / Modified (durable, beyond the commit table)

New: `docs/design/79-…`, `80-…`; `R/kernel-keywords.R` (kernel_scalar);
`tests/testthat/test-kernel-recovery.R`; this handover.
Modified engine: `R/brms-sugar.R`, `R/fit-multi.R`, `R/lambda-constraint.R`
(`dep_chol_crossblock_pins`), `R/traits-keyword.R`.
Docs: `docs/dev-log/capability-surface.html`, `vignettes/articles/api-keyword-grid.Rmd`,
`NEWS.md`, `docs/design/61-…`.

## Next Immediate Steps (priority order)

1. **🔴 Scalar-collapse (top priority, Shinichi-approved).** Add a `common =` arg to
   `phylo_indep()`/`animal_indep()`/`spatial_indep()`/`kernel_indep()` that desugars to
   the existing `*_scalar()` engine; soft-deprecate the whole `scalar()`/`*_scalar()`
   family (warn + rewrite, keep working); reframe Design 79 + widget + article to
   **3 modes {indep, dep, latent}**. Cheap (routing, no new engine). ~200+ `*_scalar`
   mentions exist (Pat's census) — soft-deprecation keeps them working.
2. **Spatial `indep(1+x)` block-diagonal.** Re-flip the parser TODO in
   `R/brms-sugar.R` (`spatial_indep` augmented → `.spatial_dep_augmented=TRUE,
   .indep_blockdiag=TRUE`; the engine pin is already in place, dormant), migrate
   `test-spatial-indep-slope-{gaussian,nongaussian}.R` to the per-trait contract, and
   verify with INLA (CI or a machine that has it).
3. **`||` uncorrelated syntax + `dep(1+x||g)`** — the remaining Axis-2 build (Design
   79 §7.3): `||` is not free two-term sugar (parser refuses slope-only terms).
4. **Full gate:** `--as-cran` + full `devtools::test()` on the final tree.
5. **Later:** AGHQ (Design 80 Bar-3, critical for logit/binary); the paper; Julia parity.
6. **Shinichi's calls (paused):** held-files disposition, merge to `main`, `v0.5.0`
   tag, CRAN. The **drmTMB coordination issue** (align `|`/`||` + `relmat`↔`kernel`)
   was approved for me to post but not yet drafted — `itchyshin/drmTMB`, `gh` authed.

## Blockers / Open Questions

- Spatial needs INLA to verify (blocker for step 2 locally).
- Scalar-collapse: confirm the soft-deprecation UX (warn-once + rewrite) with Shinichi.
- Merge/tag/CRAN — Shinichi.

## Gotchas / Failed Approaches

- **Report field is `cor_b_mat`, NOT `cor_b`** on the dep-slope path (`fit$report$cor_b`
  only partial-matches, fragile). Use `cor_b_mat` (C×C) and `sd_b` (length 2T, grouped
  by trait: `sd_b[2t-1]`=intercept, `sd_b[2t]`=slope).
- **Heavy tests skip unless `GLLVMTMB_HEAVY_TESTS=1`** AND `NOT_CRAN=true`. `fail=0
  skip=n` with the flag unset means they did NOT run.
- **`indep`/`dep` per-trait block-diagonal = the DEP 2T-wide engine + cross-block
  Cholesky pin** (`dep_chol_crossblock_pins`), not a new C++ block. Same trick works
  for `spde` (`theta_spde_dep_chol`, same packing).
- **`||`-as-two-terms does NOT work** — the parser hand-refuses standalone slope-only
  terms (S0 census). Needs a dedicated `||` desugar.
- Don't fit spatial locally (INLA absent) — it silently skips, masking failures.

## How to Resume

**FIRST, show the capability widget** (Shinichi's standing rule): live at
https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d ; source
`docs/dev-log/capability-surface.html`. Keep it current as you go.

Then read, in order: this doc → `docs/design/79-covariance-mode-taxonomy.md` (§7 =
current status) → `docs/design/80-nongaussian-re-evidence-bars.md` → the ultra-plan
`~/.claude/plans/glistening-skipping-anchor.md`. Spawn a Rose / statistical-reviewer
lens before any "finished cell" claim. Start with the **scalar-collapse** (step 1).

One-command resume (paste in an authenticated terminal, from the repo root):

```sh
claude "Rehydrate from docs/dev-log/handover/2026-07-12-claude-handover-covariance.md + the AGENTS.md snapshot. Show me the capability widget first, then start the scalar-collapse: add common= to the structured *_indep() (routing to the existing *_scalar() engines), soft-deprecate the scalar() family, and reframe to 3 modes {indep, dep, latent}."
```

## Mission control

| Area | State | Next by leverage |
|---|---|---|
| **Covariance grammar** | 2-axis taxonomy (Design 79); `scalar()`/`kernel_scalar()` landed; `indep(1+x)` per-trait (phylo/animal) landed | **scalar-collapse → 3 modes** (top); spatial indep(1+x); `\|\|` syntax |
| **Capability widget** | tested tier + estimation matrix; kernel row live; scalar cells live | keep current; reframe to 3 modes with the collapse |
| **Docs** | Design 79/80; article 5×3; brain note filed | reframe article/widget to 3 modes post-collapse |
| **Estimation / REML / AGHQ** | ML done; REML Gaussian pilot; AGHQ planned (Design 80) | AGHQ later (Bar-3, logit/binary) |
| **Release** | tip `5d1125b5` pushed; NOT `--as-cran`'d on final tree; NOT merged | Shinichi: gate, merge, tag, CRAN |
| **Cross-team** | drmTMB coordination approved, not drafted | draft + post the `itchyshin/drmTMB` issue |

Branch `claude/release-0.5.0` @ `5d1125b5`, pushed. Nothing half-done — the S2c breaking
change is committed green (phylo/animal); spatial + scalar-collapse + `\|\|` are the
clean next slices. Good luck, next lane. 🧬
