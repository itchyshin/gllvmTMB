# Codex handover: response-column slope family

**Date:** 2026-08-24
**Branch:** `codex/column-slope-family`
**Verified implementation SHA:** `2ad0238aa5bc16df6961d776e35d885823709fa6`
**Worktree:** `/Users/z3437171/.codex/worktrees/0733/gllvmTMB`
**PR:** [#1208](https://github.com/itchyshin/gllvmTMB/pull/1208) — open and unmerged
**Live remote base:** `main` at `872ae85672d54896882c5678db52eb6b5e44d71b`
**Tree identity receipt:** live `main` and local starting commit `e47ca88c93f675ecca53dd9c361fffb539c3718d` both have tree `e93e8f54bd3af8f40a08e134af76d53584fe9100`.

## First read

1. `docs/design/130-response-column-slope-family.md`
2. `docs/dev-log/after-task/2026-08-24-response-column-slope-family.md`
3. the final entry in `docs/dev-log/check-log.md`
4. `.unlazy/column-slope-family/GATES.md` in this worktree (ignored, local acceptance ledger)

## Landing State

**CLOSED FOR REVIEW:** the documented five-commit series was cleanly replayed
onto `origin/main` because the old and new base trees were identical. The
rebased branch was force-pushed with a lease and is PR #1208. The explicitly
dispatched full matrix is terminal green on macOS, Ubuntu, and Windows. The PR
is deliberately open and unmerged for maintainer review.

## DONE

- Implemented the Gaussian long-format response-column slope helper family:
  `slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, and
  `spatial_slope()`.
- Locked the public meaning: `*_slope()` always means predictor coefficients
  varying across response columns. It is never the teaching spelling for
  row-wise random regression.
- Implemented diagonal `||` and full `|` predictor covariance, labelled source
  alignment, term-local ordinary identity slopes, named extraction, and exact
  SPDE-projected response-column correlation.
- Preserved historical one-predictor phylogenetic/animal fits and existing
  observation-space spatial random slopes.
- Corrected the visual bridge article: the comparative example now uses
  `slope(elevation | trait)` plus a separate
  `phylo_latent(0 + trait | species, ...)`; the community example uses
  `phylo_slope(... | trait)` because species are response columns there.
- Added matrix, malformed-input, permutation, one-predictor parity, Gaussian
  recovery, combined axis-separation recovery, article, and visual evidence.
- Final local evidence: 16,608 pass / 0 fail / 76 expected warnings / 879
  explicit skips; source-current article build and pkgdown PASS; package check
  0 errors / 0 warnings / 4 pre-existing or environmental notes.
- Commits already present:
  - `aae16f41` — design contract
  - `d4e149a9` — fixed-source helper core
  - `8a0766a8` — complete family, spatial source, recovery, and article
  - `eae053fb` — isolated-path recovery-harness portability
- Rebased commit series published at `2ad0238a`; its remote ref equals the
  local checked-out head.
- PR #1208 was opened against `main` using this task's after-task report as
  its body. It remains open and unmerged at the verified head.
- Explicit three-OS CI run
  [32790567062](https://github.com/itchyshin/gllvmTMB/actions/runs/32790567062)
  passed on macOS (2026-08-25 00:08 UTC), Ubuntu (00:22 UTC), and Windows
  (00:24 UTC). The manual full matrix was required because routine PR CI is
  Ubuntu-only.

## OWED

- Obtain maintainer review for PR #1208. Do not self-merge it.
- After an authorised merge, verify the post-merge CI run and deployed articles
  before declaring the public site updated. Those are merge-stage obligations,
  not prerequisites for this PR closure.

## RETRACTED

- Retract `phylo_slope(elevation | species, tree = tree)` from the comparative
  article. It fit through compatibility behavior but taught the wrong axis.
- Retract the idea that a covariance term such as `dep()` or `latent()` makes
  response-column random slopes unnecessary. It models response covariance,
  not predictor-specific column deviations.
- Retract the idea that `*_indep(0 + ...)` should be the only public teaching
  surface. It remains valid underlying machinery; `*_slope()` names the user
  task.

## PROTECTED

- Existing one-predictor phylogenetic/animal objectives, parameter names,
  maps, and extraction remain unchanged.
- Existing wide workflows remain supported, but new wide column-slope grammar
  is deferred rather than guessed.
- Non-Gaussian/mixed multi-predictor slopes, latent predictor covariance,
  simultaneous response-column sources, and intervals are not advertised.
- A tree/pedigree/space/kernel supplied to `*_slope()` relates response columns;
  a relationship among row-wise species belongs in a separate row-level term.
- No Totoro/DRAC campaign and no GitHub Actions compute campaign was run.

## Resume

Review [PR #1208](https://github.com/itchyshin/gllvmTMB/pull/1208) at head
`2ad0238a`. Preserve the stated API and deferred boundaries. Do not merge from
this lane; after an authorised merge, verify the post-merge check and deployed
article before closing the release-stage gate.
