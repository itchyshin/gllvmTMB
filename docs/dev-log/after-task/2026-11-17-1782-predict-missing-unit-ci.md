# After Task: merge main into the missing-unit predict fix (#1782)

Reader: the next person looking at draft PR #1785.

## 1. Goal

`origin/main` had moved 18 commits past head `80ee4ae2`. Shard 3 of R CMD check and of coverage both failed on that head. Bring the branch up to date and make that failure a next-step bullet the existing ratchet accepts.

## 2. Implemented

`NEWS.md` was the only merge conflict. The #1782 unit-column bullet stays next to the #1781 family-constructor bullet from main. The #1787 species-column stop was already on both sides, in `predict.gllvmTMB_multi()` and in NEWS, and was left as main has it.

The unit-column abort still stops with class `gllvmTMB_predict_newdata_unit_missing` and still names the column and `re_form = ~0`. Its information bullet is now a `">"` next step. The bare-abort count goes from 771 back to 770, the ceiling on main. The ceiling was not raised.

## 3. Files Changed

- `NEWS.md` — merge resolution, both bullets kept
- `R/methods-gllvmTMB.R` — `">"` on the unit-column abort
- `docs/dev-log/check-log.d/2026-11-17-1782-predict-missing-unit-ci.md`
- `docs/dev-log/check-log.md` — pointer to that file
- `docs/dev-log/after-task/2026-11-17-1782-predict-missing-unit-ci.md`

The merge also brought in main's files (family constructor, kernel grouping, non-finite inputs, temporal marker name, README citation). No Rd, README, or design-doc edit in this follow-up. The help sentence already asks for the column or `re_form = ~0`.

## 3a. Decisions and Rejected Alternatives

**Decision:** Mark the new abort's instruction as a next step instead of raising the 770 ceiling.
**Rationale:** `dev/gapclose/count-bare-aborts.R` counts an `"i"` or `"x"` bullet as bare. The test at `test-gapclose-next-steps.R:238` may only fall. The rendered words already told the user what to do.
**Rejected alternative:** Raise `770L`. That weakens the ratchet.
**Confidence:** high. The diff against main's `R/` is exactly that one message.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-17-1782-predict-missing-unit-ci.md`. Bare-abort count 770. `#1782` FAIL 0 / PASS 6. `#1787` FAIL 0 / PASS 7. Ratchet file FAIL 0 / PASS 33. Shard 3 files from the failing commit, after attaching the package for the example files the local runner had not attached: no remaining failure.

## 5. Tests of the Tests

The #1782 file is unchanged. It still fails on main because `predict()` succeeds when the unit column is dropped. The ratchet test is the one CI ran; it failed at 771 before the bullet change and passes at 770 after.

## 6. Consistency Audit

`rg -n '^<<<<<<<|^>>>>>>>' NEWS.md R/methods-gllvmTMB.R` — no markers. `rg -n '#1782|#1781|#1787' NEWS.md` — all three bullets present. The unit abort is the only `gllvmTMB_predict_newdata_unit_missing` site.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

Inspected #1782 and PR #1785. No issue comment, no close. `refs #1782` only.

## 8. What Did Not Go Smoothly

A local `test_file(package = "gllvmTMB")` loop does not attach the package, so help-example tests reported `could not find function "simulate_unit_trait"`. The same files pass after `library(gllvmTMB)`, which is what `tests/testthat.R` does under R CMD check.

## 9. Team Learning

- Pat: the message still names the missing column and `re_form = ~0`.
- Grace: both shard 3 jobs failed on the same assertion, not on a DLL load. The `.so` line in the coverage log is covr's instrumented library path after the test failure.
- Curie: the ceiling stays 770.

## 10. Known Limitations and Next Actions

Full `R CMD check` was not run here. The species-column abort on main still uses an `"i"` bullet and is already inside the 770 count. This slice does not rewrite it.
