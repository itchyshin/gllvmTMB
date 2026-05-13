# After-Task: "two-U decomposition" prose fix

## Goal

Maintainer ratified 2026-05-13 ~08:30 MT (in PR #71 follow-up):
canonical replacement phrasing for "two-U decomposition" in
user-facing prose is **"paired phylogenetic decomposition"**.
Function names with `two_U` stay as legacy task labels per
PR #40 (`compare_dep_vs_two_U()`, `compare_indep_vs_two_U()`,
`extract_two_U_via_PIC()`).

Per the PR #71 reference-index audit Section A: 7 R/ source hits
+ 3 autogen Rd hits to replace.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

Seven R/ roxygen / error-message edits:

- **`R/extract-two-U-cross-check.R`** (2 hits):
  - L316 `@title`: "Canonical likelihood-based cross-check for the **paired phylogenetic decomposition**"
  - L486 `@title`: "Cheap diagonal cross-check for the **paired phylogenetic decomposition** (large T)"
- **`R/extract-two-U-via-PIC.R`** (1 hit):
  - L304 `@details`: "the four components of the **paired phylogenetic decomposition**:"
- **`R/brms-sugar.R`** (2 hits):
  - L1012 (in the `phylo_indep` roxygen): "paired with `phylo_unique()` for the **paired phylogenetic decomposition**"
  - L1206 (in the `phylo_dep` roxygen): "rank-reduced **paired phylogenetic decomposition**"
- **`R/fit-multi.R`** (2 hits, error messages):
  - L373 (`phylo_dep` + `phylo_latent` over-parameterised error): "for the **paired phylogenetic decomposition**"
  - L408 (`phylo_indep` + `phylo_latent` over-parameterised error): same

`devtools::document()` regenerated 5 Rd files:

- `man/compare_dep_vs_two_U.Rd` (title)
- `man/compare_indep_vs_two_U.Rd` (title)
- `man/extract_two_U_via_PIC.Rd` (details)
- `man/phylo_indep.Rd` (autogen pickup from R/brms-sugar.R + R/fit-multi.R)
- `man/phylo_dep.Rd` (same)

The PR does NOT:

