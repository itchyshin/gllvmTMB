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

## Collaboration Rhythm

Claude Code and Codex can work in parallel only when the write scopes
are separate and the handoff is explicit. The default pattern is:

- Claude Code gathers evidence, writes read-only audits, drafts
  decisions, and identifies the smallest safe PR shape.
- The maintainer chooses the next task at a discussion checkpoint.
- Codex implements bounded code, documentation, CI, pkgdown, or
  NAMESPACE changes and records checks.
- Claude Code or Codex can review the result, but the reviewer should
  not silently expand the implementation scope.

Stop for maintainer discussion before deletions, API changes, formula
grammar changes, likelihood changes, new families, or broad article
rewrites. For the current reader-path work, examples should present
long-format and wide-format calls together unless the function is
intrinsically one shape.

After-task reports are the closure rule. Any completed task or phase
that changes project state should leave
`docs/dev-log/after-task/YYYY-MM-DD-short-topic.md` with scope,
outcome, checks, and follow-up. This mirrors the `drmTMB` team habit
and is how the shared team learns without re-reading the whole diff.

Use Shannon before handoffs with branch switches, merge-order
questions, or more than one open coordination PR. Shannon is a
read-only cross-team audit: it checks working-tree hygiene, open PRs,
file overlap, CI state, message-bus coverage, and after-task report
coverage. Shannon reports; it does not edit or merge.

### Merge authority

Both Claude Code and Codex may merge their own PRs when CI is green
and the PR is **low-risk**: documentation, dev-log entries, audits,
after-task reports, design docs, CI workflow tweaks, asset additions,
or individual article rewrites against an approved snippet. For
**high-risk** changes -- deletions of public exports, API changes,
formula-grammar changes, likelihood / TMB / family changes, broad
article rewrites -- the agent must ask the maintainer before merging.
The `ROADMAP.md` "Discussion Checkpoints" list is the authoritative
high-risk set; the merge rule mirrors it.

### Integrate before adding

When the maintainer's input could fit an existing section in a doc or
plan file, integrate inline. Add a new section only for genuinely new
concerns. Reactive editing (every input becomes a new section) accretes
documents without improving them.

### Agent-to-agent handoffs go in the repo

When handing off a substantive task to the other agent, post a comment
addressed to them on the relevant PR, OR a directed line in
`docs/dev-log/check-log.md`. The async message bus is the repo; the
maintainer should not be the relay.

### Surface review asks explicitly

When opening a PR for maintainer review, follow up in chat with a
specific list of what the maintainer needs to check or decide. Do not
leave review items for the maintainer to discover by browsing the PR.

## Reusing sdmTMB / drmTMB Code

The R-side spatial helpers (`R/mesh.R`, `R/crs.R`, `R/plot.R`'s
`plot_anisotropy*`) are inherited from sdmTMB; `inst/COPYRIGHTS`
records the provenance and DESCRIPTION's `Authors@R` credits Sean
Anderson, Eric Ward, Philina English, and Lewis Barnett.

Selective reuse of A-inverse phylogenetic or further SPDE speed
modules from sister packages requires provenance notes in
`inst/COPYRIGHTS` and tests around the ported behaviour.
