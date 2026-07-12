# After Task: Retained article renewal and latent/deprecation cleanup

## 1. Goal

Renew the retained gllvmTMB documentation estate before release discussion: remove internal validation-register codes from reader pages, teach the current four-mode covariance API, make the phylogenetic guide latent-focused, make long/wide grouping roles explicit, and verify the rendered pkgdown surface with Fisher, Rose, and Pat.

## 2. Implemented

- The retained 13-article set was re-audited by Fisher, Rose, and Pat; each final audit reports 13/13 PASS.
- Reader-facing pages no longer expose DIA/CI/EXT/FAM/FG/MIX validation-register identifiers or validation-process markers.
- Current teaching uses Scalar, Independent, Dependent, and Latent. Standalone `unique()` and source-specific/kernel `*_unique()` remain compatibility syntax and are described as deprecated; the current `unique =` latent argument remains documented where it controls the diagonal Psi companion.
- `phylogenetic-gllvm.Rmd` uses `phylo_latent(..., unique = TRUE)` for the phylogenetic Lambda/Psi decomposition, with an explicit non-phylogenetic latent comparison and honest recovery limits.
- Long examples name `trait` and `unit`; repeated-measure examples name `unit_obs`; the phylogenetic guide names `cluster` only where it is a real supplied role. `cluster2` remains a supported optional second grouping role, but no invented `cluster2` column was added because these examples contain no genuine second plain-diagonal tier.
- The generated local pkgdown pages were renewed and checked against their source timestamps.

## 3. Files Changed

### Reader-facing and API surface

`README.md`; `NEWS.md`; `_pkgdown.yml`; `R/gllvmTMB.R`; `R/kernel-keywords.R`; `R/brms-sugar.R`; `R/fit-multi.R`; `R/phylo-signal-ci.R`; `vignettes/articles/api-keyword-grid.Rmd`; `vignettes/articles/gllvm-vocabulary.Rmd`; `vignettes/articles/response-families.Rmd`; `vignettes/articles/random-regression-reaction-norms.Rmd`; `vignettes/articles/convergence-start-values.Rmd`; `vignettes/articles/behavioural-syndromes.Rmd`; `vignettes/articles/fit-diagnostics.Rmd`; `vignettes/articles/missing-data.Rmd`; `vignettes/articles/pitfalls.Rmd`; `vignettes/articles/pre-fit-response-screening.Rmd`; `vignettes/articles/profile-likelihood-ci.Rmd`; `vignettes/articles/fixed-effect-zero-constraints.Rmd`; `vignettes/articles/phylogenetic-gllvm.Rmd`; `vignettes/articles/joint-sdm.Rmd`; `vignettes/articles/morphometrics.Rmd`; `vignettes/articles/pitfalls.Rmd`; and the generated `pkgdown-site/` article outputs.

### Evidence and project records

`docs/dev-log/audits/2026-07-12-retained-articles-batch-a.md`; `docs/dev-log/audits/2026-07-12-retained-articles-batch-b.md`; `docs/dev-log/audits/2026-07-12-retained-articles-batch-c.md`; `docs/dev-log/audits/2026-07-12-final-fisher-13-article-audit.md`; `docs/dev-log/audits/2026-07-12-final-rose-13-article-audit.md`; `docs/dev-log/audits/2026-07-12-final-pat-13-article-audit.md`; `docs/dev-log/audits/2026-07-12-explicit-grouping-argument-cascade.md`; `docs/dev-log/check-log.md`; `docs/dev-log/decisions.md`; this report; and the recovery checkpoint paired with the handover.

Other tracked changes already present in the branch are deliberately listed as carried-over WIP in the handover rather than silently folded into this article-renewal claim.

## 3a. Decisions and Rejected Alternatives

