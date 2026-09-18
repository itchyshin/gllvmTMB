# After Task: Standalone temporal article refresh

## Goal

Make the existing Tier-1 temporal article a clearer reader path for the earned
standalone AR1/OU provider, while retaining the 5 x 3 stable-unit grid plus one
temporal provider and refusing all temporal source-pair teaching.

## Implemented

- Reframed the opening around the reader's two decisions: AR1 versus OU time
  semantics, then `indep`, `dep`, or rank-one `latent` trait covariance.
- Added a compact mode table and the temporal-Psi equation for
  `temporal_latent(unique = TRUE)`.
- Kept the existing long and `traits(...)` wide examples through
  `gllvmTMB()`, and clarified the distinct roles of `series`, `time`,
  `replicate`, `unit`, and `unit_obs`.
- Made the rejected temporal-plus-phylogeny/pedigree/spatial/kernel boundary
  explicit without presenting those routes as options.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
or pkgdown-navigation change. The article documents the existing standalone
temporal covariance: AR1 uses \(K(t,s)=\phi^{|t-s|}\), OU uses
\(K(t,s)=\exp(-\kappa|t-s|)\), and rank-one temporal latent covariance with a
Psi companion is \(K_{time}\otimes(\Lambda\Lambda^T+\Psi)\).

## Files Changed

- `vignettes/articles/temporal-ar1.Rmd` — reader-facing prose only.
- `docs/dev-log/check-log.md` — this check record.
- `docs/dev-log/after-task/2026-09-15-temporal-article-refresh.md` — this
  closure record.

No convention changed, so `R/`, generated `man/`, `README.md`, `NEWS.md`,
`ROADMAP.md`, design documents, and `_pkgdown.yml` were deliberately left
unchanged.

## Checks Run

- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/temporal-ar1.Rmd", output_dir = "/private/tmp/gllvmTMB-temporal-article-render", quiet = TRUE)'` — passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — passed: `No problems found.`
- `git diff --check` — passed.
- `gh issue list --state open --limit 100 --search temporal` — returned no
  temporal issue; the only result, #1280, concerns `*_slope()` to `*_coef()` and
  is unrelated.

## Tests Of The Tests

No test was added because this is a prose-only refresh. The rendered article
executes every retained long and wide example against the installed development
package; it would catch an example/API mismatch in the teaching path.

## Consistency Audit

- `rg -n "temporal_(indep|dep|latent)|forecast_temporal|profile_temporal|bootstrap_temporal|compare_temporal" R/temporal.R NAMESPACE docs/design/35-validation-debt-register.md vignettes/articles/temporal-ar1.Rmd` — function names and bounded-helper wording agree with source, exports, and `TEMP-06-01` (`partial`).
- `rg -n "5 ?[x×] ?3|temporal.*(phylo|animal|spatial|kernel)|(phylo|animal|spatial|kernel).*temporal" README.md NEWS.md docs/design vignettes/articles/temporal-ar1.Rmd` — the article retains the standalone boundary; matches are current design/register history, not a public source-pair option.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" vignettes/articles/temporal-ar1.Rmd` — no stale notation.
- `rg -n "gllvmTMB\\(" vignettes/articles/temporal-ar1.Rmd` — every long-form fit has `trait = "trait"`; wide `traits(...)` fits omit it as required.
- `rg -n "gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/temporal-ar1.Rmd` — no deprecated primary syntax.
- `rg -n "in prep|in preparation" vignettes/articles/temporal-ar1.Rmd` — no unsupported foundational claim.

**Rose pre-publish verdict: PASS.** The functions are exported, their stated
defaults agree with `R/temporal.R`, the article's scope maps to `TEMP-06-01`
(`partial`), and the deferred source pairs map to `TEMP-06-02` through
`TEMP-06-14` (`blocked`). Reader-facing prose carries no internal row IDs.

## What Did Not Go Smoothly

The repository lane-preflight tool identified a second Codex lane and its local
lease registry could not write outside this worktree, but it reported no live
lease for the temporal article paths. The branch and handover were therefore
reconciled before editing; protected shared handover files remain untouched.

## Team Learning

**Pat:** a temporal tutorial needs to begin with whether the data record
occasions or elapsed time; syntax alone leaves the most consequential modelling
choice implicit.

**Rose:** the article must state that temporal is a standalone provider beside
the stable-unit grid, otherwise a reader can mistakenly infer that deferred
source pairs are available.

**Grace:** a direct vignette render plus `pkgdown::check_pkgdown()` provides
proportionate evidence for a prose-only change without treating it as a fresh
package or cross-platform release check.

## Known Limitations

The article documents only the locally verified standalone Gaussian AR1/OU
route. `TEMP-06-01` remains `partial`: no general recovery, precision,
calibration, or coverage claim follows. All temporal combinations with other
covariance sources remain blocked developer history, not public options.

## Next Actions

**Roadmap tick:** N/A — no roadmap status changed.

**GitHub issue ledger:** no relevant open issue; no issue created. #1280 was
inspected and is unrelated to temporal documentation.

The documentation change is ready for maintainer review. Do not infer a merge,
release, or refreshed three-OS package-check claim from this prose-only work.
