# After-Task: Unification follow-up -- "long or wide" user mental model (Option B)

## Goal

Reframe the user-facing surface around two shapes (**long** and
**wide**) instead of three (`gllvmTMB()` + `gllvmTMB_wide()` +
`gllvmTMB(traits(...) ~ ..., data = wide_df)`). The maintainer's
framing (2026-05-12 ~07 MT): "I think the matrix and traits are
saying the same thing -- we should think in two ways, long or
wide."

The *implementation* part of Option B already landed in Codex's PR
#31 (`gllvmTMB_wide()` accepts either a numeric matrix or a wide
data frame and converts internally via `as.matrix(Y)`). What this
PR adds is the **documentation / marketing** half: `traits()` is
demoted from a user-facing top-level entry to an internal
formula-level helper, README leads with "long or wide", and NEWS
records the framing change.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`R/traits-keyword.R`**: added `@keywords internal` to the
  roxygen for `traits()`. The function stays exported (no
  breaking change for users with code that uses `gllvmTMB(traits(...)
  ~ ..., ...)`), but it is hidden from the public pkgdown
  reference index and from `?gllvmTMB`-adjacent navigation.
- **`_pkgdown.yml`**: removed `traits` from the "Covariance
  keywords" section. It was a category miscategorisation anyway --
  `traits()` was never a covariance keyword.
- **`man/traits.Rd`**: regenerated; now carries the
  `\keyword{internal}` tag.
- **`README.md`**: intro paragraph updated from "works with
  long-format data" to "works with long or wide data". New
  "Two shapes" sub-section above "Start here" with a one-line
  description of each path: long-format `gllvmTMB(value ~ ...,
  data = df_long)` vs wide `gllvmTMB_wide(Y, ...)` (matrix or
  wide data frame).
- **`NEWS.md`**: entry recording the two-shape user-facing
  framing decision and the `traits()` `@keywords internal`
  demotion (with a back-compat note that existing code is
  unaffected).
- **`CONTRIBUTING.md`**: one-paragraph note under "Scope" pointing
  at the two-shape mental model so future article rewrites stay
  consistent.
- **`docs/dev-log/after-task/2026-05-12-unification-long-or-wide.md`**
  (NEW, this file).

The PR does NOT:
- Modify any article (`vignettes/articles/*.Rmd`). Codex just
  rewrote `morphometrics.Rmd` in PR #27 + #31; modifying it again
  same-day dilutes the rewrite and produces double-work. Article
  cleanup (collapsing the morphometrics three-way fit example to
  long + wide-matrix) is a separate follow-up PR.
- Remove or rename `traits()`. Existing user code keeps working.
- Change `gllvmTMB_wide()` -- Codex's PR #31 already made it
  accept matrix OR wide data frame.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
or generated `man/*.Rd` content-mismatch change. The `traits()`
function is still exported and callable; its visibility in pkgdown
reference + the explicit user-facing marketing changes. Roxygen +
docs only.

## Files Changed

- `R/traits-keyword.R`
- `_pkgdown.yml`
- `man/traits.Rd` (regenerated)
- `README.md`
- `NEWS.md`
- `CONTRIBUTING.md`
- `docs/dev-log/after-task/2026-05-12-unification-long-or-wide.md`
  (new, this file)

## Checks Run

