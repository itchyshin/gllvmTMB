# gllvmTMB Agent Instructions

`gllvmTMB` is an R package for stacked-trait, long-format multivariate
generalised linear latent variable models (GLLVMs) using Template
Model Builder.

## Core Scope

- The package fits multi-response models on long-format data: one row
  per `(unit, trait)` observation. The "unit" is typically a site or
  individual; the "trait" is one column of a multivariate response.
- The covariance dispatch is the 3 x 5 keyword grid:

  | correlation \ mode | scalar | unique | indep | dep | latent |
  |---|---|---|---|---|---|
  | none    | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
  | phylo   | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
  | spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

- The decomposition mode is `latent + unique` paired:
  Sigma = Lambda Lambda^T + diag(psi) (the Greek letter
  Psi, lowercase psi for the per-trait scalar entries; see
  `decisions.md` 2026-05-14 notation reversal). Standalone
  `latent` is the no-residual / rotation-invariant subset.
  Standalone `unique` is the marginal / independent mode
  (Sigma = diag(psi_t^2)) and is equivalent to `indep`.
  `dep` alone is the full unstructured Sigma.
- Single-response models (no covstruct keyword) belong in `glmmTMB`.
  Spatial-only single-response models belong in `sdmTMB`.
  Higher-dimensional latent-variable models are `gllvmTMB`'s job.
  For the full cross-package scope record (including `gllvm`,
  `MCMCglmm`, `brms`, the decision matrix, and the "what gllvmTMB
  does NOT do" section), see `docs/design/04-sister-package-scope.md`.
- The phylogenetic representation is a sparse A^-1 (Hadfield &
  Nakagawa 2010, re-implemented from the same algorithm in
  `src/gllvmTMB.cpp`). The spatial representation is the SPDE/GMRF
  approximation inherited from sdmTMB.

## Design Rules

1. Do not add a new family without simulation tests. See the
   `add-simulation-test` skill (especially the symbolic-math <->
   implementation alignment table), `docs/design/02-family-registry.md`
   for the 14-slot per-family contract, and
   `docs/design/03-likelihoods.md` for the per-family TMB likelihood
   path.
2. Do not add user-facing functions without roxygen2 documentation
   and a runnable example. The return-value contract for every
   exported `extract_*()` is recorded in
   `docs/design/06-extractors-contract.md`.
3. Do not change formula grammar (the 3 x 5 keyword grid +
   `traits()` LHS) without updating `docs/design/01-formula-grammar.md`
   (the canonical grammar contract), the 3 x 5 grid table in this
   file, and the parallel table in `CLAUDE.md`.
4. Do not change likelihood parameterisation in `src/gllvmTMB.cpp`
   without applying the `tmb-likelihood-review` skill and updating
   `docs/design/03-likelihoods.md`.
5. Do not add new grouping levels (`unit` / `unit_obs` / `cluster`)
   or new variance-share keyword categories (`phylo_*` / `spatial_*`
   / `meta_V` / any future axis) without simulation recovery on a
   known DGP and updates to `docs/design/04-random-effects.md` +
   `docs/design/05-testing-strategy.md`. (Per the Option C revision
   2026-05-16, `phy` and `spatial` are *variance-share* shortcuts
   on the unit-tier covariance, not peer grouping levels — see
   `docs/design/06-extractors-contract.md` Section 1.)
6. Keep pull requests small and focused. The 2026-05-10 lesson:
   work-in-progress > 1 produces cancel-cascades on CI.
7. Every meaningful change should append to
   `docs/dev-log/check-log.md`.
8. Every completed task or phase should create an after-task report
   under `docs/dev-log/after-task/` following
   `docs/design/10-after-task-protocol.md`.
9. If code is ported from `sdmTMB` or another upstream package,
   document provenance in `inst/COPYRIGHTS` before treating the
   change as complete.
10. **Convention changes cascade to every place the example
    code lives** (drmTMB / Rose-team discipline ratified by
    maintainer 2026-05-16). When an argument name, keyword
    default, function signature, or syntax requirement changes,
    the **same PR** must update:
    - the function's roxygen block (`@param`, `@usage`,
      `@examples`) and the regenerated `man/*.Rd` help file —
      **every R function is bound to its help file and the two
      must agree**;
    - every other roxygen `@examples` block that uses the
      changed convention;
    - every vignette / article code chunk that uses it;
    - the canonical example in `00-vision.md`, the keyword
      grid in this file, the Tiny example in `README.md`,
      and any NEWS code chunk;
    - the validation-debt register row(s) if test evidence
      moves.

    The after-task report **must enumerate every example file
    touched** and explicitly state which files were verified
    clean. A convention change merged without the cascade is a
    hard violation. See `docs/design/10-after-task-protocol.md`
    "Convention-Change Cascade" section for the operational
    checklist.

