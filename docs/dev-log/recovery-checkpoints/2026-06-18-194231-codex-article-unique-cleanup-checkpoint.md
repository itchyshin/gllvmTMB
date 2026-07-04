# Recovery checkpoint -- article unique cleanup extended

Date: 2026-06-18 19:42 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Branch and status

- Branch: `codex/r-bridge-grouped-dispersion`
- Remote relation: ahead 56 of `origin/codex/r-bridge-grouped-dispersion`
- No staging, no push, no GLLVM.jl #101 mutation.
- Pre-edit lane check for this continuation:
  - `gh pr list --state open` -> only draft PR #489.
  - `git log --all --oneline --since="6 hours ago"` -> current coevolution
    stack headed by `5346391 test(coevolution): add poisson recovery gate`.

Current tree is still broad from the inherited coevolution / ordinary
latent-Psi stack. Newly extended article cleanup touched:

- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/simulation-recovery-validated.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-article-unique-cleanup.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

Overall `git diff --stat` at checkpoint time: 82 files changed, 2586
insertions, 718 deletions. Most of this remains inherited stack state.

## Commands run since previous checkpoint

- `Rscript --vanilla -e 'pkgdown::build_article("articles/phylogenetic-gllvm", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/profile-likelihood-ci", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/simulation-recovery-validated", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/data-shape-flowchart", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully with pre-existing Pandoc math warnings for
    `\rm` fragments in the Tier-3 internal draft.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/stacked-trait-gllvm", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Result: rendered successfully.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Result: `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  - Result: passed.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/ && curl -fsS --max-time 2 http://127.0.0.1:8770/sweep.json | python3 -m json.tool | rg -n '2026-06-18 19:40 MDT|behavioural-syndromes|All nineteen|article unique cleanup'`
  - Result: local dashboard served updated "All nineteen" state.

## Cleanup outcome

The article unique-deprecation sweep now covers nineteen article sources plus
the main vignette. New in this extension:

- `phylogenetic-gllvm`: ordinary non-phylogenetic tiers now use default
  `latent()`; standalone population diagonal uses `indep()`; `phylo_unique()`
  remains explicit source-specific phylogenetic `Psi`.
- `profile-likelihood-ci`: phylogenetic signal wording now says ordinary
  `latent()` carries the non-phylogenetic diagonal `Psi`.
- `simulation-recovery-validated`: keeps the same per-trait `psi_t` coverage
  estimand but describes it as diagonal `Psi` under default `latent()`.
- `data-shape-flowchart` / `stacked-trait-gllvm`: Tier-3 drafts no longer teach
  ordinary `latent + unique` as the canonical syntax.
- `behavioural-syndromes`: Tier-3 candidate example now uses default
  `latent()` at the between- and within-individual tiers while preserving the
  `Psi_B` / `Psi_W` interpretation.

## Final residual scan

Command:

```sh
rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \| site\)|unique\(1 \| site\)|unique\(0 \+ trait \| individual\)|unique\(1 \| individual\)|add `\+ unique|paired `unique|needs a paired `unique|free `unique\(\)` component|Sigma = shared \+ unique' vignettes/articles vignettes/gllvmTMB.Rmd README.md --glob '*.Rmd' --glob '*.md'
```

Remaining hits:

- `vignettes/gllvmTMB.Rmd`
  - intentional compatibility note: "older explicit `latent() + unique()`".
- `vignettes/articles/api-keyword-grid.Rmd`
  - intentional compatibility examples for explicit ordinary `latent() +
    unique()`.
- `vignettes/articles/random-regression-reaction-norms.Rmd`
  - Tier-3 internal random-regression boundary where explicit augmented
    `unique()` is tied to Gaussian-only support. Do not remove casually; this
    needs a dedicated random-regression test/prose slice.

## Next safest action

Either:

1. Leave the article unique cleanup here and switch to the next planned
   non-documentation lane; or
2. Open a dedicated random-regression slice for
   `vignettes/articles/random-regression-reaction-norms.Rmd`, checking whether
   default augmented `latent()` really replaces explicit augmented `unique()`
   for the Gaussian example and how the non-Gaussian failure boundary should be
   described.

Do not widen the coevolution claim. Current Paper 2 / COE-04 remains partial,
and `kernel_unique()` / `*_unique()` remain compatibility syntax only.
