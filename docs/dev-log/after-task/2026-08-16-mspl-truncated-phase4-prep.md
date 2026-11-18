# After Task: MSPL truncated Poisson / NB2 Phase-4-style prep (not admitted)

**Branch**: `cursor/mspl-phase4-truncated`
**Date**: `2026-08-16`
**Roles (engaged)**: Gauss / Noether / Curie / Fisher / Rose

## 1. Goal

Land Phase-4-*style* prep for `truncated_poisson()` (fid 10) and
`truncated_nbinom2()` (fid 11). Not admission. No registry rows.
No prepare widen. No `src/` tape.

## 2. Implemented

- Research note: truncation's remaining boundary is all-ones, not
  Poisson all-zero; hurdle (#1004) is a different zero process.
- ZTP closed-form \(I_\eta=\mathrm{Var}(Y\mid Y\ge 1)\).
- TNB2 score / information from the wired `size=phi` kernel plus
  \(-\log(1-p_0)\).
- Oracles T1–T9.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-phase4-truncated-prep.md`
- `tests/testthat/test-mspl-truncated-phase4-oracles.R`
- `docs/dev-log/after-task/2026-08-16-mspl-truncated-phase4-prep.md`
- `docs/dev-log/check-log.md`

`R/mspl.R`, `R/mspl-registry.R`, `src/` untouched.

## 3a. Decisions and Rejected Alternatives

**Decision:** one PR for both truncated families. **Rationale:**
same Phase 5 bucket; shared kill ("do not reuse Poisson \(W=\mu\)").
**Rejected:** wait for #1004 hurdle merge. **Confidence:** high.

## 4. Checks Run

See check-log. Targeted:
`test-mspl-truncated-phase4-oracles.R` PASS 23;
`test-mspl-registry.R` PASS 28.

## 5. Tests of the Tests

- Failure-before-fix: T3/T6 fail if untruncated weights are used.
- Boundary: T4 \(\lambda\to 0\); T7 \(\varphi\to\infty\) tracks ZTP.
- Live-fit fence: T9.

## 6. Consistency Audit

```
rg -n 'estimator\s*=\s*["'\'']mspl' tests/testthat/test-mspl-truncated-phase4-oracles.R
# no live fit
rg -n 'truncated_poisson|truncated_nbinom2' R/mspl-registry.R
# no rows (file untouched)
```

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created.

## 8. What Did Not Go Smoothly

None.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss / Noether:** zeros are impossible; the Poisson all-zero
atom is the wrong object.
**Fisher:** not an admit packet; not a hurdle transfer.
**Rose:** no NEWS covered; no public `se=TRUE`.

## 10. Known Limitations And Next Actions

No C++ tape. No planned rows. There is no `truncated_nbinom1` in
the engine. OPEN GATE: Shinichi before planned rows or admit.
