# GOAL — cursor-mspl-phase4-tapes-planned (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`,
`cursor-mspl-phase4-prep-goal`) are historical — do not reopen their
GOALs except a one-line pointer.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo platform: Cursor
Deliverable: one shared weight-hook and five fenced planned C++ tapes; public estimator="mspl" runs only for gaussian, bernoulli, and Poisson
HEADLINE: all five tapes exist; only Poisson becomes newly callable; nobody is admitted
IN PARALLEL: Shannon lanes · five family specs/failing tests · Rose fence · handover
DEFER: admit · NEWS covered · SE · Totoro>30min · EVA/VA/AGHQ-MSPL · Codex interval lane · public MSPL on NB1/NB2/beta/Tweedie · five people editing gllvmTMB.cpp at once
DISCIPLINE: verify=failing TMB/oracle tests before cpp · compute=local OMP=1 · closure=prepare admits gaussian+bernoulli+Poisson only, five tapes planned/fenced, Rose PASS
```

## Headline

All five tapes exist; only Poisson becomes newly callable; nobody is
admitted.

## Invariants

- Workspace ONLY
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Branch `cursor/mspl-phase4-tapes-planned` from `origin/main`.
- Lane LOOP only under
  `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`.
- Never Dropbox. Never repo-root `LOOP/`. Never `git add -A`.
- Never touch `codex/lane-b-mspl-interval-feasibility`.
- Do NOT merge #972–#976 from this lane.
- Do NOT flip any family `planned` → `admitted`.
- Public `estimator="mspl"` after this GOAL: gaussian, bernoulli, and
  Poisson only. NB1, NB2, beta, Tweedie still error at prepare.
- Rate `c` stays symbolic. No Bernoulli/Gaussian `c` transplant.
- Each atom is the GLM-outer `1/2 log det(X' W X)` candidate, **not**
  Laplace-marginal `I(β)`.
- NB2 registry stays `excluded`. No new `planned` row for NB1 / beta /
  Tweedie.
- Do NOT write NEWS “covered”. Do NOT implement SE.
- One cpp owner. No second editor of `src/gllvmTMB.cpp`.
- Failing TMB/oracle tests before any `src/` edit.
- Local only; `OMP_NUM_THREADS=1`. Totoro >30 min is HARD STOP.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding G0-locked plan.
- Programme constitution:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Definition of done

1. LOOP kit committed on `cursor/mspl-phase4-tapes-planned`.
2. Shared family-dispatch weight hook in `src/gllvmTMB.cpp` without
   changing Bernoulli or Gaussian numbers.
3. Poisson tape: `W=diag(μ)`, public `estimator="mspl"` succeeds,
   registry stays `planned` (notes updated: fenced planned tape, not
   admitted).
4. NB1, NB2, beta, Tweedie C++ tapes exist; public `mspl` still errors.
5. Prepare message no longer says “binomial or gaussian only”.
6. Rose fence: no admit, no NEWS covered, public door = three families.
7. After-task + Melissa plan-actual + checkpoint overwritten.

Finish line is **fenced planned tapes + Poisson public door**, not
admission.
