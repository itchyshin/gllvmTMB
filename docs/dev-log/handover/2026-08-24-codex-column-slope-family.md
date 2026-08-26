# Codex handover: response-column slope family

**Date:** 2026-08-25 (post-merge semantic-article closure)
**Implementation branch:** `codex/column-slope-family` (merged)
**Documentation follow-up branch:** `codex/column-slope-visual-closure`
**Feature head:** `52fb00ff7d69ab2b96b99fefb8a9434ecd5b304e`
**Merge commit:** `efc4cffc02f3804222f304c22aceb2084e8a47e8`
**Publishing checkout:** `/private/tmp/gllvmTMB-article-final`
**PR:** [#1208](https://github.com/itchyshin/gllvmTMB/pull/1208)
**Live article:** <https://itchyshin.github.io/gllvmTMB/articles/where-does-the-tree-go.html>

## First read

1. `docs/design/130-response-column-slope-family.md`
2. `docs/dev-log/after-task/2026-08-24-response-column-slope-family.md`
3. the final entry in `docs/dev-log/check-log.md`
4. `.unlazy/column-slope-family/GATES.md` in this worktree (ignored, local acceptance ledger)
5. `docs/dev-log/after-task/2026-08-25-column-slope-postmerge-visual-closure.md`

## Landing State

PR #1208 is merged. Its exact feature head passed macOS, Ubuntu, and Windows;
the post-merge `main` check and pkgdown deployment also passed. A focused
post-merge article correction is being published from the documentation branch
above. It changes no R API, formula grammar, likelihood, TMB code, or existing
fit. Its only purpose is to make the public worked example teach the shipped
model correctly.

Authoritative receipts are the exact feature-head three-OS run
[32877165018](https://github.com/itchyshin/gllvmTMB/actions/runs/32877165018),
post-merge `main` run
[32883168239](https://github.com/itchyshin/gllvmTMB/actions/runs/32883168239),
and pkgdown deployment
[32887954319](https://github.com/itchyshin/gllvmTMB/actions/runs/32887954319).

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
  response columns, and species as community response columns. It includes
  readable long- and wide-data visuals for both examples.
- Corrected the community example after the post-merge reader audit. The
  response is Gaussian log-biomass intensity; `latitude:pathway` estimates C3
  and C4 mean gradients; `phylo_slope(latitude | trait)` estimates
  phylogenetically structured residual species slope deviations; and
  `latent(0 + trait | site_id, d = 2, unique = FALSE)` adjusts for remaining
  within-site species association.
- Made the simulation/data construction visible and hid plotting mechanics,
  printed the descriptive C4-minus-C3 fitted contrast, labelled planted figure
  lines as simulated-by-design, and added a verifier that refuses the
  superseded moisture/canopy teaching story.
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

- Publish the focused article/verifier/handover follow-up as one PR.
- Wait for its routine PR check. Do not repeat the completed full local
  implementation campaign unless CI exposes a relevant failure.
- Merge only when the follow-up PR is green and mergeable, then verify the
  `main` check, pkgdown deployment, and the live article text and figures.
- Do not enter the random-slope health, future intercept-plus-slope API design,
  or any other main-lane follow-up.

## RETRACTED

- Retract `phylo_slope(elevation | species, tree = tree)` from the comparative
  article. It fit through compatibility behavior but taught the wrong axis.
- Retract the idea that a covariance term such as `dep()` or `latent()` makes
  response-column random slopes unnecessary. It models response covariance,
  not predictor-specific column deviations.
- Retract the idea that `*_indep(0 + ...)` should be the only public teaching
  surface. It remains valid underlying machinery; `*_slope()` names the user
  task.
- Retract the moisture/canopy story as the primary response-column example.
  It was algebraically valid but did not answer the reader's column-metadata
  question.
- Retract any wording that puts `pathway` inside `phylo_slope()`. `pathway` is
  response-column metadata and belongs in a fixed fourth-corner interaction
  such as `latitude:pathway`.
- Retract the claim that site rows remain independent in the community
  example; the ordinary `latent(... | site_id)` term models remaining joint
  species association.
- Retract any implication that `0 + trait` supplies phylogenetically
  correlated random intercepts. It supplies separate fixed species
  intercepts.

## PROTECTED

- Existing one-predictor phylogenetic/animal objectives, parameter names,
  maps, and extraction remain unchanged.
- Existing wide workflows remain supported, but new wide column-slope grammar
  is deferred rather than guessed.
- The current API has no `column_coef()` helper. The article uses ordinary
  formula terms for fixed response-column metadata and reserves `*_slope()`
  for random response-column slope deviations. A future `column_coef()` is a
  candidate ordinary-IID random-coefficient block, but needs a separate grammar
  and identifiability design before it is advertised.
- Non-Gaussian/mixed multi-predictor slopes, latent predictor covariance,
  simultaneous response-column sources, and intervals are not advertised.
- A tree/pedigree/space/kernel supplied to `*_slope()` relates response columns;
  a relationship among row-wise species belongs in a separate row-level term.
- `phylo_slope()` uses the supplied tree covariance directly. It does not
  estimate the IID-versus-phylogenetic mixture used by gllvm's signal model;
  that belongs to a future coefficient-block design.
- A future response-column intercept-plus-slope coefficient block is a
  separate design lane. It must not widen or rename `*_slope()` during this
  closure.
- No Totoro/DRAC campaign and no GitHub Actions compute campaign was run.

## Resume

From `/private/tmp/gllvmTMB-article-final`, inspect `git status --short`, run
`Rscript --vanilla dev/trait-axis-bridge/verify-article.R`, then continue the
single documentation PR through CI, merge, and live pkgdown verification.
Preserve the stated API and deferred boundaries and do not start the separate
intercept-plus-slope design in this lane.
