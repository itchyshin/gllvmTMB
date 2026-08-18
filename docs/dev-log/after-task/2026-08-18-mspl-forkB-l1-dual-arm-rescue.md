# After Task: Rescue orphan dual-arm L1 probe into #1128

**Branch**: `cursor/mspl-forkB-l1-smoke-20260818`  
**Date**: `2026-08-18`  
**Roles (engaged)**: Curie, Fisher, Rose, Shannon

## 1. Goal

Keep the useful untracked work from the orphan clone
`~/local-scratch/lanes/gllvmTMB-g0-unlock-20260818` (separate `.git`,
tip `a6bb6916`, not an ancestor of #1130) without clobbering the live
#1130 worktree and without claiming a 6-rep probe as an L1 gate.

## 2. Implemented

#1128 now also carries the dual-arm `objective=` runner
(`dev/mspl-fork-b-l1-smoke.R`) and the rescued 6-rep T=4 receipt. The
runner fail-louds as `blocked-on-L0` when `objective=` is missing, so
it does not walk fork A as a silent substitute on current `main`. The
50-rep T=8 ADEMP receipt is unchanged. Public doors stay closed.

The orphan's `a6bb6916` `R/mspl.R` commit was **not** rescued. That
estimand lives on #1130.

## 3. Files Changed

- `dev/mspl-fork-b-l1-smoke.R` — rescued dual-arm runner + `objective=` gate
- `docs/dev-log/research/2026-08-18-mspl-forkB-l1-dual-arm.md` — honest receipt
- `docs/dev-log/research/2026-08-18-mspl-forkB-l1-dual-arm-raw.csv` — 12 rows
- `docs/dev-log/research/2026-08-18-mspl-forkB-l1-dual-arm-summary.csv` — 2 arms
- `tests/testthat/test-mspl-forkB-l1-dual-arm-smoke.R` — band / CSV / L0 / fence
- `docs/dev-log/after-task/2026-08-18-mspl-forkB-l1-dual-arm-rescue.md` — this file
- `docs/dev-log/check-log.md` — this sitting

Not touched: `R/`, `src/`, `NEWS.md`, register, #1077, live #1130
worktree `gllvmTMB-g0-unlock-1130`, orphan clone (stays until
post-#1130/#1128 cleanup).

## 3a. Decisions and Rejected Alternatives

- **Decision:** fold into #1128 rather than open a second L1 PR.
  **Rationale:** same Design 125 local-smoke family and hard OUTs; a
  new worktree off `origin/main` was the listed alternative but
  collided with live-lane hygiene. **Rejected:** rewriting #1130 from
  `a6bb6916`; treating the 6-rep as a gate. **Confidence:** high.
- **Decision:** keep the hyphenated filename `mspl-fork-b-l1-smoke.R`.
  **Rationale:** that is the orphan path; the camelCase
  `mspl-forkB-l1-smoke.R` is already the ADEMP runner. **Rejected:**
  overwriting the 50-rep runner. **Confidence:** high.

## 4. Checks Run

```sh
devtools::test(filter = "mspl-forkB-l1-dual-arm-smoke")
# first run FAIL 1 | PASS 22 (fence test treated `no NEWS covered` as a claim)
# after tightening: FAIL 0 | WARN 0 | SKIP 0 | PASS 23

devtools::test(filter = "mspl-forkB-l1-ademp-harness")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 30 (existing ADEMP suite unchanged)

rg -n "se = TRUE|NEWS covered|MSPL-04|undraft" \
  dev/mspl-fork-b-l1-smoke.R \
  docs/dev-log/research/2026-08-18-mspl-forkB-l1-dual-arm.md \
  docs/dev-log/after-task/2026-08-18-mspl-forkB-l1-dual-arm-rescue.md
# no public-claim hits (MSPL-04 / #1077 only as still blocked / still draft)

# deliberately not run: Totoro, T*, public se/vcov/confint, undraft #1077,
# NEWS covered, git add -A, isdm-package-recovery, live 100-rep dual-arm fit,
# rewrite of #1130, delete of the orphan clone
```

## 5. Tests of the Tests

- `l1_band_ready(6)` is FALSE — would catch a receipt that called n=6 a gate.
- Fork-A row on the rescued CSV fails availability and refusal if someone
  applies the L1 gate anyway.
- On main (no `objective=`), `run_dual_arm_probe()` errors `blocked-on-L0`.
- Runner text must contain `se = FALSE` and must not contain `se = TRUE`.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `se = TRUE` as a shipping claim | absent |
| `NEWS covered` | absent |
| `MSPL-04` flipped off `blocked` | absent; receipt says still blocked |
| Totoro campaign | receipt says not run |
| #1077 undraft | not touched |
| `a6bb6916` merged onto #1130 | not done; #1130 worktree left clean |

## 7. Roadmap Tick

N/A — no ROADMAP row; this is a local probe rescue.

## 7a. GitHub Issue Ledger

No relevant open issue closed. Sibling L0 authorising code is PR #1130.
#1128 remains the L1 smoke PR. #1077 stays draft.

## 8. What Did Not Go Smoothly

The orphan clone shares the branch *name* `cursor/g0-unlock-design125-forkB`
with live #1130 but is a separate `.git` whose tip is not an ancestor of
#1130. A first attempt to open a fresh worktree off `origin/main` was the
listed alternative; this sitting folded instead so the live #1130 tree
stayed untouched.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie.** CI tests the band arithmetic and the rescued CSV. It does not
re-fit six MSPL profiles.

**Fisher.** n=6 can look like “fork B covered 6/6.” That is not L1. The
receipt leads with INCOMPLETE.

**Rose.** Two L1 runners now live on one PR. The hyphenated name is the
dual-arm `objective=` probe; the camelCase name is the ADEMP `tape=`
harness. Mixing those stories is the failure mode to watch.

**Shannon.** Live #1130 worktree `gllvmTMB-g0-unlock-1130` was not
edited. The orphan clone stays on disk for post-#1130/#1128 cleanup.
Sibling `gllvmTMB-mspl-forkB-L1` (coverage-gate tsv) was left alone.

## 10. Known Limitations And Next Actions

- Dual-arm L1 still needs a 50–100-rep run after #1130 merges.
- E2, L2, T* remain out.
- Hard OUTs remain: no public `se` / `vcov` / `confint`, no undraft
  #1077, no MSPL-04 `covered`, no Totoro claim as covered.
- Orphan clone cleanup waits until #1130 and #1128 are done.
