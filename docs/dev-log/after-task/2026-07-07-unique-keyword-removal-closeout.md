# After-task — `unique()` keyword-removal closeout (v0.3.0)

**Date:** 2026-07-07 · **Agent:** Claude (Ada) · **Branch:** `claude/unique-keyword-deprecation` · **PR:** #728

## Scope
Finish the `unique()` / `*_unique()` **keyword** removal from the taught+rendered surface,
**keeping the `unique =` argument**. The prior session landed ~70% as WIP commit `6b655ef8`
(roxygen grid 4×5→4×4, main page, README, `_pkgdown.yml`, NEWS, articles batches 2 & 4). This
session did the remaining 8 article files + closeout, per
`docs/dev-log/handover/2026-07-07-claude-handover-unique-removal.md`.

## Outcome — DONE
Grep-to-zero achieved on the taught surface. `grep -rnE "unique\(|_unique\(" vignettes/ | grep -vE "unique = "`
returns only `api-keyword-grid.Rmd:65` (the single allowed deprecation notice — you must name a keyword
to deprecate it). Zero stray `#'` roxygen cross-refs outside the deprecated-function own-doc files. The
`unique =` argument is preserved throughout.

### What changed
- **Prose rewords** (keyword-free, model-preserving) in `gllvmTMB.Rmd`, `pitfalls.Rmd`, `joint-sdm.Rmd`,
  `cross-lineage-coevolution.Rmd`, `random-regression-reaction-norms.Rmd`, `phylogenetic-gllvm.Rmd`,
  `animal-model.Rmd`.
- **Intercept-only paired-table folds** reconciling summary tables to the already-folded code
  (`phylogenetic-gllvm.Rmd`, `animal-model.Rmd`, `choose-your-model.Rmd` — removed a redundant
  explicit-Psi decomposition row + fixed the "(same folded form)" reference).
- **Decision A — "fully move to latent" (maintainer):** the standalone-augmented
  `phylo_unique(1+x|sp)` / `animal_unique(1+x|id)` (ANI-11 correlated reaction norm) and the
  `compare_indep_vs_two_psi()` diagnostic demo were **folded** to `*_latent(..., unique = TRUE)`
  (`choose-your-model.Rmd`, `phylogenetic-gllvm.Rmd`, `animal-model.Rmd`). This is a **model change**:
  the fold ≡ `*_latent() + *_unique()` pair (Design 77 line 54), adding the shared low-rank ΛΛᵀ axis on
  top of the per-trait 2×2 Ψ companion.
- **Register:** `docs/design/61-capability-status.md` ANI-11 row rewritten to the folded taught spelling,
  citing `ANI-11` (companion) + `PHY-17` (reduced-rank slope) — the fold's coverage is the union.
- **R deprecation-redirect fixes** (`R/brms-sugar.R`): the `unique()` arc left several deprecation
  messages steering users TO the now-deprecated `spatial_unique()` keyword. Fixed `spatial()`
  `deprecate_warn` → `spatial_indep()`, `deprecated_map` `spde` → `spatial_indep`, trimmed the `diag`
  guidance's `unique()` mention, and the comment legend. Also dropped the "4 x 5 keyword grid" framing
  from the `spatial()` message.
- `devtools::document()` regenerated 37 `man/*.Rd` (completing the committed-but-undocumented roxygen).

## Key findings (source-verified, not assumed)
1. **Standalone augmented `*_unique(1+x|g)` has NO keyword-free equivalent.** The parser routes it to the
   2×2 companion alone; the fold equals the *pair* (companion + low-rank axis). Folding is a real model
   change — surfaced to the maintainer, who chose to fold ("fully move to latent").
2. **The handover's "random-regression demo is STALE" was WRONG.** The non-Gaussian augmented-diagonal
   error is a REAL guard (`R/fit-multi.R:1561`, by design D-28), not a stale spelling. The keyword and the
   argument *diverge* under non-Gaussian: `unique(1+x|unit)` trips the guard (errors); `latent(1+x|unit,
   unique=TRUE)` silently fits low-rank (the Gaussian-only diagonal default is off). Rewrote the demo
   keyword-free to show the working low-rank `unique = FALSE` path + prose the Gaussian-only boundary —
   NOT a false "it works now" claim.
