# Plan vs actual — Design 125 fork B local L2 (2026-08-18)

**Plan:** `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/ultra-plan.md`  
**Lane LOOP:** `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/`  
**Reconciler:** Melissa (six materiality axes only)

Campaign close after K5 / V1. L2 is **recorded**. Totoro stays blocked.

## Axes

| Axis | Planned | Actual | Tag |
|---|---|---|---|
| Scope | Local L2 only: inherit Seed A 0.880; new seeds 20260819/20 × 50 on `L1-anchor-n80-T8`; one near-tail `L1-neartail-n40-T4` / 20260821 × 50; dual coverage + refusal; official receipt. Stop before Totoro. | Delivered. Thin runner `dev/mspl-forkB-l2-smoke.R`. 150 new rows in 30.6 s after compile. Receipt `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`. No Totoro, no T\*, no undraft #1077, no public se, MSPL-04 still `blocked`. | match |
| Evidence | Multi-seed interior + one near-tail; dual `cov_ret` / `cov_eff` + refusal + Wilson + MCSE; `calibrated=FALSE`; public refuse. No numeric T\* band. | Seed B/C cov_eff 0.900 Wilson [0.7864, 0.9565] 50/0/45; near-tail 0.780 Wilson [0.6476, 0.8725] 50/0/39; all `Q_0` / B; refusal 0 so ret=eff. Seed A inherited 0.880, not re-walked. Near-tail 0.780 recorded, not branded FAIL. | match |
| Model routing | `/goal` on `cursor-mspl-fork-B-L2`; K1 runner then {K2a ∥ K2b} then K3→K4→K5. | Same worktree `~/local-scratch/lanes/gllvmTMB-mspl-forkB-L2-goal`, exec branch `cursor/mspl-forkB-L2-exec-20260818`. K3 agent polled for sibling K2, then compiled + inspected 1-rep objects, then ran the 50-rep panel. Sibling K2 shell + 1-rep rds landed on the same tree with matching numbers. | **adaptive** |
| Safety gates | LOCAL only. Public doors closed. Closed g0_unlock kit and root `LOOP/` frozen. Totoro / T\* / undraft #1077 / MSPL-04→covered / NEWS covered = hard OUT. | Held. `gh pr view 1077 --json isDraft` → `true`. Closed kit and root `LOOP/` untouched. | match |
| Public claims | No `se=TRUE`, no `vcov()` / `confint()`, no NEWS / README / article `covered`, no MSPL-04 flip. L2 is recorded, not calibrated. | Held. Receipt states `calibrated: FALSE`, `public_confint: refused`, `coverage_claim: none`. | match |
| Handoff | After K5: Melissa plan-vs-actual; checkpoint NEXT = Totoro (blocked). | This file. Checkpoint updated. D-43 panel not fired — L2 recorded is not a public-claim milestone. | match |

## Material deviations

1. **Compile before smoke** — planned K2 assumed the L1 harness would just run. Fresh worktree `load_all(compile=FALSE)` had no DLL and returned `R-FIT`. Actual: `R CMD INSTALL` to `/tmp/gllvmtmb-l2-rlib`, then inspect. **`adaptive`** · Curie. Not a DGP change.
2. **K3 sitting also wrote K1** — ultra-plan assigned K1 to `/goal` then K3 after K2. Parallel K3 agent waited; sibling K2 files appeared during the same window. Runner + Seed A guard landed here so the panel could run. **`adaptive`** · Ada.
3. **D-43 panel skipped** — ultra-plan said not a public-claim milestone. Not run. **`adaptive`** · Rose.

## Drift to Rose

None unjustified. Totoro not started. #1077 stays draft. MSPL-04 stays `blocked`. Companion 0.935 not used.

```
DECISION RECEIPT
  Questions asked      — none; G0 already signed local L2 only.
  Answers received     — (none this sitting)
  Defaults accepted    — inherit 0.880; reuse L1 harness; no T* band;
                         no Totoro; public doors closed.
  Adaptive decisions   — compile then re-smoke; write thin runner in the
                         K3 sitting; skip D-43.
  Unresolved           — Totoro / T* / undraft #1077 / public se /
                         MSPL-04→covered remain Shinichi G0.
```
