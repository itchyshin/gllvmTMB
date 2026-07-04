# Recovery checkpoint -- article unique cleanup continuation

Date: 2026-06-18 19:26 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Branch and status

- Branch: `codex/r-bridge-grouped-dispersion`
- Remote relation: ahead 56 of `origin/codex/r-bridge-grouped-dispersion`
- Broad worktree state: tracked stack remains broad from the inherited
  coevolution / unique-deprecation lane; no files were staged or pushed.
- New untracked after-task/checkpoint files remain local handoff material.

Current `git status --short --branch` summary:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
 M NEWS.md
 M data-raw/examples/make-model-selection-rank-example.R
 M docs/dev-log/check-log.md
 M docs/dev-log/dashboard/status.json
 M docs/dev-log/dashboard/sweep.json
 M inst/extdata/examples/model-selection-rank-example.rds
 M tests/testthat/test-example-model-selection-rank.R
 M vignettes/articles/fit-diagnostics.Rmd
 M vignettes/articles/mixed-family-extractors.Rmd
 M vignettes/articles/model-selection-latent-rank.Rmd
 M vignettes/articles/psychometrics-irt.Rmd
?? docs/dev-log/after-task/2026-06-18-article-unique-cleanup.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-192642-codex-article-unique-cleanup-checkpoint.md
```

The full working tree still includes the inherited coevolution and ordinary
latent-Psi changes recorded in earlier checkpoints.

## Changed files in this continuation

This continuation finished the in-flight `model-selection-latent-rank` cleanup
and then added three narrow public article wording cleanups:

- `data-raw/examples/make-model-selection-rank-example.R`
- `inst/extdata/examples/model-selection-rank-example.rds`
- `tests/testthat/test-example-model-selection-rank.R`
- `vignettes/articles/model-selection-latent-rank.Rmd`
- `vignettes/articles/fit-diagnostics.Rmd`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `NEWS.md`
- `docs/dev-log/after-task/2026-06-18-article-unique-cleanup.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

Overall `git diff --stat` at checkpoint time was 78 files changed, 2460
insertions, 650 deletions. Most of that is inherited from the broader
coevolution / unique-deprecation stack, not from this continuation alone.

## Commands run in this continuation

- `git status --short --branch && git diff --stat && git diff --check`
  - Result: branch ahead 56; broad inherited tracked stack; whitespace clean.
- `Rscript --vanilla data-raw/examples/make-model-selection-rank-example.R`
  - Result: regenerated `inst/extdata/examples/model-selection-rank-example.rds`
    with default `latent()` rank candidates and an `indep()` diagonal baseline.
- `Rscript --vanilla -e 'devtools::test(filter = "example-model-selection-rank", reporter = "summary")'`
  - Result: passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/model-selection-latent-rank", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: passed. The article now prefers the repo-local fixture before a
    stale installed-package fixture.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/fit-diagnostics", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/psychometrics-irt", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Result: `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  - Result: passed.
- Stale scans:
  - model-selection rank source / rendered HTML: only the intentional
    `default-`latent()` phrase remained.
  - fit-diagnostics source / rendered HTML: no old `latent() + unique()` hits.
  - mixed-family and psychometrics source / rendered HTML: no old
    `latent() + unique()` boundary hits.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/ && curl -fsS --max-time 2 http://127.0.0.1:8770/sweep.json | python3 -m json.tool | rg -n '2026-06-18 19:24 MDT|mixed-family-extractors|psychometrics-irt|All fifteen|article unique cleanup'`
  - Result: local dashboard served updated "All fifteen" article-cleanup state.
- `curl -fsS --max-time 2 http://127.0.0.1:8765/ | head -n 5`
  - Result: overall board is alive.

## Current article cleanup state

The article unique-deprecation cleanup report now covers fifteen public article
sources plus the main vignette:

- `convergence-start-values`
- `choose-your-model`
- `profile-likelihood-ci`
- `functional-biogeography`
- `cross-package-validation`
- `simulation-verification`
- `morphometrics`
- `api-keyword-grid`
- `pitfalls`
- `joint-sdm`
- `response-families`
- `model-selection-latent-rank`
- `fit-diagnostics`
- `mixed-family-extractors`
- `psychometrics-irt`
- main `gllvmTMB` vignette

This remains article/prose/fixture cleanup only. No keyword was removed, no
`part = "unique"` extractor contract was renamed, no source-specific or
`kernel_*()` latent-Psi fold was added, and no Paper 2 multi-kernel explicit-Psi
support was implemented.

## Remaining stale-hit classes

A final source scan still found hits in:

- `vignettes/gllvmTMB.Rmd` and `vignettes/articles/api-keyword-grid.Rmd`
  - intentional compatibility examples for explicit `latent() + unique()`.
- `vignettes/articles/simulation-recovery-validated.Rmd`
  - historical validation-grid wording for explicit Psi / per-trait psi
    coverage. This should be handled with a validation-row-aware edit, not a
    quick wording patch.
- `vignettes/articles/profile-likelihood-ci.Rmd` and
  `vignettes/articles/phylogenetic-gllvm.Rmd`
  - source-specific phylogenetic decomposition wording. This should be a
    source-specific cleanup slice, not ordinary default-latent cleanup.
- `vignettes/articles/random-regression-reaction-norms.Rmd`
  - augmented random-regression evidence wording. Needs a bounded
    random-slope/augmented-latent slice.
- `vignettes/articles/data-shape-flowchart.Rmd`,
  `vignettes/articles/stacked-trait-gllvm.Rmd`, and
  `vignettes/articles/behavioural-syndromes.Rmd`
  - internal draft / concept pages with old examples. Decide whether to retire,
    hide, or update in a separate article-council slice.

## Next safest action

Pick exactly one next lane:

1. Source-specific article cleanup: `phylogenetic-gllvm` and the remaining
   profile-likelihood pointer.
2. Validation-grid cleanup: `simulation-recovery-validated`, preserving the
   explicit per-trait psi coverage target.
3. Internal draft cleanup: `data-shape-flowchart`, `stacked-trait-gllvm`, and
   `behavioural-syndromes`, probably as an article-council retire/hide/update
   decision.

Do not widen the coevolution claim. Current Paper 2 / COE-04 evidence remains
partial, and `kernel_unique()` / `*_unique()` remain compatibility syntax only.
