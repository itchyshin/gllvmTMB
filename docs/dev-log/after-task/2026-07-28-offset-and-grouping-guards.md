# After-task — offset() and NA-grouping-label guards

Date: 2026-07-28 · Platform: Claude Code · Branch: `claude/offset-guard-20260728` · PR #807
Worktree: `/private/tmp/gllvmtmb-offset-guard` (from `origin/main` @ `b144abc0`, post-#802)

## 1. Goal

Close two silent-wrong-answer paths surfaced by the missing-data audit's adversarial pass (#804):
`offset()` silently ignored, and an `NA` grouping label silently absorbed as a group.

## 2. Implemented

Two guards and the tests that pin them.

- `R/parse-multi-formula.R` — reject any fixed term containing an `offset()` call.
- `R/fit-multi.R` — reject `NA` in a random-effect grouping column, and in the `trait` / `unit`
  identifier columns.

**Key framing:** the README already told readers these cases error. Rather than weaken the doc to
match the code, the code now matches the doc. That is why one small slice closed three escalations
from the audit.

## 3a. Decisions and rejected alternatives

- **Rejected: implementing offset support.** "Refuse to silently ignore" and "support offsets
  properly" are different jobs; the second is a feature with TMB-side work and its own validation.
  The guard is independently correct even if offsets are implemented later.
- **Rejected: a head-only offset check.** `fn == "offset"` fixed long format and missed wide, because
  the `traits()` expander rewrites predictors to `(0 + trait):x`. The check is on the whole term.
- **Rejected: editing `README.md`.** It belongs to another lane, and once these guards land its text
  is already true.
- **Rejected: touching `man/traits.Rd`.** Its "canonical complete-case" phrasing is disambiguated by
  the sentence after it, and that roxygen belongs to the docs lane.
- **Decided: no heavy gate on the new tests.** The failures they guard are *silent*; a guard that
  only runs when someone sets an environment variable does not guard.

## 4. Files touched

Modified: `R/parse-multi-formula.R`, `R/fit-multi.R`
Created: `tests/testthat/test-offset-guard.R`, `tests/testthat/test-grouping-na-guard.R`, this report

## 5. Checks run

| Check | Result |
|---|---|
| targeted guard tests | **15 pass / 0 fail** |
| full suite, default gating | **5362 pass / 0 fail / 1026 skip / 0 warn** |
| missing-response regression (`nobs` 59) | passes — the supported case is untouched |
| `lv = ~ offset(x)` keeps its own message | passes |
| variable merely *named* `offv` still fits | passes |

## 6. Tests of the tests

Both guards were written test-first and observed to fail before the fix: the two offset-rejection
tests failed on the unguarded tree, and the wide-format one **kept failing** after the first
(head-only) guard — which is how the `(0 + trait):offset(offv)` shape was found at all.

The `NA`-label test was then *strengthened after it passed for the wrong reason* — see §9.

## 7a. Issue ledger

Both defects closed. `README.md:174-177` becomes true with no edit to that file.

## 8. Consistency audit

Swept for the same class rather than fixing only the instances found:

- Every `README.md:174-177` category was re-tested after the guards: grouping, unit, offset now
  error; weights and design-matrix values errored already; **missing response still fits**.
- Checked whether the offset guard should also cover `lv` — it should not; that path has its own,
  more specific message, and `walk()` returns early on covstruct calls so the two never collide.
- Checked both formula shapes (long and wide) for both guards, since the wide path rewrites terms.

## 9. What did not go smoothly

**The guard I wrote had a bug, and my test passed anyway.** The `NA`-label guard emitted
`Invalid cli literal: {.idcol} starts with a dot` — cli reads `{.name}` as an inline style directive,
and the loop variable started with a dot. The guard still failed loud, so the *behaviour* was right,
but the message was useless.

The test did not catch it because it asserted only `expect_error(..., "site|missing|NA")` — i.e.
"did something error?". A test that cannot distinguish a good message from a broken one is not
testing the thing that matters. It now asserts the column name, the word "missing", and explicitly
`expect_no_match(err, "Invalid cli literal")`.

**The error count was misleading.** It reported "4 missing values" where the user had set 2, because
the guard runs after wide→long stacking. Now says "4 stacked rows".

**A first full-suite run was superseded** mid-flight by the grouping guard and had to be re-run.

## 10. Known residuals

- Offsets are now *rejected*, not *supported*. If offset support is wanted, that is a separate piece
  of work — the guard's message should then change with it.
- The identifier guard covers `trait` and `unit`; it does not sweep every column that could act as an
  identifier in an exotic call.
- The guards are validated on gaussian fixtures. They are structural (formula parsing and factor
  construction), so family should not matter — but that is reasoning, not measurement.
- `R CMD check` on this branch was not re-run; the tree carries pre-existing failures unrelated to
  this change (documented in the #804 handover).

## 11. Team learning

**"Did it error?" is not a test.** The strongest assertion available is usually the *diagnosis*, not
the failure. This session produced a live example: a guard with a formatting bug shipped past a
green test because the test accepted any error.

**When a doc and the code disagree, ask which one is right before "fixing" the doc.** The instinct
after an audit is to correct the prose. Here the prose described the intended behaviour and the code
had drifted from it — so the cheap doc edit would have enshrined the defect and quietly removed a
safety promise.

**Guard where the term arrives, not where it was written.** The `traits()` expander rewrote
`offset(offv)` into `(0 + trait):offset(offv)`; a guard matching the head passed the long-format
test and missed the shape most users write.

## 12. Cross-product coverage — the negative space

- This does **not** implement offsets; it refuses them.
- It does **not** change missing-*response* handling in any way — that is explicitly regression-tested.
- It makes **no** coverage or interval claim.
- It does not sweep every possible identifier column, only `trait` and `unit`.

## 13. The neighbourhood sweep — done, and it came back clean

§12 originally recorded the grammar-wide sweep as *not done*. It has since been run, because finding
two members of a class is reason to assume more.

Each candidate term was classified by whether it **changes the fit** (correct), is **rejected**
(safe), or is **accepted while leaving the likelihood bit-identical to baseline** — the dangerous
class that `offset()` belonged to.

| term | verdict |
|---|---|
| `I(w2^2)`, `poly(w2, 2)`, `log(...)`, a factor covariate, `z:w2`, a plain covariate | **changes the fit** ✓ |
| `offset(w2)` | **rejected** (this change) |
| `s(w2)`, `te(w2)` | rejected — *and still rejected with `mgcv` attached*, which was the plausible escape route |
| `strata(fac)`, `cluster(grp)`, `weights(w2)` | rejected |

**No further silent terms found. `offset()` was the unique member of its class.**

One residual, lower priority and **not fixed here**: the rejections differ in quality. `offset()`
now fails with a designed message; `s()`/`te()`/`strata()`/`cluster()` fail with R's opaque
`could not find function` or `invalid type (list) for variable`, and `weights(w2)` with
`$ operator is invalid for atomic vectors`. All fail loud, so none is a correctness risk — but a
user meeting them learns nothing about why. Worth a polish pass; not urgent.
