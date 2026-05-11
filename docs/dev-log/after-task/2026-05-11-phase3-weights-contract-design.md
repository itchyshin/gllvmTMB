# After-Task: Phase 3 weights & data-shape contract design doc

## Goal

Draft `docs/design/02-data-shape-and-weights.md` as Claude's Phase 3
design contribution per `docs/design/11-task-allocation.md` Phase 3
row. The doc defines the contract for `gllvmTMB()`,
`gllvmTMB_wide()`, and `traits()`: accepted shapes, required
identifiers, reshaping rules, trait ordering, weights handling
(including matrix-style weights when the response is wide), error
messages, and a paired-test contract. It is the design input for
Codex's Phase 3 implementation work.

This PR follows the new `CONTRIBUTING.md` "after-task at branch
start" rule: the report is added with the first commit on the
branch, alongside the design doc.

## Implemented

- `docs/design/02-data-shape-and-weights.md` (NEW) -- the contract
  specification covering the three entry points, byte-identical
  contract, identifiers, trait ordering, reshaping rules, weights
  contract (with the four accepted shapes and the binomial special
  case), error messages, paired-test contract, user-facing examples,
  implementation notes for Codex, and out-of-scope items.
- `docs/dev-log/after-task/2026-05-11-phase3-weights-contract-design.md`
  (NEW, this file) -- after-task report at branch start.
- `docs/dev-log/decisions.md` (M) -- appended the 2026-05-11
  "Binomial trial-count API: docs-only path (Option C)" decision
  the maintainer made during PR #23 review (added in the same
  PR per integrate-before-adding).

No source code changes. No likelihood, formula grammar, family, or
NAMESPACE changes.

## Mathematical Contract

This is a documentation-only design doc. No public R API,
likelihood, formula grammar, estimator, family, NAMESPACE, or
generated Rd file changes in this PR. The doc specifies behaviour
Codex will implement in a follow-up PR.

The contract preserves the current likelihood: per-observation
log-likelihood contributions are multiplied by `weights[i]`
(lme4 / glmmTMB convention) for non-binomial families, and
`weights` is overloaded as `n_trials` for binomial / betabinomial
rows (the existing behaviour in `R/fit-multi.R`). The wide-format
matrix-weights case (per-cell weights) maps one-to-one onto the
long-format per-row weights after column-major pivot.

## Files Changed

- `docs/design/02-data-shape-and-weights.md` (NEW)
- `docs/dev-log/after-task/2026-05-11-phase3-weights-contract-design.md`
  (NEW, this file)

## Checks Run

- Pre-edit lane check (per the new `AGENTS.md` rule):
  `gh pr list --state open` returned 0 open PRs;
  `git log --all --oneline --since="6 hours ago"` showed only the
  2026-05-11 doc-sprint merges; no other agent is editing
  `docs/design/`.
- The doc references `gllvmTMB()`, `gllvmTMB_wide()`, and `traits()`
  with their current public signatures as read from `origin/main`
  (`R/gllvmTMB.R`, `R/gllvmTMB-wide.R`, `R/traits-keyword.R`,
  `R/fit-multi.R`). No drift between the contract text and the
  current source.
- Worktree-based isolation: this PR was authored in
  `/tmp/gllvmTMB-phase3` so that Codex's in-flight
  `codex/morphometrics-tier1-rewrite` working tree was not touched.

## Tests Of The Tests

N/A for a design doc. The doc itself specifies the paired-test
contract (`tests/testthat/test-weights-unified.R`) that Codex will
implement in the follow-up PR. The contract states what
"byte-identical" means precisely: same `model.matrix`, same trait
factor levels in the same order, same offset, same weights vector,
same starting parameters, and the same negative log-likelihood at
the converged parameter vector (within `sqrt(.Machine$double.eps)`).

## Consistency Audit

- Numbering: the doc fills slot `02` in the existing
  `docs/design/` series (`00-vision.md`, `10-after-task-protocol.md`,
  `11-task-allocation.md`). The `01` slot is reserved by
  `AGENTS.md` design rule 3 for `01-formula-grammar.md`.
- Terminology stays inside the `AGENTS.md` "Writing Style" stable
  set: `Sigma`, `Lambda`, `s`, `latent`, `unique`, `indep`, `dep`,
  `phylo_*`, `spatial_*`, `meta_known_V(V = V)`, plus the new
  identifiers `unit`, `unit_obs`, `cluster`, `trait`.
- Cross-references match: the doc points at `ROADMAP.md` Phase 3,
  `docs/design/11-task-allocation.md` Phase 3 row, and the current
  source files for each entry point.
- The long-format weights special case (binomial `n_trials`
  overload) matches the comment block in
  `R/fit-multi.R:699-738`. The wide-format matrix shape
  disambiguation matches `R/gllvmTMB-wide.R:84-110`.

## What Did Not Go Smoothly

- The shell working directory was on Codex's
  `codex/morphometrics-tier1-rewrite` branch with 17 modified
  files when this task started. Switching branches in place would
  have disturbed Codex's WIP. The fix was to use `git worktree
  add -b agent/phase3-weights-contract /tmp/gllvmTMB-phase3
  origin/main`, which gives a fresh checkout in an isolated
  directory while leaving Codex's working tree intact. Adding to
  the team-learning column below.

## Team Learning

- `git worktree add` is the safe pattern when two agents are
  active and one has uncommitted WIP. It is cheaper than stash +
  switch + work + restore, and it makes the lane separation
  visible at the directory level.
- The new "after-task at branch start" rule (`CONTRIBUTING.md`)
  immediately changed how this PR was authored: the report
  skeleton was the second file created on the branch, before any
  design-doc content. This pre-empts the post-PR-close backfill
  failure mode that PR #13 had to repair.
- The "pre-edit lane check" rule (`AGENTS.md`) ran in ~3 seconds
  and confirmed `docs/design/` was clear before any keystroke
  hit the design doc.

## Known Limitations

- This PR specifies a contract; it does not implement it. The
  three entry points still reach the engine through their current
  pre-pass code paths. Codex's follow-up PR will:
  - add `R/weights-shape.R` with the normalisation helper;
  - refactor `gllvmTMB()`, `gllvmTMB_wide()`, and `traits()` to
    call the helper instead of duplicating shape-handling
    code inline;
  - add `tests/testthat/test-weights-unified.R` with the paired
    contract.
- Per-cell weights inside the `traits()` formula LHS path remain
  intentionally unsupported in this design. The doc tells users
  who need per-cell matrix weights to use `gllvmTMB_wide()`. A
  future extension could lift this restriction, but it is not in
  Phase 3 scope.
- The doc does not specify behaviour for ragged wide formats
  (different trait coverage per row). The current
  `tidyr::pivot_longer(values_drop_na = TRUE)` path already
  handles those by dropping `NA` cells; the contract makes that
  drop explicit but does not introduce a new ragged-format mode.

## Next Actions

1. Maintainer reviews the contract draft. Specific review asks:
   (a) the four accepted weight shapes (NULL / scalar / vector /
       matrix) and the disambiguation rule;
   (b) the byte-identical contract definition (which fields must
       match);
   (c) the trait-ordering rule (user-supplied order beats column
       order beats factor level order);
   (d) the `NA` semantics under `traits()` and `gllvmTMB_wide()`.
2. After approval, Codex picks up Phase 3 implementation per
   `docs/design/11-task-allocation.md` Phase 3 row. The sequence
   is: helper → refactor entry points → paired tests → Rd
   regeneration.
3. After the implementation lands, Rose pre-publish gate runs on
   the unified Rd wording and the README weights example.
