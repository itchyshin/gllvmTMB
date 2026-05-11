# gllvmTMB Roadmap

This roadmap is the shared map for humans, Codex, and Claude Code. It
keeps the next implementation work small enough to review while
preserving the long-term package identity: stacked-trait multivariate
GLLVMs in TMB, with long-format data as the canonical representation
and wide-format entry points available for users who think in response
matrices.

## Current Position

The 2026-05-10 reset rebuilt `gllvmTMB` from a clean repository,
modelled on `drmTMB`'s process discipline but not on `drmTMB`'s
runtime profile. The package now has:

- a clean R package skeleton with `src/gllvmTMB.cpp` compiled at
  install time;
- the gllvmTMB-native parser, extractors, methods, tests, and
  worked-example articles;
- 3-OS `R-CMD-check` on pull requests and `main`;
- pkgdown sequencing after green `R-CMD-check` on `main`;
- a reader-first homepage and Get Started article;
- project-local skills for simulation tests, likelihood review,
  article triage, prose review, and Rose pre-publish auditing.

The package is not ready for new modelling ambitions until the public
surface, data-shape contract, examples, and feedback loop are stable.

## Phase 1 -- Stabilise The Reader Path

Goal: a new applied ecology, evolution, or environmental-science user
should be able to see the purpose, choose a data shape, fit a tiny
model, and know which workflows are supported.

Work:

- Present every Tier-1 fit example with long-format and wide-format
  calls side by side. The long form
  `gllvmTMB(value ~ ..., data = df_long)` is canonical; the wide form
  is the convenience equivalent through `gllvmTMB_wide()` or
  `gllvmTMB(traits(...) ~ ..., data = df_wide)`.
- Rewrite public articles that still teach through legacy helper
  names (`getLoadings`, `ordiplot`, `extract_ICC_site`, or similar)
  before those helpers are removed from the public surface.
- Keep the 3 x 5 covariance keyword grid visible, but introduce it
  after the user promise and the runnable example.
- Run Rose before merging README, vignette, `_pkgdown.yml`, exported
  roxygen, or Rd changes.

First PR shape:

- one article or homepage section at a time;
- no likelihood, parser, or NAMESPACE changes;
- `pkgdown::check_pkgdown()` plus the affected article render.

## Phase 2 -- Finalise The Public Surface

Goal: the exported API, pkgdown reference index, examples, and tests
should describe the fresh package, not the legacy package.

Work:

- Use the Priority 2 export audit as the review input.
- Keep canonical user functions, internalise implementation helpers,
  and delete legacy exports that no longer have a supported purpose.
- Update tests to use public functions when testing user behaviour and
  `gllvmTMB:::` only when testing intentional internals.
- Add one `NEWS.md` entry for the surface cleanup.

First PR shape:

- rewrite article examples before deleting helpers they currently use;
- then remove one coherent export bucket at a time;
- run `devtools::document()`, `devtools::test()`, and
  `pkgdown::check_pkgdown()`.

## Phase 3 -- Unify Data Shapes And Weights

Goal: long-format and wide-format entry points should feel like two
views of one model, not two separate packages.

Work:

- Define the contract for `gllvmTMB()`, `gllvmTMB_wide()`, and
  `traits(...)`: accepted shapes, required identifiers, reshaping
  rules, trait ordering, and error messages.
- Unify weights across long and wide inputs, including matrix-style
  weights when the response is wide.
- Add paired tests: one long call and one wide call should produce the
  same model matrix, trait ordering, and fitted target for a tiny
  example.
- Add user-facing examples that show how to move between `df_long` and
  `Y` / `df_wide`.

This phase can touch parser-facing code, so Boole and Rose should
review docs and syntax. Gauss or Noether are needed only if the
likelihood or parameterisation changes.

## Phase 4 -- Improve Feedback Time

Goal: keep the 3-OS discipline while making the maintainer's feedback
loop less punishing.

Work:

- Identify the slowest tests and decide which are true smoke tests,
  which are simulation recovery tests, and which should run only under
  an explicit slow-test flag.
- Keep full 3-OS `R-CMD-check` for pull requests and `main`.
- Defer fast-lane / slow-lane CI until the public surface and data
  shape contract are stable.
- Lower the temporary Windows timeout only after the gated suite
  reliably fits inside the stricter budget.

Grace owns this phase; Curie reviews test value before any simulation
test is gated.

## Phase 5 -- CRAN Readiness

Goal: produce a package that can pass CRAN review without relying on
private knowledge of the repo reset.

Work:

- Keep DESCRIPTION title, authorship, license, and DOI metadata clean.
- Ensure vignettes build quickly or use acceptable precomputed
  artefacts with clear fallbacks.
- Keep 3-OS CI green for a sustained period.
- Write `cran-comments.md`.
- Run CRAN extra checks before submission.

## Phase 6 -- Methods Paper And Extensions

Goal: after the package surface is stable, add scientific depth
without blurring the scope.

Candidate extensions:

- functional-biogeography reproducibility article linked to the
  Nakagawa et al. methods paper;
- `add_barrier_mesh()` SPDE barrier path for coastal data;
- random-slope bar syntax `(1 + x | g)` once the intercept-only path
  is fully tested;
- sparse-count families such as zero-inflated Poisson or ZINB;
- two-level `phylo + cluster` cross-pollination if simulation
  recovery and identifiability checks justify it.

Every extension follows the relevant design-doc, simulation-test,
likelihood-review, documentation, and after-task-report rules.

## Collaboration Stops

Agents may gather evidence in parallel, but the project should stop
for maintainer discussion at four points:

1. after a read-only audit proposes deletions, API changes, or
   grammar changes;
2. before a PR touches NAMESPACE, formula parsing, likelihood code, or
   family support;
3. before merging when CI is still running on another related PR;
4. after a phase completes, so the roadmap can be re-ranked before
   the next PR starts.

Claude Code is best used for read-only audits, prose diagnostics, and
decision drafts. Codex is best used for implementation, CI/pkgdown
plumbing, local validation, and PR integration. Either agent can
review, but no agent should take a broad, multi-file implementation
without a small write scope and a handoff note.

After-task reports are required for completed tasks and phases. They
are the durable handoff document for Ada, Boole, Gauss, Noether,
Darwin, Fisher, Pat, Jason, Curie, Emmy, Grace, Rose, and Shannon to
push back from the same evidence base rather than from stale memory.
Use Shannon when the question is not the content of a PR but whether
the two teams' branches, PRs, dev-log entries, and after-task reports
still describe one coherent project state.

## Out Of Scope

- Single-response models: use `glmmTMB`.
- Spatial-only single-response models: use `sdmTMB`.
- One- or two-response distributional regression: use `drmTMB`.
- Bayesian sampling: use `brms` or `MCMCglmm`.
- Dimension reduction without a likelihood model: use `gllvm` for that
  flavour.
