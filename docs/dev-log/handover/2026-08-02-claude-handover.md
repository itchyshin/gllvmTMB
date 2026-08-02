# Session Handoff: Design 108 Gate A Stage 2 closed (VA mixed-family)

**Meta:** 2026-08-02 · from Cursor · to Claude · fresh context required

**Capability widget (step 0):** open `docs/dev-log/capability-surface.html` (live artifact
https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d) before planning.

## Mission-control summary

| Field | Value |
| --- | --- |
| Repo | `gllvmTMB` |
| `origin/main` tip at handoff write | `e51122c7` (includes #893 + #892) |
| This session shipped | Design 108 Gate A **Stage 2** — VA mixed-family + per-trait Gaussian SD |
| PR | [#893](https://github.com/itchyshin/gllvmTMB/pull/893) **MERGED**; R-CMD-check + pkgdown **success** on `27ccc4a0` |
| Register | **VA-11** = `partial` (admission plumbing only; no public claim) |
| Next (needs Shinichi) | Design 108 Stage **3** lognormal (0.5 d CHEAP) vs Stage **4** probit (Design 108 §6 info preference) vs other D-113 lane |
| Plan by leverage | Do **not** auto-start Stage 4; Stage 3 only if Shinichi opts in as early Rung 1 |

## Critical Context

1. **Stage 2 is DONE and on `main`.** Do not re-implement mixed-family VA packing.
2. **Multi-lane.** Read `docs/dev-log/handover/2026-07-25-active-lane-split.md` before any mutation. Do not touch the Dropbox primary checkout on `claude/profile-coverage-remeasure-20260718` (D-112 / PROTECTED dirty). Do not absorb Codex foreign lanes. Open sibling PR [#890](https://github.com/itchyshin/gllvmTMB/pull/890) (missing-data ledger) is not this lane unless Shinichi reassigns.
3. **VA remains hard-fenced opt-in.** No NEWS/README/article advertise of mixed-family VA. VA `mi()` stays refused. Pure binomial keeps JJ; mixed/non-binomial uses GH.
4. **Design 108 §6** prefers Stage 4 for information value; the Arc Card for Stage 2 explicitly overrode that. Do **not** silently jump to Stage 4.

## Goals / Mission

gllvmTMB = stacked-trait long-format GLLVMs (sister to drmTMB). Design 108 Gate A
unblocks Ayumi-shaped models on `integration = "va"`: Stage 1 mask (done #891) →
Stage 2 mixed-family + `log_sigma` (done #893) → optional Stage 3 lognormal →
Stages 4–6 probit/ordinal/phylo toward Gate A close. First CRAN target remains
`0.6.0` with recovery-only interval framing (D-112); this VA work is research-fence
capability, not a reason to widen public claims.

## Plans / Roadmap (beyond immediate steps)

- Design 108 Gate A Stages 3–6 (see `docs/design/108-va-parity-programme.md`).
- D-113 post-0.6 menu: missing-data #332/#336, EVA (Codex-owned unless reassigned),
  AGHQ claim-earning, remaining slope gaps (tweedie gated).
- Do not reopen VGH-for-gaussian or coverage re-measure (D-112).

## What Was Accomplished (this Cursor session)

- **#891** Design 107 Stage 1 (`is_y_observed`) already on main before Stage 2.
- **#893** Design 108 Stage 2 implemented, tested, merged:
  - Template: dense `DATA_IVECTOR(family)`; `PARAMETER_VECTOR(log_sigma)` length `T`.
  - R: packing/route/fence; mixed abort lifted for admitted set; gaussian identity on fence.
  - Tests: `test-va-mixed-family.R` + Stage 1/fence/routing/prototype regression green.
  - Register VA-11 `partial`; after-task + Melissa plan-actual; lane LOOP under
    `lanes/design108-stage2/LOOP/` (root `LOOP/` untouched).

## Current Working State

- **Working:** Stage 2 on `origin/main`; CI green on merge commit `27ccc4a0`.
- **In progress:** none for Design 108 Stage 2.
- **Not working / blocked:** next Design 108 stage needs Shinichi pick (Stage 3 vs 4 vs other).
- **Protected / foreign:** Dropbox dirty profile checkout; Codex spatial docs already
  merged (#892); open #890 missing-data ledger — do not bleed into it.

## Key Decisions & Rationale

- Per-row `family` IVECTOR (mirrors Laplace + Stage 1 mask), not length-`T` lookup.
- Estimated per-trait `log_sigma`; oracle fixtures may pin `estimate_gaussian_sd = FALSE`.
- Pure binomial → `jj`; mixed → `gh` (no per-row JJ).
- No Stage 3/4 auto-start after Stage 2 green.

## Landing State

`handoff_gate.sh` on the Dropbox primary checkout fails (expected: parked dirty
D-112 tree + many legacy unpushed local branches). Those are **not** Stage 2
artifacts. Stage 2 WT at handoff time: clean relative to this lane's work; Stage 2
commit is on `origin/main`.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `origin/main` `27ccc4a0` (#893) | yes | yes | [#893 merged](https://github.com/itchyshin/gllvmTMB/pull/893) | **LANDED** |
| `origin/main` `3f66d553` (#891 Stage 1) | yes | yes | [#891 merged](https://github.com/itchyshin/gllvmTMB/pull/891) | **LANDED** |
| `handover/2026-08-02-claude` (this doc + snapshot) | yes when PR opens | yes when pushed | handover PR (human merges) | **LANDED when handover PR merges** |
| `/private/tmp/gllvmtmb-design108-stage2-mixed-20260801` | n/a | n/a | n/a | disposable WT; optional delete after handover PR |
| Dropbox `claude/profile-coverage-remeasure-20260718` | mixed/dirty | partly no | none | **CARRIED-OVER / PROTECTED** — D-112 history; do not resume for Design 108. Resume only if Shinichi reopens coverage: inspect that checkout; never `git clean` it from another lane |
| PR [#890](https://github.com/itchyshin/gllvmTMB/pull/890) missing-data ledger | yes | yes | open | **FOREIGN / sibling** — do not absorb unless Shinichi reassigns |
| Legacy unpushed local branches (gate noise) | mixed | no | none | **CARRIED-OVER** — ignore; not this lane |

## Files Created / Modified (Stage 2 — already on main via #893)

- `inst/tmb/gllvmTMB_va_r3.cpp`
- `R/va-r3-proto.R`
- `R/va-routing.R`
- `R/approximation-engine.R`
- `R/integration-fence.R`
- `tests/testthat/test-va-mixed-family.R`
- `tests/testthat/test-integration-fence.R`
- `tests/testthat/test-va-r3-prototype.R`
- `docs/design/35-validation-debt-register.md` (VA-02/03 notes; VA-11)
- `docs/dev-log/after-task/2026-08-01-design108-stage2-va-mixed-family.md`
- `docs/dev-log/plan-actual/2026-08-01-design108-stage2-va-mixed-family.md`
- `docs/dev-log/check-log.md`
- `lanes/design108-stage2/LOOP/GOAL.md`
- `lanes/design108-stage2/LOOP/ultra-plan.md`

### This handover PR adds

- `docs/dev-log/handover/2026-08-02-claude-handover.md` (this file)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (Design 108 row refresh)
- `CLAUDE.md` Live Phase Snapshot refresh (multi-lane pointer)

## Next Immediate Steps (classify before acting)

1. **OWED — rehydrate only:** open capability widget; read `AGENTS.md`, this doc,
   `2026-07-25-active-lane-split.md`; run `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"`;
   classify items `OWED` / `DONE` / `RETRACTED` / `PROTECTED`.
2. **DONE — do not redo:** Stage 1 (#891), Stage 2 (#893), VA-11 register row.
3. **OWED — G0 with Shinichi (no code until answered):** pick next Design 108 rung —
   **(A)** Stage 3 lognormal (0.5 d CHEAP), **(B)** Stage 4 probit (Design 108 §6 preferred),
   or **(C)** leave VA and take another D-113 lane (e.g. #890 / #336).
4. **If A chosen (only after G0):** fresh WT from `origin/main`, named lane LOOP under
   `lanes/design108-stage3/`, implement lognormal VA branch; local tests; no public claim.
5. **PROTECTED:** do not edit root `LOOP/`; do not touch Codex foreign surfaces; do not
   stage Dropbox profile-checkout dirt; do not advertise mixed-family VA.

## Blockers / Open Questions

🔴 **Needs Shinichi:** Stage 3 vs Stage 4 vs non-VA next lane.

## Gotchas & Failed Approaches

- Large mixed GH smokes can hover just above the `1e-4` gradient health gate; thin
  in-fence fixtures (`n≥100`, small `p`/`q`, mild DGP) are the admission evidence.
- `n_starts = 1` must **not** report `healthy` — gate bypass stays visible as
  `failed_health_gate` (prototype test pins this).
- Known-SD gaussian oracle tests need `estimate_gaussian_sd = FALSE` after Stage 2.
- Do not reuse Design 107 WT for Stage 3+; cut fresh from `origin/main`.

## How to Resume

```sh
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"   # or a fresh WT from origin/main
cd "$REPO"
bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"
git fetch origin main
git status --short --branch
# Read: AGENTS.md → CLAUDE.md Live Phase Snapshot → this handover → active-lane-split
open docs/dev-log/capability-surface.html   # step 0
```

Safe verify (Stage 2 regression, local):

```sh
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-mixed-family.R")'
```

Do not stage: Dropbox `.claude/`, `.uinit/`, dirty profile-coverage files, foreign PR trees.

### Paste-ready Claude resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-02-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```

Interactive launch (human terminal):

```sh
claude "Rehydrate from docs/dev-log/handover/2026-08-02-claude-handover.md + the AGENTS.md / CLAUDE.md snapshot, then continue with the OWED Next Immediate Steps."
```
