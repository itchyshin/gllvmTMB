# After Task: Poisson ordinary q1/q2 experimental-point admit

**Branch**: `cursor/mspl-poisson-admit-g0`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada (G0 flip), Rose (fence)

## 1. Goal

Flip Poisson ordinary `q=1,2` from `planned` → `admitted` as an
**experimental point** after #1008 CI-green, per Shinichi G0
tonight. Record the #990 Rose fence honestly.

## 2. Implemented

- Registry rows `poisson:log:ordinary:q1` and `q2` are `admitted`
  / `admit_packet`.
- Notes name #1008 atoms, G0 2026-08-16, and **#990 operational
  PASS / admit-evidence FAIL**.
- Tests that asserted `planned` were swept to the new contract.
- Public `se=TRUE` still withholds `sdreport()` / `vcov()` /
  `confint()`.

## 3. Files Changed

- `R/mspl-registry.R` (two Poisson rows only)
- `tests/testthat/test-mspl-registry.R`
- `tests/testthat/test-mspl-poisson-admit-packet.R` (A7 + A8)
- `tests/testthat/test-mspl-poisson-public-door.R`
- `tests/testthat/test-zz-mspl-poisson-se-feasibility.R`
- `tests/testthat/test-mspl-poisson-phase4-oracles.R`
- `tests/testthat/test-mspl-fenced-family-tapes.R`
- `tests/testthat/test-mspl-gaussian-heywood-oracles.R` (planned
  rows are no longer required to be Poisson)
- this after-task + `docs/dev-log/check-log.md`

No NEWS. No README. No `src/`. No public vcov. No other-family
admit. No repo-root `LOOP/`. No `git add -A`. Tweedie/Beta
implementer branch left alone.

## 3a. Decisions and Rejected Alternatives

- **Decision:** evidence token `admit_packet`, not `oracle_local`
  and not `covered`.
  **Rationale:** #990 multi-seed smoke was operational PASS /
  admit-evidence FAIL. Admission is the atom packet + G0, not a
  passing recovery campaign.
  **Rejected:** `oracle_local` (overclaims the smoke);
  `covered` (forbidden).
  **Confidence:** high (G0 + #990 receipt).

## 4. Checks Run

See the matching `docs/dev-log/check-log.md` entry.

## 5. Tests of the Tests

A8 now fails if the rows stay `planned` or if evidence is
`covered`. The SE pin still fails if `vcov()` / `confint()`
open.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| only poisson ordinary q1/q2 flipped | PASS |
| no NEWS `covered` | PASS (NEWS untouched) |
| no public SE | PASS (SE pin still withholds) |
| no NB/Tweedie/Beta/hurdle admit | PASS |
| Codex Lane B not absorbed | PASS |
| Tweedie/Beta implementer not edited | PASS |

## 7. Roadmap Tick

N/A. Internal estimator admission only.

## 7a. GitHub Issue Ledger

No issue closeout.

## 8. What Did Not Go Smoothly

Tweedie/Beta implementer (`cursor/mspl-se-tweedie-beta-impl`)
also edits `R/mspl-registry.R` (planned doors). This PR does
not absorb those rows. They will rebase after this lands.

## 9. Team Learning

- **Ada:** G0 was "after #1008 green", not "after #990 admit
  evidence PASS".
- **Rose:** admit ≠ covered; #990 FAIL stays in the notes.

## 10. Known Limitations And Next Actions

No public SE. No NEWS covered. No other-family admit. B1 is a
separate Totoro job and does not justify interval admission.
