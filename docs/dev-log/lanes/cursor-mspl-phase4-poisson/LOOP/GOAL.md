# GOAL — cursor-mspl-phase4-poisson (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`) are historical —
do not reopen their GOALs. Sibling `cursor/mspl-phase4-tweedie` is a
different family cell; do not edit it.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: strengthen Poisson LA-MSPL Phase-4 PREP (planned only):
  derivation note + pure-R oracles E1–E7 + this LOOP kit + after-task + docs+test PR
HEADLINE: pin information atom, all-zero/near-zero coercivity, and exposure≠information without admitting Poisson
DEFER: admit; prepare widen; NEWS covered; live Poisson estimator="mspl" success tests; C++ tape; NB1/NB2; SE (Codex Lane B); Gaussian SE; Totoro campaign
DISCIPLINE: planned only; se=FALSE if any fit; OMP=1; verify by logs; explicit-path commits; HARD STOP before admit/merge-to-main
```

## Headline

Earn a stronger Phase-4 Poisson *prep* surface — algebraic identities
inside E1–E7, not a new family tape and not an admission.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-phase4-poisson`.
- Branch `cursor/mspl-phase4-poisson`.
- Lane LOOP only under `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/`.
- OWN only: this LOOP/, the Poisson prep note, the Poisson oracle
  test, and this lane's after-task.
- Do NOT edit `R/mspl.R`, `src/`, other families, Codex
  `codex/lane-b-mspl-interval-feasibility`, repo-root `LOOP/`,
  Dropbox checkout, or sibling Phase-4 Tweedie files.
- Do NOT flip Poisson `planned` → `admitted`.
- Do NOT widen `.gllvmTMB_mspl_prepare()` beyond `family_id %in% {0,1,2}`.
- Do NOT write NEWS “covered”. Do NOT add live Poisson MSPL success tests.
- Local oracles only; `OMP_NUM_THREADS=1`.
- Never `git add -A`. Stage explicit paths.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding arc detail for this run.
- Programme constitution Phase 4:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- Prep note:
  `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`

## Definition of done

1. Note + oracles E1–E7 strengthened (identities, not just monotone
   smoke) and still **planned / phase4_prep** only.
2. Oracles run; structured PASS counts recorded in after-task +
   checkpoint (log, not exit code).
3. LOOP kit committed. After-task present.
4. Explicit-path commit(s) pushed. Docs+test PR open.
5. HARD STOP stated: no admit, no merge-to-main.

Finish line is **prep + PR**, not admission.
