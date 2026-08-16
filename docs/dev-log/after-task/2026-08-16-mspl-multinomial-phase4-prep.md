# After Task: MSPL multinomial Phase-4-style prep (not admitted)

**Branch**: `cursor/mspl-phase4-multinomial`
**Date**: `2026-08-16`
**Roles (engaged)**: Gauss / Noether / Curie / Fisher / Rose

## 1. Goal

Land Phase-4-*style* prep for `multinomial()` (fid 16): matrix
Jeffreys atom on the \(K-1\) free logits, anchor-once contract,
pure-R oracles. Not admission. No registry row. No prepare widen.
No `src/` tape.

## 2. Implemented

- Research note: unordered softmax is not binomial Design 88 and
  not ordinal-probit (#1005). `gll_mspl_log_weight_glm` cannot
  host this atom (scalar \(\log w\)).
- Oracles M1–M8, including \(K=2\) Bernoulli recovery and the
  anti-double-counting pin.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md`
- `tests/testthat/test-mspl-multinomial-phase4-oracles.R`
- `docs/dev-log/after-task/2026-08-16-mspl-multinomial-phase4-prep.md`
- `docs/dev-log/check-log.md`

`R/mspl.R`, `R/mspl-registry.R`, `src/` untouched.

## 3a. Decisions and Rejected Alternatives

**Decision:** pin the single-observation kernel only. **Rationale:**
the GLLVM stacked-unit block information is a later derivation.
**Rejected:** pretend a scalar GLM-outer weight exists.
**Confidence:** high.

## 4. Checks Run

See check-log. Targeted:
`test-mspl-multinomial-phase4-oracles.R` PASS 23;
`test-mspl-registry.R` PASS 28.

## 5. Tests of the Tests

- Failure-before-fix: M4/M6 fail if a scalar binomial weight or
  per-row Bernoulli sum is used.
- Boundary: M5 separation; M3 \(K=2\).
- Live-fit fence: M8.

## 6. Consistency Audit

```
rg -n 'estimator\s*=\s*["'\'']mspl' tests/testthat/test-mspl-multinomial-phase4-oracles.R
# no live fit
rg -n 'multinomial' R/mspl-registry.R
# no row (file untouched)
```

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created.

## 8. What Did Not Go Smoothly

None.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss / Noether:** a later tape that weights every contrast
pseudo-row repeats the double-counting bug the engine already
guards.
**Fisher:** \(K=2\) recovery is a limit check, not Design 88
transfer.
**Rose:** no NEWS covered; no public `se=TRUE`.

## 10. Known Limitations And Next Actions

No C++ tape. No planned row. Stacked-unit / loading atoms OPEN.
OPEN GATE: Shinichi before planned row or admit.
