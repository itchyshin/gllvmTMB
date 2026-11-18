# After Task: retarget rest-family MSPL notes to planned (phase4_prep)

**Branch**: `cursor/mspl-docs-planned-retarget`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Rose

## 1. Goal

#1005 / #1023 / #1024 / #1025 shipped student, ordinal_probit,
betabinomial, truncated Poisson/NB2, and multinomial oracles with
**No registry row** status lines. #1039 adds the `planned` /
`phase4_prep` rows and left those notes stale on purpose. Retarget
the five research notes so they match the gamma/hurdle planned-row
wording. Not admission. No code. No registry edit.

## 2. Implemented

Each note now says the ordinary `q=1,2` cells are `status =
"planned"`, `evidence = "phase4_prep"`, **not** `admitted`. S12,
O11, B9, T9, and M8 pin the planned row. Verdict tables split
planned-row PASS from admitted / C++ / live-MSPL FAIL. Prepare
fence, public door, `se=TRUE`, and NEWS stay closed.

## 3. Files Changed

- `docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md`
- `docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md`
- `docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md`
- `docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md`
- `docs/dev-log/after-task/2026-08-16-mspl-rest-family-note-retarget.md`

`R/`, `src/`, NEWS, and the validation-debt register were not
touched. `docs/dev-log/check-log.md` is left alone (same collision
avoidance as #1039). #995 and #981 were left alone.

## 3a. Decisions and Rejected Alternatives

**Decision:** docs-only follow-up after #1039, not a rewrite of the
prep after-tasks. **Rationale:** #1039 already recorded the stale
status line and rejected a five-note rewrite in the same slice.
**Rejected:** editing `R/mspl-registry.R` or the oracle tests.
**Confidence:** high.

## 4. Checks Run

Docs-only `rg` on the five notes (patterns in §6). No
`devtools::test()`, no `--as-cran`. Check-log left alone so this
PR can rebase after #1039 without colliding.

## 5. Tests of the Tests

N/A — no test files changed. S12 / O11 / rest-family registry pins
live in #1039.

## 6. Consistency Audit

```
rg -n 'No registry row' docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md \
  docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md
# 0 hits — PASS

rg -n 'phase4_prep' docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md \
  docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md
# each note names planned / phase4_prep — PASS

rg -n 'status = "admitted"|NEWS covered' \
  docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md \
  docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md \
  docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md
# only kill-list / FAIL rows — PASS
```

## 7. Roadmap Tick

N/A. Internal research-note honesty only.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is the docs
follow-up #1039 deferred.

## 8. What Did Not Go Smoothly

#1039 was still open when this slice started. The notes name #1039
as the planned-row source; merge this PR only after #1039 is on
`main`.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Ada:** kept the slice to the five notes plus this after-task.
- **Rose:** stale "No registry row" after a planned-row PR is a
  repeated honesty miss; gamma/hurdle already had the wording.

## 10. Known Limitations And Next Actions

Still not admitted. Public `estimator = "mspl"` still rejects these
families. No C++ tape. No `se=TRUE`. Leave #995 (expected-red) and
#981 (B0) alone.
