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

## Scope

The package is for stacked-trait multivariate GLLVMs. Two
user-facing data shapes -- **long** (`gllvmTMB(value ~ ...,
data = df_long, ...)`) and **wide** (`gllvmTMB_wide(Y, ...)` where
`Y` is a numeric matrix or a wide data frame). Both reach the same
engine. New examples, articles, and roxygen `@examples` blocks
should use one of these two canonical shapes. The formula-LHS
`traits(...)` marker stays exported for back-compatibility but is
internal (`@keywords internal`); new user-facing prose should not
recommend it.

Single-response models belong in `glmmTMB`; spatial single-response
models belong in `sdmTMB`.

The covariance dispatch is the 3 x 5 keyword grid:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The decomposition mode is `latent + unique` paired:
Sigma = Lambda Lambda^T + diag(psi) (the Greek letter
Psi; see `decisions.md` 2026-05-14 notation reversal).

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

Keep work-in-progress to one open PR, and let GitHub Actions finish
before pushing a follow-up commit. The pkgdown workflow is sequenced
after a green `R-CMD-check` on `main`; do not use pkgdown as a
parallel substitute for the full check.

## Pre-Publish Audit

Any PR touching public prose or reference navigation should run the
Rose pre-publish audit before merge. The audit is deliberately narrow:
method lists, default-value claims, exported function names, the
3 x 5 keyword grid, argument names, family lists, and stale
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
