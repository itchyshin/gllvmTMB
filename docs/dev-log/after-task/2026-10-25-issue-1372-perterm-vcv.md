# After Task: refuse a conflicting in-keyword vcv and phylo_vcv

**Branch**: `cursor/issue-1372-perterm-vcv-c93d`
**Date**: `2026-10-25`
**Roles (engaged)**: Curie, Emmy, Rose

## 1. Goal

Close the #1372 silent-drop: when a phylo keyword carried `vcv = K1` and
`gllvmTMB()` also received `phylo_vcv = K2` of the same size, the fit used
K2 and dropped K1 with no message.

## 2. Implemented

The harvest now compares the two matrices by value. A mismatch stops with
class `gllvmTMB_phylo_vcv_conflict` and names both arguments. Matching
matrices (including the existing `phylo(species, vcv = Cphy)` plus
`phylo_vcv = Cphy` path) still fit.

## 3. Files Changed

- `R/fit-multi.R`: `.gllvmTMB_same_phylo_vcv()` helper; harvest abort
- `tests/testthat/test-issue-1372-perterm-vcv.R`
- `NEWS.md`
- `docs/dev-log/after-task/2026-10-25-issue-1372-perterm-vcv.md`
- `docs/dev-log/check-log.d/2026-10-25-issue-1372-perterm-vcv.md`

## 3a. Decisions and Rejected Alternatives

Decision: refuse a conflicting pair rather than let the per-term matrix
win with a warning. Rationale: the comment said they must agree, and
switching from the current silent-global winner to a silent-per-term
winner would change existing fits without a signal. Rejected: keep the
dim-only warning (that is the bug). Confidence: high.

The tip-label-only tree comparison in the same loop is left alone; it
was source-read, not run-confirmed, in #1372.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-25-issue-1372-perterm-vcv.md`.

## 5. Tests of the Tests

The helper test fails if comparison is dim-only. The abort test fails if
the harvest still swallows a same-size mismatch. The matching-matrix
test fails if the abort is too broad.

## 6. Consistency Audit

- `rg -n "gllvmTMB_phylo_vcv_conflict" R tests NEWS.md`
- `rg -n "Using the global .arg phylo_vcv" R/fit-multi.R` (should be gone
  from the vcv harvest)

## 7. Roadmap Tick

N/A

## 7a. GitHub Issue Ledger

- Inspected #1372 (open, no PR). This slice closes the verified VCV
  silent-drop.
- Related and not closed: the same loop's tree comparison still uses
  tip labels only.

## 8. What Did Not Go Smoothly

The harvest sits late in `gllvmTMB()`, so the conflict test still walks
formula parsing before it can abort.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Curie: the regression pins both the helper and a live `gllvmTMB()`
call, so a later rewrite of the harvest cannot drop the abort by
keeping the helper.

Emmy: the new class is specific to this conflict; callers can catch it
without matching the prose.

Rose: NEWS names the class and the two arguments; no register codes
on the reader surface.

## 10. Known Limitations And Next Actions

The per-term `tree =` vs global `phylo_tree` path still keeps the
global tree when tip labels match. That is a follow-up, not this close.
