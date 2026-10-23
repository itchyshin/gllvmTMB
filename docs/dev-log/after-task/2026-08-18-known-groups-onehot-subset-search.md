# After Task: known_groups one-hot subset search (#1154)

**Branch**: `claude/1154-onehot-subsets`
**Date**: `2026-08-18`
**Roles (engaged)**: `Boole`

## 1. Goal

Close the third, disclosed `known_groups=` blindness in `screen_gllvmTMB()`:
the one-hot test was WHOLE-GROUP only, so `known_groups = list(g =
c("A","B","C","D"))` where `{A,B,C}` is a genuine one-hot block and `D` is
unrelated reported `known_group_checked` PASS instead of certifying the
subset. Same shape as the nesting defect fixed in PR #1150. Reported by
@Ayumi-495, who is actively using `known_groups` on 191x73 systematic-map
data with review/scope/temporal one-hot blocks.

## 2. Implemented

- `.screen_known_group_one_hot_subsets()`: bounded exhaustive search over
  every subset of size >= 2 of a declared group (smallest first), reporting
  each MINIMAL one-hot subset and skipping any subset already covered by a
  smaller found one. A subset whose members are all constant is excluded
  (degenerate guard, mirrors the whole-group guard).
- `.screen_known_group_subset_max <- 12L`: the search is attempted only when
  the declared group has <= 12 members (2^12 - 13 = 4083 row-sum checks,
  microseconds). Justification: the real motivating dataset's largest
  declared block is 6; 12 gives comfortable headroom while an unbounded
  search is combinatorial (2^20 is over a million subsets) for groups that
  are small by construction.
- `.screen_known_group_rows()`: when the whole group is not one-hot, each
  minimal subset found gets its own `known_one_hot_subset` FAIL row (same
  shape as the existing `known_one_hot` row) and contributes the same
  canonical null vector (`.screen_one_hot_null_vector()`) to the
  certified-span rank computation in `.screen_response_dependencies_table()`
  -- so it counts toward `unresolved` exactly once, including when the same
  relation is also certified under a different, overlapping declared group.
  `k > SUBSET_MAX` never falls through to a silent PASS: an explicit
  `known_group_subset_not_attempted` (WARN) row is emitted instead, distinct
  from a genuine exhaustive negative (`known_group_checked`, unchanged
  wording plus a note that the search covered every subset up to `k`
  members).
- Nesting is untouched: its pairwise O(k^2) scan already covers every pair
  within the declared group regardless of unrelated members, so it has no
  equivalent blindness (see Sibling-Predicate Audit below).

## 3. Files Changed

- `R/screen-gllvmTMB.R` -- `.screen_known_group_subset_max`,
  `.screen_known_group_one_hot_subsets()`, restructured
  `.screen_known_group_rows()`, updated `@param known_groups` roxygen.
- `man/screen_gllvmTMB.Rd` -- regenerated via `devtools::document()`.
- `tests/testthat/test-screen-known-groups.R` -- 8 new `test_that()` blocks.
- `NEWS.md` -- new bullet under the 0.7.0 dev "Fixed" section, next to the
  #1150 entry.

## 3a. Decisions and Rejected Alternatives

- **SUBSET_MAX = 12** (not e.g. 20 or unbounded): chosen so the checked
  subset count (`2^k - k - 1`) stays in the low thousands regardless of
  `n_rows`, while covering more than double the largest declared block seen
  in the motivating real dataset (6). Confidence: high for the stated use
  case; the value is a judgment call documented in the code comment and NEWS
  so it can be revisited if a future user declares a larger single group.
- **Subset certificates get a distinct `known_one_hot_subset` type**, not
  the same `known_one_hot` string used for the whole-group case. Rejected
  alternative: reuse `known_one_hot` for both. Rationale: makes the two
  cases unambiguously distinguishable in `$response_dependencies` without
  parsing the certificate text, and the task brief's "exactly as a
  fully-declared one-hot block is reported today" was read as a
  structural/fields parity requirement, not a literal type-string
  requirement.
- **`known_group_subset_not_attempted` is `WARN`**, not `PASS` or `FAIL`:
  the whole-group and nesting checks did run and found nothing, but the
  one-hot question itself was not resolved either way -- `WARN` is an
  existing status in this codebase's severity ordering
  (`FAIL > WARN > INFO > NOT_CHECKED > PASS`) reserved for exactly this
  "checked but not conclusively" shape.

## 4. Checks Run

- `NOT_CRAN=true` focused file: `devtools::test_file("tests/testthat/test-screen-known-groups.R")`
  -- 229 tests, 0 failures (post-fix).
- Wide sweep: `devtools::test(filter = "screen|response-dep|affine|known-group|ridge-path")`
  matched files `test-ridge-path.R`, `test-screen-gllvmTMB.R`,
  `test-screen-known-groups.R`, `test-screen-separation.R` -- 0 failures
  across all four.
- `devtools::document()` -- reproduces only the 3 pre-existing
  `aghq-report.R` S3-export warnings (`anova`/`BIC`/`AIC.gllvmTMB_multi`);
  no new warnings.
- `grep -rn` for every message-literal substring introduced or changed
  (`"did not show an exact one-hot sum"`, `"contains a one-hot subset"`,
  `"SUBSET_MAX"`, `"known_group_subset_not_attempted"`,
  `"known_one_hot_subset"`, `"was not attempted at this size"`,
  `"the whole declared group does not"`) across `tests/` and `R/` -- no
  collisions with filenames or other tests' expectations.