## Standard Commands

```r
devtools::document()
devtools::test()
devtools::check()
pkgdown::check_pkgdown()
pkgdown::build_articles(lazy = FALSE)  # for parser-touching changes
```

## Recovery Checkpoints

For long runs, stream failures, context-compaction events, or
handoffs between agents, write a compact recovery checkpoint
*before* continuing. Drop a Markdown file under
`docs/dev-log/recovery-checkpoints/` named
`YYYY-MM-DD-HHMMSS-<agent>-checkpoint.md` with:

- current branch and `git status --short` output;
- changed files and `git diff --stat`;
- commands already run, with exact outcomes;
- commands that still need to run;
- next safest action;
- any blocking question for the maintainer.

After a crash or context-compaction event, **the repository is
authoritative**. Rehydrate from:

```sh
git status --short --branch
git diff --stat
git diff
```

Then read the newest check-log entry and the newest recovery
checkpoint *before* editing. Do not trust private agent memory
alone. (Kit absorption from drmTMB 2026-05-16; closes the
context-loss gap demonstrated in the 2026-05-16 Phase 0A
session.)

## Definition of Done

A feature is "done" only when **all six** items below are
present. This is a hard contract (drmTMB-team discipline
ratified by maintainer 2026-05-16). The after-task report
names which of these were checked and by whom.

1. **Implementation.** Code merged on `main` with passing
   3-OS CI.
2. **Simulation recovery test** for any new likelihood,
   family, keyword, or estimator. See `add-simulation-test`
   skill and `docs/design/05-testing-strategy.md` for the
   test-layer contract. Curie signs off on test fidelity.
3. **Documentation.** Roxygen `@param` + `@return` +
   `@examples` complete; `man/*.Rd` regenerated; affected
   article(s) updated. The return-value contract for any
   new extractor lands in
   `docs/design/06-extractors-contract.md`.
4. **Runnable user-facing example.** README, vignette, or
   article example exercising the feature on data the
   reader can copy. Pat reads it as an applied PhD user.
5. **`docs/dev-log/check-log.md` entry** recording the exact
   commands run, the exact rg patterns used for stale-wording
   scans, and what was deliberately not run.
6. **Review pass for likelihood / parameterization /
   scope.** Gauss + Noether on TMB-likelihood touches; Boole
   on formula-grammar touches; Fisher on inference-machinery
   touches; Rose on the cross-file consistency audit before
   merge. The after-task report names which reviewers
   actively engaged.

If one of these six is genuinely not appropriate, the
after-task report must say **why**. Skipping silently is a
hard violation. **And every advertised capability must have
a row in `docs/design/35-validation-debt-register.md`**
marked `covered` (with test evidence path), `partial`, or
`blocked` — see the Writing Style section's scope-boundary
rule.

## CI Pacing Discipline

The default CI workflow (`.github/workflows/R-CMD-check.yaml`) runs
on three OSes for pull requests and pushes to `main`. The pkgdown
workflow runs only after a successful `R-CMD-check` on `main` /
`master` or by manual dispatch. Do not add a fast lane or skip slow
tests unless the maintainer asks for that separate change.

Before any PR or main push that changes exported functions,
reference topics, README, vignettes, or parser-facing examples:

- run `pkgdown::check_pkgdown()` locally;
- render affected articles with `pkgdown::build_articles(lazy = FALSE)`
  when formula parsing, tutorial code, or article examples changed;
- keep work-in-progress to one open PR;
- wait for the active GitHub Actions run to finish before pushing
  another fix-up commit.

## Writing Style

For user-facing prose, developer notes, after-task reports, and
release text, write for a named reader and keep the prose concrete.
The main readers are applied ecology, evolution, and
environmental-science users, plus statistical method developers and R
package contributors.

- Name the purpose before mechanics.
- Pair symbolic equations, R syntax, and interpretation when
  explaining models. The 5-row alignment table from the
  `add-simulation-test` skill is the canonical form.
- Use concrete terms: files, equations, functions, keyword names, or
  numerical results, rather than vague phrases such as "various
  factors" or "significant improvements".
