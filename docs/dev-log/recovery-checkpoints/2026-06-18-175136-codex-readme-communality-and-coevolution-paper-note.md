# 2026-06-18 17:51 MDT -- Codex README/communality closeout + Paper 2 coevolution note

## Branch and status

- Branch: `codex/r-bridge-grouped-dispersion`
- Remote relation: ahead of `origin/codex/r-bridge-grouped-dispersion` by 56 commits.
- No files staged.
- `git diff --check`: clean at 17:49 MDT after dashboard/check-log updates.
- Dashboard: `http://127.0.0.1:8770/` live and synced; `status.json` reports `updated = "2026-06-18 17:49 MDT"`.

## Current changed-file summary

`git diff --stat` at checkpoint:

```text
51 files changed, 1314 insertions(+), 436 deletions(-)
```

New current-slice files:

- `docs/dev-log/after-task/2026-06-18-readme-communality-latent-psi-alignment.md`
- `docs/dev-log/recovery-checkpoints/2026-06-18-175136-codex-readme-communality-and-coevolution-paper-note.md`

Current-slice edited files:

- `README.md`
- `R/traits-keyword.R`
- `R/extractors.R`
- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `tests/testthat/test-extractors.R`
- `tests/testthat/test-extractors-extra.R`
- `man/traits.Rd`
- `man/extract_communality.Rd`
- `man/extract_ICC_site.Rd`
- `man/extract_ordination.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Commands run and outcomes

Question answered during this checkpoint:

- User asked whether all coevolution model stuff is finished.
- Answer: no. The current local implementation/calibration stop point is reached, but Paper 2 coevolution is not complete.

Paper 2 note read:

- `/Users/z3437171/.codex/attachments/93d6ad50-4129-4147-938c-6b1dd92c7be9/pasted-text.txt`
- Key implication: the paper/model still needs the estimand freeze, kernel definition/residualization decision, empirical separability/identifiability simulations, coevolutionary module outputs, interval/uncertainty, mechanistic validation, and empirical data/trait audit before any "finished coevolution model" claim.

Pre-edit lane check before shared-file edits:

- `gh pr list --state open`
  - Only draft PR #489 observed.
- `git log --all --oneline --since='6 hours ago'`
  - Current coevolution / mission-control stack observed.
- `git diff --check`
  - Clean before edits.

Current slice verification:

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Regenerated changed Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "extractors|extract-communality|profile-derived|profile-ci|confint-derived", reporter = "summary")'`
  - First rerun exposed dangling formula `+` operators after removing explicit `unique()` lines.
- `Rscript --vanilla -e 'devtools::test(filter = "extractors|extract-communality|profile-derived|profile-ci|confint-derived", reporter = "summary")'`
  - Passed after fixes; expected heavy skips remained.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|unique-family-deprecation|extractors|extract-communality", reporter = "summary")'`
  - Passed with expected heavy skips and informational per-row diagonal `sigma_eps` messages.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found.`
- Rd spot checks:
  - `man/extract_communality.Rd`: keyword count 0.
  - `man/extract_ICC_site.Rd`: keyword count 1, expected internal keyword.
  - `man/extract_ordination.Rd`: keyword count 0.
  - `man/traits.Rd`: keyword count 0.
- Focused stale scans:
  - Old add-unique/no-unique/latent-only communality guidance removed from touched README/R/test/Rd surface.
  - Remaining `unique(1 | individual)` hits are intentional `traits()` compatibility documentation.
- Dashboard checks:
  - `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check` passed.
  - `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/` completed.
  - `curl http://127.0.0.1:8770/status.json` confirmed 17:49 timestamp and README/communality note.
  - `curl http://127.0.0.1:8770/sweep.json` confirmed README/communality alignment entry.

## What changed in the current slice

- README smoke-test and Tiny examples now use ordinary `latent()` alone for the full Gaussian decomposition.
- README explains ordinary `latent()` carries `Psi` by default and `latent(..., residual = FALSE)` is the no-Psi subset.
- `traits()` docs now teach `latent(1 | individual, d = K)` as primary wide shorthand while retaining `unique(1 | individual)` as compatibility syntax.
- `extract_communality()`, `extract_ICC_site()`, `profile_ci_communality()`, and `profile_communality()` no longer frame ordinary users around adding explicit `unique()`.
- Extractor tests that only needed diagonal/Psi structure now use `indep()` or default `latent()` instead of deprecated ordinary `unique()`.

## Coevolution guard state

Local coevolution implementation/calibration progress is substantial:

- Fixed named multi-kernel latent-only path exists locally.
- COE-04 has near-orthogonal recovery, moderate-overlap promoted cells, high-overlap collapse/failure calibration, fixed-rho profile/sensitivity, pair-specific covariance extraction, narrow Poisson recovery cells, and diagnostics.

But the full Paper 2 coevolution model is not finished:

- Kernel definition/residualization decision remains open.
- Kernel separability/identifiability is not closed.
- `rho` is profiled/fixed, not estimated with intervals.
- Interval calibration and module-level uncertainty are not closed.
- Mechanistic biological validation is not done.
- Empirical DoPI/trait audit and nested model sequence are not done.
- The paper-level estimand/module framing has not yet been frozen into a design note.

Preserve: `PR green != bridge complete != release ready != scientific coverage passed`.

## Next safest action

Given the user's Paper 2 note, the next coevolution-facing action should be a design checkpoint, not another code gate:

1. Create or update a compact design/audit note that freezes the Paper 2 estimands:
   `Gamma_phy`, `Gamma_tip`, global cross-lineage covariance, and coevolutionary modules.
2. Add a decision table mapping current implementation evidence to the note's Stages 1-7.
3. Only then choose the next code gate: kernel residualization/separability, module extractor, or interval/calibration.

For the `unique()` lane, continue one slice at a time through remaining public examples and exported docs. Do not expand `kernel_unique()` for Paper 2 multi-kernel coevolution.
