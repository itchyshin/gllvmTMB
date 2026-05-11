# After-Task Report: Roadmap And Collaboration Rules

Date: 2026-05-11

## Scope

This documentation-only task records how humans, Codex, and Claude
Code should coordinate the next `gllvmTMB` phase. It also moves the
long-format plus wide-format teaching rule into the active roadmap so
future examples do not treat wide input as an afterthought.

Changed files:

- `ROADMAP.md`
- `CLAUDE.md`
- `AGENTS.md`
- `docs/dev-log/claude-group-handoff-2026-05-11.md`
- `docs/dev-log/decisions.md`
- `docs/dev-log/check-log.md`

## Outcome

The roadmap now prioritises:

1. reader path stability, including paired long/wide examples;
2. public-surface cleanup from the Priority 2 audit;
3. unified data-shape and weights semantics across `gllvmTMB()`,
   `gllvmTMB_wide()`, and `traits(...)`;
4. feedback-time improvements after the public face is stable;
5. CRAN readiness, methods-paper support, and later model extensions.

The collaboration instructions now say that Claude Code should usually
propose from audits and Codex should usually implement bounded changes
after the maintainer chooses the next PR shape. Both can review, but
implementation stops before deletions, API changes, formula-grammar
changes, likelihood changes, new families, or broad article rewrites.

The instructions also make the `drmTMB` after-task habit explicit:
completed tasks and phases should leave a short after-task report with
scope, outcome, checks, and follow-up. This report is the first
application of that rule in the current roadmap/collaboration pass.

## Verification

This task did not change R code, generated Rd files, likelihoods,
formula grammar, NAMESPACE, or pkgdown navigation. I refreshed the
GitHub PR list before editing and confirmed that the active Claude
and Codex PRs touched different file scopes.

No package checks were run because this is a project-instruction and
roadmap update only.

## Follow-Up

The next maintainer decision is which near-term PR to do first:

- article rewrite for long/wide examples and legacy helper removal;
- public-surface cleanup based on the Priority 2 audit;
- data-shape and weights contract tests for long versus wide inputs.