- Use active voice when the actor matters.
- Do not turn prose into bullets unless the content is a genuine
  list.
- Keep terms stable: `Sigma`, `Lambda`, `psi` (per-trait
  scalar) / `Psi` (matrix), `latent`, `unique`, `indep`, `dep`,
  `phylo_*`, `spatial_*`, `meta_V(value, V = V)`. These should
  not drift across documents. (`meta_known_V` is retained as
  a deprecated alias through 0.2.x; new examples use `meta_V`.)
- Support factual, statistical, or literature claims with a citation,
  local evidence, or a clear note that the statement is a design
  assumption.
- For tutorials and error-message docs, tell the reader what to try
  next when a model or syntax is unsupported.
- When demonstrating how to fit a `gllvmTMB` model in user-facing
  prose -- README, vignettes, and Tier-1 articles -- show **both**
  long-format and wide-format calls side by side, through the single
  `gllvmTMB()` entry point. The long form
  (`gllvmTMB(value ~ ..., data = df_long)`) is canonical; the wide
  data-frame form uses the simplified `traits(...)` LHS grammar
  (`traits(...) ~ 1 + latent(1 | unit, d = K) + unique(1 | unit)`).
  Readers vary in mental model -- some think in matrices, some in
  long tibbles -- and examples should avoid making wide-data-frame
  readers write `0 + trait` and `(0 + trait):x` by hand. The same
  shorthand applies to `indep()`, `dep()`, and `spatial_*()` terms;
  ordinary `(1 | group)` random intercepts pass through unchanged.
  The legacy matrix wrapper `gllvmTMB_wide(Y, ...)` is
  **removed in 0.2.0** (per validation-debt register row
  FG-16); new examples must use the `traits(...)` LHS
  formula API.
  Roxygen `@examples` blocks for individual keyword or extractor
  functions may stay single-form when the keyword is intrinsically
  one shape.
- **Scope-boundary statement required** on every NEWS entry,
  vignette, article, README section, and roxygen `@description`
  that advertises a capability. State explicitly:
  - what is **IN** (`covered` rows in
    `docs/design/35-validation-debt-register.md`);
  - what is **PARTIAL** (`partial` rows; works in the named
    regime, not yet at the depth advertised elsewhere);
  - what is **PLANNED** or **REJECTED** (`blocked` rows; not
    advertised in user-facing prose, only in the register).

  Reference register row IDs (e.g. FG-NN, FAM-NN, MIX-NN) so
  readers and future auditors can trace each claim to evidence.
  This rule, had it existed 2026-05-15, would have prevented
  the article-port overpromise crisis.

Use the project-local `prose-style-review` skill for substantial
README, vignette, pkgdown, after-task, release, or paper-oriented
text.

## Article style

Every public article is **Tier 1** (worked example) by default. Tier
2 / Tier 3 require explicit justification. The `article-tier-audit`
skill encodes the triage. The `vignettes/articles/morphometrics.Rmd`
article is the canonical Tier-1 exemplar.

## Multi-Agent Collaboration

Codex and Claude Code may both contribute to this repository. All
agent work must follow the same project rules:

- preserve the multivariate stacked-trait scope;
- avoid unreviewed likelihood or formula-grammar changes;
- update design docs when architecture changes;
- add tests with implementation;
- do not revert changes made by another agent or human unless
  explicitly asked;
- prefer small, reviewable commits or pull requests.

**Pre-edit lane check.** Before editing any shared rule file
(`AGENTS.md`, `CLAUDE.md`, `ROADMAP.md`, `CONTRIBUTING.md`,
`docs/dev-log/decisions.md`, `docs/dev-log/check-log.md`,
`docs/design/`, `docs/dev-log/after-task/`, `inst/COPYRIGHTS`,
`DESCRIPTION`), run `gh pr list --state open` and
`git log --all --oneline --since="6 hours ago"` to confirm no other
agent is editing the same file. If a collision is detected, post a
coordination comment and wait. This prevents the parallel-edit
pattern that produced the 2026-05-11 Shannon double-ship.

When an agent hands work to another agent, leave enough context in
`docs/dev-log/check-log.md` or the relevant issue/PR for the next
agent to continue without rediscovering the whole problem.

Claude Code should read this file first. It should not introduce a
parallel agent configuration system inside the package unless the
project owner asks for one.

