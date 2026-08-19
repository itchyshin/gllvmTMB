# Ultra-plan — Design 125 fork B, DRAC confirm panel (RECORD only)

Frozen at G0 approval (Shinichi 2026-08-19): **DRAC confirm after T1**.
Binding detail for `/goal`. Locked grid:
`docs/dev-log/research/2026-08-19-mspl-forkB-drac-confirm-grid-proposal.md`.
Do **not** reopen closed T1 / L2 / g0_unlock kits or repo-root `LOOP/`.

## 🎯 GOAL

```
🎯 GOAL
Solo platform: Cursor (this session; read, not inferred)
Deliverable: DRAC confirm panel recorded — L1 confirm 200 + n160 3-seed × 200 = 800 fits; dual coverage + refusal pricing; official receipt. Kit on docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/LOOP/
HEADLINE: Post-T1 multi-seed stability on DRAC arrays (Fir/Nibi/Rorqual); inherit T1 + L1/L2; T* stays NOT-FROZEN unless separate G0
IN PARALLEL: kit docs (this sitting) · later /goal: local smoke → sbatch arrays
DEFER: T* freeze (unless signed after discussion packet) · undraft #1077 · public se/vcov/confint · MSPL-04→covered · NEWS covered · re-walk T1 800 · E2 · other families · GPU clusters
DISCIPLINE: verify=read LOG + object · compute=DRAC arrays (Totoro smoke) · closure=confirm receipt recorded, not calibrated
```

LANE TAKEN: **`cursor-mspl-fork-B-drac-confirm`** — new kit only.

---

## Phase 0.2 — Shannon pre-flight

```
VERDICT: FOREIGN LANES ACTIVE (Claude slope-ci, MSPL scaffold, etc.)
PLATFORM: cursor
LANE TAKEN: cursor-mspl-fork-B-drac-confirm (docs-only this sitting)
WORKTREE: ~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro @ origin/main
PRIOR: T1 GOAL_MET on main (#1173); T* packet landing this PR
```

---

## DECISIONS LOCKED

- Post-T1 confirm panel; **800 fits** as declared; DRAC primary; Totoro smoke
- Fork B; E1 only; RECORD only; T\* NOT-FROZEN unless separate signed G0
- Hard OUTs: #1077, public se, MSPL-04, NEWS covered, re-walk T1 hold-out

## QUESTIONS STILL OPEN

- Shinichi T\* choice (Options A/B/C in discussion packet) — **not asked here**
- DRAC account strings — read live at execute time

---

## Arc programme (for `/goal`)

| Arc | Deliverable |
|---|---|
| D0 | This kit + grid proposal + T\* packet (docs PR) |
| D1 | Runner extension (reuse `dev/mspl-forkB-t1-smoke.R`) |
| D2 | Smoke local + one DRAC cluster |
| D3 | 800-fit DRAC arrays |
| D4 | Official confirm receipt |
| D5 | After-task + check-log + PR |

---

## File-ownership fence

**May write:**

- `docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/**`
- `docs/dev-log/research/2026-08-19-mspl-forkB-{tstar-discussion-packet,drac-confirm-grid-proposal}.md`
- `docs/dev-log/after-task/2026-08-19-mspl-tstar-drac-design108-stale.md`
- `docs/dev-log/check-log.md` (append)
- `lanes/design108-stage2/LOOP/**` (stale banner only)
- `dev/mspl-forkB-drac-confirm.R` (execute arc only — not this sitting)

**Must not write:**

- `R/`, `src/`, `tests/`, Design 125 body, ADEMP body, `decisions.md` (unless T\* signed)
- Closed kits: `cursor-mspl-fork-B-totoro`, `cursor-mspl-fork-B-L2`, `cursor-mspl-fork-B`, repo-root `LOOP/`

---

## Launch prompt (paste-ready)

See `LOOP/launch-prompt.md`.
