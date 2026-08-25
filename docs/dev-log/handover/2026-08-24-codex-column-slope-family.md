# Codex handover: response-column slope family

**Date:** 2026-08-25 (closure refresh)
**Branch:** `codex/column-slope-family`
**Feature and article SHA before this handover-only refresh:** `fa58e05477258ecb35247a74008c0f62e34eccc3`
**Publishing checkout:** `/private/tmp/gllvmTMB-article-final`
**PR:** [#1208](https://github.com/itchyshin/gllvmTMB/pull/1208)
**Rebased remote base:** `main` at `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`

## First read

1. `docs/design/130-response-column-slope-family.md`
2. `docs/dev-log/after-task/2026-08-24-response-column-slope-family.md`
3. the final entry in `docs/dev-log/check-log.md`
4. `.unlazy/column-slope-family/GATES.md` in this worktree (ignored, local acceptance ledger)

## Landing State

**MERGE AUTHORISED; FINAL PUBLICATION GATES APPLY:** the slope implementation
was cleanly replayed onto `origin/main`, then the reader article was rewritten
and visually checked in the same PR. The maintainer subsequently authorised
merging PR #1208. Merge only from the exact tested branch head after routine PR
CI and an explicitly dispatched macOS, Ubuntu, and Windows matrix are terminal
green. After merge, verify the `main` check and the live pkgdown article before
declaring this lane closed. The PR, Actions run, and deployed page are the
authoritative time-varying closure receipts; this file records the durable
scope and procedure because a file cannot name the SHA of the commit that
contains it.

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
- Rebuilt the Tier-1 article, *Where does the phylogeny belong?*, around two
  contrasting plant examples: species as sampled units with morphology as
  response columns, and species as community response columns. It now includes
  readable model-axis diagrams plus long- and wide-data visuals for both
  examples. The article teaches `slope()` for the first axis and
  `phylo_slope()` for the second, without an integrated-model detour.
- Reworked the 5 × 3 keyword-grid article and its responsive styling so the
  live keyword table remains legible rather than clipping or mis-rendering.
- Added matrix, malformed-input, permutation, one-predictor parity, Gaussian
  recovery, combined axis-separation recovery, article, and visual evidence.
- Final local evidence: 16,608 pass / 0 fail / 76 expected warnings / 879
  explicit skips; source-current article build and pkgdown PASS; package check
  0 errors / 0 warnings / 4 pre-existing or environmental notes.
- Rebased commits already present:
  - `3a125c41` — design contract
  - `235c32a8` — fixed-source helper core
  - `7d38ce2f` — complete family, spatial source, recovery, and article
  - `c150f7cd` — isolated-path recovery-harness portability
  - `c4488499` — programme closure documents
  - `5bb6555e` — reader-first tree-axis and 5 × 3 grid rewrite
  - `fa58e054` — long- and wide-data article figures
- Rebased implementation series plus the two reader-first article commits were
  published through `fa58e054` before this handover-only refresh.
- PR #1208 was opened against `main` using this task's after-task report as
  its body.
- Explicit three-OS CI run
  [32790567062](https://github.com/itchyshin/gllvmTMB/actions/runs/32790567062)
  passed on macOS (2026-08-25 00:08 UTC), Ubuntu (00:22 UTC), and Windows
  (00:24 UTC). The manual full matrix was required because routine PR CI is
  Ubuntu-only.
- After the article additions, routine Ubuntu PR run
  [32852625158](https://github.com/itchyshin/gllvmTMB/actions/runs/32852625158)
  passed at `fa58e054`. Its first attempt was cancelled after a confirmed
  checkout-infrastructure stall; the single retry completed the package check.

## OWED AT THIS HANDOVER REFRESH

- Let the active explicit three-OS run finish before pushing this handover-only
  commit, then run routine PR CI and one final exact-head macOS, Ubuntu, and
  Windows matrix. Do not overlap pushes with active runs.
- Merge PR #1208 only when those exact-head checks are terminal green and the
  PR remains mergeable. The maintainer has authorised the repository-default
  merge and normal remote-branch cleanup.
- Verify the post-merge `main` check, pkgdown deployment, and the live article
  at <https://itchyshin.github.io/gllvmTMB/articles/where-does-the-tree-go.html>.
- Do not enter the random-slope health or any other main-lane follow-up; the
  maintainer owns what comes next there.

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

Close [PR #1208](https://github.com/itchyshin/gllvmTMB/pull/1208) only through
the exact-head gate above. Preserve the stated API and deferred boundaries.
After merge, verify the post-merge check and deployed article, then close this
lane without starting the separate main-lane follow-up.
