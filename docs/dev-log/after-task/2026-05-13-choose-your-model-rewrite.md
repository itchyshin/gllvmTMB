# After-Task: choose-your-model.Rmd rewrite (F1 + F2 + F3 + broken-link cleanup)

## Goal

Address all four Pat audit (PR #62) findings on
`choose-your-model.Rmd` -- the live pkgdown decision-tree
article -- plus the remaining 7 broken-link references that
the article-cleanup PR (#74) deliberately left for this
rewrite to handle together.

Maintainer ratified the four leans 2026-05-13 ~08:45 MT with a
blanket "go": F1+F2+F3 fix, long+wide pair, broken-link removals
per Section H verdicts.

Codex pause window (2026-05-13 -> ~2026-05-17): Claude owns this
lane per the coordination board.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

### F1: wide-format framing in Section 1

Replaced the "long-format only" opener with the post-PR #65
single-entry-point framing. Section 1 now says:

> `gllvmTMB` accepts data in two shapes through one entry point.
> Long-format data have one row per `(unit, trait)` observation
> (`gllvmTMB(value ~ ..., data = df_long, unit = "...")`); wide-
> format data have one row per unit and one column per trait,
> marked by `traits(...)` on the formula left-hand side
> (`gllvmTMB(traits(t1, t2, t3) ~ ..., data = df_wide,
> unit = "...")`). [...]

Section 1's data-layout table picks up the wide-form equivalent:
the random-effect grouping column now shows both `latent(0 +
trait | unit)` (long) and `latent(1 | unit, d = K)` (wide via
`traits()`). The two-level row points at `behavioural-syndromes`
instead of the broken `corvidae-two-stage` link.

A new paragraph after the table tells the reader:

> This article writes the examples in §6 in long format because
> the long form makes the multi-component formulas easier to
> read. Each example has an equivalent wide form via
> `traits(...)`; the Get Started vignette shows the long/wide
> equivalence check (`all.equal(logLik(fit), logLik(fit_wide))`).

### F2: phylogeny advice in Section 3 + 6c

Section 3 rewritten to recommend the **canonical paired
four-component decomposition** (per PR #53):

```
Omega = (Sigma_phy ⊗ A) + (Sigma_non ⊗ I)
Sigma_phy = Lambda_phy Lambda_phy^T + S_phy
Sigma_non = Lambda_non Lambda_non^T + S_non
```

New table row:

| **Canonical paired phylogenetic decomposition** | `+ phylo_latent(species, d = K_phy, tree = tree) + phylo_unique(species, tree = tree) + latent(0 + trait | species, d = K_non) + unique(0 + trait | species)` |

Prose explicitly cites `extract_phylo_signal()` and the
`phylogenetic-gllvm` article for the worked example and the
identifiability discussion. The `phylo_scalar` and bare
`phylo_latent` options are demoted to "simpler single-component
phylo model" status.

Section 6c (worked phylogeny example) rewritten to fit the
canonical 4-component model:

```r
fit_phy <- gllvmTMB(
  value ~ 0 + trait +
          phylo_latent(species, d = 1, tree = tree) +
          phylo_unique(species, tree = tree) +
          latent(0 + trait | species, d = 1) +
          unique(0 + trait | species),
  data = df_p,
  unit = "species"
)
```

Section 6e (capstone) updated: the capstone formula's phy
piece is now `phylo_latent + phylo_unique`, matching the
4-component canonical pattern (was `phylo_scalar` alone).

### F3: ladder figure

Replaced the heuristic-recovery bar chart (cited a nonexistent
`simulation-recovery.html`) with a compact 6-row markdown
table. The table preserves the complexity-ladder framing
(rung 0 -> capstone) and lists the formula piece each rung
adds, without invented recovery-quality numbers. The
`library(ggplot2)` dependency goes away with the chunk.

Caption-citation to the nonexistent simulation-recovery
article is removed.

### Broken-link removals (7 hits)

All 7 references that the article-cleanup PR (#74)
deliberately left in this article are now gone:

- L59 (ladder caption): removed with the ladder figure
- L110 (Section 1 table, two-level row): pointed at
  `behavioural-syndromes` instead of `corvidae-two-stage`
- L181 (Section 4 spatial prose): SPDE-benchmark citation
  stripped to plain prose
- L301 (Section 6d): SPDE-benchmark citation removed
- L366 (See also): SPDE-benchmark entry removed
- L367 (See also): Corvidae-two-stage entry removed
- L372 (See also): Simulation-based-recovery entry removed

`lambda-constraint` references (Section 5 + see-also) are
preserved -- live targets on Codex's Tier-2 queue per PR #41.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, or pkgdown navigation change. Single article
rewrite.

Math in the new Section 3:
`Sigma_phy = Lambda_phy Lambda_phy^T + S_phy`,
`Sigma_non = Lambda_non Lambda_non^T + S_non`,
`Omega = (Sigma_phy ⊗ A) + (Sigma_non ⊗ I)`. Matches PR #40 S/s
notation and PR #53 paired-decomposition framing.

## Files Changed

- `vignettes/articles/choose-your-model.Rmd` (M, ~80 lines net
  -- opener rewrite + Section 3 rewrite + Section 6c rewrite +
  Section 6e formula update + ladder-figure replacement +
  see-also cleanup)
- `docs/dev-log/after-task/2026-05-13-choose-your-model-rewrite.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: PR #74 (article cleanup + long+wide
  sweep) open; touches multiple articles but NOT
  `choose-your-model.Rmd`. Codex paused (per PR #70). Safe.
- `rg -ne 'corvidae-two-stage|cross-package-validation|simulation-recovery|spde-vs-glmmTMB' vignettes/articles/choose-your-model.Rmd`
  after edits: **zero hits**.
- `rg -ne 'lambda-constraint' vignettes/articles/choose-your-model.Rmd`
  after edits: 2 hits (Section 5 + see-also). Preserved per
  audit (Codex Tier-2 lane).
- `pkgdown::build_article("articles/choose-your-model", new_process = FALSE)`:
  rendered cleanly. Only known `logo.png` warning.
- Section 6c canonical-fit verification: the new fit uses
  `phylo_latent + phylo_unique + latent + unique` with
  `unit = "species"`. Matches the PR #53 phylogenetic-gllvm
  article's canonical 4-component decomposition.

## Tests Of The Tests

The "tests" are whether the rewritten article addresses each
finding:

1. **F1**: a reader in Section 1 sees both shapes. ✓
2. **F2**: the phy section recommends the 4-component canonical
   form, not just `phylo_scalar`. ✓
3. **F3**: no heuristic recovery numbers, no citation to a
   nonexistent article. ✓
4. **Broken links**: zero remaining references to the 4 dead
   article targets. ✓

If a future audit re-checks `choose-your-model.Rmd`, the four
findings should all show "addressed". If a future Tier-2 article
write picks up `simulation-recovery.html` or
`spde-vs-glmmTMB.html`, the article links can be re-added.

## Consistency Audit

```sh
rg -ne 'corvidae-two-stage|cross-package-validation|simulation-recovery|spde-vs-glmmTMB' vignettes/articles/
```

verdict after this PR: zero hits across ALL articles
(combined with PR #74's removals in 4 other articles, the
broken-link slate is clean).

```sh
rg -ne 'traits\(' vignettes/articles/choose-your-model.Rmd
```

verdict: 3 hits in Section 1's opener + table + paragraph
explaining long-vs-wide. Wide-format framing is explicit.

```sh
rg -ne 'phylo_latent|phylo_unique|phylo_scalar' vignettes/articles/choose-your-model.Rmd
```

verdict: `phylo_latent` + `phylo_unique` appear together as the
canonical recommended form; `phylo_scalar` appears once as the
"simpler single-component" alternative. The audit's F2 finding
(undersells the 4-component decomposition) is addressed.

## What Did Not Go Smoothly

Nothing substantive. The rewrite was bounded by the Pat audit
findings + the broken-link list.

The hardest decision was the ladder figure. The original was
visually informative but tied its bar heights to a nonexistent
simulation study. Three options:

- (a) Keep the figure with revised non-quantitative bars (e.g.
  all equal heights, decorative)
- (b) Drop the figure entirely
- (c) Replace with a compact markdown table

Chose (c). Reasons: a decorative bar chart with no meaningful
y-axis would mislead; a markdown table preserves the
complexity-ladder pedagogy (rung 0 -> capstone, one piece per
rung) in a smaller footprint. The ggplot2 dependency for the
chunk goes away too.

The 4-component example in Section 6c uses `unit = "species"`
(species are the unit of analysis for phylogenetic models),
matching the PR #53 `phylogenetic-gllvm` article. Earlier
revisions of choose-your-model used `unit = "site"` -- but a
phylogenetic GLLVM treats species as the unit. The fix here
aligns the two articles.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- the decision-tree article is the
  most-clicked Tier-1 article. The F1+F2+F3 fixes make Pat's
  first pass smoother: wide-form data shape is named in
  Section 1, the canonical phylogenetic decomposition is
  recommended in Section 3, and the ladder figure no longer
  cites a nonexistent benchmark.
- **Rose (cross-file consistency)** -- the Section 6c fit
  matches the PR #53 phylogenetic-gllvm article's
  4-component canonical form. The capstone formula in §6e
  also picks up the paired phy pattern.
- **Noether (math consistency)** -- the new Section 3 math
  block uses S/s notation per PR #40
  (`Sigma_phy = Lambda_phy Lambda_phy^T + S_phy`).
- **Shannon (coordination)** -- Codex paused (per PR #70);
  Claude owns this lane during the pause window per the
  coordination board. No collision with PR #74 (Codex-lane
  files untouched).

## Known Limitations

- The ladder figure replacement (markdown table) is less
  visually striking than the original bar chart. If the
  simulation-recovery study lands later (Phase 6 methods
  paper), the figure can be restored with real numbers.
- Sections 6a, 6b, 6d are unchanged (their long-format
  examples are fine; the long/wide note in Section 1 covers
  the wide-form pointer). A future revision could add
  per-section wide-form companions if pedagogically
  motivated, but the section is already dense.
- The `unit = "species"` change in Section 6c is correct for
  phylogenetic models but breaks naïve copy-paste from Sections
  6a/6b (which use `unit = "site"`). A reader assembling the
  capstone in Section 6e from the per-rung pieces should pay
  attention to the `unit` argument. The capstone formula in
  6e shows the assembled result.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible:
   single-article rewrite, no source / API / NAMESPACE change.
2. After merge, the Codex pause queue is empty for Claude.
   Claude stands by until Codex returns (~May 17) or
   maintainer dispatches new work.
3. When Codex returns, the lambda-constraint and
   psychometrics-irt Tier-2 article writes pick up from the
   Codex queue per PR #41.