- Change any function name with `two_U` (legacy task labels stay,
  per PR #40).
- Change file names (`R/extract-two-U-cross-check.R`,
  `R/extract-two-U-via-PIC.R`, `tests/testthat/test-phylo-two-U-recovery.R`).
- Change test names or article cross-references using `two_U`
  as a function-name reference.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE
export, vignette, or pkgdown navigation change. Roxygen prose
replacement + 5 Rd regenerations. Function bodies unchanged.

## Files Changed

- `R/extract-two-U-cross-check.R` (M, 2 lines)
- `R/extract-two-U-via-PIC.R` (M, 1 line)
- `R/brms-sugar.R` (M, 2 lines)
- `R/fit-multi.R` (M, 2 lines)
- `man/compare_dep_vs_two_U.Rd` (M, autogen)
- `man/compare_indep_vs_two_U.Rd` (M, autogen)
- `man/extract_two_U_via_PIC.Rd` (M, autogen)
- `man/phylo_indep.Rd` (M, autogen)
- `man/phylo_dep.Rd` (M, autogen)
- `docs/dev-log/after-task/2026-05-13-two-U-prose-fix.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open Claude PRs (#70 Codex-pause
  coord-board; #71 reference-index audit). Neither touches R/
  or man/. Safe. Codex is paused (per #70).
- Source verification: `rg -n 'two-U decomposition' R/` after
  the edits returns zero hits.
- `devtools::document(quiet = TRUE)`: regenerated 5 Rd files
  as expected (the 2 title-changed Rd + 1 details-changed Rd
  + 2 autogen pickups from error-message changes).
- Rendered-Rd spot-check per PR #36 protocol on each of the
  5 regenerated Rd files: `tail -3` clean (ends with `}`
  closing a normal Rd section), `grep -c '^\\keyword'`
  returns 0 or 1 (no roxygen-tag-after-prose drift).

## Tests Of The Tests

The "test" is whether the user-facing reference index now
reads with the canonical phrasing. After this PR:

- `?compare_dep_vs_two_U` title: "Canonical likelihood-based
  cross-check for the paired phylogenetic decomposition".
- `?compare_indep_vs_two_U` title: same pattern.
- `?extract_two_U_via_PIC` details: "the paired phylogenetic
  decomposition".
- Error messages from `phylo_dep + phylo_latent` and
  `phylo_indep + phylo_latent` over-parameterisation guards
  point users at "the paired phylogenetic decomposition".

If future prose introduces a new "two-U decomposition" hit
(e.g. in a Tier-2 article), the audit-protocol grep
(`rg -n 'two-U decomposition'`) catches it.

## Consistency Audit

```sh
rg -n 'two-U decomposition' R/ man/
```

verdict: zero hits after this PR.

```sh
rg -n 'two_U' R/ man/ | head -5
```

verdict: remaining hits are all function names
(`compare_dep_vs_two_U`, `compare_indep_vs_two_U`,
`extract_two_U_via_PIC`) and file-path references
(`R/extract-two-U-cross-check.R`,
`R/extract-two-U-via-PIC.R`). All are legacy task labels per
PR #40 and stay.

```sh
rg -n 'paired phylogenetic decomposition' R/ man/
```

verdict: 7 R/ hits + 5 Rd hits, all in the contexts the audit
proposed.

## What Did Not Go Smoothly

Nothing. The fix was bounded by the audit's Section A catalog:
7 hits, surgical edit per location, single
`devtools::document()` to pick up the autogen Rd refresh.

The autogen pickup surprised me slightly:
`devtools::document()` regenerated `man/phylo_indep.Rd` and
`man/phylo_dep.Rd` even though the roxygen above their function
definitions wasn't touched. The reason: the `phylo_indep` /
`phylo_dep` roxygen references the error-message paths in
`R/fit-multi.R` via cross-link markup, and the autogen rebuild
picked up the new error-message wording. Net: still safe; the
two extra Rd files match the new prose.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user)** -- the user-facing reference index
  is the first thing Pat reads after deciding to use the
  package. Removing the legacy "two-U" prose makes the
  reference page read consistently with PR #40 (S/s
  notation) and PR #53 (the paired phylogenetic-gllvm
  article).
- **Rose (cross-file consistency)** -- 7 hits across 4 files
  + 5 Rd files all converge on one canonical phrase. No
  drift remains.
- **Noether (math consistency)** -- the canonical phrasing
  matches the PR #53 article opener ("separate
  phylogenetically conserved trait covariance from
  non-phylogenetic species-level covariance") without
  introducing new notation.
- **Ada (orchestrator)** -- small focused PR; Claude lane;
  Codex paused (per #70), but this PR only touches roxygen
  prose, not source, so no Codex-lane infringement.

## Known Limitations

- The legacy task labels `two_U` in function names, file
  names, and test names are preserved. If a future maintainer
  decides to rename them (e.g. to `compare_dep_vs_paired()`),
  the API surface changes and the migration is bigger; out of
  scope here.
- "Two-U" still appears in `tests/testthat/test-phylo-two-U-recovery.R`
  and similar test-file names. Test files are not user-facing,
  so this is acceptable; flagged if the maintainer wants
  consistency across the entire repo.
- Article cross-references to `compare_dep_vs_two_U()` and
  `compare_indep_vs_two_U()` stay valid because the function
  names are unchanged.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible per
   `docs/dev-log/decisions.md`: documentation prose fix
   touching roxygen + autogen Rd, no API / NAMESPACE / family /
   likelihood / formula-grammar change.
2. After merge, the pkgdown reference index rebuilds and the
   "two-U decomposition" wording is gone from user-facing
   prose.
3. Next Claude lane (per the Codex pause queue): navbar
   restructure PR (`_pkgdown.yml`), which bundles the PR #71
   Section B reference-grouping fix.
