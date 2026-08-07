# After Task: VA S0b exact-route absolute-first (fresh Totoro)

**Branch**: `codex/va-gh-all-families`  
**Date**: `2026-08-07`  
**Roles (engaged)**: Ada (conductor), Curie (campaign), Fisher (absolute-first protocol), Rose (no soft-PASS)

## 1. Goal

Execute Arc S0b only after G0b yes: fresh known-truth absolute-first scientific
ledgers on Totoro for `poisson_log`, `lognormal_log`, and `gamma_log` at
q∈{2,5}, then stop for Shinichi before S1 — without mutating frozen Arc-2
labels or the public VA fence.

## 2. Implemented

- LOOP kit under `lanes/va-s0b-exact/LOOP/` plus protocol and Totoro launcher.
- Totoro campaign root
  `/home/snakagaw/gllvm_work/va-s0b-exact-022b4eab-20260807` with **3,600**-row
  plan (seeds **10301:10600**, n=300, three cells × q∈{2,5} × VA+Laplace,
  n=120, p=8, estimator rev `022b4eab`).
- Exit receipt **COMPLETE**, 3600/3600 bundles; export MD5
  `1e0a78c16eca8f93ca18b2981b816217`.
- Scientific ledger under default caps β≤0.35 / Σ≤0.50:

| cell | q | scientific | β RMSE | Σ rel Frob | reliability | LA healthy | frozen Arc-2 |
| --- | ---: | --- | ---: | ---: | --- | ---: | --- |
| poisson_log | 2 | **FAIL** | 0.111 | 0.626 | PASS | 275/300 | FAIL |
| poisson_log | 5 | **PASS** | 0.122 | 0.482 | PASS | 278/300 | PASS |
| lognormal_log | 2 | **PASS** | 0.070 | 0.372 | PASS | 155/300 | INCONCLUSIVE |
| lognormal_log | 5 | **PASS** | 0.083 | 0.347 | PASS | 179/300 | INCONCLUSIVE |
| gamma_log | 2 | **FAIL** | 0.080 | 0.423 | FAIL | 0/300 | FAIL |
| gamma_log | 5 | **FAIL** | 0.125 | 0.459 | FAIL | 0/300 | FAIL |

Alternate caps **not proposed**. Frozen Arc-2 MD5
`e57f8460fd98bd0eac43b4a6c014317d` unchanged. Fence / `calibrated=FALSE`
untouched.

## 3. Files Changed

- `lanes/va-s0b-exact/**`
- `lanes/va-s0a-gaussian/LOOP/checkpoint.md` (G0b yes pointer)
- `docs/dev-log/audits/2026-08-07-va-s0b-exact-scientific-ledger.{csv,md}`
- `docs/dev-log/after-task/2026-08-07-va-s0b-exact-absolute-first.md` (this)
- `docs/dev-log/plan-actual/2026-08-07-va-s0b.md`
- `docs/dev-log/check-log.md`

Local evidence (not in git): `/private/tmp/va-s0b-exact-evidence-20260807/`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** n_seeds=300, range 10301:10600. **Rationale:** same band as
  S0a; disjoint from Arc-2 and S0a. **Rejected:** reuse Arc-2 rows.
- **Decision:** no alternate abs caps. **Rationale:** poisson q=2 fails Σ
  clearly (0.626); gamma fails reliability; lognormal and poisson q=5 clear
  defaults with margin.
- **Decision:** STOP at G0c (S1 not started).

## 4. Checks Run

```sh
# Totoro smoke PASS; plan 3600; run EXIT:0; bundles 3600/3600
# export MD5 1e0a78c16eca8f93ca18b2981b816217

md5 /private/tmp/va-gh-h7-final-evidence/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv
# e57f8460fd98bd0eac43b4a6c014317d (unchanged)

git diff --stat HEAD -- R/ src/ NAMESPACE DESCRIPTION
# empty (no package mutation)
```

## 5–7. Tests / Consistency / Roadmap

No package tests changed. Ledger does not soft-PASS Arc-2 labels. No ROADMAP
edit. No issue opened/closed.

## 10. Known Residuals

- Gamma VA healthy rates were 249/300 (q=2) and 65/300 (q=5).
- **RETRACTED (same day):** Laplace “0/300 healthy” at both ranks was a
  `laplace_health` bug (`gr(last.par.best)` FE+RE). FE-only proxy
  `conv0∧pdHess`: **282/300** (q=2), **214/300** (q=5). See
  `docs/dev-log/after-task/2026-08-07-va-s0b-laplace-health-fe-gradient-fix.md`.
  Dual-report (B) and Arc-2 frozen labels unchanged.
- Poisson q=2 abs cov failure replicates Arc-2 (shared hardness vs Laplace).
- Lognormal clears absolute-first while Arc-2 overall remains INCONCLUSIVE
  (Laplace pairing shortfall) — same pattern as Gaussian S0a.

## 12. What Did NOT Happen

No S1; no fence change; no threshold package mutation; no Arc-2 re-run; no
multinomial; raw evidence not staged.
