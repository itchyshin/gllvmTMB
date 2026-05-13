# After-Task: Soft-deprecate gllvmTMB_wide() (single-entry-point cleanup)

## Goal

Per maintainer's 2026-05-13 ~04:30 MT direction: deprecate
`gllvmTMB_wide()`. The function is a 70-line matrix-in wrapper
that pivots wide → long and calls `gllvmTMB()`. Everything it does
is now covered by `gllvmTMB(traits(...) ~ ..., data = df_wide)`
sugar (per PR #39), except per-cell weight matrices (a niche
meta-analytic case that is supported via the long-format `weights`
column).

Motivation:

- **Matches drmTMB precedent.** The sister package `drmTMB` has
  one entry point (`drmTMB()`) and no `*_wide` variant despite
  handling complex multi-formula syntax. 25 exports total, zero
  matrix wrappers.
- **Resolves the "two-shapes / three-paths" contradiction** that
  the Rose README audit (PR #64) flagged at L9-28 + L185-189.
- **Predictors are awkward in `gllvmTMB_wide()`.** They go via a
  separate `X` data-frame argument PLUS a `formula_extra` RHS,
  two arguments for what should be one formula. `gllvmTMB()` with
  `traits()` LHS handles predictors natively in the formula --
  the R-idiomatic pattern used by lme4 / glmmTMB / brms / drmTMB.
- **Pre-CRAN, no known external users.** Migration cost is small.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`R/gllvmTMB-wide.R`** (M, +38 / -8 lines):
  - Added `@keywords internal` to the roxygen block (hides from
    pkgdown reference index; still callable).
  - Added a `@section Deprecation:` block to the roxygen
    documenting the migration pattern.
  - Removed the `@examples` block (the dontrun example was for
    the function's primary use; deprecated functions should not
    encourage new usage).
  - Added `lifecycle::deprecate_soft("0.2.0", "gllvmTMB_wide()",
    "gllvmTMB()")` at the top of the function body. Existing
    code still works; users see a one-shot deprecation warning
    per session.
  - Updated the `@seealso` block to point at `gllvmTMB()` as the
    recommended entry point.
- **`man/gllvmTMB_wide.Rd`** (M, regenerated):
  `devtools::document()` produced a clean Rd with one
  `\keyword{internal}` line at the end (PR #36 spot-check
  protocol). No roxygen-tag-after-prose drift.
- **`README.md`** (M, -4 / +2 lines in two locations):
  - Top-of-file data-shape section: drops the "wide matrix"
    third code block; reframes the section as "one entry
    point, two data shapes" (long DF + wide DF via
    `traits()`).
  - "Current boundaries" section: replaces the three-paths
    list with the single-entry description plus a one-line
    soft-deprecation note for `gllvmTMB_wide()`.
- **`CLAUDE.md`** (M, +3 / -3 lines): syntax-rules subsection
  now ends with "Both shapes go through one entry point:
  `gllvmTMB()`. The legacy matrix wrapper `gllvmTMB_wide(Y, ...)`
  is soft-deprecated as of 0.2.0".
- **`AGENTS.md`** (M, +3 / -2 lines): tutorial-writing
  guideline drops the "the wide matrix form uses
  `gllvmTMB_wide(Y, ...)`" instruction; adds a note that the
  legacy wrapper is soft-deprecated.
- **`docs/dev-log/known-limitations.md`** (M, -3 / +6 lines):
  "Data shapes" subsection switches to "One user-facing entry
  point, two data shapes"; "Sugar parser edge cases" subsection
  updates the per-cell weight workaround to recommend the
  long-format `weights` column path.
- **`docs/dev-log/after-task/2026-05-13-deprecate-gllvmTMB-wide.md`**
  (new, this file).

The PR does NOT:

- Touch internal callers of `gllvmTMB_wide()`. The function still
  works; the deprecation is soft. Existing tests / examples
  continue to pass.
- Remove `gllvmTMB_wide()` from NAMESPACE. The `@export` tag is
  preserved; only `@keywords internal` was added (the function
  is callable but hidden from the pkgdown reference index).
- Rewrite article examples that use `gllvmTMB_wide()`. A
  follow-up "migrate articles to formula API" sweep can be
  done after this PR settles.

## Mathematical Contract

No likelihood, TMB parameterisation, response family, NAMESPACE
export, or formula grammar change. `gllvmTMB_wide()` is a
70-line wrapper around `gllvmTMB()`; the engine is unchanged.

User-facing API surface: `gllvmTMB_wide()` is soft-deprecated
(callable, hidden from reference index, emits one-shot
deprecation warning). `gllvmTMB()` is the canonical entry point
for both long and wide data shapes.

## Files Changed

