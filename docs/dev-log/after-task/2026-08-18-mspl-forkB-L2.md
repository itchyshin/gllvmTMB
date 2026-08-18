# After Task: Design 125 fork-B local L2 panel + receipt

- **Branch**: `cursor/mspl-forkB-L2-exec-20260818`
- **Date**: `2026-08-18`
- **Roles (engaged)**: Curie, Fisher, Rose, Melissa

## 1. Goal

Record ADEMP / Design 125 gate L2 for fork B on local compute only:
multi-seed interior plus one near-tail cell, dual coverage and refusal
pricing, official receipt. Do not escalate to Totoro. Do not open public
interval doors.

## 2. Implemented

After compiled-DLL smoke-first (K2), the frozen 50-rep grid recorded:

- Seed A inherited: cov_eff **0.880**, Wilson [0.7620, 0.9438], 50/0/44 (#1128; not re-walked)
- Seed B 20260819 `L1-anchor-n80-T8`: availability 1, refusal 0, cov_eff **0.900**, Wilson [0.7864, 0.9565], 50/0/45
- Seed C 20260820 same cell: cov_eff **0.900**, Wilson [0.7864, 0.9565], 50/0/45
- Near-tail 20260821 `L1-neartail-n40-T4`: cov_eff **0.780**, Wilson [0.6476, 0.8725], 50/0/39

All 150 new rows `tape = Q_0` / fork B. `calibrated = FALSE`;
`public_confint = refused`; `coverage_claim = none`. Verdict **RECORDED**.

## 3. Files Changed

- `dev/mspl-forkB-l2-smoke.R` — thin L2 runner (K1)
- `dev/mspl-forkB-l2-k2-smoke-first.sh` — 1-rep driver
- `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md` — official receipt
- `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.rds` — 150-row object + inherited Seed A
- `docs/dev-log/research/2026-08-18-mspl-forkB-l2-k2-*.md` / `*.rds` — K2 1-rep objects
- `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/{checkpoint,arcs,launch-prompt}.md`
- `docs/dev-log/after-task/2026-08-18-mspl-forkB-L2.md` — this file
- `docs/dev-log/after-task/2026-08-18-mspl-forkB-L2-k1-runner.md` — K1 sitting
- `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-L2.md`
- `docs/dev-log/check-log.md` — this sitting

Not touched: `R/`, `src/`, `NEWS.md`, register, #1077, closed
`docs/dev-log/lanes/cursor-mspl-fork-B/**`, repo-root `LOOP/`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** inherit Seed A; do not re-run 20260818. **Rationale:** GOAL
  invariant 2. **Rejected:** rematch as new L2 history. **Confidence:** high.
- **Decision:** record near-tail 0.780 without applying L1's 0.80 Wilson
  rule. **Rationale:** inventing a band here is a silent T\*. **Rejected:**
  branding L2-FAIL. **Confidence:** high.

## 4. Checks Run

```sh
# K3 object inspected (not exit code): 150 new rows, all tape=Q_0 fork=B
# Seed A 20260818 absent from walked seed_bases
gh pr view 1077 --json isDraft   # true
rg -n "MSPL-04" docs/design/35-validation-debt-register.md  # still blocked
rg -n "se = TRUE|NEWS covered|calibrated: TRUE|coverage_claim: covered" \
  dev/mspl-forkB-l2-smoke.R \
  docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md
# no public-claim hits
git diff --stat -- LOOP docs/dev-log/lanes/cursor-mspl-fork-B/ R src NEWS.md
# empty
# deliberately not: Totoro, T*, public se/vcov/confint, undraft #1077,
# NEWS covered, git add -A, isdm-package-recovery
```

## 5. Tests of the Tests

No new testthat file. L1 harness already owns Wilson / refusal tests.
Seed A guard was exercised (20260818 not walked).

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `se = TRUE` on L2 receipt / runner | none |
| `NEWS covered` / `calibrated: TRUE` | none |
| `coverage_claim: covered` | none; receipt says `none` |
| Seed A `20260818` walked in L2 object | absent (inherited only) |
| closed g0_unlock kit / root `LOOP/` | untouched |
| companion 0.935 mixed into L2 headline | not used |

## 7. Roadmap Tick

N/A — recording gate, no advertised capability.

## 7a. GitHub Issue Ledger

No new issue. #1077 stays draft. MSPL-04 stays `blocked`.

## 8. What Did Not Go Smoothly

Fresh worktree `load_all(compile=FALSE)` had no DLL and first classified
K2 as `R-FIT`. Smoke was re-run after `R CMD INSTALL`. Parallel K1/K2
files landed on the same tree; 1-rep numbers match.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie.** Smoke-first must inspect the DLL, not only the row.
**Fisher.** Dual coverage recorded; no T\* band invented.
**Rose.** Headline stays inherited 0.880 plus new cells; 0.935 out of band.
**Melissa.** Plan-vs-actual at `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-L2.md`.

## 10. Known Limitations And Next Actions

L2 recorded, local only. Totoro / T\* / undraft #1077 / public se /
MSPL-04→covered remain hard OUT. E2 still NOT-EVALUABLE on `b_fix`.

**Close:** [#1162](https://github.com/itchyshin/gllvmTMB/pull/1162)
squash-merged at `93ea79bd` after ubuntu-latest (release) green.
Checkpoint is **GOAL_MET**. NEXT = Totoro (blocked; new G0 required).
