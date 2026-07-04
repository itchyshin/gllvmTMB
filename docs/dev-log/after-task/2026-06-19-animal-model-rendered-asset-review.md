# Animal Model Rendered Asset Review

Date: 2026-06-19

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Close the rendered HTML and asset evidence slice for the internal
`animal-model` candidate article. This does not replace true browser
scroll-through, larger-pedigree validation, cross-package agreement evidence,
or final public placement review.

## Files Touched

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/after-task/2026-06-19-animal-model-rendered-asset-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Checks

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No recent commits were reported.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/animal-model", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/animal-model.html` successfully.
- Rendered HTML scope check
  - Passed for the internal article gate, diagnostic labels, heritability, and
    animal-model wording.
  - No rendered hits for `release ready`, `scientific coverage passed`, or
    `publication-grade`.
- Figure asset dimension check
  - `G3-correlation-1.png`: 1113 x 921.

## Status

The article has rendered HTML and asset evidence. It remains internal until
true browser review and final public-placement review pass. This is not
larger-pedigree validation, cross-package agreement evidence, bridge
completion, release readiness, or scientific coverage.
