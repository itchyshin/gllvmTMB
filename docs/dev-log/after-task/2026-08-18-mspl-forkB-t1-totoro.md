# After Task: Design 125 fork-B Totoro T1 panel + receipt

- **Branch**: `cursor/mspl-fork-B-totoro-20260818`
- **Date**: `2026-08-18`
- **Roles (engaged)**: Curie, Fisher, Rose, Grace

## 1. Goal

Run ADEMP / Design 125 gate T1 for fork B on Totoro: declared hold-out
cells, dual coverage and refusal pricing, smoke-first then 800-rep panel
at 16 cores. Record against the locked grid. Do **not** freeze T\*. Do
not open public interval doors.

## 2. Implemented

- Totoro BatchMode load `2.11 2.07 2.01` (idle). Deploy
  `~/gllvmtmb-mspl-forkB-t1-20260818` @ `7187b7d` + rsynced T1 runner.
- 1-rep smoke `T1-anchor-n40-T8` / seed `20260830`: `smoke_ok: TRUE`,
  two-sided `Q_0` / fork B, RDS 724 bytes, LOG 698 bytes.
- 800-rep panel at 16 workers, 15.3 s. 800 unique-seed rows, no empty cell.
  Anchor cov_eff 0.940 / 0.975; near-tail 0.710; far-tail 0.580.
- `tstar_status: NOT-FROZEN`. `calibrated: FALSE`. `public_confint: refused`.

## 3. Files Changed

- `dev/mspl-forkB-t1-smoke.R` — T1 runner (far_tail + four hold-outs)
- `dev/mspl-forkB-t1-totoro-panel.sh` — smoke-then-panel launcher (16-core cap)
- `docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`
- `docs/dev-log/research/2026-08-18-mspl-forkB-t1-receipt.md`
- `docs/dev-log/research/2026-08-18-mspl-forkB-t1-panel.rds` / `.md` / `.log`
- `docs/dev-log/research/2026-08-18-mspl-forkB-t1-k2-T1-anchor-n40-T8-20260830-n1.rds` / `.log`
- `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/` — kit pointer
- `docs/dev-log/after-task/2026-08-18-mspl-forkB-t1-totoro.md` — this file
- `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-t1-totoro.md`
- `docs/dev-log/check-log.md` — this sitting

Not touched: `R/`, `src/`, `NEWS.md`, register, #1077, closed L2 kit,
closed g0_unlock kit, repo-root `LOOP/`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** record T1; do not freeze T\*. **Rationale:** user lock +
  proposal. **Rejected:** copying L1’s 0.80 Wilson rule as T\*. **Confidence:** high.
- **Decision:** 16 cores, not 150. **Rationale:** GOAL + D-143 courtesy.
  **Rejected:** filling the D-143 ceiling. **Confidence:** high.

## 4. Checks Run

```sh
# Totoro load before smoke: 2.11 2.07 2.01
# smoke RDS 724 bytes, LOG 698 bytes, smoke_ok: TRUE, tape=Q_0 fork=B
# panel RDS: 4 cells × 200 = 800 unique seeds; all tape=Q_0 fork=B
# first cell nonempty (200/0/188)
# no leftover mspl-forkB-t1 processes after panel
gh pr view 1077 --json isDraft   # must stay true
rg -n "se = TRUE|calibrated: TRUE|coverage_claim: covered|tstar_status: FROZEN" \
  dev/mspl-forkB-t1-smoke.R \
  docs/dev-log/research/2026-08-18-mspl-forkB-t1-receipt.md
# no public-claim / T* freeze hits
git diff --stat -- LOOP docs/dev-log/lanes/cursor-mspl-fork-B/ \
  docs/dev-log/lanes/cursor-mspl-fork-B-L2/ R src NEWS.md
# empty vs those closed paths
```

## 5. Tests of the Tests

No new testthat file. L1 harness already owns Wilson / classify.
Smoke object inspected (not exit code): finite `lo < hi`, `Q_0`, fork B.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| public `se = TRUE` | none |
| `calibrated: TRUE` / `coverage_claim: covered` | none |
| `tstar_status: FROZEN` | none; receipt says NOT-FROZEN |
| L1/L2 seeds `20260818`–`20260821` walked | absent |
| closed L2 / g0_unlock / root `LOOP/` | untouched |
| #1077 undrafted | no |

## 7. Roadmap Tick

N/A — recording gate, no advertised capability.

## 7a. GitHub Issue Ledger

No new issue. #1077 stays draft. MSPL-04 stays `blocked`.

## 8. What Did Not Go Smoothly

Classifier gated the remote scp / panel twice; both needed an explicit
approval retry. Panel wall (15.3 s) matched the optimistic clock, not
the conservative 25 min serial estimate.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie.** Smoke RDS/LOG bytes inspected before the 800.
**Fisher.** Dual coverage + refusal pricing recorded; T\* left open.
**Rose.** Hard OUTs held: no public se, no #1077, no NEWS `covered`.
**Grace.** 16-core cap in the launcher; D-143 150 is a ceiling, not a target.

## 10. Known Limitations And Next Actions

T1 recorded on Totoro. T\* remains a later human freeze. E2 still
NOT-EVALUABLE on `b_fix`. Optional confirm `T1-confirm-n80-T8` / seed
`20260834` was not run.
