# After-Task: known-limitations.md refresh (Phase 5 prep)

## Goal

Refresh `docs/dev-log/known-limitations.md` to reflect the current
state of the package post-PR #39 (sugar pivot + `traits()` public)
and to track Phase 5 / CRAN-readiness items in flight.

The existing file was written before PR #39 landed and still
described `traits()` as a "hidden" wide marker. Today's actual
supported surface is wider (sugar parser, three data shapes, mixed
families flowing through long engine, per-row weight replication)
and has known design boundaries (per-cell weights only via
`gllvmTMB_wide()`, subtractive controls beyond `-1` not specifically
guarded, mixed-family-list pass-through, etc.) that users hit.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/known-limitations.md`** (M, ~143 lines, was 44):
  full refresh.
  - New top-line "Last refreshed 2026-05-12" date.
  - Implemented section reorganised into four subsections
    (covariance grammar, response families, structured-effect
    representations, inference, data shapes).
  - New "Sugar parser (PR #39)" section enumerating the compact
    RHS expansions (`1`, `x`, `latent(1|g)`, etc.) and the
    pass-through terms (species-axis phylo, ordinary
    `(1 | group)`, literal `-1`).
  - New "Sugar parser edge cases" subsection naming the four
    intentional design boundaries: per-cell weights -> matrix
    path; mixed families flow through long engine; subtractive
    controls beyond `-1` not specifically guarded; trait factor
    levels follow `traits()` argument order, not alphabetical.
  - "Not yet implemented" section retained with clarified wording
    on random slopes (intercept-only on structured-effect paths;
    ordinary `(1 + x | g)` accepted but not trait-stacked) and
    the first-class two-U single-call API.
  - New `S` / `s` notation reminder paragraph per PR #40 naming
    convention.
  - New "Pre-CRAN backlog (Phase 5, in flight)" section tracking
    the @examples Rd punch-list and the `RUN_SLOW_TESTS` gating
    plan, with cross-references to the Phase 4 / Phase 5
    Shannon audits.
- **`docs/dev-log/after-task/2026-05-12-known-limitations-refresh.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. One markdown
file rewritten in place.

The refreshed file uses `S` / `s` notation (`Sigma = Lambda
Lambda^T + diag(s)`), per `decisions.md` 2026-05-12 naming
convention.

## Files Changed

- `docs/dev-log/known-limitations.md` (M)
- `docs/dev-log/after-task/2026-05-12-known-limitations-refresh.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 3 open Claude PRs (#47 skills refresh,
  #48 docs wording bundle, #49 methods-paper outline) + 1 Codex
  PR (#46 Tier-2 articles). None touch
  `docs/dev-log/known-limitations.md`. Safe.
- Source-of-truth alignment: each item references an existing
  repo artefact:
  - 3 x 5 grid: matches `R/families.R`, `R/fit-multi.R`, README.
  - Family list: matches `family_to_id()` in `R/fit-multi.R`.
  - Sugar parser: matches `R/traits-keyword.R` post-PR #39.
  - `S` / `s` notation: matches PR #40 + `decisions.md`.
  - Phase 5 backlog: matches the two Shannon audit reports
    referenced by name.
- Notation spot-check: every math expression uses `s` / `S`,
  not `u` / `U`. The function-name references
  (`compare_dep_vs_two_U()`, etc.) are intentional task labels.

## Tests Of The Tests

This is a documentation refresh; the "test" is whether the
file's claims match the code. Specifically:

- The "Implemented" family list should match exactly what
  `family_to_id()` in `R/fit-multi.R` accepts. If the engine
  gains or drops a family, this list needs updating.
- The "Sugar parser" expansions should match the rewrite rules
  in `R/traits-keyword.R`. If `traits()` learns a new pass-through
  term or a new expansion, this section needs updating.
- The "Not yet implemented" list should match the open feature
  tickets / roadmap items. If random slopes or ZINB or barrier
  meshes land, that item moves to "Implemented".
- The Phase 5 backlog should drop items as they land.

A future stale-wording sweep can run:

```sh
rg -n "currently only|not yet implemented|planned" docs/dev-log/known-limitations.md
```

to catch claims that no longer match the code.

## Consistency Audit

```sh
rg -n "diag\\(s\\)|diag\\(U\\)|U_phy|U_non" docs/dev-log/known-limitations.md
```

verdict: only `diag(s)` appears in the refreshed file; no `U`
notation in math contexts.

```sh
rg -n "traits\\(\\)|gllvmTMB_wide|long.format|wide.format" docs/dev-log/known-limitations.md
```

verdict: the three user-facing entry points are named consistently
(canonical long, wide data frame via `traits()`, wide matrix via
`gllvmTMB_wide()`).

```sh
rg -n "ZINB|ZIP|barrier|two-U|Bayesian" docs/dev-log/known-limitations.md
```

verdict: each "not yet" item is named exactly once, in its own
bullet, with a follow-up sentence about how it is handled today.

## What Did Not Go Smoothly

Nothing. The hardest decision was how granular to make the
sugar-parser edge cases section: too few items hides real
design boundaries, too many makes the list feel like a bug
catalogue. Four items hit the right balance -- each is a
question a user actually asks ("can I pass per-cell weights to
`traits()`?", "does the parser handle subtractive controls?",
"can I mix families?", "does trait order match alphabetical?").

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- the "Sugar parser edge cases" section
  is exactly what Pat needs: not bugs, but design boundaries a
  user hits when they try the obvious thing and it does not do
  what they expected.
- **Rose (cross-file consistency)** -- the file is now a single
  source of truth that the `after-task-audit` skill can grep
  for stale-wording terms. PRs that change the supported
  surface should update this file in the same commit.
- **Ada (orchestrator)** -- the file records Phase 5 items
  explicitly, so when the Phase 5 PRs land they have a checklist
  to remove from.
- **Noether (math consistency)** -- the `S` / `s` notation is
  used throughout. The function-name references to "two-U"
  remain because those are task labels, not math.

## Known Limitations

- The file is a snapshot dated 2026-05-12. Future code changes
  that move items in or out of the supported surface need to
  update this file in the same PR. The "Last refreshed" date
  at the top helps reviewers spot when this file has drifted.
- The sugar parser edge cases enumerated here are based on the
  PR #39 implementation and recovery notes
  (`docs/dev-log/after-task/2026-05-12-long-wide-reader-sweep.md`).
  If the parser is later hardened against subtractive controls
  beyond `-1`, or against per-cell weights via the formula path,
  this section should be revised.
- The Phase 5 backlog item counts (~22 exports without
  `\examples`, 30 of 76 test files for `RUN_SLOW_TESTS`) come
  from the two Shannon audit reports and may drift if exports
  / tests are added or removed before the Phase 5 PRs land.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: documentation
   refresh of an internal dev-log file, no source / API / NAMESPACE
   change.
2. After merge, future PRs that change the supported surface
   (random slopes, ZINB, barrier path, two-U single-call API,
   etc.) should update this file in the same commit.
3. The "Pre-CRAN backlog" section is the live working list for
   Phase 5; items drop as their respective PRs land.
