# After Task: call uncalled family constructors before the multinomial scan (#1781)

## 1. Goal

`gllvmTMB(family = gaussian)` stopped in `expand_multinomial_response()` with `cannot coerce type 'closure' to vector of type 'character'`, before `family_to_id()` could call the constructor. The same crash hid `family = multinomial`.

## 2. Implemented

An uncalled constructor is called once, with its defaults, and the family object is what the rest of the fit sees. `family = gaussian()` and `family = "gaussian"` are unchanged. `family = multinomial` is still expanded. A constructor that errors, or that does not return a family object, stops with class `gllvmTMB_family_constructor`.

## 3. Files Changed

- `R/gllvmTMB.R` — `.gllvmTMB_resolve_family_constructors()`
- `tests/testthat/test-1781-family-constructor.R`
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-12-1781-family-constructor.md`
- `docs/dev-log/after-task/2026-11-12-1781-family-constructor.md`

No README, roxygen, Rd, design-doc, or validation-debt edit. The public default is unchanged.

## 3a. Decisions and Rejected Alternatives

**Decision**: Call the constructor, matching `family_to_id()`.
**Rationale**: That function already accepts `family = gaussian`. The crash was only the earlier scan (#1781).
**Rejected alternative**: Refuse every uncalled constructor. That would still be a new error for a form `family_to_id()` already fits once the scan is passed.
**Confidence**: high.

## 4. Checks Run

Installed main: 3 tests errored on the closure coercion; `family = "gaussian"` passed (2 expectations). Source fix: FAIL 0 / ERROR 0 / 4 tests / 8 expectations. See the check-log file for the commands.

## 5. Tests of the Tests

- `#1781 family = gaussian (the function) fits` — failure-before-fix. Errors on main, passes with the fix.
- `#1781 family = multinomial (the function) still expands the response` — failure-before-fix, and the boundary that the constructor must still be detected as multinomial.
- `#1781 a constructor that cannot be called stops with a gllvmTMB error` — failure-before-fix for the classed error (main throws the closure error instead).
- `#1781 family = "gaussian" still fits` — prophylactic. Passes on main and with the fix (`family_id` 0).

## 6. Consistency Audit

`rg -n "as.character\(f\)" R/gllvmTMB.R` still matches the character-family branch, which is the right path for `family = "multinomial"`. `rg -n "gllvmTMB_family_constructor" R tests NEWS.md` matches the new class in `R/gllvmTMB.R` and the test. The closing-keyword scan hits a pre-existing NEWS sentence ("Fixes include:") and the scan lines in this report and the check-log. This slice's NEWS bullet does not use those words.

## 7. Roadmap Tick

N/A.

## 8. What Did Not Go Smoothly

The first character-family assertion read `fit$family$family`. A character `family = "gaussian"` stores the string, so that assertion failed on main for a reason other than the bug. The guard now checks `family_id_vec`.

## 9. Team Learning

- Boole: the scan and `family_to_id()` now agree on an uncalled constructor.
- Curie: the regression tests error on installed main.
- Pat: the error for a constructor that cannot be called names `gaussian()` and a character name.

## 10. Known Limitations and Next Actions

Constructors that need arguments still have to be called by the user (`binomial(link = "probit")`). No validation-debt row changes. Full `R CMD check` was not run.
