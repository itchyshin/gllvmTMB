# After Task: CI tiered gates

**Branch**: `codex/ci-tiered-gates`
**Date**: 2026-05-18
**Roles**: Ada (orchestration), Grace (GitHub Actions and CI pacing),
Rose (process consistency), Curie (simulation/test boundary), Shannon
(lane check).

## Goal

Reduce unnecessary R-CMD-check waiting without weakening package
quality gates.

## Implemented

- Added a scope-classification step to `.github/workflows/R-CMD-check.yaml`.
- Kept the existing OS-named check jobs (`ubuntu-latest`, `macos-latest`,
  `windows-latest`) so future required-check settings do not get stuck
  on path-skipped workflows.
- Fast-pass process-only PRs and pushes after checkout/classification.
- Fall back to full R CMD check for package-affecting, unknown, mixed,
  manual, or tag-triggered runs.
- Documented the tiered CI policy in `CONTRIBUTING.md`.

## Mathematical Contract

No model, likelihood, formula grammar, statistical claim, or public API
changed.

## Files Changed

- `.github/workflows/R-CMD-check.yaml`
- `CONTRIBUTING.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-18-ci-tiered-gates.md`
- `docs/dev-log/recovery-checkpoints/2026-05-18-155307-codex-checkpoint.md`

## Checks Run

- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/R-CMD-check.yaml"); puts "yaml ok"'` - passed (`yaml ok`).
- `git diff --check` - passed (no whitespace errors).

## Tests Of The Tests

This PR changes CI policy rather than package tests. The guardrail is
conservative classification: only known process-only files skip the
expensive R setup and package check steps. Any unknown file path
requires full R CMD check.

## Consistency Audit

The workflow does not use `paths-ignore` because skipped workflows can
leave required checks pending. Instead, every OS-named job starts and
either runs full R CMD or records a fast-pass summary.

## What Did Not Go Smoothly

The immediate trigger was the #184/#185/#186 sequence: small
process/test-hygiene slices still paid for 30-40 minute Windows R CMD
checks under the old workflow. The red-main #184 rerun also showed that
R CMD is valuable, but it should catch package risks, not consume a
full runner cycle for files that R CMD cannot exercise.

## Team Learning

Grace: keep full checks for TMB/API/parser/test/vignette/pkgdown
surfaces, but classify process-only diffs before installing R.

Curie: long simulation, coverage, and power studies should move to
manual/scheduled/cluster artifact workflows, not ordinary R CMD.

Rose: if a PR skips expensive checks, the reason must be visible in
the workflow summary and PR template, not just assumed from file names.

## Known Limitations

This first pass only fast-passes narrow process-only paths. It does
not yet create the manual simulation/power workflow, the cluster shard
manifest, or a pkgdown-specific classifier.

## Next Actions

1. Open the CI policy PR and let full R CMD run once because this PR
   changes the workflow itself.
2. Use the next process-only PR to confirm the fast path exits in
   minutes.
3. Plan the separate simulation/power-analysis workflow and cluster
   manifest slice.