Use Shannon (`.agents/skills/shannon-coordination-audit/SKILL.md`)
for periodic cross-team coordination audits between the Claude team
and the Codex team. Shannon is a read-only checklist gate analogous
to Rose, but checks process state -- branches, PRs, after-task
pairing, dev-log consistency -- rather than document content.
Invoke Shannon at maintainer-dispatch checkpoints: before handing
off the next bounded task, before any branch switch with
uncommitted work in the tree, when more than one PR is open across
both teams, and at end-of-session before handing off to the next
sitting. Shannon reports pass, warn, or fail with concrete evidence;
it does not edit, merge, or replace Rose, Grace, Pat, or any
implementation reviewer.

## Pre-Publish Gate

Use one narrow Rose pre-publish audit for any PR that touches
README, vignettes, `_pkgdown.yml`, NEWS, roxygen for exported
functions, or generated Rd files. The gate checks method lists,
default-value claims, exported function names, the 3 x 5 keyword grid,
argument names, family lists, and stale terminology. It does not
replace Boole, Gauss, Noether, Grace, Pat, or Darwin; it only checks
cross-file consistency before user-facing content is published.

Keep role dispatch bounded:

- Grace owns CI, pkgdown, CRAN, dependency, and platform concerns.
- Rose owns cross-file consistency and repeated-process failures.
- Pat and Darwin own the applied-user reading path and biological
  interpretation.
- Boole, Gauss, and Noether are invoked only when syntax, likelihood,
  mathematical alignment, or TMB plumbing changes.

Do not create per-role skill files for every reviewer unless the
maintainer asks. More static context is not a substitute for narrower
dispatch. The project-local Rose and Shannon skills are intentional
exceptions because they are narrow, checklist-driven gates.

## Standing Review Roles

These names are shorthand for recurring review perspectives. They do
not run continuously; the orchestrator should launch them only for
bounded tasks. Use these canonical names when reporting team
perspectives; do not rename them in status updates or project notes.

| Name | Role | Primary questions |
| --- | --- | --- |
| Ada | Orchestrator and integrator (the maintainer) | What should happen next, and are code, math, docs, tests, pkgdown, and git consistent? |
| Boole | R API and formula reviewer | Is the syntax memorable, parseable, and internally consistent? |
| Gauss | TMB likelihood and numerical reviewer | Is the likelihood correct and numerically stable? |
| Noether | Mathematical consistency reviewer | Do the symbolic equations, R syntax, and TMB implementation match exactly? |
| Darwin | Ecology / evolution audience reviewer | Does the example answer a real biological question for the target audience? |
| Fisher | Statistical inference reviewer | Do simulations, comparator checks, likelihood profiles, and identifiability diagnostics support the claim? |
| Pat | Applied PhD student user tester | Can a new applied user follow the tutorial, interpret output, recover from errors, and avoid hidden jargon? |
| Jason | Landscape and source-map scout | What do related packages and papers already do, and what should `gllvmTMB` learn or avoid? |
| Curie | Simulation and testing specialist | Do recovery tests cover ordinary, edge, and malformed-input cases without becoming too slow? |
| Emmy | R package architecture reviewer | Are S3 methods, object structures, extractors, and internal APIs coherent? |
| Grace | CI, pkgdown, CRAN, and reproducibility engineer | Will this pass on all platforms, deploy cleanly, and avoid compiled-code or dependency risk? |
| Rose | Systems auditor | What discrepancies, repeated mistakes, stale wording, unsupported claims, and missing feedback loops are accumulating? |
| Shannon | Cross-team coordination auditor | Are the two teams' working trees, branches, PRs, and dev-log entries consistent? Is every completed task closed by an after-task report? Are open PRs going to merge cleanly? |

The Codex `.toml` agent files under `.codex/agents/` map (not 1:1) to
these names; the `description` line of each `.toml` records the
internal-name mapping. The runtime-dispatchable agents are Codex's
file names; the review-perspective names above are how to refer to a
role in prose.

## pkgdown Policy

The pkgdown site is a first-class project artefact. User-facing
features should include reference documentation and, when
substantial, a Tier-1 article. Keep `_pkgdown.yml` synchronised with
exported functions and vignettes.

## CI Policy

The default CI workflow (`.github/workflows/R-CMD-check.yaml`) runs
on three OSes (ubuntu-latest, macos-latest, windows-latest) on every
push to `main` and every pull request. Pre-push checklist:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Do not rely on CI to catch what `check_pkgdown()` would catch
locally in 30 seconds. See the `ci-pacing-discipline` global skill
and the after-task-audit skill's "Anti-patterns from 2026-05-10"
section.
