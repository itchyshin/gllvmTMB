# After Task: Revise #1757 traits() intercept draft for review BLOCKED items

**Branch**: `cursor/fix-1757-traits-implicit-intercept-0b8b` (PR #1774, stays draft)
**Date**: `2026-11-11`
**Roles (engaged)**: Boole (formula grammar), Curie (tests of the tests), Rose (consistency), Ada (owner option 1)

## 1. Goal

Keep the owner decision that wide `traits()` formulas follow the usual R
intercept default, and apply the code-review BLOCKED list on PR #1774:
drop the `shared()` skip, restore slope-only screen parity, tighten the
new intercept test so it actually fails on `main`, and write explicit
`1 +` in the named heavy / screen formulas. Leave `column_data`
main-effect errors untouched.

## 2. Implemented

`rewrite_traits_lhs()` still prepends `0 + trait` when
`terms(~ compact_rhs)` has an intercept and the expanded RHS does not
already carry one. It no longer skips that step because the compact RHS
mentions `shared()`. `~ shared(x)` and `~ z + shared(x)` therefore get
per-trait intercepts plus the common slope, matching `~ 1 + ...`.
`~ 0 + shared(1 + latitude)` is unchanged (compact `terms()` intercept
is 0). A user-defined `shared()` function is no longer treated as the
internal marker for this skip, because the skip is gone.

`?traits` now reads "compact wide shorthand, which follows the usual R
formula intercept rule".

## 3. Files Changed

- `R/traits-keyword.R` — removed `.traits_rhs_contains_shared()`; intercept
  injection uses only `terms()` + existing trait-intercept detection;
  roxygen grammar comma
- `man/traits.Rd` — same grammar sentence (hand-aligned; `document()` not run)
- `tests/testthat/test-fix-1757-traits-implicit-intercept.R` — anchored
  `^0 + trait`; dropped the duplicate `(0 + trait):x` line; added `-1`,
  `x - 1`, `+0`, `shared(x)`, `z + shared(x)`; `set.seed(1)` on block 2
- `tests/testthat/test-column-coef-foundation.R` — `~ shared(latitude)`
  is 4 design columns; user-defined `shared()` RHS must start with
  `0 + trait`
- `tests/testthat/test-screen-separation.R` — `traits(a, b) ~ 0 + x`
  against long `y ~ 0 + trait:x`
- `tests/testthat/test-screen-gllvmTMB.R` — wide `~ 1 + x + latent(...)`
  against long `~ 0 + trait + trait:x + latent(...)`
- `tests/testthat/test-missing-predictor-{binary,categorical,ordered,gaussian}.R`
  — `1 + z + mi(...)` as in the existing gaussian:599 contract
- `docs/dev-log/check-log.d/2026-11-11-fix-1757-traits-intercept-review.md`
- `docs/dev-log/after-task/2026-11-11-fix-1757-traits-implicit-intercept-review.md`

Not edited: `docs/design/131-response-column-coefficient-foundation.md` §4;
`NEWS.md` (already states the R intercept rule); `src/`; CI; parity files.

## 3a. Decisions and Rejected Alternatives

- **Decision:** remove the `shared()` exception entirely rather than
  restrict it to the internal marker. Rationale: `~ shared(x)` still has
  `terms()` intercept 1, so skipping injection reintroduces #1757; a
  name walk also matches a user `shared()` function.
- **Rejected:** keep skipping only when `.shared_marker_active()` is
  true. That still silently drops per-trait intercepts on
  `~ shared(x)` / `~ z + shared(x)`.
- **Rejected:** change `column_data` main-effect `~ pathway` /
  `~ leaf_area` so they fit instead of `gllvmTMB_rank_deficient_design`.
  Awaits Shinichi; Design 131 §4 left as-is.
- **Confidence:** high on the skip removal and regex anchoring; tests
  were not executed on this VM.

## 4. Checks Run

R is not installed on this VM (`R` / `Rscript` absent from PATH and from
`/usr`, `/usr/local`, `/opt`, `$HOME`). Per the task rule, no install was
attempted and no testthat result is claimed.

Static scans (this slice):

```sh
rg -n "traits_rhs_contains_shared" R tests
rg -n "shorthand follows" R/traits-keyword.R man/traits.Rd
rg -n "shared\\(\\.\\.\\.\\) fixed-effect blocks are left unchanged"
rg -n "\\bS_B\\b|\\bS_W\\b" R/traits-keyword.R man/traits.Rd NEWS.md tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "gllvmTMB_wide" R/traits-keyword.R man/traits.Rd NEWS.md
rg -n "meta_known_V" R/traits-keyword.R man/traits.Rd NEWS.md
```

Not run: `devtools::test()`, `devtools::document()`,
`pkgdown::check_pkgdown()`, `devtools::check()`, article render.

## 5. Tests of the Tests

- **Failure-before-fix (designed, not executed here):** anchored
  `^0 \\+ trait` on implicit `~ x` matches only a leading intercept.
  On `main` the expanded RHS starts with `(0 + trait):x`, so the old
  unanchored `0 \\+ trait` passed and the new one must fail. Block 2
  still requires 6 coefficients for `~ x` / `~ 1 + x` and 3 for
  `~ 0 + x`.
- **Boundary:** `-1`, `x - 1`, `+0` must not inject; `shared(x)` and
  `z + shared(x)` must inject; user-defined `shared()` must still
  expand to a trait interaction *and* carry `0 + trait`.
- **Feature combination:** screen slope-only parity (`~ 0 + x` vs
  `0 + trait:x`); heavy `mi()` formulas write `1 +` so they do not
  silently change meaning relative to the long-hand gaussian:599
  contract.

No tolerance, skip, or nocov was added.

## 6. Consistency Audit

| Pattern | Verdict |
| --- | --- |
| `rg -n "traits_rhs_contains_shared" R tests` | PASS — 0 hits |
| `rg -n "shorthand follows" R/traits-keyword.R man/traits.Rd` | PASS — 0 hits (comma form is present) |
| `rg -n "\\bS_B\\b\|\\bS_W\\b" R/traits-keyword.R man/traits.Rd NEWS.md tests/testthat/test-fix-1757-traits-implicit-intercept.R` | PASS — 0 hits |
| `rg -n "gllvmTMB_wide" R/traits-keyword.R man/traits.Rd NEWS.md` | PASS — still described as soft-deprecated, not primary |
| `rg -n "meta_known_V" R/traits-keyword.R man/traits.Rd NEWS.md` | PASS — 0 hits in the touched public files |
| Design 131 §4 | PASS — not edited |
| NEWS vs `shared()` skip | PASS — NEWS never promised a `shared()` exception; code now matches that |

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row moved.

## 7a. GitHub Issue Ledger

- Inspected [#1757](https://github.com/itchyshin/gllvmTMB/issues/1757):
  silent drop of per-trait intercepts on compact `traits()` RHS.
- Inspected draft [#1774](https://github.com/itchyshin/gllvmTMB/pull/1774):
  revised in place; remains draft; not merged.
- No new issue. `column_data` main-effect `~ pathway` / `~ leaf_area`
  rank-deficiency is left for Shinichi as instructed.

## 8. What Did Not Go Smoothly

This VM has no R, so fail-on-main / pass-on-branch for the tightened
counts could not be demonstrated. The regex change is the part that was
shown to be a false pass on `main` by inspection (`0 \\+ trait` is a
substring of `(0 + trait):x`). CI on PR #1774 has to be the first
execution of the revised files.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Boole: a `shared()` name walk is not a grammar exception. R's intercept
bit on `terms(~ compact_rhs)` already decides `~ shared(x)` vs
`~ 0 + shared(1 + x)`; extra AST matching both reopened #1757 and
collided with a user function of the same name.

Curie: `expect_match(..., "0 \\+ trait")` is not a test of a leading
intercept when the expander always emits `(0 + trait):x`. Anchor at
`^` or the assertion passes on the bug.

Rose: the first-draft PR body said `shared(...)` blocks were left
unchanged while NEWS said the compact RHS follows the R intercept rule.
Those two sentences cannot both be true.

Ada: `column_data` main effects stay on the rank-deficient error until
an explicit owner call; this slice does not interpret that error as
in-scope.

## 10. Known Limitations And Next Actions

- R was unavailable here; run
  `test-fix-1757-traits-implicit-intercept.R`,
  `test-column-coef-foundation.R`, `test-screen-separation.R`,
  `test-screen-gllvmTMB.R`, and `test-traits-keyword.R` under a real
  `R CMD INSTALL` / `devtools::test()` before merge.
- `column_data` main-effect `traits(...) ~ pathway` /
  `~ leaf_area` still error with `gllvmTMB_rank_deficient_design`
  (Shinichi).
- Heavy `mi()` files keep `skip_if_not_heavy()`; only the formula
  spelling changed.
- PR #1774 stays draft until CI and maintainer review.