3. **Live fit verification (both folds FIT).** `phylo_latent(1+x|sp, d=1, unique=TRUE)` ✓ and
   `animal_latent(1+x|sp, d=1, A=A, unique=TRUE)` ✓ both fit on a minimal Gaussian fixture (the fold tests
   in-repo are parser-level only). This resolved a phylo-vs-animal asymmetry: animal-model flagged the
   reduced-rank `animal_latent()` slope as a v0.3.0 follow-up, but the short d=1 fold fits — so the
   follow-up caveat was scoped down to `animal_dep()` + the trait-augmented long LHS.
4. **Additional keyword spots beyond the punch-list** (found by re-grep, not in the handover):
   `choose-your-model.Rmd:186,248,446`; `phylogenetic-gllvm.Rmd:743,812`. All sweeped.

## Checks
- `devtools::document()` — clean; 37 `man/*.Rd` regenerated.
- `devtools::check_man()` — clean.
- `pkgdown::check_pkgdown()` — "No problems found."
- Grep-to-zero (vignettes + R roxygen) — only the allowed `api-keyword-grid.Rmd:65` remains.
- `git diff --check` — no whitespace issues.
- All 8 touched articles: balanced code fences.
- Live: both folded spellings fit (Gaussian minimal fixture).
- Independent completeness gate: **Rose** (read-only audit) — DoD checks PASS (grep-to-zero,
  argument preserved, folds sound with no false family-general claim, animal follow-up consistency,
  R deprecation targets correct). Verdict "NOT CLEAR" on two items, **both pre-existing or
  decision-gated, neither a regression from this arc** (see below).

