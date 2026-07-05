# After Task: spatial orientation bare-name guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: 2026-07-05
**Roles (engaged)**: Ada / Boole / Curie / Rose / Shannon

## 1. Goal

Repair issue #627 locally: `spatial_*()` should not treat every bare
`name | name` bar as the deprecated `coords | trait` orientation. The real
deprecated alias remains accepted, but malformed forms such as `sp | coords`
now fail loud with a canonical-orientation message.

## 2. Implemented

- Tightened `normalise_spatial_orientation()` so the deprecated bare-name alias
  fires only when the RHS is the literal `trait` symbol.
- Added pure parser tests proving:
  - `spatial_unique(coords | trait)` still normalises to
    `spatial_unique(0 + trait | coords)`;
  - `spatial_unique(sp | coords)` errors instead of being flipped;
  - `spatial_indep(coords | trait)` remains canonical-only because
    `spatial_indep()` was introduced after the orientation flip.
- Updated validation-debt row `FG-13`.

## 3. Mathematical Contract

No likelihood, parameterisation, family, extractor, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change.

This is a formula-parser guard only. The canonical spatial keyword bar remains:

```text
0 + trait | coords
```

The deprecated compatibility alias remains:

```text
coords | trait
```

Any other bare-name pair is malformed because the parser cannot know whether the
user meant a trait symbol, a coordinates symbol, or a typo.

## 4. Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-spatial-orientation-parser.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-spatial-orientation-bare-name-guard.md`

## 3a. Decisions and Rejected Alternatives

Decision: recognise the deprecated alias only when the RHS is exactly
`trait`.

Rationale: that preserves the documented compatibility route while rejecting
the issue #627 failure mode, where `sp | coords` was silently inverted.

Rejected alternative: infer plausible coordinate names. That would be brittle
and would turn parser behavior into a heuristic over user column names.

## 4. Checks Run

```sh
Rscript --vanilla -e 'parse("R/brms-sugar.R"); parse("tests/testthat/test-spatial-orientation-parser.R"); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-orientation-parser.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-orientation.R")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-orientation.R")'
git diff --check
```

Outcomes: parser tests passed 6 assertions. The default
`test-spatial-orientation.R` run skipped under its CRAN guard; the
`NOT_CRAN=true` rerun passed 16 assertions and preserved the byte-identical
deprecated-alias fixture. `git diff --check` passed.

## 5. Tests Of The Tests

The new tests are boundary tests. They exercise the precise ambiguity from
issue #627 and the neighbouring accepted alias. They would have failed before
the fix because `spatial_unique(sp | coords)` was treated as a deprecated
orientation instead of an error.

## 6. Consistency Audit

```sh
rg -n "spatial_unique\\(sp \\| coords\\)|Only the deprecated orientation|coords \\| trait|name \\| name" R tests/testthat docs/design docs/dev-log/after-task docs/dev-log/check-log.md
```

Verdict: current references either document the accepted deprecated
`coords | trait` alias or the new malformed bare-name rejection.

## 7. Roadmap Tick

N/A. No roadmap status chip or public capability row changed.

## 7a. GitHub Issue Ledger

- Inspected #627: `spatial_*(<name> | coords)` with a non-`0+trait` LHS was
  silently reinterpreted as deprecated `coords | trait`. This slice implements
  the local fail-loud parser repair.
- #625, #626, and #632 were inspected in the same structural issue cluster; no
  additional edits for #625/#626 here because this branch already contains
  local repairs, and #632 was closed locally in the previous commit.

No GitHub comment or close was posted from this local-only branch.

## 8. What Did Not Go Smoothly

The existing spatial orientation fixture is skipped by default because of
`skip_on_cran()`. The guard was therefore validated in two layers: a pure parser
test that always runs locally, and the existing fit-based orientation suite with
`NOT_CRAN=true`.

## 9. Team Learning

Ada kept the change scoped to the ambiguous parser branch rather than changing
spatial keyword grammar broadly.

Boole preserved the compatibility syntax while making the malformed grammar
fail loud.

Curie added a pure parser regression so the guard is cheap and does not depend
on SPDE fitting.

Rose checked the claim boundary: this is not removal of `coords | trait`; it is
removal of an accidental reinterpretation of other bare-name bars.

Shannon confirmed the shared docs/dev-log edits stayed inside one local commit
on the completion branch.

## 10. Known Limitations And Next Actions

- The broader `spatial_*()` family remains `partial` in `FG-13`; this slice only
  locks one parser boundary.
- No user-facing documentation regeneration was needed because the documented
  accepted forms did not change.
- Continue the structural-dependency arc with the remaining issue queue after
  this local guard is committed.
