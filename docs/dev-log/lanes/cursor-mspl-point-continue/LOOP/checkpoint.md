# checkpoint — cursor-mspl-point-continue

GOAL: see GOAL.md.   STATE: **RUNNING** — A0+A1+B1 done; C* remain.

ARCS DONE (verified):
- A0 — branch `cursor/mspl-point-programme-continue` @ `origin/main` tip; LOOP kit written under `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/`.
- A1 — multi-seed Gaussian LA-ML vs LA-MSPL point grid + research note.
  Script `dev/mspl-gaussian-multiseed-point-grid.R`; TSV
  `docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-grid.tsv`;
  note `docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-evidence.md`.
  Grid: 64/64 finite conv0 in 14.5 s; near-Heywood q=1 ML uniqueness
  collapse 4/8 vs MSPL 0/8; no registry flip; no SE.
- B1 — Poisson Phase-4 prep (NOT admission).
  Note `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`;
  oracles `tests/testthat/test-mspl-poisson-phase4-oracles.R`;
  registry `poisson:log:ordinary:q1/q2` status=`planned`, evidence=`phase4_prep`.
  Prepare fence still `family_id %in% {0,1}`; `git diff -- src/` empty on B1.

ARC IN PROGRESS:
- (none on B1)

NEXT: C1 Mission Control + Rose; then C2 closeout.

OPEN GATES (need human): Poisson `planned`→`admitted` (smoke + Shinichi);
loading-atom coercivity under Laplace still OPEN in the Phase-4 note.
HARD STOPs listed in GOAL.md.

TRUTH LIVES IN: worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`; branch `cursor/mspl-point-programme-continue`; this LOOP kit; handover `docs/dev-log/handover/2026-08-15-cursor-handover.md`.

RESUME:
```text
You are cursor/mspl-point-programme-continue — RESUME.
READ FIRST: docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/GOAL.md → checkpoint.md → ultra-plan.md → AGENTS.md → docs/dev-log/handover/2026-08-15-cursor-handover.md.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap on cursor/mspl-point-programme-continue (reattach + pull; do NOT recreate; do NOT use Dropbox checkout).
CONTINUE FROM: checkpoint NEXT. Pause only at HARD STOP in GOAL.md.
Never write repo-root LOOP/. Never touch Codex binary SE lane. Never admit Poisson without Shinichi.
```
