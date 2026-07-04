# After-task report: cross-lineage article kernel-unique cleanup

Date: 2026-06-18 21:03 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup on the Paper 2
article surface by making the internal cross-lineage coevolution article teach
latent-only `kernel_latent()` syntax first.

## Files touched

- `vignettes/articles/cross-lineage-coevolution.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The article scope boundary now says the current Paper 2 first-wave syntax is
  latent-only.
- `kernel_unique()` is now mentioned only as soft-deprecated compatibility for
  older explicit-Psi fixtures and equivalence tests.
- Wide, long, null, and fixed-`rho` profile snippets no longer add
  `kernel_unique(...)`.
- The workflow overview now names `extract_coevolution_modules()` as the
  point-estimate module summary helper.

## Definition-of-done accounting

1. Implementation: article cleanup only on the local branch; not merged to
   `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: internal article source updated.
4. Runnable example: article rendered directly with `rmarkdown::render()`.
5. Check-log: `docs/dev-log/check-log.md` has the 21:03 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood, parser, or exported API change. This was a
   lifecycle/article consistency slice.

## Validation

- `pkgdown::build_article("cross-lineage-coevolution")` could not address this
  internal article by slug.
- `rmarkdown::render("vignettes/articles/cross-lineage-coevolution.Rmd",
  output_dir = tempfile("coev-article-"), quiet = TRUE)` rendered successfully.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- The stale scan found no first-line `kernel_unique()` teaching in the article.
- `git diff --check` was clean.

## Still open

- No keyword removal.
- No Paper 2 multi-kernel explicit Psi.
- No source-specific or kernel paired-Psi fold.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
