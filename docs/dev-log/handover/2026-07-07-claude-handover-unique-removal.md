# Claude → Claude handover (2026-07-07) — the `unique()` keyword-removal arc

**You are the next Claude, finishing the `unique()` / `*_unique()` KEYWORD removal
for v0.3.0.** ~70% is done and on the branch (uncommitted → will be committed with
this doc). The remaining work is a **precise punch-list** (below) — the grep IS the
definition of done. Spawn **Rose** (the completeness gate) before claiming done.

> Context is ephemeral; the repo is authoritative. This doc is the map; the
> whole-surface grep is the territory.

## THE GOAL (active session goal)

Remove the `unique()` / `*_unique()` **KEYWORD** from the entire **taught + rendered**
surface; **KEEP the `unique =` ARGUMENT**. Verified **zero-keyword**, semantically
correct, visually clean. Part of **v0.3.0**.

**The one distinction that must not slip (this is why it's failed 6–7 times):**
- `unique =` **ARGUMENT** on `latent()` / `*_latent()` → **STAYS, untouched.**
- `unique()` / `*_unique()` **KEYWORD** (call form) → **removed from grids, examples,
  cross-refs, teaching prose.** It still *parses* as soft-deprecated compat (old
  formulas run; the augmented fold desugars to `*_unique` internally), but is no
  longer taught/shown.

## Mission control

| Item | State |
|---|---|
| Branch | `claude/unique-keyword-deprecation` (off `main`) |
| Fold arcs (context) | `*_latent(1+x|…, unique=TRUE)` folds for ALL sources — **merged** (#725 phylo/animal, #727 spatial). So augmented `*_unique(1+x|g)` now migrates to `*_latent(1+x|g, unique=TRUE)`. |
| DONE (on disk) | roxygen grid `R/gllvmTMB.R` (4×5→4×4 + all cross-refs); main page `api-keyword-grid.Rmd`; `README.md`; `_pkgdown.yml` (dedup); NEWS entry; all "4×5"→"4×4"; **articles batches 2 & 4** (covariance-correlation, response-families, functional-biogeography, morphometrics, lambda-constraint, ordinal-probit, gllvm-vocabulary, convergence-start-values, data-shape-flowchart); **roxygen RX1/RX2/RX3a/RX3b** (unique-keyword, animal-keyword, kernel-keywords, traits-keyword, brms-sugar 50→18, spde-keyword, extract-omega, extract-sigma, extract-two-psi-cross-check, extractors, + 8 one-liners) |
| NOT DONE (agents stalled — files UNTOUCHED) | **batch 1** articles: `animal-model.Rmd` (8), `phylogenetic-gllvm.Rmd` (5), `choose-your-model.Rmd` (6), `random-regression-reaction-norms.Rmd` (7). **batch 3** articles: `joint-sdm.Rmd` (2), `cross-lineage-coevolution.Rmd` (2), `gllvmTMB.Rmd` (1), `pitfalls.Rmd` (1). |
| Closeout | grep-to-zero → fix `brms-sugar.R:4038` cli msg → `devtools::document()` → `pkgdown::build_site()` + rendered QA → PR |

## Punch-list — the exact remaining KEYWORD lines (run this first)

```sh
cd "<repo>"
# The taught-surface sweep. "Done" = only unique= argument, *_unique OWN deprecated
# docs, "unique variance"/"part=unique" concept/extractor names remain.
grep -rnE "unique\(|_unique\(" vignettes/ 2>/dev/null | grep -vE "unique = "
grep -rnE "^#'.*(unique\(|_unique\()" R/ 2>/dev/null | grep -vE "unique = "
```

The 8 unswept article files above are the bulk. **Replacement map** (preserve meaning):
- standalone `unique(0+trait|g)` → `indep(0+trait|g)`; `*_unique(grp)` → `*_indep(grp)`.
- paired `latent(…) + unique(…)` → `latent(…)` (Ψ default); `*_latent(…,unique=FALSE)+*_unique(…)` → `*_latent(…, unique=TRUE)`.
- **augmented** `*_unique(1+x|g)` → `*_latent(1+x|g, unique=TRUE)` (the fold is now live for every source).
- prose teaching the keyword → reword around `indep()` or the `unique =` argument.

## ⚠️ SUBTLE CASES — hand-review, do NOT blind-swap (Fisher/Rose)

1. **`random-regression-reaction-norms.Rmd:529` `# This intentionally errors today; unique() is the compatibility spelling`** — **STALE.** The augmented fold works now (#725/#727), so `*_latent(1+x|…, unique=TRUE)` no longer errors. Rewrite the example to show the working fold, not an error demo. Check lines 523–546.
2. `choose-your-model.Rmd:317,322` + `phylogenetic-gllvm.Rmd:566,581` + `animal-model.Rmd:606,614,719,726` — prose/examples teaching the **augmented** `*_unique(1+x|…)` 2×2 companion. Migrate to `*_latent(1+x|…, unique=TRUE)` (the folded spelling), keeping the biology.
3. `joint-sdm.Rmd:190,364` — prose "`latent()` alone instead of an explicit `unique()`" — reword (it's contrasting, not teaching a call).
4. Allowed to remain: `api-keyword-grid.Rmd:65` (the single deprecation note); `R/{unique-keyword,animal-keyword,kernel-keywords}.R` **own** deprecated-function doc blocks (badged `lifecycle::badge("deprecated")`); `brms-sugar.R` `phylo_unique`/`spatial_unique` own-doc blocks (~18 lines — **verify** they are all own-docs, not stray cross-refs).

## Closeout steps (after the 8 files are swept)

1. **Rose grep-to-zero** (command above) → only allowed forms remain.
2. **`R/brms-sugar.R:4038`** — cli deprecation message still says "the unique cell of the 4 x 5 keyword grid" — update to "…soft-deprecated; use `spatial_indep()` or the `unique =` argument" (drop the "4 x 5 / unique cell" framing). (Was locked by RX2; free now.)
3. **`devtools::document()`** — regenerate `man/*.Rd` (the roxygen edits are not yet in `man/`). Keep the 4 `*_unique` man pages (deprecated); confirm links to `*_indep()` resolve (all `*_indep` are exported + documented — verified).
4. **`pkgdown::build_site()`** (or `build_article("api-keyword-grid")`) — **Florence rendered QA**: the grid renders **4×4**, the TOC shows "**The Four Modes**", no broken `[*_unique()]`/table links, `_pkgdown.yml` "Soft-deprecated" section still lists the exports.
5. **`devtools::check(document = FALSE, args = "--no-tests")`** — no new doc warnings.
6. **PR** on the branch; NEWS entry is already written (top of `NEWS.md`). Do NOT bump DESCRIPTION Version yet (stays 0.2.0 until the 0.3.0 release cut). After-task report.

## Rehydration recipe (next Claude)

```sh
cd "<repo>"; git status --short --branch      # branch claude/unique-keyword-deprecation
git log --oneline -3
# read: this doc; then run the punch-list grep to see live state.
```
Then spawn **Rose** (completeness gate — grep-to-zero is the DoD; no over-claim).
Claude does the doc edits + document(); hand a live `pkgdown::build_site()` /
`R CMD check` render to Codex if it's slow, but the sweep + document() are Claude-doable.

### One-command resume (paste in your authenticated terminal, repo root)

```
claude "Rehydrate from docs/dev-log/handover/2026-07-07-claude-handover-unique-removal.md, spawn Rose, then finish the unique() keyword-removal arc: sweep the 8 unswept article files per the punch-list (hand-review the SUBTLE cases — the random-regression 'intentionally errors' demo is STALE), grep-to-zero, fix brms-sugar.R:4038, devtools::document(), pkgdown::build_site() + rendered QA, open the PR. Keep the unique= ARGUMENT."
```

## APPENDIX — the exact 30 remaining KEYWORD lines (as of this handover)

Grouped by file, with the fix for each. Re-grep first (`grep -rnE "unique\(|_unique\(" vignettes/ | grep -vE "unique = "`) in case line numbers drift.

**`vignettes/articles/animal-model.Rmd` (8)**
- L62, L63: table cells `animal_latent(id, d=1) + animal_unique(id)` / `rank-1 animal_latent() + explicit genetic animal_unique()` → fold to `animal_latent(id, d=1, unique=TRUE)` / `rank-1 animal_latent(id, unique=TRUE)`.
- L75: prose "`animal_unique()` is used here only as…" → reword to "`animal_latent(unique=TRUE)`".
- L131: "(`animal_indep()`; the older `animal_unique()` spelling remains…" → drop the "older `animal_unique()` spelling" clause.
- L606, L614, L719, L726: augmented `animal_unique(1 + x | id)` → `animal_latent(1 + x | id, unique=TRUE)` (folded; register ANI-11 still applies).

**`vignettes/articles/phylogenetic-gllvm.Rmd` (5)**
- L72: "Use `phylo_unique()` in this…" → `phylo_indep()` (or `phylo_latent(unique=TRUE)` per context).
- L85: table `phylo_latent() + phylo_unique()` → `phylo_latent(..., unique=TRUE)`.
- L566, L581: augmented `phylo_unique(1 + x | species)` → `phylo_latent(1 + x | species, unique=TRUE)`.
- L743: code `phylo_unique(species, tree = tree) +` → fold with the adjacent `phylo_latent` to `phylo_latent(species, tree = tree, unique=TRUE)` (check the whole formula block).

**`vignettes/articles/choose-your-model.Rmd` (6)**
- L216: table formula `+ phylo_latent(...) + phylo_unique(species, tree=tree) + latent(...)` → fold the phylo pair → `+ phylo_latent(species, d=K_phy, tree=tree, unique=TRUE) + latent(...)`.
- L317, L322: prose augmented `phylo_unique(1+x|species)` / `animal_unique(1+x|id)` (2×2) → `*_latent(1+x|…, unique=TRUE)`.
- L588, L591, L593: code block — the `# Soft-deprecated … phylo_unique(1+x|species)` comment + `value ~ 0 + trait + phylo_unique(0 + trait + (0+trait):x | species)` → `phylo_latent(0 + trait + (0+trait):x | species, unique=TRUE)`.

**`vignettes/articles/random-regression-reaction-norms.Rmd` (7) — ⚠️ SUBTLE, verify before editing**
- L73, L172, L523, L524: prose about the `unique()` component → reword to the `unique =` argument / `latent(unique=TRUE)`.
- **L529, L534: `# This intentionally errors today; unique() is …` + `unique(0 + trait + (0+trait):temperature | individual)`.** The augmented FOLD is now live (#725/#727) for **source-specific** terms, BUT this is an **ordinary** augmented term and the surrounding prose says it's "guarded for **non-Gaussian** families." **VERIFY** whether `latent(0 + trait + (0+trait):temperature | individual, unique=TRUE)` still errors for the family used here BEFORE rewriting: if it now runs, show the working fold; if it's still non-Gaussian-guarded, keep an honest "guarded today" note but spell it with the `unique =` argument, not the `unique()` keyword.
- L546: "augmented `latent()` part without `unique()`" → reword to "without the `unique =` companion".

**`vignettes/articles/joint-sdm.Rmd` (2)**
- L190, L364: prose "`latent()` alone instead of an explicit `unique()`" / "no `unique()` at the unit level" → reword (contrast is fine; just drop the keyword call — e.g. "…instead of an explicit diagonal companion").

**`vignettes/articles/cross-lineage-coevolution.Rmd` (2)**
- L81: "`kernel_unique()` remains soft-deprecated…" → drop/reword.
- L131: "add a diagonal `kernel_unique()` term" → `kernel_indep()` (or `kernel_latent(unique=TRUE)`).

**`vignettes/articles/pitfalls.Rmd` (1)**
- L243: "For any `latent()`, compatibility `unique()`, `indep()`, `dep()`, or `*_scalar()`" → drop "compatibility `unique()`," from the list.

**`vignettes/gllvmTMB.Rmd` (1)**
- L180: "The older explicit `latent() + unique()` spelling" → reword to the default-Ψ `latent()`.

**Then the closeout** (from the steps above): `R/brms-sugar.R:4038` cli msg · `devtools::document()` · `pkgdown::build_site()` + rendered QA (4×4 grid, "Four Modes" TOC) · `devtools::check(--no-tests)` · PR. NEWS entry already written.
