# After Task: fold `phylo_latent()` diagonal Psi by default (`unique =`) — PR B

PR: [#519](https://github.com/itchyshin/gllvmTMB/pull/519) · supersedes the red
[#516] · branch `claude/phylo-unique-fold-20260621` (off `origin/main` c106df4) ·
author Claude (Ada).

## 1. Goal

Stage A, phylo slice of the `latent_*`-only migration: make `phylo_latent()`
auto-carry its phylo-structured diagonal `Psi_phy` companion by default, mirroring
the ordinary `latent()` fold, using the `unique =` argument from PR A (#518). This
redoes the mechanics of #516 (which was correct) and adds the **equivalence-cascade
fix** that #516 lacked (the reason it was red).

## 2. Implemented

### Mathematical Contract

`phylo_latent(species, d = K, unique = TRUE)` (default) fits
`Sigma_phy = Lambda_phy Lambda_phy^T ⊗ A + Psi_phy ⊗ A`, where `A` is the phylo
correlation (tip vcv / `A^-1` path) and `Psi_phy` is the per-trait phylogenetic
specific variance routed to the engine's `phylo_diag` slot (`use_phylo_diag = 1`,
`log_sd_phy_diag`, sharing `Ainv_phy_rr`). `unique = FALSE` →
`Sigma_phy = Lambda_phy Lambda_phy^T ⊗ A` (loadings-only, rank-deficient).

What this is **not**: not a new likelihood/family/parameter; not a change to the
ordinary-`latent` fold (PR A), the lone-`phylo_unique` three-piece path, augmented
`phylo_latent(1 + x | sp)` slopes, or the `phylo_indep`/`phylo_dep` mutual-exclusion
guards. The fold default change applies only to the intercept-only `phylo_latent`.

### Behaviour

- `phylo_latent()` gains a `unique = TRUE` formal + roxygen `@param`.
- Parser fold block (`R/brms-sugar.R`, after the ordinary-`latent` fold): reads
  `unique` (default TRUE), drops it from the call, returns `phylo_rr(...)` alone for
  `unique = FALSE`, else emits
  `phylo_rr(...) + phylo_rr(.phylo_unique = TRUE, .auto_unique = TRUE)` sharing the
  same `A` via `.pass_through_extras(e, c("tree","vcv"))`.
- Dedup (`R/fit-multi.R`): `is_auto_phylo_psi` (kind `phylo_rr` && `.phylo_unique`
  && `.auto_unique`); an explicit `phylo_unique()` at the same grouping supersedes
  the auto-companion → byte-identical to the explicit pair; the
  `auto_unique_off_family` (ordinal/delta) gate drops the phylo companion too.

## 3. Files Changed

**Engine/parser**: `R/brms-sugar.R` (formal + roxygen + fold block),
`R/fit-multi.R` (dedup + per-family gate).
**Generated docs**: `man/phylo_latent.Rd` (regenerated).
**Grammar contract / status**: `docs/design/01-formula-grammar.md` (pairing-rule
note), `NEWS.md` (new dated entry).
**Tests**: new `tests/testthat/test-phylo-latent-unique-fold.R`; equivalence-cascade
fix in `test-kernel-equivalence.R`, `test-canonical-keywords.R`,
`test-animal-keyword.R`, `test-matrix-animal-nongaussian.R`.
**This report** + `check-log.md` entry.

## 3a. Decisions and Rejected Alternatives

> **Decision**: `phylo_latent()` gets `unique =` only (no `residual =` alias).
> **Rationale**: `phylo_latent` never shipped a `residual` argument, so there is no
> backward-compat burden; `unique` matches PR A and `extract_Sigma(part="unique")`.
> **Rejected alternative**: mirror PR A's `residual=` alias on `phylo_latent` —
> unnecessary code for an argument that never existed there.
> **Confidence**: high.

> **Decision**: fix the broken equivalence tests by setting the *compared*
> `phylo_latent(...)` to `unique = FALSE`, not by suppressing the fold.
> **Rationale**: the comparators (`kernel_latent`, `phylo_dep`, `animal_latent`) are
> loadings-only; making the phylo side loadings-only restores a true
> loadings-only ≡ loadings-only identity and preserves each test's intent.
> **Rejected alternative**: weaken tolerances or skip the tests — would hide a real
> behaviour difference.
> **Confidence**: high (handover-specified; confirmed green).

> **Decision**: defer the bare-`phylo_latent` fire-on-use warning, the AGENTS/CLAUDE
> grid reword, and the validation-debt register row to a later Stage-B slice.
> **Rationale**: matches the handover staging (PR B = fold mechanics + equivalence
> cascade, like #516's scope); keeps the PR reviewable.
> **Rejected alternative**: bundle Stage B into PR B — broadens a grammar PR.
> **Confidence**: medium — see §10 so the gap is not silent.

## 4. Checks Run

- `devtools::document(quiet = TRUE)` → clean; `man/phylo_latent.Rd` regenerated.
- `devtools::check(document = FALSE, args = "--no-manual", error_on = "never",
  env_vars = c(NOT_CRAN = "true"))` → `Status: 1 ERROR, 1 WARNING`, `0 NOTES`; fast
  suite `[ FAIL 1 | WARN 13 | SKIP 745 | PASS 3398 ]`.
  - ERROR = the **pre-existing env-only** `test-block-V.R:117` / `glmmTMB::equalto`
    (`"equalto" %in% getNamespaceExports("glmmTMB")` == FALSE; glmmTMB 1.1.11 vs TMB
    1.9.21). Identical on `origin/main`; PR B touches no `meta_V`/`block_V` path.
  - WARNING = Apple-clang `R_ext/Boolean.h` `-Wfixed-enum-extension` header note.
- Targeted `GLLVMTMB_HEAVY_TESTS=1` (the fold + the 4 equivalence files):
  `test-phylo-latent-unique-fold` **14/0**, `test-kernel-equivalence` **38/0**,
  `test-canonical-keywords` **61/0** (3 skip), `test-animal-keyword` **32/0** (1
  skip), `test-matrix-animal-nongaussian` **50/0**. Every equivalence cascade green.
- **Ran the FULL `devtools::check()` before pushing** — the exact step whose absence
  produced the red #516 (the equivalence breakages live OUTSIDE the phylo files).
- CI on #519: pending at closeout (fresh Linux; the env-only `equalto` should be
  absent there).

## 5. Tests of the Tests

- `test-phylo-latent-unique-fold.R`, **failure-before-fix**: the two parser tests
  were watched RED on `c106df4` (bare `phylo_latent(unique=TRUE)` rewrote to
  `phylo_rr(..., unique = TRUE)` — no `.phylo_unique`/`.auto_unique`). **Feature
  combination + byte-identity**: the fitting tests combine the fold with the
  explicit `phylo_unique()` pair (dedup) and assert `logLik` + `extract_Sigma(level
  = "phy")` equality < 1e-6.
- Equivalence-cascade edits are **boundary/identity** tests: they assert
  loadings-only ≡ loadings-only across kernel/dep/animal comparators; the `unique =
  FALSE` edit is precisely what keeps the asserted identity true under the new fold.

## 6. Consistency Audit (verbatim patterns + verdicts)

- `rg -n 'identical\(fn, "phylo_latent"\)' R/brms-sugar.R` → the augmented
  `.latent_slope` guard (2748) **and** the new intercept-only fold block (2905).
  **Verdict**: augmented slopes are returned earlier; the fold sees only the
  intercept-only form.
- `rg -c "\.auto_unique" R/fit-multi.R R/brms-sugar.R` → present in both the emit
  (brms-sugar) and the dedup/gate (fit-multi). **Verdict**: emitter + consumer agree
  on the PR A marker name.
- `rg -n "phylo_latent\(" tests/testthat/test-kernel-equivalence.R
  test-canonical-keywords.R test-animal-keyword.R test-matrix-animal-nongaussian.R`
  → every bare-`phylo_latent` comparator now carries `unique = FALSE`; the paired
  forms (e.g. `phylo_latent(...) + phylo_unique`) are untouched. **Verdict**: cascade
  scoped to the broken identities only.

## Convention-Change Cascade (AGENTS.md Rule 10)

Default-meaning change to `phylo_latent()`. Targets: function↔help (roxygen +
`man/phylo_latent.Rd`) ✓; grammar contract `01-formula-grammar.md` ✓; NEWS ✓.
**Deferred to Stage B** (per handover): the AGENTS/CLAUDE keyword-grid note ("`phylo_latent
+ phylo_unique` is canonical" should gain "or bare `phylo_latent()` which now folds"),
the validation-debt register row, and the bare-`phylo_latent` fire-on-use warning.
Bare-`phylo_latent` examples in roxygen/articles intentionally keep the new default
(they now fold Psi — the intended behaviour), so no example edits were required.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row chip changed (Stage A is tracked via the plan file + this
report; the register/roadmap promotion is a Stage-B/maintainer-gated step).

## 8. What Did Not Go Smoothly

- The first targeted heavy re-run was killed mid-`matrix-animal-nongaussian`; re-ran
  that one file alone to confirm (50/0). No code issue.
- Mixed tab/space indentation in `brms-sugar.R` again required a programmatic block
  insert (indent derived from the file) rather than a literal Edit match.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Boole (grammar)**: the fold reuses the exact #516 rewriter shape; the only new
  surface is the `unique` arg, kept consistent with PR A. The arg/keyword name
  collision (`phylo_latent(unique=...)` vs the `phylo_unique()` keyword) is a
  documentation watch-item for Stage D articles.
- **Gauss/Noether (engine/math)**: byte-identity (`logLik` + `extract_Sigma`)
  against the explicit `phylo_latent(unique=FALSE) + phylo_unique()` pair is the
  guard that the `phylo_diag` routing and the dedup are exactly equivalent — no
  double-count, no lost `Psi`.
- **Curie (testing)**: RED-first at the parser level gave a fast tripwire; the
  empirical "implement → run the 4 named files → fix exactly what broke" loop avoided
  guessing the cascade and is reproducible.
- **Grace (CI/repro)**: running the FULL check locally caught nothing new here, but is
  the discipline that would have caught #516; the only failure is the env-only
  glmmTMB/TMB mismatch, confirmed not branch.

## 10. Known Limitations and Next Actions

- **Stage B (deferred, next):** bare-`phylo_latent` fire-on-use warning (mirror
  `.gllvmTMB_warn_latent_default_psi`); AGENTS/CLAUDE keyword-grid note; validation-
  debt register row for the phylo fold; per-family/per-level `Psi_phy` recovery gates
  (Poisson/NB2/Gamma/Beta) beyond the Gaussian byte-identity here.
- **Stage A continues:** `spatial_latent` → `animal_latent` → `kernel_latent` folds,
  each as its own slice (same rewriter + dedup + per-family gate + byte-identity
  gate), then slice 1b (augmented `phylo_latent(1 + x | sp)` fold).
- **Stage C/D/E (later):** deprecation messaging → article reorg → `*_unique()`
  removal (only after all four source folds + recovery gates are green).
- **#516** is superseded by #519 and should be **closed** once #519 merges.
- Local `test-block-V.R` ERROR is environmental (reinstall glmmTMB from source).

## GitHub Issue Ledger

- Inspected: `gh issue list` filtered for `latent|unique|psi|migration|fold|grammar`
  → no matching open issue; the migration is plan/handover-tracked.
- #516 (the red phylo-fold PR): **superseded** by #519 — close on merge (recorded in
  the #519 body). No new issue created.
