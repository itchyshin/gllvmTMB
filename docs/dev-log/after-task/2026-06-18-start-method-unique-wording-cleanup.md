# Start-Method Unique Wording Cleanup

Date: 2026-06-18 23:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Remove stale `unique()`-first vocabulary from the start-method article and
design/status rows. The implementation still supports compatibility syntax,
but the public and design wording should describe the ordinary start target as
an independent diagonal model or an ordinary latent covariance model.

## Files Touched

- `vignettes/articles/convergence-start-values.Rmd`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- Changed the convergence/start-values article label from a Gaussian
  `latent+unique` fit to a Gaussian two-level ordinary latent covariance fit.
- Reworded the profile fallback note from full `latent+unique` models to full
  latent covariance models.
- Updated ASReml-speed and validation-debt rows so residual starts and
  independent warm starts no longer teach `unique()`-only or `latent+unique`
  as the ordinary spelling.
- Reworded the RE-12 validation row from `unique`-only diagonal extraction to
  explicit compatibility diagonal extraction.

## Checks

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/convergence-start-values", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  rendered the article successfully.
- `Rscript --vanilla -e 'devtools::test(filter = "start-method|gllvmTMBcontrol|unique-family-deprecation", reporter = "summary")'`
  completed successfully.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Stale phrase scans over the touched start-method surface returned no hits for:
  - `unique()-only`
  - `unique-only`
  - `full latent+unique`
  - `Gaussian two-level latent+unique`
  - `latent+unique fit`
- `git diff --check` passed.

## Still Not Claimed

- No behavior change to `start_method`.
- No `unique()` keyword removal.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.

## Addendum: Adjacent Augmented Labels

After the main start-method cleanup, three adjacent stale labels were tightened:

- `NEWS.md` now says explicit compatibility diagonal path instead of
  `unique`-only diagonal path for RE-12 evidence.
- `docs/design/04-random-effects.md` now says explicit compatibility diagonal
  extraction instead of `unique`-only diagonal extraction.
- `docs/design/48-m3-4-boundary-regimes.md` now asks about Gaussian two-level
  ordinary latent covariance fits rather than Gaussian two-level
  `latent+unique` fits.

Additional checks:

- Exact stale-label scans for those three phrases returned no hits.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.