## What did not go smoothly / honesty
- The handover conflated the keyword fold with the non-Gaussian guard (finding #2) and asserted the
  standalone→fold migration uniformly (finding #1). Both needed source verification before acting; a blind
  swap would have produced false examples — the exact "failed 6-7 times" trap.
- All code edits were in `eval=FALSE` chunks or prose/tables; **no `eval=TRUE` fitting chunk was touched**,
  so article fit behavior is unchanged.

## Known limitations / follow-up
- **Full `R CMD check` + `pkgdown::build_site()`** (TMB recompile, all article fits) NOT run here — the
  heavy Codex/maintainer step per the division of labour. My edits are markdown/`eval=FALSE`-only, so
  render risk is low, but the full site build should be run before release.
- **Possible real gap (flagged, out of scope):** ordinary `latent(1+x|unit, unique=TRUE)` under a
  non-Gaussian family **silently ignores** `unique=TRUE` (fits low-rank; the augmented diagonal is
  Gaussian-only via `diag_B_slope_is_default`, `R/fit-multi.R:644`). The keyword errors loudly; the
  argument does not. Worth a warn-or-error for consistency.
- **Family-generality trade-off of the ANI-11 fold:** the standalone `phylo_unique(1+x|sp)` companion was
  family-general; the folded `phylo_latent(1+x|sp, unique=TRUE)` adds the low-rank slope whose family
  coverage is narrower (Gaussian + some non-Gaussian). Removed the "fits family-generally" claim from the
  folded prose. The docs no longer advertise family-generality for that capability.
- **Fold recovery not re-validated:** I verified the folds *fit*, not that the combined model *recovers*
  the 2×2 (that's covered separately by ANI-11 companion + PHY-17 slope; joint recovery unverified). The
  ANI-11 examples are `eval=FALSE`.

## Consistency audit (reproducible)
```sh
grep -rnE "unique\(|_unique\(" vignettes/ | grep -vE "unique = "        # only api-keyword-grid.Rmd:65
grep -rnE "^#'.*(unique\(|_unique\()" R/ | grep -vE "unique = " \
  | grep -vE "R/(unique-keyword|animal-keyword|kernel-keywords|brms-sugar|spde-keyword)\.R"   # empty
```

## Runtime-message sweep (2nd pass — the taught+rendered surface is more than vignettes)
Rose flagged 2 cli hints; a Rose-principle grep found the keyword in **~30 user-facing R runtime
messages** across `fit-multi.R`, `extract-sigma.R`, `profile-derived.R`, `profile-derived-curves.R`,
`phylo-signal-ci.R`, `extract-omega.R`, `communality-ci.R`, `extract-two-psi-cross-check.R`,
`julia-bridge.R`. Swept by category:
- **Teachable suggestions** ("Refit with / Use / Add a / paired / with optional `*_unique()`") →
  redirected to `phylo_latent(..., unique = TRUE)` / `phylo_indep` / `indep`. (~22 edits.)
- **Family-general hints** (`fit-multi.R:1388,1496`): redirect would be *wrong* (fold isn't
  family-general) → reworded to the valid `phylo_indep(0 + trait | species)` fallback + the family
  limitation, keyword-free.
- **Column-ref diagnostics** (`fit-multi.R:2900,3128`) that hardcoded `spatial_unique`/`unique` →
  generalized (also a correctness fix: they'd mislabel a user who wrote `spatial_indep`/the fold).
- **KEPT (intentional):** "you wrote X" duplicate/redundancy diagnostics (`fit-multi.R:502,986,1022,
  1123/1124,1139,1165/1167,1248/1249,1276/1278,2588,2851`) — they name the user's *actual* formula
  input, so naming the (compat, still-parsing) keyword is correct. Internal parser allow-lists
  (`traits-keyword.R`, `missing-predictor.R`), `.phylo_unique` markers, and base `unique()` untouched.
- Verified: `load_all()` + `document()` clean; **no test asserts on any removed fragment** (grep of
  `expect_*`/snapshots; the one column-ref assertion uses lenient alternatives preserved by the rewrite).

## 🔴 Third open item (maintainer decision) — print-label leak (verified)
`R/methods-gllvmTMB.R:339-347` maps diagonal covstructs to `"unique"`-flavored **display labels** by
default. Empirically confirmed: a folded `phylo_latent(species, d = 1, tree = tree, unique = TRUE)` fit
**prints its companion as `"phylo_unique"`** (from the default map at line 345 — `use` carries only
`phylo_rr` + `phylo_diag`, no sub-flag). So the deprecated keyword leaks into the fit's print/summary
output for a user who wrote the fold. **Not fixed:** the map's comment (350-353) documents an
intentional design ("surfaces the indep form *when the user wrote it*", default = unique), so inverting
it to default-`indep` is a print-API change that also changes what existing explicit-`phylo_unique`
fits render — a maintainer call. Recommended: default diagonal labels → `indep`-flavored
(`phylo_diag`→`phylo_indep`, `spde`→`spatial_indep`, `diag_W`→`indep_unit_obs`, `diag_species`→`indep_*`),
update the comment, and keep the explicit-`phylo_unique` sub-flag override only if a fit that *explicitly*
used the keyword should still echo it.

## Rose gate — two open items (🔴 need maintainer decision; NOT arc regressions)
1. **Pre-existing defects in `choose-your-model.Rmd`** (verified pre-existing via `git diff` — my edits
   are at hunks 184/213/246/312/443/585, none at 355-380): a headerless/broken table at ~365-366 +
   duplicated prose blocks (357-363 vs 368-380; the double "The full decomposition reads" at 186-197;
   the Rung-2 paragraph at 444-457). Unrelated to the keyword removal. Per surgical discipline +
   the broad-article-change policy, **flagged, not fixed here** — offer a separate small cleanup PR.
2. **Runtime cli hints `R/fit-multi.R:1388,1496`** still name `phylo_unique(1 + x | species)` **(family-general)**
   as the escape hatch for augmented correlated phylo random regression on families **outside** the
   validated low-rank-slope set. This is finding #1 in runtime form: the folded `phylo_latent(unique=TRUE)`
   contains the same low-rank slope that just fail-louded, so **redirecting these hints to the fold would
   give wrong advice**. There is no keyword-free *family-general* equivalent. Decision needed: keep the
   `phylo_unique` hint as the documented family-general escape hatch, drop the correlated suggestion (leave
   only `phylo_indep`), or reword to the capability (ANI-11) without naming the keyword. **Not swapped** —
   a mechanical swap would be semantically wrong.

## Next actions
- **🔴 Maintainer:** decide the two Rose items above, then #728 → ready.
- Merge #728 after maintainer review + a full `build_site()`/`R CMD check` pass (high-risk broad-article
  arc → maintainer sign-off per merge policy).
- Open a small follow-up for the non-Gaussian `unique=TRUE` silent-ignore (finding above).
- DESCRIPTION stays 0.2.0 until the 0.3.0 release cut.
