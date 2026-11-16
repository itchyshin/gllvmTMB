# After Task: resolve family constructors at gllvmTMB() entry (refs #1781)

**Branch**: `cursor/fix-1781-family-constructor-382a`
**Date**: `2026-11-16`
**Roles (engaged)**: Boole, Curie, Pat, Rose

## 1. Goal

Code Reviewer blocked PR #1784 because `.gllvmTMB_resolve_family_constructors()` ran only inside `expand_multinomial_response()`. `gllvmTMB()` still read `family` earlier: `temporal_latent()` did `family$family` on a closure, and `.column_coef_assert_gaussian_family()` rejected `family = gaussian` because a closure fails `inherits(x, "family")`.

## 2. Implemented

`gllvmTMB()` now calls `.gllvmTMB_resolve_family_constructors(family)` once after the optional-slot defaults and before the wide/traits rewrite. The existing call in `expand_multinomial_response()` remains and is a no-op on an already-resolved family. Two new tests fit `temporal_latent()` and `column_coef()` with `family = gaussian` and compare them to `family = gaussian()`. Existing tests, tolerances, and timeouts are unchanged.

## 3. Files Changed

- `R/gllvmTMB.R` — entry-point resolve; comment on the helper
- `tests/testthat/test-1781-family-constructor.R` — two added tests
- `NEWS.md` — #1781 bullet names the earlier gates
- `docs/dev-log/check-log.d/2026-11-16-1781-family-constructor-gates.md`
- `docs/dev-log/after-task/2026-11-16-1781-family-constructor-gates.md`

No README, roxygen, Rd, design-doc, or validation-debt edit. The public default is still `gaussian()`.

## 3a. Decisions and Rejected Alternatives

**Decision**: Call the existing helper at the top of `gllvmTMB()`, leave the multinomial-scan call in place.
**Rationale**: That is the reviewer's requested shape. One resolve covers every later `$family` / `inherits(..., "family")` gate without teaching those gates about constructors.
**Rejected alternative**: Teach the two gates to call constructors themselves. That would leave the next early reader of `family` as a new crash.
**Confidence**: high.

## 4. Checks Run

Installed source tree, then `testthat::test_file("tests/testthat/test-1781-family-constructor.R", package = "gllvmTMB")`: FAIL 0 / ERROR 0 / 6 tests / 22 expectations. See the check-log file for the commands.

## 5. Tests of the Tests

- `#1781 family = gaussian fits temporal_latent the same as gaussian()` — failure-before-fix for the `$family` gate; compares `opt$par`, `logLik`, and `use_temporal`.
- `#1781 family = gaussian fits column_coef the same as gaussian()` — failure-before-fix for the `inherits(..., "family")` gate; compares `opt$par`, `logLik`, and `response_column_coef`.
- The four tests from 2026-11-12 are unchanged.

## 6. Consistency Audit

`rg -n "gllvmTMB_resolve_family_constructors" R/gllvmTMB.R` matches the new entry call, the helper, and the scan no-op. `rg -n "Fixes |Closes |Resolves "` on this slice's NEWS, tests, check-log, and after-task hits only the pre-existing NEWS sentence ("Fixes include:"). This slice does not use those words.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

Inspected #1781 (this slice) and closed #1353 (a different character-family bug: `could not find function "f"` in `family_to_id()`). Searched open issues for character `family = "gaussian"` on the `temporal_latent()` `$family` gate: none at search time. The maintainer filed [#1804](https://github.com/itchyshin/gllvmTMB/issues/1804). This slice does not close #1781 or #1804.

## 8. What Did Not Go Smoothly

The cloud image had no R. Tests ran after installing CRAN R 4.6.2 and r2u binaries. Character `family = "gaussian"` on `temporal_latent()` still errors with `$ operator is invalid for atomic vectors`; that path is out of this slice.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Boole: one resolve at entry is the right API seam; per-gate constructor calls would miss the next reader of `family`.

Curie: the new tests fail on the previous head (closure at the temporal gate; Gaussian-only refusal at `column_coef`) and pass when the constructor is called first.

Pat: `family = gaussian` now fits the two routes a user already writes with `gaussian()`. The error for a constructor that cannot be called is unchanged.

Rose: NEWS names the earlier gates and does not claim that a character family is fixed.

## 10. Known Limitations And Next Actions

Character `family = "gaussian"` still breaks the `temporal_latent()` gate (`$` on an atomic). That is [#1804](https://github.com/itchyshin/gllvmTMB/issues/1804) (refs #1781), not fixed here. Constructors that need arguments still have to be called by the user (`binomial(link = "probit")`). No validation-debt row changes. Full `R CMD check` was not run.
