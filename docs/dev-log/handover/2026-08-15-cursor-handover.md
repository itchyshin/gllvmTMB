# Session Handoff: LA-MSPL point programme continue (Gaussian depth + Poisson Phase-4)

Meta: 2026-08-15 · from Cursor → Cursor · AUTHOR=cursor · TARGET=cursor · lane RUNNING

You are Cursor, picking up the **LA-MSPL** programme (Laplace + soft outer criterion). You inherit **no chat history**. This committed handover is authoritative. Reconcile it with live `git` before any mutation.

## Critical Context

1. **Estimator identity:** this lane is **LA-MSPL** — Laplace for the latent integral, soft outer criterion for the MSPL point. It is **not** EVA, **not** VA, and **not** AGHQ-MSPL.
2. **Workspace:** ONLY `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`. Do **not** use the Dropbox checkout.
3. **Active lane (this run):** `cursor/mspl-point-programme-continue`  
   LOOP: `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/` — **never** repo-root `LOOP/`.
4. **Closed kits — do not reopen as unfinished:**
   - `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/` — CLOSED (#963/#964/#969)
   - `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` — CLOSED (#967/#968)
   - `docs/dev-log/lanes/cursor-mspl-arc-1a/LOOP/` — CLOSED (#962)
5. **PROTECTED — Binary SE / interval lane:** `codex/lane-b-mspl-interval-feasibility`. Do not touch.
6. **No Gaussian SE.** Point estimates only (`se = FALSE`).
7. **Shinichi pacing:** run **≥5 hours**, parallel, **until the lane GOAL is finished** (not a tiny smoke).

## Immutable GOAL (also in LOOP/GOAL.md)

```text
Solo: Cursor
Deliverable: (A) multi-seed failure-inclusive Gaussian LA-ML vs LA-MSPL point evidence on ordinary cells, evidence thickened beyond single-seed oracle_local; (B) Poisson LA-MSPL Phase-4 prep: symbolic atom + pure-R oracles + planned registry rows (NOT admitted until smoke); (C) durable handover + Mission Control updates
HEADLINE: finish the point-estimate MSPL arc for Gaussian depth + Poisson derivation without touching SE
DEFER: binary SE (Codex PROTECTED); Gaussian SE; NEWS covered; Totoro/DRAC campaign unless ≤30min local first then STOP for Shinichi if larger; EVA; free-ε reopen
DISCIPLINE: se=FALSE; OMP=1; verify by logs; failure-inclusive denominators; apples-to-apples; closure=after-task+PRs+Melissa
```

## Plans / Roadmap

| Arc / lane | Status | Notes |
|---|---|---|
| #961–#969 MSPL series on main | **DONE** | programme, 1A, Bernoulli, smokes, Ψ map, Hirose admit, LOOP closeouts |
| **`cursor/mspl-point-programme-continue`** | **RUNNING** | A Gaussian multi-seed + B Poisson Phase-4 prep + C handover/MC |
| Binary SE / intervals | **PROTECTED** | Codex lane-b |
| Gaussian SE | **NOT YET** | Out of scope |
| Poisson admit | **HARD STOP** | planned rows only until smoke + Shinichi |
| Campaign / Totoro | **GATED** | local ≤30 min first |

## What Was Accomplished (prior series on `main`)

- #962 Arc 1A provenance; #963 Phase 2 registry + Phase 3 prep; #965 binary smoke;
  #966 pick C; #967 Gaussian ordinary Hirose admit/`oracle_local`; #968/#969 LOOP closeouts.

## Current Working State

- **Branch:** `cursor/mspl-point-programme-continue` tracking / diverging from `origin/main` @ `d8c12011` (reconcile live).
- **In progress:** A1 Gaussian multi-seed grid; B1 Poisson derivation/oracles/planned registry (parallel).
- **Not working:** Binary SE; Gaussian SE; Poisson admit; NEWS covered; free-ε.

## Key Decisions & Rationale

1. Stick to lane name **`cursor/mspl-point-programme-continue`** (not reopen closed kits).
2. Uniqueness **pick C** remains pinned for Gaussian.
3. Poisson Phase-4 = derivation + oracles + **`planned`** registry only.
4. Failure-inclusive denominators; apples-to-apples ML vs MSPL; `se = FALSE`.
5. Never write repo-root `LOOP/`. Never `git add -A`.

## HARD STOP (must pause and ask)

- Binary SE / interval lane files
- Gaussian SE implementation
- Flip Poisson planned→admitted without smoke+Shinichi
- Totoro/DRAC job >30 min without pre-run receipt + approval
- NEWS saying "covered"
- Repo-root LOOP/

## Files (this lane)

- `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/{GOAL,arcs,checkpoint,ultra-plan}.md`
- `docs/dev-log/handover/2026-08-15-cursor-handover.md` (this file — extend, do not fork conflicting handovers)
- Research notes / tests / registry edits as arcs land (see checkpoint)

## Mission Control

Update vault `live/status/gllvmTMB.json` NOW / claim_guard / capability.estimators note and any MSPL-by-family strip when A/B land. Curated status only — never hand-type tallies.

## Next Immediate Steps (OWED)

1. **OWED — A1:** multi-seed Gaussian LA-ML vs LA-MSPL (healthy + near-Heywood; q=1,2); research note; optional fixtures.
2. **OWED — B1:** Poisson symbolic atom + pure-R oracles + planned registry rows.
3. **OWED — C1:** Rose fences + Mission Control refresh.
4. **OWED — C2:** after-task + Melissa + stacked PRs; freeze checkpoint.

## How to Resume

```text
You are cursor/mspl-point-programme-continue — RESUME.
READ FIRST: docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/GOAL.md → checkpoint.md → ultra-plan.md → AGENTS.md → docs/dev-log/handover/2026-08-15-cursor-handover.md.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap on cursor/mspl-point-programme-continue.
CONTINUE FROM: checkpoint NEXT. Pause only at HARD STOP.
Never write repo-root LOOP/. Never touch Codex binary SE. Never admit Poisson without Shinichi.
```
