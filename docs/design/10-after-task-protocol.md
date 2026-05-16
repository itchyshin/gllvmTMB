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
  Fisher / Jason / Shannon). **Depth scales with PR type**:
  - for engine / article / scope PRs (anything advertised in
    user-facing prose, or anything that touches code, families,
    grammar, likelihoods, or tests): **one short paragraph per
    engaged role** describing what it caught, what it would
    have caught, and what to watch for next time;
  - for trivial coord-board / dev-log / typo-only PRs:
    one-line-per-role is acceptable.
  Roles that did not engage are omitted; do not list a role
  just to enumerate the team;
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
repository. Standard checks:

```sh
# Cross-feature presence
rg "Sigma_B|Sigma_W|Lambda_B|Lambda_W|latent\\(|unique\\(|indep\\(|dep\\(" .
rg "phylo_latent|phylo_unique|spatial_latent|spatial_unique" .
rg "full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" README.md ROADMAP.md NEWS.md docs vignettes
```

In addition, the following **gllvmTMB-specific stale-wording**
patterns should run on every PR that touches user-facing prose,
articles, or roxygen:

```sh
# Legacy S/U notation (canonical is psi / Psi per decisions.md 2026-05-14)
rg "\\bS_B\\b|\\bS_W\\b|\\\\bf S" .

# Long-format gllvmTMB() calls MUST pass trait = "..." explicitly
# (Option A uniform-naming rule per 01-formula-grammar.md). Enumerate
# every gllvmTMB( call site below; manually verify each long-format
# call has trait = "..." present. Wide-format calls (traits(...) LHS)
# do NOT take a trait = argument.
rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design

# Foundational in-prep citations (engine-specific in-prep validation
# claims are OK; foundational results should cite published literature)
rg "in prep|in preparation" docs vignettes

# Deprecated keyword aliases that should not appear in user-facing prose
rg "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes

# meta_known_V is now a deprecated alias (canonical: meta_V); flag any
# user-facing prose that still uses the old name as primary
rg "meta_known_V" README.md NEWS.md docs vignettes

# gllvmTMB_wide() is REMOVED in 0.2.0 (per validation-debt register
# row FG-16); any user-facing reference describing it as
# "soft-deprecated" or as a current API is stale
rg "gllvmTMB_wide" README.md NEWS.md docs vignettes
```

The goal is not only to make tests pass. It is to make sure code,
docs, examples, design notes, and site navigation describe the same
package.

**Record the exact rg patterns used, verbatim, in the after-task
report or the check-log entry.** A generic phrase such as
*"stale-wording scans"* or *"ran the audit"* is not enough for
later auditors — they need the exact pattern + scope to
reproduce the check or rerun it after a related change. (Kit
absorption from drmTMB 2026-05-16; the rule that prevents
unverifiable audit claims.)

