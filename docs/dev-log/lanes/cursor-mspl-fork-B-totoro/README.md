# Lane — cursor-mspl-fork-B-totoro (ADEMP T1 on Totoro)

**NEW `/goal` kit.** Do **not** reopen the closed local-L2 kit at
`docs/dev-log/lanes/cursor-mspl-fork-B-L2/` (GOAL_MET; #1162 + #1168).
Do **not** reopen `docs/dev-log/lanes/cursor-mspl-fork-B/` (g0_unlock GOAL_MET).
Do **not** overwrite repo-root `LOOP/` (Poisson \(W_*\) REPLACE GOAL_MET).

Worktree: `~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro`
Branch: `cursor/mspl-fork-B-totoro-20260818` from `origin/main`.

| File | Role |
|---|---|
| `LOOP/GOAL.md` | Immutable mission for **Totoro T1** (RECORD only) |
| `LOOP/ultra-plan.md` | Binding plan (G0 2026-08-18: Totoro locked) |
| `LOOP/arcs.md` | T1 arc table |
| `LOOP/checkpoint.md` | Resume pointer |
| `LOOP/decision-queue.md` | Signed G0 + remaining hard OUTs |
| `LOOP/launch-prompt.md` | Paste-ready `/goal` cold start |
| `LOOP/grid-proposal.md` | Pointer to the locked 800-fit grid |

**Compute target: Totoro** (`totoro.biology.ualberta.ca`), 16 cores.
DRAC is fallback only if Totoro dies mid-run.

**Inherited, not rewritten:** official L1 (#1128) cov_eff **0.880**;
official L2 (#1162) Seed B/C **0.900** / near-tail **0.780**.
Companion 0.935 walk is a different harness — do not mix.

**T1 grid (LOCKED, T\* not frozen):**
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`
and `LOOP/grid-proposal.md`. Four hold-out cells × 200 = **800 fits**,
seeds `20260830`–`20260833`, RECORD only. Smoke-first local then Totoro
1-rep × 4 **before** the full 800.

**Hard OUT:** T\* freeze · undraft #1077 · public `se`/`vcov`/`confint` ·
MSPL-04 → `covered` · NEWS `covered` · reopen closed L2 / g0_unlock ·
`git add -A` · isdm-package-recovery.
