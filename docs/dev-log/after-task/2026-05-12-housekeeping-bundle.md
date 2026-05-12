# After-Task: Two small housekeeping items bundled

## Goal

Two pre-existing housekeeping items that surfaced during today's
PR flurry, bundled into one small PR so each does not need its
own CI cycle:

1. **`tidyselect` listed in both `Imports` and `Suggests`** -- the
   long-standing NOTE on every R CMD check run. The Suggests
   entry was added back in the 2026-05-10 bootstrap because of a
   misdiagnosed warning; per CRAN's "Writing R Extensions"
   §1.1.3 each package belongs in exactly one of
   `Depends / Imports / Suggests / Enhances`. `tidyselect` is
   used by `R/` (so it belongs in Imports) and by tests (which
   inherit from Imports automatically). Drop from Suggests.
2. **Rendered-Rd spot-check process lesson** -- after PR #32
   shipped a malformed `man/traits.Rd` (30+ garbage `\keyword{}`
   entries) and PR #33 fixed it, the after-task for PR #33 named
   the lesson but did not codify it in
   `docs/design/10-after-task-protocol.md`. Codify the
   spot-check pattern so future PRs that add tags after long
   descriptions get caught earlier.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`DESCRIPTION`** (M): removed `tidyselect` from `Suggests:`.
  It remains in `Imports:` (where it belongs because `R/` uses
  `tidyselect::all_of()` and related verbs). Tests automatically
  inherit Imports.
- **`docs/design/10-after-task-protocol.md`** (M): new section
  "Rendered-Rd Spot-Check" between "Prose Audit" and "Tests of
  the Tests". Codifies the `tail -5 man/<changed>.Rd` and
  `grep -c '^\\keyword' man/<changed>.Rd` checks after
  `devtools::document()` when a task adds tags after a long
  description block. References PR #32 + #33 as the worked
  example.
- **`docs/dev-log/after-task/2026-05-12-housekeeping-bundle.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated `man/*.Rd`, vignette, or pkgdown navigation change.
DESCRIPTION metadata + protocol-doc prose only.

## Files Changed

- `DESCRIPTION`
- `docs/design/10-after-task-protocol.md`
- `docs/dev-log/after-task/2026-05-12-housekeeping-bundle.md`
  (new, this file)

## Checks Run

- **Pre-edit lane check**: 1 open PR (#35, my Shannon audit) on
  `docs/dev-log/shannon-audits/` and `docs/dev-log/after-task/`;
  no overlap with `DESCRIPTION` or `docs/design/`. Codex's
  in-flight sweep on `codex/long-wide-example-sweep` is on
  articles + `docs/design/02-data-shape-and-weights.md` + dev
  notes; no overlap with `DESCRIPTION` or
  `docs/design/10-after-task-protocol.md`. Safe.
- **CRAN docs check** ("Writing R Extensions" §1.1.3): a package
  should be listed in only one of
  `Depends / Imports / Suggests / Enhances`. The pre-edit state
  had `tidyselect` in both Imports (line 44) and Suggests (line
  70). Post-edit, only in Imports.
- **Rationale for the original double-listing**: the
  2026-05-10 check-log entry says "added `tidyselect` to
  `Suggests:` so R CMD check finds the test-side namespace
  declaration too." That diagnosis was wrong: tests inherit
  Imports without needing a Suggests declaration. The NOTE
  surfaced by R CMD check after the Suggests addition was the
  actual signal that the duplicate listing was incorrect; this
  PR closes the loop.
- **`grep -c '^\\\\keyword' man/traits.Rd`**: 1 (sanity check
  that PR #33's fix is still in place; the protocol-doc lesson
  references this exact pattern).

## Tests Of The Tests

No new tests added. Implicit tests:

1. The next R CMD check run on main should drop the "Package
   listed in more than one of Depends, Imports, Suggests,
   Enhances: 'tidyselect'" NOTE. If the NOTE stays, the
   diagnosis here is wrong and we need to keep tidyselect in
   Suggests (which would mean removing from Imports instead).
2. The protocol-doc addition is documentation; the "test" is
   whether the next Codex or Claude PR that adds a roxygen tag
   actually runs the `tail -5` spot-check. The Codex
   reader-facing sweep PR (in flight) does not add new roxygen
   tags, so the rule's first real test will likely be Phase 1a
   row 2's `covariance-correlation.Rmd` rewrite or a later
   parser change.

The protocol-doc section was placed *before* "Tests of the
Tests" because the spot-check IS a test-of-the-test in a
documentation sense -- it tests that the generated Rd matches
the source roxygen intent.

## Consistency Audit

```sh
rg -n "tidyselect" DESCRIPTION
```

post-edit verdict: one mention, in `Imports:` block (line 44).
No double-listing.

```sh
rg -n "## " docs/design/10-after-task-protocol.md
```

post-edit verdict: nine top-level sections in order: Location,
Required Sections, Mathematical Contract, Consistency Audit,
Status Inventory, Prose Audit, **Rendered-Rd Spot-Check** (new),
Tests of the Tests, Closing Rule. No heading-level drift.

```sh
rg -n "PR #32|PR #33|malformed.*Rd|\\\\keyword" docs/design/10-after-task-protocol.md
```

post-edit verdict: the new section references PR #32 + #33 as
the worked example and shows the literal `\keyword{}` patterns
both as the failure mode (garbage entries) and the success mode
(single `\keyword{internal}`). Codex's review caught the issue;
this is the codified prevention.

## What Did Not Go Smoothly

Nothing significant. Two clean low-risk housekeeping changes in
one bundle.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Rose (cross-file consistency)** is the lead role: both items
  in this bundle are Rose-style cross-file findings. The
  tidyselect double-listing was flagged by R CMD check; the
  rendered-Rd lesson was flagged by Codex on PR #32. Rose's
  audit pattern caught both, even if not in real time.
- **Grace (CI / pkgdown / CRAN)** is the silent beneficiary:
  R CMD check NOTE drops; future PRs that add roxygen tags get a
  documented prevention.
- **Ada (orchestrator)** bundled the two items into one PR
  rather than two separate small PRs -- the items are
  thematically housekeeping, the diff is small (~15 lines
  total), and one CI cycle is cheaper than two.
- **Codex (implementer)** does not engage; this is Claude-lane
  housekeeping, no source behaviour.

## Known Limitations

- The R CMD check NOTE about `tidyselect` should drop after
  merge. If it does not, the diagnosis was wrong and a follow-up
  PR will need to re-add `tidyselect` to one of the fields. The
  conservative option (re-add to Imports if we accidentally
  removed from there too) is the safe fall-back.
- The Rendered-Rd Spot-Check section depends on `devtools::document()`
  being run as part of any roxygen-modifying PR. The CONTRIBUTING.md
  Development Checks section already names `devtools::document()`;
  the new protocol-doc section adds the post-document spot-check.
- Branch hygiene (22 merged-but-not-deleted origin branches from
  the Shannon audit finding) is **not** addressed by this PR.
  Branch deletion is destructive and needs explicit maintainer
  authorisation per the project rules; flagged in the Shannon
  audit doc (PR #35) and left for a separate decision.

## Next Actions

1. Maintainer reviews / merges (self-merge eligible: tooling
   metadata + design-doc prose, no source behaviour change).
2. After merge, R CMD check on main should drop the NOTE about
   `tidyselect`. Verify by inspecting the next main R-CMD-check
   run's "NOTE" line.
3. Continue idle until Codex's sweep PR appears.