Each `rg` invocation should also be paired with a **one-line
verdict** (for example: *"found only intentional boundaries for
random slopes and richer labelled covariance blocks"*, or
*"confirmed the implemented target names and the residual-rho12
separation are visible in source, tests, docs, tutorials, and
generated help"*). The verdict is the signal; the rg pattern is
the reproducible evidence.

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

Every new test must satisfy **at least one** of the following:

1. **Failure-before-fix verification**: the test was demonstrated
   to fail before the fix (a reproducer of a real bug);
2. **Boundary case**: the test exercises a boundary, malformed
   input, missing-data path, or family × $d$ edge regime
   (variance near zero, rank-deficiency, fixed-residual ordinal,
   etc.);
3. **Feature combination**: the test combines the new feature
   with at least one already-supported neighbouring feature
   (mixed-family × phylo, random slope × `lambda_constraint`,
   etc.).

A "happy-path-only" test that adds coverage without satisfying
any of the three is acceptable only when explicitly marked
prophylactic (no specific bug, just covering a contract).

When adding tests, also confirm that they actually exercise the
intended behaviour:

- inspect failure messages before relaxing expectations;
- check that parser tests assert parsed fields, not only object
  classes;
- use deterministic seeds for simulation tests;
- add a negative test when a rule should reject unsupported
  syntax or data (kit absorption from drmTMB 2026-05-16);
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

## Convention-Change Cascade

When a PR changes an argument name, keyword default, function
signature, or syntax requirement (any *convention*), the same PR
must propagate the change to **every place the example code
lives** — not just the function source. Per AGENTS.md Design
Rule #10:

**Required cascade targets**:

1. **Function ↔ help-file binding.** The function's roxygen
   block (`@param` / `@usage` / `@examples`) AND the
   regenerated `man/*.Rd` file. Run `devtools::document()`
   in the same PR. Every R function is bound to its help
   file; the two must agree.
2. **All other `@examples` blocks in `R/`** that use the
   changed convention.
3. **All vignette / article code chunks** under `vignettes/`.
4. **Canonical examples in design docs and root files**:
   `docs/design/00-vision.md` signature feature, the keyword
   grid in `AGENTS.md`, the Tiny example in `README.md`,
   `CLAUDE.md` if present, any `NEWS.md` code chunk.
5. **Validation-debt register row(s)** in
   `docs/design/35-validation-debt-register.md` if test
   evidence moves.

**Operational checklist** (run during after-task audit):

```sh
# Enumerate all gllvmTMB( call sites in the repository
rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design

# Enumerate roxygen @examples blocks
rg -ln "@examples" R

# Enumerate man/*.Rd files (regenerated; should be in sync
# with R/ roxygen)
ls man/*.Rd | wc -l
```

For each enumerated call site, the audit **verifies** the
example uses the post-change convention. The audit verdict
records, file by file, whether the cascade is complete.

**The after-task report enumerates every example file
touched.** A convention change merged without the cascade is
a hard violation (the kind that ships an article saying
`trait = "trait"` is redundant while the same PR makes it
required — exactly the discrepancy the 2026-05-16 Phase 0A
session would have shipped without this gate).

Pattern adapted from drmTMB / Rose-team discipline; in their
project, every argument-rename or default-change PR enumerates
its cascade and runs the audit before merge.

## Closing Rule

A task is not done until the after-task report says **what was
checked, what was not checked, and what remains uncertain**. (Kit
absorption from drmTMB 2026-05-16; the explicit "what was *not*
checked" requirement is what closes the silently-skipped-step
failure mode.)

## After-Task Report Template (10 sections)

Every meaningful after-task report opens with these 10 canonical
sections. Conditional sections (Mathematical Contract,
Rendered-Rd Spot-Check, Prose Audit, Status Inventory) layer on
top when relevant — see the dedicated sections above.

```md
# After Task: <Title>

## 1. Goal

What was this PR trying to accomplish? One paragraph.

## 2. Implemented

What is now true after this PR that was not true before? Bullets
or short paragraphs. For engine PRs: include the Mathematical
Contract (see dedicated section above) before the bullets.

## 3. Files Changed

Every file path touched, grouped by area. Include the
status-inventory cascade (README, NEWS, ROADMAP, design docs,
vignettes, generated `man/*.Rd`), not only the implementation
file.

## 4. Checks Run

Every command + its exact outcome. Include the **verbatim** rg
patterns from the Consistency Audit. Commands deliberately not
run go under "Tests of the Tests" or "What Did Not Go Smoothly"
with the reason.

## 5. Tests of the Tests

For every new or modified test, name which of the three rules
(failure-before-fix / boundary / feature-combination) it
satisfies, or explicitly mark it prophylactic. Couple each test
to the bug it would have caught when relevant.

## 6. Consistency Audit

The exact rg patterns used + the one-line verdict per pattern.
Per the rule above, a generic "ran the audit" line is not
enough.

## 7. Roadmap Tick

Which `ROADMAP.md` phase or sub-phase row had its status chip
or progress bar change? Form: `Phase Xa → progress ███░░░░░
3/5 (was 2/5); status stays 🟢 In progress.` Or `N/A`.

## 8. What Did Not Go Smoothly

Process friction, surface defects, scope creep, persona
gaps, anything that took longer than expected. Be honest;
the next reader benefits.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Paragraph-per-engaged-role for engine / article / scope PRs;
one-line-per-role for trivial dev-log / coord-board / typo PRs.
Roles that did not engage are omitted.

## 10. Known Limitations and Next Actions

What is still uncertain? What did this PR not address that
should be on a follow-up's plate? Cross-reference
`docs/dev-log/known-limitations.md` when relevant.
```

Validation-debt register update is not a separate section but
appears under either "Files Changed" (when a row is appended or
edited) or "Known Limitations" (when a row stays `partial` or
`blocked`).
