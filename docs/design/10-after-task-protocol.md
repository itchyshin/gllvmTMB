# After-Task Protocol

Every meaningful task or phase should leave a compact Markdown
report. The report is part of the project memory and should make
later Codex, Claude Code, and human review easier.

Use the project-local `after-task-audit` skill before closing the
task. That skill is the operational checklist; this document is the
stable design note.

## Location

Task reports live in:

```text
docs/dev-log/after-task/
```

Phase reports live in:

```text
docs/dev-log/after-phase/
```

## Required Sections

Each report should include:

- task goal;
- files created or changed;
- checks run and exact outcomes;
- consistency audit;
- tests of the tests;
- what did not go smoothly;
- team learning and process improvements;
- design-doc updates;
- pkgdown/documentation updates;
- known limitations and next actions.

## Consistency Audit

Before closing a task, check for stale names and syntax across the
repository. Common checks include:

```sh
rg "Sigma_B|Sigma_W|Lambda_B|Lambda_W|latent\\(|unique\\(|indep\\(|dep\\(" .
rg "phylo_latent|phylo_unique|spatial_latent|spatial_unique" .
rg "full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" README.md ROADMAP.md NEWS.md docs vignettes
```

The goal is not only to make tests pass. It is to make sure code,
docs, examples, design notes, and site navigation describe the same
package.

## Status Inventory

For family, formula-grammar, diagnostic, or implemented-scope
changes, explicitly check the status inventory before closing:

- `README.md` current project status;
- `ROADMAP.md`;
- `NEWS.md`;
- `docs/dev-log/known-limitations.md`;
- `docs/design/01-formula-grammar.md` (when added);
- `_pkgdown.yml` when navigation should change.

Paste the exact `rg` patterns used into the check log or after-task
report.

## Prose Audit

If the task changes README text, vignettes, pkgdown pages,
after-task notes, release notes, paper drafts, or long design docs,
run a prose-style pass before closing using the project-local
`prose-style-review` skill.

For very small prose-only tasks, keep the report compact.

## Tests of the Tests

When adding tests, confirm that they actually exercise the intended
behaviour:

- inspect failure messages before relaxing expectations;
- check that parser tests assert parsed fields, not only object
  classes;
- use deterministic seeds for simulation tests;
- pair every guard's rejection-case test with the matching
  acceptance-case test (the 2026-05-10 lesson recorded in the
  `after-task-audit` skill).

## Closing Rule

A task is not done until the after-task report says what was checked
and what remains uncertain.
