# Codex handover — Traits along gradients bridge article

You are Codex, continuing the `gllvmTMB` visual documentation lane. Read
`AGENTS.md`, the multi-lane map
`docs/dev-log/handover/2026-07-25-active-lane-split.md`, this handover, and
`docs/dev-log/after-task/2026-08-24-trait-axis-bridge-article.md`. Do not
replace the lane-map pointer in `AGENTS.md`: multiple independent lanes are
live.

## Critical context

This is a documentation/fixture PR, not an API or likelihood change. Its job
is to let an ecology graduate student see, before reading a formula, whether a
tree relates comparative species units, Gaussian species response columns, or
neither. The public article title is **Traits along gradients: where does the
tree go?**; the repeated teaching question inside it is “What does the tree
relate?”

The only covered multi-predictor column-slope example is Gaussian and
long-format:

```r
phylo_slope(elevation + forest_cover | trait, tree = tree)
```

It has no random intercept. iSDM sources specify source-masked observation
models; they do not identify abundance, occupancy, or detectability.

## Goals and plan

The article/fixture bridge is the completed high-leverage slice. Do not widen
this lane into morphology-versus-life-history slope covariance blocks, wide
column-predictor grammar, spatial/kernel/latent slope-only variants, or
non-Gaussian multi-predictor slopes. Those remain separate design or evidence
arcs.

## What was accomplished

- Added a seeded 48-species montane-bird fixture with comparative,
  response-column, and source-observation data.
- Added executable source-current gates for the two fitted Gaussian formulas
  and ordinary iSDM survey syntax.
- Added a Tier-1 article with four rendered, visually inspected figures:
  decision map, comparative trajectories, community slopes/covariance, and
  three source observation models.
- Added Model Guides navigation.
- Corrected two real first-render defects: cramped diagrams and mixed raw
  measurement scales in the comparative figure.
- CI run `32730224105` for commit `8acc8a7b` passed Ubuntu R-CMD-check.

## Current working state

- **Working:** `codex/trait-axis-bridge` at committed, pushed
  `8acc8a7b` with draft PR [#1206](https://github.com/itchyshin/gllvmTMB/pull/1206).
- **In progress:** public-title correction and this handover are intentionally
  uncommitted at this snapshot. Re-render, commit, push once, then wait for
  the new PR-head CI before marking the PR ready.
- **Blocked:** no technical blocker. `handoff_gate.sh` reports unrelated
  unpushed branches elsewhere in the shared repository; this lane's commit is
  pushed and has the declared PR.

## Key decisions and rationale

1. The PCM article uses
   `phylo_indep(0 + trait | species, tree = tree) + phylo_slope(elevation |
   species, tree = tree)`, not the initially proposed large augmented term.
   The large term is parser-valid but estimates four separate
   intercept--slope covariance blocks and gave `nlminb` false convergence on
   the fixture. The selected formula converged cleanly and matches the stated
   shared species-slope story.
2. Comparative figure values are standardised within response column. Raw body
   mass, bill length, clutch size, and laying date are not comparable on one
   shared y-scale.
3. The source declaration is ordinary `~ observer + method`; do not resurrect
   a survey `0 +` workaround.
4. The article must be rendered after `devtools::load_all()`; a successful
   render against an old installed package is not evidence for the branch.

## Files created or modified

| Path | Purpose |
|---|---|
| `data-raw/examples/make-trait-axis-bridge.R` | deterministic fixture generator |
| `inst/extdata/examples/trait-axis-bridge.rds` | installed fixture |
| `dev/trait-axis-bridge/verify-formulas.R` | PCM, column-slope, iSDM gates |
| `dev/trait-axis-bridge/verify-article.R` | source-current render/navigation/pkgdown gate |
| `dev/trait-axis-bridge/verify-scope.R` | reader-boundary scan |
| `vignettes/articles/where-does-the-tree-go.Rmd` | Tier-1 bridge article and four figures |
| `_pkgdown.yml` | Model Guides entry |
| `docs/dev-log/check-log.md` | check receipt |
| `docs/dev-log/after-task/2026-08-24-trait-axis-bridge-article.md` | after-task report |
| `docs/dev-log/handover/2026-08-24-codex-trait-axis-bridge-handover.md` | this durable handover |

## Landing state

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `codex/trait-axis-bridge` `8acc8a7b` article/fixture | yes | yes | #1206 draft | CARRIED-OVER: PR awaits its final title/handover commit and corresponding CI |
| title correction + this handover | no | no | #1206 target | CARRIED-OVER: commit and push as the next atomic docs closeout |

## Classification

- **DONE:** reproducible fixture; four publication-quality rendered figures;
  source-current smoke gates; visual and reader-path review; targeted
  regression test; article render and `pkgdown::check_pkgdown()`; first PR CI.
- **OWED:** commit the title correction and this handover; push once; wait for
  the new PR head to be green; mark #1206 ready for review; do not merge.
- **RETRACTED:** a compulsory survey `0 +` formula; interpreting source labels
  as a phylogenetic axis; an unsupported non-Gaussian multi-predictor slope
  claim; teaching the unstable rich PCM formula as the beginner path.
- **PROTECTED:** current one-predictor helper behavior; existing wide syntax;
  no random intercept in the column-slope term; the Gaussian-only and
  relative-intensity boundaries; foreign lanes and their working files.

## Next immediate steps

1. Run `Rscript --vanilla dev/trait-axis-bridge/verify-article.R` after the
   title correction. It should print `ARTICLE BUILD PASS`.
2. Run `Rscript --vanilla dev/trait-axis-bridge/verify-scope.R` and
   `git diff --check`.
3. Stage only `_pkgdown.yml`, the article, and this handover; commit them on
   `codex/trait-axis-bridge`, then push once.
4. Wait for the resulting PR #1206 R-CMD-check. If green, use `gh pr ready
   1206`; do not merge. If red, inspect the failed logs and make only a
   scoped repair.
5. Release the `gllvmTMB` lane lease after the PR is ready. The user/human
   remains the merger.

## Mission-control receipt

| Repo | Branch / PR | CI | What shipped | Next highest-leverage action |
|---|---|---|---|---|
| gllvmTMB | `codex/trait-axis-bridge`, #1206 | first run green; final docs commit owed | visual tree-axis bridge article and fixture | final commit, one CI receipt, publish PR |

## How to resume

From the isolated worktree root, start Codex and paste:

```text
Rehydrate from docs/dev-log/handover/2026-08-24-codex-trait-axis-bridge-handover.md + the AGENTS.md snapshot, reconcile against git and PR #1206, then continue only the OWED steps.
```

Codex owns live R/TMB fits, checks, simulations, and article rendering. Before
editing, run `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"`; preserve
the current multi-lane map and never stage another lane's work.