- **Decision**: Teach four public covariance modes and keep deprecated `unique()` only as compatibility context. **Rationale**: the current package contract and reader-facing rule distinguish `indep()` from the latent `unique =` argument. **Rejected alternative**: retain a five-column public grid because it would teach a deprecated central mode. **Confidence**: high.
- **Decision**: Make the phylogenetic worked example latent-focused with `phylo_latent(..., unique = TRUE)`. **Rationale**: the scientific target is the phylogenetic Lambda/Psi decomposition and both parts must be extractable. **Rejected alternative**: lead with `phylo_dep()` or a loadings-only route. **Confidence**: high.
- **Decision**: Add grouping arguments only when the data contain the corresponding role. **Rationale**: Rose’s parsed 22/22 audit found no valid third tier in the other retained examples. **Rejected alternative**: invent `cluster`/`cluster2` arguments everywhere for visual symmetry. **Confidence**: high.
- **Decision**: Treat the local rendered site as verified but do not claim the public GitHub Pages site is updated. **Rationale**: the branch has not been merged or deployed. **Rejected alternative**: infer live-site freshness from the local server. **Confidence**: high.

## 4. Checks Run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, no problems found.
- `git diff --check` — PASS.
- All 13 `vignettes/articles/*.Rmd` / `pkgdown-site/articles/*.html` pairs — PASS; every HTML mtime is newer than its Rmd.
- Rose grouping render command for `profile-likelihood-ci`, `pitfalls`, and `gllvm-vocabulary` — exit 0; three outputs; zero warning/error/deprecation matches.
- Fisher phylogenetic fit checks — 150-species 13/13 health, 500-species 16/16 health, long/wide likelihood differences below `4e-10`.

## 5. Tests of the Tests

No package tests were added in this docs-only renewal slice. The integration test is the non-lazy render of all affected articles; the grouping audit specifically parsed executable calls and retained one intentional negative example to preserve the error-recovery lesson.

## 6. Consistency Audit

- `rg -n --glob '*.Rmd' --glob '*.html' 'DIA-[0-9]+|CI-[0-9]+|EXT-[0-9]+|FAM-[0-9]+|FG-[0-9]+|MIX-[0-9]+|validation-debt register|\\bvalidated\\b' vignettes/articles pkgdown-site/articles` — zero reader-facing matches.
- `rg -n --glob '*.Rmd' '\\b(unique|animal_unique|phylo_unique|spatial_unique|kernel_unique)\\s*\\(' <13 retained sources>` — only base-R data deduplication calls and one explicit deprecation distinction; no deprecated covariance teaching route.
- `rg -n 'phylo_(dep|indep)\\s*\\(' vignettes/articles/phylogenetic-gllvm.Rmd pkgdown-site/articles/phylogenetic-gllvm.html` — zero matches.
- `rg -n 'gllvmTMB\\(' vignettes/articles README.md NEWS.md docs/design` — 22 executable calls and five display calls checked; every long call has explicit `trait` and `unit`, with `unit_obs` where applicable.

## 7. Roadmap Tick

N/A. Release remains paused pending the broader documentation walk and Claude’s fresh-eye review.

## 8. What Did Not Go Smoothly

The repository already contained a large dirty WIP estate (261 uncommitted paths at the landing gate), so this slice cannot safely claim that the whole branch is landed. A stale generated profile page also demonstrated why source edits must always be paired with a forced render. These are declared explicitly in the handover.

## 9. Team Learning

Fisher checked inference wording, latent decomposition, fit health, and long/wide likelihood parity. Rose checked cross-file consistency, internal-code removal, grouping arguments, and the Rose “find ten more” cascade. Pat checked applied-user readability, responsive tables, figure clipping, and mobile rendering. All three final retained-article audits report 13/13 PASS.

## 10. Known Limitations and Next Actions

The public GitHub Pages site is not updated until the branch is merged and deployed. The branch still contains broad pre-existing WIP outside this article slice. Claude should read the handover, inspect the full dirty tree, run a fresh article review, and decide what belongs in the eventual PR. Do not merge, tag `v0.5.0`, or submit to CRAN until Shinichi calls for those actions.
