# After-Task: Phylogenetic / two-U doc-validation branch

## Goal

Start the maintainer-dispatched Codex item #1 lane after PR #39:
adapt the useful legacy phylogenetic / two-U documentation to the
current package vocabulary without expanding beyond three
user-visible items.

## Scope Cap

This branch is capped at:

1. `vignettes/articles/phylogenetic-gllvm.Rmd`;
2. `docs/design/03-phylogenetic-gllvm.md`;
3. a focused `traits()` wide-formula phylogenetic equivalence test.

The separate legacy `two-U-phylogeny.Rmd` article and full Curie
identifiability simulation deep-dive remain follow-up work.

## Mathematical Contract

No likelihood, TMB, family, exported function, or formula-grammar
change. The documentation contract is:

```text
Sigma_phy = Lambda_phy Lambda_phy^T + S_phy
Sigma_non = Lambda_non Lambda_non^T + S_non
```

where `S_phy` and `S_non` are diagonal unique-variance matrices. The
legacy nickname "two-U" remains a task label and function/file-name
label only; public math uses `S` / `s`.

## Files Changed

Initial branch-start file list:

- `vignettes/articles/phylogenetic-gllvm.Rmd` (new)
- `docs/design/03-phylogenetic-gllvm.md` (new)
- `tests/testthat/test-traits-keyword.R`
- `_pkgdown.yml`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-12-phylo-two-u-doc-validation.md`

The final branch also updates existing roxygen/Rd/vignette wording that
still used legacy `U`, `U_phy`, or `U_non` notation in public equations:

- `R/brms-sugar.R` and generated keyword Rd files
- `R/extract-omega.R` and generated extractor Rd files
- `R/extract-two-U-cross-check.R` and generated Rd
- `R/extract-two-U-via-PIC.R` and generated Rd
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `vignettes/articles/covariance-correlation.Rmd`

## Checks Run

Before editing:

- `git status --short --branch`: clean `main`;
- `gh pr list --repo itchyshin/gllvmTMB --state open`: no open PRs;
- `git log --all --oneline --since="6 hours ago"`: recent merges
  inspected, with PR #39 merged and no active overlapping PR.

A live pre-write probe fitted the intended long and wide data-frame
phylogenetic formulas and returned convergence `0` for both with
zero log-likelihood difference.

Final branch validation:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: passed,
  updating the generated Rd files touched by the roxygen notation sweep.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|two-U-cross-check|extract-omega")'`:
  passed with `FAIL 0 | WARN 2 | SKIP 1 | PASS 82`. The two warnings are
  the existing `B`/`W` deprecation checks in `test-extract-omega.R`; the
  skip is the existing fixed-effects-only fallback skip in
  `test-traits-keyword.R`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/phylogenetic-gllvm", new_process = FALSE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`:
  passed. Both article renders emitted only the known missing
  `../logo.png` pkgdown warning.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`:
  passed with "No problems found".
- `git diff --check`: passed.

## Consistency Audit

The branch follows:

- `docs/dev-log/decisions.md` naming rule: public math uses `S/s`,
  not legacy `U`;
- `AGENTS.md` article rule: user-facing examples show long and wide
  data-frame forms side by side;
- `docs/design/02-data-shape-and-weights.md` wide-formula RHS rule:
  `unique(1 | species)` expands to `unique(0 + trait | species)`,
  while species-axis `phylo_latent(species, ...)` and
  `phylo_unique(species, ...)` pass through.

## Tests Of The Tests

The new focused test would have caught the exact documentation drift
this branch is meant to prevent: a public wide data-frame phylogenetic
example that silently falls back to explicit long syntax or fails to
match the long-form likelihood.

## What Did Not Go Smoothly

The stale-notation sweep had to be done as a narrow prose/comment pass:
some `U_phy` / `U_non` names are current list component names and test
component labels, so the branch updates public equations to `S/s` while
leaving those API names unchanged.

## Team Learning

- **Ada** capped the branch at three Codex-owned items while allowing
  work to continue during post-merge main CI.
- **Boole** is represented by the compact-vs-explicit formula test.
- **Noether** is represented by the `S/s` notation contract.
- **Pat** is represented by the article's long + wide side-by-side
  syntax and the explanation that `gllvmTMB_wide()` is not the row-
  phylogeny shortcut.
- **Shannon** passed the pre-edit lane check: no open PRs and no
  overlapping target branch.

## Known Limitations And Next Actions

Follow-up work should not be silently folded into this branch: the
standalone two-U cross-check article and the Curie simulation deep-dive
are separate tasks. The branch did not run a full `devtools::check()`;
it used focused tests, affected article renders, `pkgdown::check_pkgdown()`,
and whitespace validation.
