# After Task: Hotfix nbinom2 Phase-4 oracles after #1007

**Branch**: `cursor/hotfix-nbinom2-oracles`
**Date**: `2026-08-16`
**Roles (engaged)**: Curie, Rose, Grace

## 1. Goal

Restore green `main` after #1007 opened a planned-only nbinom1/nbinom2
door. Ubuntu R-CMD-check on `f3bd4e6a` failed seven stale assertions
that still required nbinom2 ordinary cells to stay `excluded`.

## 2. Implemented

`test-mspl-nbinom2-phase4-oracles.R` now matches the nbinom1 oracle
contract: planned door allowed, not admitted, no live MSPL call.
Header comment no longer forbids planned registry rows.

## 3. Files Changed

- `tests/testthat/test-mspl-nbinom2-phase4-oracles.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-16-hotfix-nbinom2-oracles.md`

No `R/`, `src/`, NEWS, README, register, or public-door change.

## 3a. Decisions and Rejected Alternatives

Decision: rewrite the one stale oracle block to the nbinom1 "planned
door allowed" shape rather than delete it. Rationale: keep the
not-admitted pin. Rejected: reverting #1007. Confidence: high — CI
named this file and these seven lines.

## 4. Checks Run

`devtools::test(filter="mspl-nbinom2-phase4-oracles|mspl-nbinom1-phase4-oracles|mspl-registry$")`
→ `FAIL 0 | WARN 0 | SKIP 0 | PASS 185`. Not a full `R CMD check`.

## 5. Tests of the Tests

Failure-before-fix: the seven CI assertions on `f3bd4e6a`. After the
rewrite they accept `planned` / `phase4_prep` and still refuse
`admitted`.

## 6. Consistency Audit

- `stay excluded|NB2 waits for Phase 4` in `tests/testthat`: none left.
- Historical after-task prose that recorded the old excluded note is
  left as history.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No new issue. This is a same-day hotfix for main CI on #1007.

## 8. What Did Not Go Smoothly

#1007 updated nbinom1 oracles and the fenced-tape tests but missed
this one nbinom2 oracle file. Later main `495a7638` (#1005) inherits
the same fail.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Curie: a planned-door PR must grep every `excluded` / lookup-NULL
  pin for that family, not only the files the door author touched.
- Rose: nbinom1 and nbinom2 oracle files drifted; they should stay
  paired.
- Grace: main is red on ubuntu-only R-CMD-check; macOS/Windows jobs
  were not started on that run.

## 10. Known Limitations And Next Actions

nbinom1/nbinom2 stay planned / not admitted. No public SE. Merge this
hotfix; do not force-push main.
