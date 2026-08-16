# Morning pointer — LA-MSPL items 1–3 (KEEP PLANNED)

Meta: 2026-08-15 evening → Shinichi morning · from Cursor
conductor · AUTHOR=cursor · TARGET=cursor · workspace
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` only
(not Dropbox). Repo-root `LOOP/` was not touched.

You are Cursor. Reconcile with live `git` before any mutation.

## Critical Context

1. **LA-MSPL** = Laplace + soft outer criterion (not EVA/VA/AGHQ-MSPL).
2. **Verdict: KEEP PLANNED.** Poisson `q1`/`q2` stay
   `status = "planned"`, `evidence = "phase4_prep"`.
3. **Do not merge #972–#976.** Do not merge an admit flip.
4. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE).
5. Public `se=TRUE` still withholds `sd_report`. No Totoro/DRAC SE
   campaign (D-139 receipt on `main` via #988).

## What Was Accomplished

Shinichi said do items 1–3. Conductor opened/pushed the sibling
receipts that had commits, watched checks, and squash-merged only
docs/test CI-green PRs that do not admit.

| Item | Result | PR |
|---|---|---|
| 1. Poisson multi-seed point smoke | Operational **PASS**, admit evidence **FAIL** (`n=8`, 64 arms, `se=FALSE`). Two sparse MSPL arms died to a null factor. | [#990](https://github.com/itchyshin/gllvmTMB/pull/990) |
| 2. #972–#976 stay unmerged | Commented; stale base `cursor/mspl-point-programme-continue`. Census written. | none (leave OPEN) |
| 3. No Totoro/DRAC SE campaign | D-139 receipt: host=none, minutes=0. Bernoulli \(Q_0\) non-PD (−0.774) on the #979 first cell. | [#988](https://github.com/itchyshin/gllvmTMB/pull/988) **MERGED** `6dfd2d75` |
| SE-CI honesty | Tests assert withhold + `skip_if` missing pin source; Bernoulli \(Q_0\) non-PD is a finding. | [#989](https://github.com/itchyshin/gllvmTMB/pull/989) |
| Ada verdict | **KEEP PLANNED** after reading the smoke. | this handover branch |

## Current Working State

- **Working:** #978 tapes + Poisson public door, #979 internal pin,
  #983 closeout, #988 no-campaign receipt — all on `main`.
- **In progress:** #989 (tests) and #990 (smoke docs) — watch CI;
  squash-merge only if green and still no admit.
- **Not working / blocked:** Poisson admit; calibrated SEs;
  Totoro/DRAC campaign.

## Key Decisions & Rationale

- Ada default **no admit** unless the smoke note exists **and** is
  an unambiguous PASS. The note exists and is **FAIL** for admit
  evidence. Operational finiteness is not Phase-4 exit.
- #972–#976 remain parked OPEN. `MERGEABLE`/`CLEAN` is against the
  stale continue-branch base, not `main`.
- #981 (B0 prereqs / Design 118) is **not** this sitting and is
  **not** a docs/test merge from this conductor.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `docs/mspl-no-se-campaign-receipt` @ `6dfd2d75` | y | y | #988 merged | LANDED |
| `cursor/mspl-se-ci` | y | y | #989 open | LANDED as PR; merge only if CI green |
| `cursor/mspl-poisson-point-smoke` | y | y | #990 open | LANDED as PR; merge only if CI green |
| #972–#976 | y | y | open, stale base | **CARRIED-OVER** — do not merge; human retarget later |
| this handover branch | y | y | this PR | LANDED as docs pointer |
| Codex Lane B | n (foreign) | y | none from Cursor | **PROTECTED** |

## Next Immediate Steps

1. Watch `gh pr checks 989` and `gh pr checks 990`. Squash-merge
   each only if CI-green, docs/test only, and `R/mspl-registry.R`
   is untouched.
2. Leave #972–#976 open. Do not retarget from this lane.
3. Do **not** flip Poisson `planned` → `admitted`. Next G0 (human):
   pinned \(c\), proved loading atom, TMB oracles — or defer Phase 4.
4. Do **not** start Totoro/DRAC. Receipt is already on `main`.

## Blockers / Open Questions

- Poisson loading atom under Laplace is still OPEN.
- Soft rate \(c = 1\) is unpinned.
- Bernoulli \(Q_0\) non-PD on the first pin cell: do not repair;
  do not campaign.

## Gotchas & Failed Approaches

- Shared worktree collisions aborted Curie/SE-CI before they
  committed. Conductor copied finished smoke files into
  `/private/tmp/gllvmtmb-mspl-poisson-point-smoke` and committed
  SE tests on `cursor/mspl-se-ci` with **explicit paths** (never
  `git add -A`).
- #979 CI flake: VA `delta_lognormal_log` health gate when SE pins
  ran first. SE files stay `test-zz-*`. Do not edit the VA suite.
- Do not read #978's public Poisson door as admission.

## HARD STOP

planned → admitted · NEWS covered · public `mspl` on NB1/NB2/beta/
Tweedie · merge #972–#976 · merge an admit flip · Codex absorb ·
repo-root `LOOP/` · Totoro/DRAC SE campaign · Dropbox checkout

## Mission control

| Repo | Branch / main | What shipped | Plan by leverage |
|---|---|---|---|
| gllvmTMB | `main` @ #988 + earlier #978/#979 | no-SE receipt; tapes; pin | KEEP PLANNED |
| gllvmTMB | #989 / #990 | SE-CI honesty; Poisson smoke | merge if green; no admit |
| gllvmTMB | #972–#976 | stale Phase-4 prep | leave OPEN |

## How to Resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-15-cursor-handover-mspl-1-3.md.
Run the handover rehydration steps, reconcile them with the current git state,
then continue only the OWED Next Immediate Steps.
KEEP PLANNED. Do not merge #972-976. Do not merge an admit flip.
Watch #989 and #990; squash-merge only docs/test CI-green PRs.
```
