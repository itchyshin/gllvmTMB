# After Task: CI Ignored-Source Fast Path

Date: 2026-05-19

Branch: `codex/ci-ignored-docs-fast-path-2026-05-19`

Roles: Ada coordinated; Grace owned CI pacing; Rose checked
consistency; Shannon watched lane overlap; Curie reviewed the
simulation/dev-script boundary.

## Goal

Reduce repeated 30-40 minute waits for PRs that only touch files
excluded from R package builds, while keeping full R CMD checks for
package-facing changes.

## Implemented

- Expanded the existing in-job classifier in
  `.github/workflows/R-CMD-check.yaml` to fast-pass ignored-source
  planning/doc paths: `docs/`, `dev/`, `ROADMAP.md`, `AGENTS.md`,
  `CLAUDE.md`, `CONTRIBUTING.md`, and the PR template.
- Kept workflow-level triggers unchanged so the OS-named required
  checks still start on every pull request.
- Added light fast-path validation: `git diff --check` on the changed
  file range, plus `Rscript parse(file = ...)` for changed ignored
  `dev/*.R` scripts.
- Left full R CMD check required for `R/`, `src/`, `tests/`, `man/`,
  `vignettes/`, `README.md`, `NEWS.md`, package metadata, workflow
  files, unknown paths, and mixed scopes.
- Updated `CONTRIBUTING.md`, `docs/dev-log/check-log.md`, and
  `docs/dev-log/coordination-board.md`.

## Safety Notes

The workflow still uses the same OS-named job matrix. This avoids the
required-check pending-state problem that can occur when path filters
skip an entire required workflow.

The expanded fast path is intentionally tied to `.Rbuildignore`:
`docs/`, `dev/`, `AGENTS.md`, `CLAUDE.md`, `ROADMAP.md`, and
`CONTRIBUTING.md` are not part of the built package. R CMD check cannot
exercise most of those files, so the faster replacement gate is more
honest: whitespace validation, parse validation for ignored R scripts,
and reviewer evidence in the PR.

## Checks Run

- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/R-CMD-check.yaml"); puts "yaml ok"'`
  -> `yaml ok`.
- Extracted every workflow `run:` block with GitHub expressions replaced
  by `DUMMY`; `bash -n` returned cleanly for each script.
- local classifier simulation for ignored-source and package-affecting
  file sets:
  - `docs/design/42-m3-dgp-grid.md`, `docs/dev-log/check-log.md`,
    `ROADMAP.md`, and `AGENTS.md` -> fast path, no R parse.
  - `dev/m3-grid.R` -> fast path plus R parse.
  - `R/fit-multi.R`, `src/gllvmTMB.cpp`, `README.md`, and
    `.github/workflows/R-CMD-check.yaml` -> full R CMD check.
- `Rscript --vanilla -e 'parse(file = "dev/m3-grid.R"); cat("r parse ok\n")'`
  -> `r parse ok`.
- `git diff --check` -> clean.

## Definition-of-Done Check

1. Implementation: workflow classifier and light validation updated.
2. Simulation recovery test: not applicable.
3. Documentation: `CONTRIBUTING.md`, check-log, coordination board,
   and after-task updated.
4. Runnable user-facing example: not applicable.
5. Check-log entry: added.
6. Review pass: Grace, Rose, Shannon, and Curie perspectives recorded.

## Next Action

Use the next ignored-source PR to verify that all three OS-named jobs
fast-pass in minutes while package-affecting PRs still run full R CMD.