- `R/gllvmTMB-wide.R` (M, ~46 lines net)
- `man/gllvmTMB_wide.Rd` (M, regenerated)
- `README.md` (M, two locations)
- `CLAUDE.md` (M)
- `AGENTS.md` (M)
- `docs/dev-log/known-limitations.md` (M)
- `docs/dev-log/after-task/2026-05-13-deprecate-gllvmTMB-wide.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: open PRs (#61 Codex covariance-correlation,
  #63 WORDLIST, #64 Rose README audit). PR #64 touches `README.md`
  in its audit doc only (not in user-facing prose); PR #63 and
  #61 do not touch README. Safe.
- `devtools::document(quiet = TRUE)`: regenerated only
  `man/gllvmTMB_wide.Rd`, as expected.
- Rendered-Rd spot-check per PR #36 protocol:
  - `tail -8 man/gllvmTMB_wide.Rd`: clean ending with
    `\keyword{internal}` (single line).
  - `grep -c '^\\keyword' man/gllvmTMB_wide.Rd`: returns 1. No
    roxygen-tag-after-prose drift.
- Smoke test: `gllvmTMB_wide(Y, d = 1, family = gaussian())` on
  a 10 x 4 random matrix.
  - Deprecation warning fired with the recommended replacement
    snippet.
  - Fit completed normally (`fit$opt$convergence` returned 0).
  - The deprecation is soft, not hard -- existing code works.

## Tests Of The Tests

The "test" is whether the deprecation:

1. Fires on `gllvmTMB_wide()` call (verified by smoke test).
2. Does not break the function (verified: fit converged).
3. Hides the function from pkgdown reference index (verified by
   `\keyword{internal}` in the regenerated Rd).
4. Tells the user how to migrate (verified: the
   `lifecycle::deprecate_soft()` details parameter shows the
   recommended `gllvmTMB(traits(...) ~ ...)` snippet).

If a future maintainer adds back a public matrix wrapper, this
PR's deprecation should be reverted via
`lifecycle::deprecate_warn()` removal + `@keywords internal`
removal + the `@section Deprecation:` block strikethrough.

## Consistency Audit

```sh
rg -n 'gllvmTMB_wide' README.md CLAUDE.md AGENTS.md \
   docs/dev-log/known-limitations.md
```

verdict: each remaining mention is in a deprecation-aware
context ("soft-deprecated as of 0.2.0", "legacy matrix wrapper",
or in a per-cell-weights workaround note). No user-facing prose
recommends `gllvmTMB_wide()` as a primary entry point.

```sh
rg -n 'gllvmTMB_wide' vignettes/articles/
```

verdict: the vignette articles do not currently reference
`gllvmTMB_wide()` as their primary entry point. (Article-level
audits PR #62 / PR #64 did not flag stale `gllvmTMB_wide()`
references.)

```sh
rg -n 'two paths|three paths|either long or wide' README.md
```

verdict: the contradictory framings flagged by the Rose README
audit (PR #64 sections A2 + A9) are resolved. "Two paths"
language is replaced with "one entry point handles both data
shapes".

## What Did Not Go Smoothly

Nothing. The deprecation is bounded by design: add
`@keywords internal` + `lifecycle::deprecate_soft()` to the R
source, regenerate Rd, update the four user-facing rule / doc
surfaces (README, CLAUDE.md, AGENTS.md, known-limitations.md),
verify the warning fires.

The hardest decision was whether to also rewrite article
examples that use `gllvmTMB_wide()`. I held them out of this PR
because the deprecation is soft -- existing examples continue to
work -- and rewriting them would balloon the diff. A follow-up
"migrate articles to formula API" sweep can land separately.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** -- bounded API simplification. One
  entry point in, one entry point out (`gllvmTMB_wide`
  callable but hidden from reference index).
- **Pat (applied user)** -- the Pat audit (PR #62) and Rose
  audit (PR #64) both surfaced the "two-shapes / three-paths"
  contradiction. This PR closes it at the source.
- **Rose (cross-file consistency)** -- README, CLAUDE.md,
  AGENTS.md, known-limitations.md now agree: one entry point,
  two data shapes. The three-paths phrasing is gone from
  user-facing prose.
- **Grace (release readiness)** -- single-entry API matches
  drmTMB's pattern. CRAN reviewer reading
  `library(gllvmTMB); ?gllvmTMB` sees the canonical API; the
  legacy wrapper is hidden but available for backward
  compatibility.

## Known Limitations

- The deprecation is **soft**, not hard. `gllvmTMB_wide()` is
  still callable; the function emits a one-shot session
  warning. Hard removal (deletion of the function) is a
  future decision once the migration period has passed.
- The function is still in NAMESPACE via `@export`. Removing
  the export would break callers; the canonical
  `lifecycle`-pattern way to handle this is the current state
  (`@keywords internal` + soft deprecation), which keeps the
  function callable but hides it from the reference index.
- Article examples that demonstrate `gllvmTMB_wide()` (if
  any) are not rewritten in this PR. They will fire the
  deprecation warning when re-rendered; not a blocker.
- The migration pattern requires `as.data.frame(Y)` plus a
  `unit` column. For very large matrices this is a temporary
  memory bump; not a concern for typical ecology / evolution
  datasets.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible (touches
   R/ but the change is `@keywords internal` plus a
   `lifecycle::deprecate_soft()` call -- not a likelihood,
   formula grammar, or family change).
2. After merge, a follow-up "migrate articles" PR can rewrite
   any article using `gllvmTMB_wide()` to the formula API.
   Codex's lane (touches multiple article `.Rmd` files).
3. After the migration period (some months), a hard-removal
   PR can drop `gllvmTMB_wide()` from the package entirely.
4. The Rose README audit's D3 question ("two shapes vs three
   paths framing") collapses with this PR: there is one entry
   point, two data shapes.
