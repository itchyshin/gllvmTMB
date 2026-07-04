# 2026-06-18 17:42 MDT -- Codex unique extractor/article alignment checkpoint

## Branch and status

- Branch: `codex/r-bridge-grouped-dispersion`
- Remote relation: ahead of `origin/codex/r-bridge-grouped-dispersion` by 56 commits.
- No files staged.
- `git diff --check`: clean at 2026-06-18 17:42 MDT.
- Dashboard: `http://127.0.0.1:8770/` live; `status.json` reports `updated = "2026-06-18 17:39 MDT"`.

Working tree remains intentionally broad because this branch carries the coevolution and post-coevolution `unique()` compatibility slices. New/untracked recovery and after-task files are present. Do not run `git add -A`; stage only intentional paths if the maintainer asks for a commit.

## Current changed-file summary

`git diff --stat` at checkpoint:

```text
40 files changed, 1155 insertions(+), 362 deletions(-)
```

Primary current-slice files:

- `R/extract-sigma.R`
- `R/extract-omega.R`
- `tests/testthat/test-extract-sigma.R`
- `tests/testthat/test-mixed-family-extractor.R`
- `tests/testthat/test-m1-3-extract-sigma-mixed-family.R`
- `man/extract_Sigma.Rd`
- `vignettes/articles/covariance-correlation.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-extractor-covariance-correlation-latent-psi-alignment.md`

## Commands run and outcomes

Pre-edit lane check before shared-file edits:

- `gh pr list --state open`: only draft PR #489 observed.
- `git log --all --oneline --since="6 hours ago"`: current coevolution stack observed; no collision detected.
- `git diff --check`: clean before edits.

Evidence before the fix:

- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma", reporter = "summary")'`
  - Failed because stale extractor tests still treated plain `latent()` as missing Psi/`unique()`.

Implemented and verified current slice:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Regenerated `man/extract_Sigma.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|mixed-family-extractor", reporter = "summary")'`
  - Passed with expected heavy skips.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|extract-sigma|mixed-family-extractor", reporter = "summary")'`
  - Passed with expected heavy skips.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Rendered `pkgdown-site/articles/covariance-correlation.html`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|mixed-family-extractor|m1-7-extract-omega|phylo-signal", reporter = "summary")'`
  - Passed with expected heavy skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found.`
- `tail -5 man/extract_Sigma.Rd && grep -c '^\\keyword' man/extract_Sigma.Rd`
  - Confirmed no runaway Rd keyword block.
- Stale wording scan:
  - `rg -n 'without unique|without \`unique\\(\\)\`|no-unique|no unique|missing-unique|missing unique|fit has only latent\\(\\)|no \`unique\\(\\)\` term|add \`\\+ unique|Refit with \`\\+ unique|reminding the user to add \`\\+ unique|latent\\(0 \\+ trait \\| unit, d = K\\).*no' R tests/testthat man NEWS.md README.md docs/design docs/dev-log/dashboard vignettes`
  - Remaining hits reviewed as intentional: augmented non-Gaussian reaction-norm context, OLRE/reference-fit baselines, matrix ordinal no-unique half, and source-specific `spatial_latent()` no-unique diagnostic.
- Confirmation scan:
  - `rg -n 'residual = FALSE|default latent|no-Psi|ordinary latent|latent\\(\\).*Psi' R tests/testthat man vignettes docs/dev-log/dashboard pkgdown-site/articles/covariance-correlation.html`
  - Confirmed updated source, tests, Rd, article, rendered HTML, and dashboard.
- `Rscript --vanilla -e 'jsonlite::fromJSON("docs/dev-log/dashboard/status.json"); jsonlite::fromJSON("docs/dev-log/dashboard/sweep.json"); cat("json ok\n")'`
  - Dashboard JSON parsed; command printed objects because return values were not assigned invisibly.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  - Synced dashboard files.
- `curl -sS http://127.0.0.1:8770/status.json`
  - Confirmed live dashboard timestamp at 17:39 MDT.
- `curl -sS http://127.0.0.1:8770/sweep.json | rg -n "extractor/article alignment|coevolution"`
  - Confirmed current alignment and coevolution entries are visible.
- Final `git diff --check`
  - Clean.

## What changed in this slice

- Aligned `extract_Sigma()` documentation and diagnostics with the ordinary `latent()` Psi fold.
- Reframed no-Psi examples and tests around `latent(..., residual = FALSE)`.
- Preserved `part = "unique"` compatibility naming and return shape.
- Updated `extract_phylo_signal()` no-Psi advisory language for non-phylogenetic residual tiers.
- Rewrote `vignettes/articles/covariance-correlation.Rmd` away from stale "latent-only versus latent+unique" framing toward default ordinary `latent()` with Psi and explicit `residual = FALSE` for the no-Psi subset.
- Recorded the slice in `docs/dev-log/check-log.md`, dashboard JSON, and after-task report.

## Guardrail state

Coevolution model status:

- The narrow local coevolution gate is finished for this stop point.
- COE-04 remains `partial`, not `covered`.
- No bridge completion, release readiness, interval calibration, broad non-Gaussian/mixed-family coverage, or scientific coverage is claimed.
- Preserve: `PR green != bridge complete != release ready != scientific coverage passed`.

`unique()` status:

- `unique()` / `phylo_unique()` / `animal_unique()` / `spatial_unique()` / `kernel_unique()` are soft-deprecated compatibility syntax.
- Ordinary `latent()` now carries Psi by default; `latent(..., residual = FALSE)` is the explicit no-residual subset.
- Source-specific `phylo_latent()`, `animal_latent()`, `spatial_latent()`, and `kernel_latent()` do not auto-fold Psi in this slice.
- `part = "unique"` remains a compatibility spelling in extractors.
- `common =` migration and free-correlation rehoming are not done.

## Next safest action

Continue one slice at a time in the post-coevolution `unique()` deprecation lane. Before any shared-file edit, rerun:

```sh
gh pr list --state open
git log --all --oneline --since="6 hours ago"
git diff --check
```

Suggested next narrow slice: audit the remaining exported examples and compatibility docs for `unique()` appearances, then choose only one of these: source-specific fold decision, `common =` migration planning, or extractor naming compatibility. Do not expand `kernel_unique()` for Paper 2 multi-kernel coevolution.