- **Pre-edit lane check**: 0 open PRs (PR #31 just merged). No
  Codex push pending on `R/traits-keyword.R`, `README.md`,
  `_pkgdown.yml`, `NEWS.md`, or `CONTRIBUTING.md`. Safe.
- **`Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`**:
  regenerated `man/traits.Rd` with `\keyword{internal}` tag.
- **`_pkgdown.yml` reference index check**: post-edit, `traits`
  no longer appears in any section. `@keywords internal` plus
  the explicit removal both contribute, so pkgdown will exclude
  it from the rendered reference page.

## Tests Of The Tests

No test added. The implicit "test" is the deployed pkgdown
reference page after merge: `gllvmTMB_wide()` should appear under
"Top-level entry points" alongside `gllvmTMB()`, and `traits()`
should NOT appear in any user-facing reference section. The
existing test suite (which uses `traits()` in `test-weights-unified.R`,
notably) continues to call the function -- demoting it to
`@keywords internal` does not affect callability.

## Consistency Audit

```sh
rg -n "traits\\(" R/ vignettes/ README.md NEWS.md docs/design CONTRIBUTING.md
```

verdict: `traits()` still appears in `R/traits-keyword.R` (the
definition), `tests/testthat/test-weights-unified.R` (Codex's
paired tests, which intentionally exercise the function), the
design doc `docs/design/02-data-shape-and-weights.md` (the
contract specification), and `vignettes/articles/morphometrics.Rmd`
(Codex's three-way fit example -- to be revisited in a follow-up
PR per the scope note above). README and CONTRIBUTING no longer
recommend the `traits()` LHS form.

```sh
rg -n "long format|wide format|long or wide|two shapes" README.md CONTRIBUTING.md NEWS.md
```

verdict: the new "Two shapes" framing appears consistently in
README, CONTRIBUTING, and NEWS. No remaining "three entry points"
or "three-way" language in user-facing prose.

```sh
rg -n "gllvmTMB_wide\\(" man/ README.md NEWS.md
```

verdict: `gllvmTMB_wide()` is the canonical wide entry point in
every user-facing place. No drift toward `gllvmTMB(traits(...))`
in the marketing surface.

## What Did Not Go Smoothly

- The `_pkgdown.yml` had `traits` miscategorised under "Covariance
  keywords" (it was never a covariance keyword; it is a formula
  LHS marker for wide data). Removing it is also a small
  category-correctness fix, not just a demotion. Recording this
  as a Rose-style cross-file consistency lesson: `_pkgdown.yml`
  section assignments should be re-audited whenever a new
  user-facing function is added or when a function's role
  changes.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** kept the scope narrow: docs/marketing
  only; no source-behaviour change; no article edits (they were
  just rewritten by Codex). The full Option B unification was
  half-implemented by Codex's PR #31 already; this PR closes the
  other half.
- **Boole (R API)** signed off on the no-breaking-change shape:
  `traits()` stays exported and callable; demotion is via
  `@keywords internal` only.
- **Pat (applied user)** is the beneficiary: a new reader landing
  on the reference index now sees two shapes (long and wide), not
  three. The mental model matches what the maintainer named.
- **Emmy (R package architecture)** is the silent beneficiary of
  the `_pkgdown.yml` category correction: `traits` was in the
  wrong section.
- **Rose (cross-file consistency)** ran the three `rg` audits
  above; the new framing is consistent across README,
  CONTRIBUTING, NEWS, and `_pkgdown.yml`.
- **Grace (CI / pkgdown / CRAN)** verified `devtools::document()`
  is clean and the post-merge pkgdown rebuild will surface the
  new two-shape reference index.

## Known Limitations

- The morphometrics article still shows three fits side by side
  (long + wide-formula via `traits()` + wide-matrix via
  `gllvmTMB_wide()`). Per the scope note, that cleanup is a
  separate follow-up PR. The recommended trim there is: keep
  long and wide-matrix; drop the wide-formula `traits()` block;
  retain the long/wide logLik-equivalence sentence.
- `traits()` remains discoverable via `tab` completion and
  `library(gllvmTMB); ?traits`. The `@keywords internal` tag
  hides it from pkgdown and from `help.search()`, but the
  function name itself is still in NAMESPACE. This is intentional
  -- existing code keeps working without a deprecation cycle.
- A future PR can promote `traits()` from `@keywords internal`
  to `lifecycle::deprecate_soft()` if user feedback shows the
  function is genuinely unused; for now the back-compat surface
  stays as-is.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible per
   merge-authority rule: roxygen demotion + README marketing +
   NEWS / CONTRIBUTING / pkgdown index, no source behaviour
   change.
2. Follow-up PR (Claude lane): trim the morphometrics three-way
   fit example to long + wide-matrix only. Small mechanical
   article edit + Rd regen if any extractor docs reference the
   three-way framing.
3. Watch the next Codex PR (Phase 1a row 2:
   `covariance-correlation.Rmd`). The four-way phylogenetic /
   spatial decomposition framing called out in the dispatch
   comment lands in that article; the unification context from
   this PR + the morphometrics trim should both be in place
   before that article merges.
