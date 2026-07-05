# After-task: reconcile `codex/r-bridge-grouped-dispersion` with `origin/main` (43-conflict merge)

Meta: 2026-07-05 · Claude · isolated worktree `claude/merge-main-reconcile-20260705`
(off branch tip `ee837989`) · **nothing landed on `main`** — this prepares the
verified-green tree for the maintainer's land decision.

## Scope

`origin/main` advanced 139 commits (twin-review fixes, robustness/clean-file
guards, family-label/mesh, meta/pedigree PD, dead-code cleanup, and PR #706
`unique-latent-psi-fold`) while the completion-arc branch went 295 commits ahead.
Merging `origin/main` into the branch was **not** a fast-forward: **43 conflicts**
(10 `R/`, `src/gllvmTMB.cpp`, 4 `man/`, `NEWS`/`ROADMAP`/`_pkgdown.yml`, 6 design
docs, `check-log`, 1 test, 17 vignettes). Resolved as a **union-merge** (prefer
main's newer landed fixes; preserve the branch's conservative scope caveats and
deliverables; union distinct additions), not a blanket take-one-side.

## Outcome

All 43 resolved; working tree conflict-marker-free; merged C++ compiles clean;
`man/` regenerated. Full suite (NOT_CRAN=true): initial run **1 fail / 5172 pass**
→ after the `spatial_latent` fix (below), **0 fail** (targeted canonical-keywords
+ all spatial: `[ FAIL 0 | SKIP 81 | PASS 174 ]`; full-suite reconfirmation
recorded in check-log). Preserve-list 7/7 intact. Rose pre-land audit: **clean**.

## Key resolution decisions (the judgment calls)

**Engine (`R/` + `src`):**
- `src/gllvmTMB.cpp` — all 3 hunks comment-only, code byte-identical; took main's
  newer wording. No likelihood-semantics change.
- `R/fit-multi.R` spatial-flag block — took **main** (PR #706 superset:
  `length(spde_idx)>0` robustness guards + a new duplicate-spatial-Psi abort;
  the branch had re-done main's fold — the branch-drift trap the brief warned of).
- `R/extract-sigma.R` — took **main** (adds functional `names(S) <- trait_names`).
- `R/profile-derived.R` / `-curves.R` — kept **HEAD's tier-dependent sign**
  (`exp(-2·)` spde vs `exp(+2·)` other tiers). **Verified against C++**
  (`sd_B = exp(theta_diag_B)`, gllvmTMB.cpp:862 → log-SD → variance `exp(2·)`).
  main's unconditional `exp(-2·)` would mis-scale every non-spde tier — a real bug
  avoided. (Fisher/Noether review point.)
- `R/methods-gllvmTMB.R` SPDE-SD reporting — took **HEAD** (the clean-merged
  continuation references HEAD's `term_spde`/`est_spde`/`sd_spde_shared`).
- `R/init-warmstart.R` — **union**: kept branch's `Gamma` warmstart (#622) + main's
  dead-code removal of the never-firing `gamma_delta` branch (#639).
- `R/gllvmTMB-wide.R` — **union**: main's #589 comment + HEAD's `drop_masked =
  drop_na_cells` (self-consistent with the clean-merged `n_obs`; `normalise_weights`
  still has the param).
- `R/bootstrap-sigma.R` — roxygen-only, took main.
- `R/brms-sugar.R` lv-guard — **union**: kept BOTH the branch's
  `.abort_source_specific_lv` + `.source_specific_lv_keywords` (covers
  `phylo_slope`/`animal_slope`/`phylo_rr`) AND main's `.abort_unsupported_lv_keyword`
  (covers ordinary `unique`/`indep`/`dep`/`gr`); clean-merged call sites invoke both.
- `R/julia-bridge.R` + `tests/testthat/test-julia-bridge.R` — took **main's entire
  pair** (main's bridge is the coherent, more-conservative superset: `XLV_FAMILIES`,
  populated `MASK`/`X_FAMILIES`, full `GJL-GATE-*` system; the branch's was the older
  divergent bridge). Parity stays quiet.

**`R/brms-sugar.R` `spatial_latent` — the one that broke a test.** I first took
main's *by-name* `d`/`unique` extraction; the suite caught
`test-canonical-keywords.R:339` ("control args are first-class positional"), a
branch-owned tested contract and a named preserve-list item ("positional control
args"). Restored the branch's positional-capable `.named_or_positional_arg`
extraction + HEAD's signature (`unique` 3rd formal) + roxygen, and kept main's
conservative augmented-`unique` fail-loud guard (adapted to `unique_val`; neither
behaviour was test-asserted). Both named and positional now desugar identically.

**Docs / register (`docs/design/35`):**
- ANI-05 — took **main's** wording ("default `animal_latent(..., unique = FALSE)`
  is loadings-only"), **verified against code** (source-tier `_latent` default
  `unique = FALSE`; only ordinary `latent()` folds by default). The stale
  "phylo/animal fold by default" AGENTS.md sentence was already corrected on main
  and adopted by the merge (Rose CHECK 5).
- RE-13 (predictor-informed `lv`) + the lv extractor row — main's new rows kept.
- **EXT numbering collision** resolved: `EXT-31 = extract_lv_effects()`
  (code-baked in `R/extractors.R` + `R/julia-bridge.R`, ~10 test assertions);
  branch's `extract_proportions` moved to **EXT-34**. (Cosmetic: EXT rows now
  physically ordered 34/32/33/31 — IDs correct.)
- LAM-02 + MIS-07 `partial`→`covered` — took main's upgrades (backed by
  `test-lambda-constraint.R` / `test-integration-tour.R`); MIS-07's
  "point-prediction only; newdata simulation/intervals gated" caveat retained.
- FG-13 spatial, RE-12, JUL-01 addenda + LV section — unioned (both sides' distinct
  evidence/notes kept).
- **NEWS.md** — union of both sides' entries; removed one orphaned stale
  `kernel_latent()...by default (2026-06-21)` header (superseded by main's revised
  `...explicitly (revised 2026-07-03)` entries).
- ROADMAP / `_pkgdown.yml` / design 01/03/04/61/65 / vignettes — resolved by
  five scoped sub-agents under the same union policy; all verified marker-free.

## Checks run

- `src/gllvmTMB.cpp` compiles (via `devtools::document()`); `man/` regenerated
  (the `\item{...}` Rd warning is pre-existing on `origin/main`).
- Full test suite (NOT_CRAN=true): 1→0 fail after the `spatial_latent` fix.
- Preserve-list grep: 7/7 present (interval_status, brms lv-guards, MIX-10 partial,
  FAM-17 caveat, D-28/positive-part in Design 02, Design 57 banner, delta vignette).
- Rose pre-land audit: clean (no overclaim; register IDs correct; grid/family lists
  consistent).
- **Pending before land:** `_R_CHECK_FORCE_SUGGESTS_=false rcmdcheck(args =
  c("--no-manual","--no-build-vignettes"))` → 0 errors.

## Follow-ups (non-blocking, maintainer's call)

- Register 35 EXT rows physical ordering (cosmetic; IDs correct).
- The **FAM-17 delta-boundary reproduction with `sdreport`** (the session's
  original task) remains owed — paused when this reconciliation took priority.
- The land-on-`main` decision (295+139 reconciled) is the maintainer's.

## Guards honored

No push to `main`; no PR-to-main; isolated worktree only; the live branch and
`origin/main` untouched throughout.
