# Launch / resume prompt — paste into a FRESH Cursor chat

Do **not** read repo-root `LOOP/GOAL.md` first — that file is the closed
REPLACE **GOAL_MET** kit.

Do **not** reopen `docs/dev-log/lanes/cursor-mspl-fork-B-L2/` (L2 GOAL_MET).
Do **not** reopen `docs/dev-log/lanes/cursor-mspl-fork-B/` (g0_unlock GOAL_MET).

Worktree: `~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro`
Kit: `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/`

---

## COLD START (paste this)

```markdown
/goal

Ultra-plan G0 approved. Run this plan to completion via LOOP/.

LANE: cursor-mspl-fork-B-totoro
REPO: ~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro
PLAN: docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/ultra-plan.md

READ FIRST, IN ORDER:
  docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/GOAL.md
  docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/checkpoint.md
  docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/ultra-plan.md
  docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/arcs.md
  docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md
  ./AGENTS.md

WORKSPACE: branch cursor/mspl-fork-B-totoro-20260818 in
~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro
(reattach + pull; do NOT recreate; do NOT use the Dropbox cloud-agent baton)

RUN goal skill — re-read GOAL each arc; verify by LOG not exit code;
conductor lean; pause at OPEN GATE; overwrite checkpoint each arc;
fresh chat at batch barriers.

START ARC: K1 (thin T1 runner: four locked cells + far_tail).
NEXT GATE: T* freeze / undraft #1077 / public se / MSPL-04→covered — NEVER auto-start.

COMPUTE: Totoro (totoro.biology.ualberta.ca), 16 cores,
OMP_NUM_THREADS=1, OPENBLAS_NUM_THREADS=1. DRAC = fallback only if
BatchMode SSH is dead. Not GitHub Actions (D-50).

LOCKED T1 GRID (800 fits; RECORD only; T* NOT-FROZEN):
  T1-anchor-n40-T8     / seed 20260830 / n=40  T=8  anchor     / n_rep=200 / RECORD
  T1-anchor-n160-T8    / seed 20260831 / n=160 T=8  anchor     / n_rep=200 / RECORD
  T1-neartail-n80-T8   / seed 20260832 / n=80  T=8  near_tail  / n_rep=200 / RECORD
  T1-fartail-n40-T4    / seed 20260833 / n=40  T=4  far_tail   / n_rep=200 / RECORD-ONLY
  far_tail intercepts = (−2.4, −2.2, −2.6, −2.3)
  E1 only; tape Q_0 / fork B; calibrated FALSE
  optional confirm T1-confirm-n80-T8 / 20260834 is OUT of the primary 800

SMOKE-FIRST (binding, before the full 800):
  1. K1 extend harness with far_tail + four T1-* ids
  2. K2a local 1-rep × 4; inspect objects (two-sided Q_0 / fork B with lo < hi, or typed ADEMP refusal)
  3. K2b Totoro BatchMode + deploy + R CMD INSTALL + 1-rep × 4; inspect again
  4. THEN K3 the 800-fit panel
  Abort the moment the first new cell is empty, blocked-on-L0, or untyped.

INHERIT (do not rewrite):
  official L1 #1128 cov_eff 0.880 Wilson [0.7620, 0.9438] seed 20260818
  official L2 #1162 Seed B/C 0.900 / near-tail 0.780
  Companion 0.935 is a different harness. Do not re-walk 20260818–20260821.

HARD OUT: T* freeze; undraft #1077; public se/vcov/confint; MSPL-04→covered;
NEWS covered; reopen closed L2 / g0_unlock; overwrite root LOOP/; git add -A;
isdm-package-recovery.
```

---

## RESUME

```markdown
/goal

RESUME. LANE cursor-mspl-fork-B-totoro.
READ FIRST: LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md
(under docs/dev-log/lanes/cursor-mspl-fork-B-totoro/).
WORKSPACE: ~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro
CONTINUE FROM: whatever checkpoint.md names as NEXT.
Do not redo landed arcs. Smoke-first before the full 800.
Do not freeze T*. Do not undraft #1077.
```
