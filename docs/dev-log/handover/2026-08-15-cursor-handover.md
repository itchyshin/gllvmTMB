# Session Handoff: LA-MSPL Gaussian point evidence + Poisson Phase-4 plan

Meta: 2026-08-15 · from Cursor → Cursor · AUTHOR=cursor · TARGET=cursor · catch-up / Gaussian atom series closed on `main`

You are Cursor, picking up the **LA-MSPL** programme (Laplace + soft outer criterion). You inherit **no chat history**. This committed handover is authoritative. Reconcile it with live `git` before any mutation.

## Critical Context

1. **Estimator identity:** this lane is **LA-MSPL** — Laplace for the latent integral, soft outer criterion for the MSPL point. It is **not** EVA, **not** VA, and **not** AGHQ-MSPL. Do not reopen EVA/VA LOOP kits or transplant their language.
2. **Workspace:** ONLY `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`. The Dropbox checkout (`/Users/z3437171/Dropbox/Github Local/gllvmTMB`) must **not** be used for MSPL — it hosts foreign lanes and the root `LOOP/` EVA kit on `main`.
3. **Closed kits — do not reopen as unfinished:**
   - `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/` — CLOSED after #963/#964/#969
   - `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` — CLOSED after #967/#968
4. **PROTECTED — Binary SE / interval lane:** `codex/lane-b-mspl-interval-feasibility` in `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`. Do not touch, rebase, stage, merge, or “finish” it. Binary SE remains Codex-owned.
5. **No Gaussian SE yet.** Point estimates only (`se = FALSE`). No sandwich / profile / coverage claim from this lane.
6. **Shinichi pacing (this chat):** the **NEXT** lane must run **≥5 hours**, **parallel**, and **keep going until the lane GOAL is done** — not a tiny smoke-and-stop slice.

## Goals / Mission

