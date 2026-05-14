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
- mathematical contract (see the dedicated section below): what
  changed about the model, equations if parameterisation moved,
  or a one-line "no public API / likelihood / grammar / family
  change";
- files created or changed -- list every file, including the
  status-inventory cascade (`README.md`, `NEWS.md`, `ROADMAP.md`,
  design docs, vignettes, generated `man/*.Rd`), not only the
  implementation file;
- checks run and exact outcomes;
- consistency audit;
- tests of the tests;
- what did not go smoothly;
- team learning and process improvements, named by the
  `AGENTS.md` "Standing Review Roles" framework (Ada / Boole /
  Gauss / Noether / Curie / Pat / Darwin / Rose / Grace / Emmy /
  Fisher / Jason / Shannon) -- one line per role that engaged
  describing what it did or would have caught;
- design-doc updates;
- pkgdown/documentation updates;
- **Roadmap tick**: one-line statement of which `ROADMAP.md`
  row's status chip or progress bar changed in this PR, or
  `N/A` if no row changed. See the dedicated section below;
- known limitations and next actions.

## Mathematical Contract

For any PR that touches parameterisation, likelihood, formula
grammar, or family code, the Mathematical Contract section should
write:

- the model equations in either `\eqn{...}` LaTeX or plain
  markdown, including parameter transforms
  (for example `rho = 0.999999 * tanh(eta_cor)`);
- an explicit statement of what the change is **not** -- residual
  covariance vs random-effect covariance, phylogenetic vs spatial,
  between-unit vs within-unit, etc.

For doc-only, CI, audit, or process-only PRs the section can be a
single line: "No public R API, likelihood, formula grammar,
family, NAMESPACE, generated Rd, vignette, or pkgdown navigation
change."

Pattern adapted from drmTMB's
`docs/dev-log/after-task/2026-05-11-mu-sigma-mean-scale-covariance.md`,
where every new TMB parameter and its bounded transform appears in
this section before any prose discussion of the implementation.

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

Each `rg` invocation should be paired with a one-line verdict (for
example: "found only intentional boundaries for random slopes and
richer labelled covariance blocks", or "confirmed the implemented
target names and the residual-rho12 separation are visible in
source, tests, docs, tutorials, and generated help"). A generic
"ran the audit" line does not tell the next reader whether the
audit found real drift or nothing -- the verdict is the signal.

Pattern adapted from drmTMB's
`2026-05-11-mu-sigma-mean-scale-covariance.md`, where each of three
`rg` checks closes with an explicit classified verdict.

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

## Roadmap Tick

Every after-task report includes a one-line **Roadmap tick**
stating which `ROADMAP.md` phase or sub-phase row had its status
chip or progress bar change as a result of this PR, or `N/A`
when no row changed. The form is:

> **Roadmap tick**: Phase 1a → progress `███░░░░░` 3/5 (was 2/5);
> status stays 🟢 In progress.

This is the bridge from per-PR memory to the public roadmap.
Without it, the rendered roadmap on pkgdown drifts from canon
between manual refreshes -- as it did 2026-05-11 → 2026-05-14,
when the published `ROADMAP.md` was three days stale on the
pkgdown site despite multiple phase-changing PRs merging in
between.

When the tick changes a row, also update the source `ROADMAP.md`
in the same PR (small edit to the row's chip and progress bar).
The `pkgdown::build_articles()` workflow then re-renders the
roadmap article on the next `main` push.

Lesson recorded after the 2026-05-14 roadmap refresh, when Rose
flagged the drift pattern during persona consults. See
`docs/dev-log/after-task/2026-05-14-roadmap-refresh.md`.

## Prose Audit

If the task changes README text, vignettes, pkgdown pages,
after-task notes, release notes, paper drafts, or long design docs,
run a prose-style pass before closing using the project-local
`prose-style-review` skill.

For very small prose-only tasks, keep the report compact.

## Rendered-Rd Spot-Check

When a task adds or rearranges a roxygen tag after a long
description block -- especially `@keywords`, `@family`,
`@concept`, or `@aliases` -- run `devtools::document()` and then
spot-check the rendered `man/<file>.Rd`:

```sh
tail -5 man/<changed>.Rd
grep -c '^\\keyword' man/<changed>.Rd
```

The tail should end with the expected single-line tag (for
example `\keyword{internal}` for `@keywords internal`). The
keyword count should be 1 (or whatever the source roxygen
intended). A count of 30+ entries with words from the
description (`\keyword{through}`, `\keyword{trait)}`,
`\keyword{wide_df,}`, etc.) means a tag was placed mid-prose and
roxygen tokenised the following words as keywords.

Lesson recorded after PR #32 shipped a malformed `man/traits.Rd`
to main: the `@keywords internal` tag was placed in the middle
of the description, producing 30+ garbage `\keyword{}` entries
in the rendered Rd. R CMD check accepted the malformed Rd
silently; air-format did not catch it; only manual review by
Codex caught it. PR #33 fixed both the roxygen layout and the
rendered Rd; this section codifies the post-`document()`
spot-check so the same defect cannot ship again.

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

When a test was motivated by a specific past mistake or manual
probe, name what the test would have caught. Worked example from
drmTMB's `2026-05-11-mu-sigma-mean-scale-covariance.md`:

> "The corpairs() test ... would have caught the manual probe
> that briefly reported `to_response = 'z'` for the sigma endpoint
> before `random_effect_response_name()` was fixed to use the
> original response for univariate sigma."

This sentence couples the new test to a specific bug it prevents.
Generic coverage prose ("the test exercises X, Y, Z") does not
give the reader the same signal. Where the test was prophylactic
(no specific bug, just covering a contract), say that explicitly
instead.

## Closing Rule

A task is not done until the after-task report says what was checked
and what remains uncertain.
