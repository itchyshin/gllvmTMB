# Claude Code Instructions for gllvmTMB

This repository is shared by humans, Codex, and Claude Code. Read
`AGENTS.md` first; it is the source of truth for project rules.
For the current Claude handoff, also read
`docs/dev-log/claude-group-handoff-2026-05-11.md` before starting new
work.

## Project Identity

`gllvmTMB` is a sister package to `drmTMB`, but it has a different
role:

- `drmTMB`: univariate and bivariate distributional regression.
- `gllvmTMB`: multivariate stacked-trait GLLVMs with phylogenetic
  and spatial extensions.

Keep `gllvmTMB` focused on the stacked-trait, long-format multi-
response model. Single-response models live in `glmmTMB`; spatial
single-response models live in `sdmTMB`.

## Syntax Rules to Preserve

- Use the canonical 3 x 5 keyword grid (correlation x mode):
  `latent`, `unique`, `indep`, `dep`, `scalar`, with `phylo_*` and
  `spatial_*` variants.
- The decomposition mode is the `latent + unique` pair:
  Sigma = Lambda Lambda^T + diag(s).
- `phylo_latent + phylo_unique` is the canonical phylogenetic
  decomposition; the standalone `phylo_unique` carries
  intra-phylogeny diagonal-only structure.
- `meta_known_V(V = V)` is the meta-analytic known-sampling-covariance
  keyword. `block_V(study, sampling_var, rho_within)` is the helper
  that builds V.
- The wide-format entry is `gllvmTMB_wide()` with `traits()` as the
  LHS marker. Long-format is the canonical input; wide is
  re-shaped under the hood.

## Before Finishing Work

- Run the narrow tests you touched, then `devtools::test()` more
  broadly when practical.
- Update design docs if grammar, likelihoods, families, random
  effects, phylogenetic, spatial, or meta-analysis behaviour
  changes.
- Add or update an after-task report in `docs/dev-log/after-task/`.
- For substantial prose, apply the `prose-style-review` skill.
- Do not revert Codex or human changes unless explicitly asked.

## Reusing sdmTMB / drmTMB Code

The R-side spatial helpers (`R/mesh.R`, `R/crs.R`, `R/plot.R`'s
`plot_anisotropy*`) are inherited from sdmTMB; `inst/COPYRIGHTS`
records the provenance and DESCRIPTION's `Authors@R` credits Sean
Anderson, Eric Ward, Philina English, and Lewis Barnett.

Selective reuse of A-inverse phylogenetic or further SPDE speed
modules from sister packages requires provenance notes in
`inst/COPYRIGHTS` and tests around the ported behaviour.