Keep LA-MSPL a falsifiable parallel to LA-ML. After the Gaussian ordinary cell is admitted on `main` (#967), earn **multi-seed point evidence** (healthy + near-Heywood) under LA-ML vs LA-MSPL, then **plan** Poisson Phase-4 (derivation + local oracles only). Do not promote, export, or change defaults.

Durable programme (still required reading):

- `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Plans / Roadmap

| Arc / lane | Status | Notes |
|---|---|---|
| Arc 1A provenance | **DONE** | #962 merged |
| Phase 2 Bernoulli registry | **DONE** | #963 |
| Local binary point smoke | **DONE** | #965 |
| Gaussian Ψ uniqueness pick C | **DONE** | #966 |
| Gaussian Hirose ordinary cell | **DONE** | #967 admitted / `oracle_local` |
| LOOP closeouts | **DONE** | #968 Gaussian; #969 catch-up pointer |
| **`cursor/mspl-gaussian-point-evidence`** | **OWED NEXT** | Multi-seed Gaussian point smoke + Poisson Phase-4 **planned only** |
| Binary SE / intervals | **PROTECTED** | Codex lane-b |
| Gaussian SE | **NOT YET** | Explicitly out of scope |
| Campaign / Totoro grid | **GATED** | Needs G0 + compute receipt; no campaign without both |

## What Was Accomplished (this Cursor series on `main`)

- **#963** — Phase 2 Bernoulli registry + Phase 3 Heywood prep (no Gaussian admit in that PR’s prep oracles).
- **#966** — Gaussian uniqueness map pinned to **pick C**.
- **#967** — Gaussian ordinary LA-MSPL via Hirose soft atom; cell **admitted** / `oracle_local`.
- **#968 / #969** — LOOP closeouts for Gaussian and catch-up kits.
- Local **binary** and **gaussian** point smokes recorded (pair smoke docs / after-tasks on the merged tips).
- Arc 1A (#962) and programme doc (#961) already on `main` from earlier in the series.

## Current Working State

- **Working:** `origin/main` includes #963–#969. Catch-up and Gaussian LOOP kits are historical CLOSED.
- **In progress:** none — this handover opens the **next** lane.
- **Not working / blocked:** Binary SE stays on the protected Codex branch (ahead/behind vs its remote; classify only, do not mutate). Shared `active-lane-split` is multi-lane; MSPL row refreshed with this doc.
- **Compute:** local multi-seed point smokes are in-scope for the next lane; any fit **>30 min** STOP for a receipt; any **campaign** needs G0 + receipt and Totoro/DRAC (D-50), never Actions artifacts.

## Key Decisions & Rationale

1. **LA-MSPL ≠ EVA/VA/AGHQ-MSPL** — outer criterion on Laplace; do not confuse integration engines with the soft criterion.
2. **Gaussian uniqueness pick C** is pinned — do not reopen pick B / free-ε without a new G0.
3. **Point-first fence** — no Gaussian SE; do not absorb Codex binary SE work.
4. **Next lane is long-horizon (≥5 h, parallel)** until its GOAL is complete — Shinichi explicit in this chat. Create a fresh LOOP kit; do not rewrite closed kits’ GOALs.
5. **Poisson Phase-4 is planned/oracles only in this next GOAL** — derivation + local oracles; no inherited Gaussian/binary claim; no family-wide admit in the same PR without its own gate.
6. **Never write repo-root `LOOP/`** — that path is the 0.6 EVA/VA kit on `main`. Lane kits live under `docs/dev-log/lanes/<lane>/LOOP/`.
7. **Never `git add -A`.** Scope-stage explicit paths. Foreign untracked Dropbox files must not be staged.

## Files Created / Modified

### This handover branch (`handover/2026-08-15-cursor`)

- `docs/dev-log/handover/2026-08-15-cursor-handover.md` (this file)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (MSPL lane row / refresh — multi-lane map)
- `CLAUDE.md` (Live Phase Snapshot prepend — points at lane map + this handover; does not orphan sibling lanes)

### Explicitly not modified by this handover

- `R/`, `src/`, tests, NEWS, register promotion, DESCRIPTION
- Dropbox checkout; Design 117; Codex interval worktree
- Closed LOOP kits’ GOAL text (historical)

## Landing State

`handoff_gate.sh` on the MSPL worktree reported **GATE FAIL** from **hundreds of historical unpushed local branches** shared by this bare repo object — **not** from dirty MSPL working-tree files. Current MSPL feature tips for catch-up/Gaussian are **merged**. Declare foreign/historical unpushed branches **CARRIED-OVER / out of scope**; do not land them from this lane.

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `origin/main` @ `d8c12011` (#969 and prior MSPL merges) | yes | yes | #963–#969 merged | **LANDED** |
| This handover `handover/2026-08-15-cursor` | yes (this commit) | yes (with PR) | open docs PR | **LANDED when PR open; human merges** |
| `codex/lane-b-mspl-interval-feasibility` | local yes | remote divergent (ahead/behind) | none for MSPL point lane | **PROTECTED / CARRIED-OVER** |
| Historical unpushed `agent/*` / old Claude/Codex tips | mixed | no | n/a | **CARRIED-OVER — out of scope; do not push from MSPL** |
| Dropbox foreign dirty / untracked LOOP copies | n/a | n/a | n/a | **NEVER STAGE — wrong checkout** |

Protected-lane classify-only check:

```sh
git -C "/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB" status -sb
```

## Mission Control

| Repo / lane | Branch / main | CI / shipped | Plan by leverage |
|---|---|---|---|
| MSPL programme (Cursor) | `origin/main` + next `cursor/mspl-gaussian-point-evidence` | #963–#969 on main; LA-MSPL Gaussian ordinary admitted | New LOOP → G0 (this chat) → `/goal` ≥5 h until GOAL done |
| Binary SE sibling | `codex/lane-b-mspl-interval-feasibility` | Private / divergent | **PROTECTED** |
| CRAN 0.7 / VA / other | see active-lane-split | separate | Do not absorb |
| Dropbox checkout | foreign | wrong tree for MSPL | **Do not use** |

## Next Immediate Steps (OWED)

Classify against live git first (`OWED` / `DONE` / `RETRACTED` / `PROTECTED`). Then execute only `OWED`:

1. **OWED — rehydrate** in `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`: read `AGENTS.md`, this handover, programme after-task, lane map.
2. **OWED — live reconciliation:** `~/shinichi-brain/tools/lane_preflight.sh` on this worktree; `git fetch origin --prune`; `git status -sb`; open PRs; confirm #963–#969 on `main`; classify Codex interval lane **PROTECTED**.
3. **OWED — cut the next lane from `origin/main`:** branch `cursor/mspl-gaussian-point-evidence` (fresh tip; do not reopen closed catch-up/gaussian kits).
4. **OWED — create lane LOOP kit** at `docs/dev-log/lanes/cursor-mspl-gaussian-point-evidence/LOOP/` (`GOAL.md`, `arcs.md`, `checkpoint.md`, `ultra-plan.md`). **Never** repo-root `LOOP/`.
5. **OWED — ultra-plan / G0:** treat Shinichi’s instruction in this chat as **G0 implied** for this lane GOAL (below). If the ultra-plan skill still requires a written Gate-0 file, write the minimal plan-actual that quotes this GOAL and the ≥5 h parallel mandate; do not invent a narrower scope.
6. **OWED — run `/goal` (or the Cursor `goal` skill) on that long mission** and **keep going until the lane GOAL is done** (≥5 hours, parallel work OK). Do not stop after a single smoke if arcs remain.
7. **OWED — lane GOAL content (immutable intent):**
   - **Gaussian multi-seed point evidence:** healthy + near-Heywood cells; **LA-ML vs LA-MSPL**; `se = FALSE`; local smokes with `OMP_NUM_THREADS=1` (and BLAS thread pins).
   - **Poisson Phase-4:** derivation + local oracles **planned only** (and implement oracles only if the LOOP arcs say so after the Gaussian evidence arc closes) — no inherited Gaussian/binary penalty claim.
   - **Out of scope:** Binary SE; Gaussian SE; campaigns without G0+receipt; NEWS covered claims; default change; absorbing Codex interval files.
8. **OWED — closeout:** after-task + LOOP checkpoint freeze + scoped PR(s); hand back only when GOAL done or a real blocker needs Shinichi.

## Blockers / Open Questions

- **Binary SE** remains Codex-owned — surface conflicts to Shinichi; do not unilaterally resolve (D-87/D-88).
- **Campaign authorization** still needs explicit G0 + compute receipt if multi-seed grows past local smoke budget.
- **Arc 1B** (`estimator="ml"` outside Laplace) is a separate API G0 — not part of this point-evidence lane.
- Duplicate design-number ledger across refs — do not mint a new `docs/design/NN` without claiming by commit.

## Gotchas & Failed Approaches

- Do not reopen `cursor-mspl-catchup` or `cursor-mspl-gaussian` LOOP kits as if unfinished.
- Do not write repo-root `LOOP/` (clobbers EVA/VA kit).
- Do not use the Dropbox checkout for MSPL.
- Do not touch `codex/lane-b-mspl-interval-feasibility`.
- Do not `git add -A`.
- Do not call the composite estimator MAP/Firth wholesale; do not transfer Bernoulli `V_loading` onto Gaussian.
- Do not claim Gaussian SE or coverage from point smokes.
- Do not treat AGHQ, VA, or EVA as this lane’s engine.

## Live Environment and Safe Commands

```sh
cd "/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap"
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NOT_CRAN=true
```

Opening checks:

```sh
~/shinichi-brain/tools/lane_preflight.sh "/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap"
git status -sb
git fetch origin --prune
git log origin/main -8 --oneline
gh pr list --state open --limit 20
```

Safe verification for docs-only edits:

```sh
git diff --check
```

For fits/tests later: targeted `devtools::test(filter = ...)` only; estimate runtime; STOP at >30 min without a receipt.

## How to Resume

Start a fresh Cursor agent with the worktree:

```text
/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
```

Paste:

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-15-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```

Do not assume Cursor extensions, GitHub auth, R/TMB, or remote sockets — verify each before relying on it.
