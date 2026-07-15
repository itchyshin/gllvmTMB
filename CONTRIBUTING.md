# Contributing to gllvmTMB

`gllvmTMB` is early-stage software. Contributions should be small,
tested, and linked to the project design documents.

## Definition of Done

A modelling feature is complete only when it includes:

- implementation in `R/` (and `src/gllvmTMB.cpp` if a likelihood
  change);
- simulation or unit tests under `tests/testthat/`, including the
  symbolic-math <-> implementation alignment table from the
  `add-simulation-test` skill;
- documentation (roxygen on every exported function);
- a runnable example in the function's roxygen `@examples`;
- a check-log entry under `docs/dev-log/check-log.md`;
- review for likelihood, parameterisation, and scope (the `reviewer`
  Codex agent or the equivalent inline review hat).

**Create the after-task report at branch start, not at PR close.**
Right after `git switch -c agent/<topic>`, the first commit on the
branch should add `docs/dev-log/after-task/YYYY-MM-DD-<topic>.md` with
the template skeleton (Goal / Implemented / Mathematical Contract /
Files Changed / Checks Run / Tests Of The Tests / Consistency Audit /
What Did Not Go Smoothly / Team Learning / Known Limitations /
Next Actions). Fill in as work progresses. The file's presence is the
structural prevention of the "forgot to write an after-task" failure
that produced PR #13 backfill on 2026-05-11.

## PR Slice Contract

Every pull request should use `.github/pull_request_template.md`.
Keep the slice goal to one bounded change, list files intentionally
touched and intentionally not touched, name the relevant test evidence when
advertised capability status moves, record exact checks run, and name
only the review roles that actually engaged.

If a change needs several independent surfaces -- for example an
engine change, a README rewrite, a pkgdown navigation change, and a
validation-readiness matrix -- split it into several PRs unless the
maintainer explicitly asks for one bundled cascade.

## Scope

The package is for stacked-trait multivariate GLLVMs. Two
user-facing data shapes are current: **long**
(`gllvmTMB(value ~ ..., data = df_long, ...)`) and **wide data
frame** (`gllvmTMB(traits(...) ~ ..., data = df_wide, ...)`). Both
reach the same long-format engine. New examples, articles, and
roxygen `@examples` blocks should use one of these two formula-API
shapes. The legacy matrix wrapper `gllvmTMB_wide(Y, ...)` remains
exported but is soft-deprecated in 0.2.0; do not use it in new
user-facing prose except in migration notes.

Single-response models belong in `glmmTMB`; spatial single-response
models belong in `sdmTMB`.

The covariance dispatch is the 4 x 5 keyword grid:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| animal  | `animal_scalar()`  | `animal_unique()`  | `animal_indep()`  | `animal_dep()`  | `animal_latent()`  |
| phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The folded decomposition mode is `latent()`:
Sigma = Lambda Lambda^T + diag(psi) (the Greek letter
Psi; see `decisions.md` 2026-05-14 notation reversal). Ordinary
`latent()`, `phylo_latent()`, and `animal_latent()` carry the diagonal
Psi companion by default; use `*_latent(..., unique = FALSE)` only for
the older loadings-only subset on folded terms.

## Code Formatting

Run [Air](https://posit-dev.github.io/air/) on R and Rmd source
before pushing:

```sh
air format .
```

Air is a Rust-based R formatter from Posit; install via
`curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
on macOS / Linux, or follow the project's install page for Windows.
Configuration lives in `air.toml` at the repository root (80-char
line width, two-space indent). Editors with Air integration
(Positron, RStudio, VS Code via the extension) format on save once
the binary is on `PATH`.

There is no CI gate on formatting; the local `air format .`
discipline is the only check. This matches the `drmTMB` sister
package's practice. A CI gate may be added later if format drift
starts landing through PRs, but for now the local-only convention
is the simpler and lower-friction setup.

## Development Checks

Use these commands before review:

```r
devtools::document()
devtools::test()
devtools::check()
pkgdown::check_pkgdown()
```

For changes that touch README, vignettes, reference navigation,
exported functions, or generated Rd files, run `pkgdown::check_pkgdown()`
before pushing. For changes that touch user-formula parsing, tutorial
code, or article examples, also render the affected articles:

```r
pkgdown::build_articles(lazy = FALSE)
```

Long simulation studies should live outside CRAN-time tests, gated
by `Sys.getenv("RUN_SLOW_TESTS")` or moved to `data-raw/`.

### Tiered CI policy

Use the smallest check that can catch the class of failure introduced
by the slice.

| Change type | Local evidence before PR | Full GitHub R-CMD-check |
| --- | --- | --- |
| TMB likelihood, formula grammar, exported API, generated Rd, package metadata | targeted tests plus relevant docs; run full local or CI check when practical | required on every PR before merge |
| Tests, simulation helpers, gallery renderers | targeted `devtools::test()` plus artifact smoke render when relevant | required before merge, but later slices can be planned while it runs |
| README, NEWS, pkgdown, vignettes, articles, generated Rd, package-facing examples | render or check the affected surface; run `pkgdown::check_pkgdown()` when pkgdown or reference navigation is touched | required before merge, usually batched at a checkpoint |
| Ignored-source docs and planning files (`docs/`, `dev/`, `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md`, `.github/pull_request_template.md`, `CONTRIBUTING.md`) | `git diff --check` plus Shannon/Rose review as relevant; changed ignored `dev/*.R` scripts also get an R parse check in CI | fast-passed by CI unless bundled with package-affecting files |
| Long simulation and power-analysis experiments | manifest-driven local/cluster run with saved artifacts and summary checks | not inside ordinary R-CMD-check |

The `R-CMD-check` workflow keeps the same OS-named checks on every
pull request. For ignored-source / process-only diffs it exits quickly
after classifying the changed files and running light validation, so
required checks do not remain pending. Unknown or mixed file scopes
fall back to the full R CMD check.

Keep work-in-progress to one open PR when possible, and let package-
affecting GitHub Actions finish before pushing a follow-up commit. The
pkgdown workflow is sequenced after a green `R-CMD-check` on `main`;
do not use pkgdown as a parallel substitute for the full check.

## Pre-Publish Audit

Any PR touching public prose or reference navigation should run the
Rose pre-publish audit before merge. The audit is deliberately narrow:
method lists, default-value claims, exported function names, the
4 x 5 keyword grid, argument names, family lists, and stale
terminology. It is a consistency gate, not a general rewrite pass.

## Cross-Team Coordination Audit

Use the Shannon coordination audit before a working-tree switch, a
merge-order decision, a multi-PR fan-out, or an end-of-session
handoff. Shannon is read-only. It checks branch state, dirty files,
open PRs, file overlap, CI state, dev-log handoffs, and after-task
report coverage, then reports pass, warn, or fail with the smallest
recommended next action.

## Articles

Every public article is **Tier 1** by default. Tier 2 / Tier 3
require explicit justification in the article's YAML front-matter.
The `article-tier-audit` skill encodes the triage. The
`vignettes/articles/morphometrics.Rmd` is the canonical Tier-1
exemplar.
