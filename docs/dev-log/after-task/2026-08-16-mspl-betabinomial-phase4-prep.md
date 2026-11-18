# After Task: MSPL betabinomial Phase-4-style prep (not admitted)

**Branch**: `cursor/mspl-phase4-betabinomial`
**Date**: `2026-08-16`
**Roles (engaged)**: Gauss / Noether / Curie / Fisher / Rose

## 1. Goal

Land Phase-4-*style* prep for `betabinomial()` (fid 8): information
atom, boundary objects, and pure-R oracles. Not admission. No
registry row. No prepare widen. No `src/` tape.

## 2. Implemented

- Research note distinguishing BB from Beta (#975) and from
  Bernoulli Design 88.
- Exact finite-support Fisher from the wired Hilbe/Bolker pmf;
  quasi \(N\mu(1-\mu)(\varphi+1)/(\varphi+N)\) kept as a contrast.
- Oracles B1–B9, including \(N=1\) Bernoulli recovery and
  \(\varphi\to\infty\) binomial recovery.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-phase4-betabinomial-prep.md`
- `tests/testthat/test-mspl-betabinomial-phase4-oracles.R`
- `docs/dev-log/after-task/2026-08-16-mspl-betabinomial-phase4-prep.md`
- `docs/dev-log/check-log.md`

`R/mspl.R`, `R/mspl-registry.R`, `src/` untouched.

## 3a. Decisions and Rejected Alternatives

**Decision:** no registry row. **Rationale:** sibling doors already
edit the registry; nbinom1/Beta preps on main also shipped oracles
first. **Rejected:** planned rows in this PR. **Confidence:** high.

## 4. Checks Run

See check-log. Targeted:
`test-mspl-betabinomial-phase4-oracles.R` PASS 27;
`test-mspl-registry.R` PASS 28.

## 5. Tests of the Tests

- Failure-before-fix: B3/B6 fail if quasi or Ferrari is treated as
  the Jeffreys atom.
- Boundary: B4 \(N=1\); B5 large \(\varphi\); B7 all-0 / all-\(N\).
- Feature-combination: B8 kill on \(V_{\mathrm{loading}}\) / Hirose.
- Live-fit fence: B9.

## 6. Consistency Audit

```
rg -n 'estimator\s*=\s*["'\'']mspl' tests/testthat/test-mspl-betabinomial-phase4-oracles.R
# no live fit
rg -n 'status = "admitted"|family = "betabinomial"' R/mspl-registry.R
# no BB row (file untouched)
```

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created.

## 8. What Did Not Go Smoothly

None beyond writing the exact score from the wired lgamma pmf
rather than trusting the quasi weight.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss / Noether:** \(N=1\) is \(\varphi\)-inert Bernoulli; a later
tape must not keep a precision atom on single-trial rows.
**Curie:** full finite support, no tail truncation.
**Fisher:** not an admit packet.
**Rose:** no NEWS covered; no public `se=TRUE`.

## 10. Known Limitations And Next Actions

No C++ tape. No planned row. OPEN GATE: Shinichi before any later
`planned` row or admit. Merge is human.
