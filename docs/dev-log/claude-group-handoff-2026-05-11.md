# Claude Group Handoff -- gllvmTMB

Date: 2026-05-11

This handoff is for Claude Code agents joining the current
`gllvmTMB` work after the CI, site, and team repair.

## Read First

Read these files in order:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `.agents/skills/rose-pre-publish-audit/SKILL.md`
4. `CONTRIBUTING.md`
5. `docs/dev-log/after-task/2026-05-11-ci-site-team-repair.md`
6. `docs/dev-log/check-log.md`
7. `docs/dev-log/decisions.md`
8. `ROADMAP.md`

The short active plan is also in:

```text
~/.claude/plans/please-have-a-robust-elephant.md
```

## What Changed

The project has just been reset around three practical rules:

1. **CI discipline before CI speed.** `R-CMD-check` remains the full
   3-OS gate for PRs and `main`. `pkgdown` now runs after a successful
   `R-CMD-check` on `main` / `master`, not in parallel.
2. **Reader-first public site.** `README.md` is the homepage source
   and now starts with purpose, Start here, preview status, install,
   a tiny smoke test, current supported workflows, boundaries, and
   sister packages. The 3 x 5 keyword grid is still central, but no
   longer the first thing a new user sees.
3. **Rose is a narrow pre-publish gate.** Rose checks public
   consistency for README, vignettes, `_pkgdown.yml`, NEWS, exported
   roxygen, and generated Rd changes. Rose is not a broad rewrite
   agent and not a replacement for syntax/math/TMB reviewers.

## Current Priorities

Use `ROADMAP.md` as the shared map. The near-term order is:

1. **Finish feedback verification.**
   - Confirm the post-merge `main` `R-CMD-check` completes.
   - Confirm pkgdown starts only after that green `R-CMD-check`, not
     in parallel.

2. **Stabilise the reader path.**
   - Public examples should show long-format and wide-format calls
     together: canonical long input plus the equivalent
     `gllvmTMB_wide()` or `traits(...)` call.
   - Rewrite articles that still depend on legacy helper names before
     those helpers are removed.

3. **Stabilise the public surface.**
   - Use the Priority 2 export audit as input.
   - Keep only functions that belong in the fresh package.
   - Do not preserve legacy functions just because legacy tests call
     them by bare name.

4. **Unify the data-shape and weights contract.**
   - Make `gllvmTMB()`, `gllvmTMB_wide()`, and `traits(...)` agree on
     weights, trait ordering, reshaping, and error messages.
   - Add paired long/wide tests for accepted and rejected shapes.

5. **Only then add new modelling features.**
   - New families, grammar, likelihoods, tiers, or structured effects
     require design-doc updates, simulation recovery, examples, and
     the appropriate reviewer roles.

## What Not To Do

- Do not add fast-lane / slow-lane CI yet. That is backlog work.
- Do not create per-role skill files for every reviewer. More static
  context is not the fix.
- Do not start new model features before the feedback loop, reference
  index, and public surface are stable.
- Do not treat pkgdown as a parallel substitute for R-CMD-check.
- Do not broaden `gllvmTMB` into single-response modelling. Use
  `glmmTMB` for single-response GLMMs, `sdmTMB` for spatial
  single-response models, and `drmTMB` for one- or two-response
  distributional regression.

## Role Dispatch

Keep dispatch narrow:

- **Grace**: CI, pkgdown, CRAN, dependencies, platform risk.
- **Rose**: cross-file consistency, stale claims, repeated process
  failures, missing feedback loops.
- **Pat / Darwin**: applied-user reading path, examples, biological
  interpretation.
- **Boole**: R API and formula grammar.
- **Gauss**: TMB likelihoods, transforms, numerical stability.
- **Noether**: symbolic equations, R syntax, and TMB implementation
  alignment.
- **Curie**: simulation recovery and test coverage.
- **Emmy**: R package architecture and S3/API structure.

If the task does not touch a role's domain, do not invoke that role.

## Required Checks By Change Type

For public prose or reference navigation:

```r
pkgdown::check_pkgdown()
```

For README, Get Started, or article changes:

```r
pkgdown::build_home(preview = FALSE)
pkgdown::build_article("gllvmTMB", quiet = TRUE)
```

For parser-facing tutorial or article changes:

```r
pkgdown::build_articles(lazy = FALSE)
```

For roxygen changes:

```r
devtools::document(quiet = TRUE)
pkgdown::check_pkgdown()
```

For R behavior changes:

```r
devtools::test()
```

For likelihood, formula-grammar, family, or structured-effect changes:

```r
devtools::test()
devtools::check(args = "--no-manual", quiet = TRUE)
```

## Pre-Publish Rose Sweep

Before merging any PR that touches README, vignettes, `_pkgdown.yml`,
NEWS, exported roxygen, or generated Rd files, run the Rose
pre-publish audit.

Minimum grep set:

```sh
rg -n "method *=|default|fisher-z|profile|wald|bootstrap" R README.md vignettes man
rg -n "latent|unique|indep|dep|phylo_|spatial_|meta_known_V|trio" README.md vignettes docs R man
rg -n "unit_obs|unit =|trait =|cluster =|tier =|level =" README.md vignettes R man
```

The audit should return `PASS`, `WARN`, or `FAIL`. A fail blocks the
merge until public prose, generated docs, pkgdown navigation, and
source defaults agree.

## Handoff Rule

When passing work to the next agent, leave enough context in one of:

- `docs/dev-log/check-log.md`
- `docs/dev-log/decisions.md`
- `docs/dev-log/after-task/`
- the relevant issue or PR

Do not make the next Claude agent rediscover why a decision was made.
For completed tasks or phases, prefer an after-task report under
`docs/dev-log/after-task/` over a long chat summary. The report should
state scope, outcome, checks, and follow-up.

## Discussion Checkpoints

Parallel work is useful for audits and reviews, but implementation
should stop for maintainer discussion at these points:

- after a read-only audit proposes deletions, API changes, or grammar
  changes;
- before a PR touches NAMESPACE, formula parsing, likelihood code, or
  family support;
- before merging while related CI is still running;
- after a phase completes, so the maintainer can re-rank the next
  roadmap item.

For current work, Claude Code should propose and document narrow tasks
from audits. Codex should implement bounded changes after the
maintainer chooses the next PR shape.