- Trailing whitespace: `grep -n ' $'` on every changed file -- none found.
- Lane check (pre-commit hook): confirmed the only new commit on
  `origin/main` since this branch's fork point (`b6c50d28`, PR #1152) does
  not touch `R/screen-gllvmTMB.R` at all, and its one `NEWS.md` addition is
  at the very top of the 0.7.0 section, non-adjacent to this change's
  insertion point in the "Fixed" section -- no real overlap despite the
  file-level staleness warning.

## 5. Tests of the Tests

Fail-first evidence recorded before implementing (see task-required tests
1/3/7):

- **Test 1 (disclosed case)**: 5 assertions failed pre-fix -- `kg$status`
  was never `"FAIL"`, `known_group_checked` was present, no
  `known_one_hot_subset` row existed.
- **Test 3 (minimality)**: 2 assertions failed pre-fix, same root cause (no
  subset row emitted at all yet, so the minimality property couldn't be
  observed).
- **Test 7 (unresolved count integration)**: `unresolved` was 1 pre-fix
  (expected 0), and `known_one_hot_subset` count was 0 (expected 1). Note:
  this test had to be built on THREE simultaneous one-hot blocks (reusing
  `.three_one_hot_blocks_data()` plus an unrelated spare trait `X`), not a
  single isolated block -- a single-block construction is already resolved
  by the automatic global affine-certificate search independent of
  `known_groups`, so it would not have exercised the fix.
- All other new tests (2, 4, 5, 6, 8, and the nesting-trap regression re-run)
  pass post-fix; tests 4 and 6 pass identically pre- and post-fix by design
  (regression guards / guards against a defect that never manifests without
  the new code path).

## 6. Consistency Audit

Ran the `grep -rn` sweep listed under Checks Run for every changed message
literal; zero collisions with other files' `filter =` selections or exact
`expect_equal(..., "...")` assertions elsewhere in `tests/`.

## 7. Roadmap Tick

N/A -- this closes issue #1154 directly (a follow-up defect disclosed
during PR #1150), not a ROADMAP row.

## 7a. GitHub Issue Ledger

Not pushed; issue #1154 is expected to be closed by the eventual PR, not by
this local branch directly. No new issue created.

## 8. What Did Not Go Smoothly

The first draft of the "unresolved count integration" and "double-credit"
tests used a single padded one-hot block (`{A,B,C,D}` with `D` unrelated),
which turned out to already be resolved by the automatic global
affine-certificate search regardless of `known_groups` -- so it wasn't
actually exercising the `known_groups`-specific fix (confirmed by running
it pre-fix and seeing it pass when it should have failed). Rebuilt both
tests on the existing three-simultaneous-one-hot-blocks fixture (which the
automatic search is documented to NOT resolve) plus a spare unrelated
trait, which correctly failed pre-fix.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Boole: the automatic affine-rank search and the `known_groups` search are
two independent mechanisms with different blind spots, and a test meant to
isolate one must first confirm the other doesn't already solve it --
otherwise a "fail-first" claim is not actually load-bearing evidence.

## 10. Known Limitations And Next Actions

- `SUBSET_MAX = 12` is a judgment call, not a proof; if a future user
  declares a single group larger than 12 members that contains a genuine
  one-hot subset, they will see the honest
  `known_group_subset_not_attempted` row rather than a false PASS, and can
  split the declaration.
- No change to the automatic (non-`known_groups`) global affine-certificate
  search's own documented "not exhaustive minimal-subset discovery"
  limitation -- out of scope for this issue, which was specifically about
  the user-declared `known_groups` path.

### Sibling-predicate audit (whole-group blindness class, per AGENTS.md)

| Predicate | Location | Whole-group scoped? | Subset blindness? | Verdict |
|---|---|---|---|---|
| One-hot sum test | `.screen_known_group_rows()` | Yes (row sum over declared group) | Yes -- this issue | **AFFECTED, fixed here** |
| Pairwise nesting/containment | `.screen_known_group_rows()` | No -- O(k^2) scan over every pair independently; unrelated members appear in no relation and cannot mask a real pair | No | **NOT AFFECTED** (already exhaustive per PR #1150; verified the trap test at the end of `test-screen-known-groups.R` still passes) |
| All-constant (degenerate) group check | `.screen_known_group_rows()` | Yes, but by design (`!any(non_const)`): a group with a genuine non-constant member is correctly NOT flagged degenerate, and constant members are excluded per-member from nesting elsewhere | No -- a constant-only subset can never certify a real relationship, and the new subset search's own per-subset degenerate guard independently protects the subset path | **NOT AFFECTED** |
| Pairwise duplicate/complement check | `.screen_binomial_pairs()` (automatic, not `known_groups`-scoped) | No -- checks every trait PAIR globally regardless of any declared group | N/A -- no user-declared-group concept exists here to be "too large" | **NOT APPLICABLE** (different mechanism entirely) |
| Automatic global one-hot certificate search | `.screen_response_affine_certificates()` | Operates on the whole screened trait set, not a user-declared group | Yes, but already disclosed in its own docstring ("Exhaustive minimal-subset discovery over all trait subsets is combinatorial and is not attempted") and unbounded in principle (could be any size) | **OUT OF SCOPE** for #1154, which is specifically the `known_groups=` feature; left untouched |
