# GOAL — cursor-mspl-phase4-hurdle (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`) are historical —
do not reopen their GOALs.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: delta/hurdle LA-MSPL Phase-4-style prep — shared-eta note, pure-R oracles, planned registry rows (NOT admitted; no public door)
HEADLINE: pin that hurdle zeros are a two-part shared-η object, not Poisson/Tweedie/Bernoulli
DEFER: prepare widen; C++ tape; estimator=mspl on delta_*; NEWS covered; admit; SE; campaign
DISCIPLINE: planned only; board was na; no prepare widen past {0,1,2}; no src/; verify by logs
```

## Headline

Earn `delta_lognormal` and `delta_gamma` as **planned** ordinary
cells whose information atom is the *sum* of a logit occurrence
weight and a positive-part weight on **one shared η**. Do not
admit. Do not open a public `estimator = "mspl"` door.

## Invariants

- Workspace ONLY `/tmp/gllvmtmb-mspl-hurdle`.
- Branch `cursor/mspl-phase4-hurdle` from `origin/main`.
- Lane LOOP only under `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/`.
- OWN: this LOOP kit; the hurdle research note; hurdle oracles;
  planned `delta_*` registry rows + the two tests that count
  planned families.
- Do NOT edit `R/mspl.R`, `src/`, NEWS, or sibling lane files.
- Do NOT widen `.gllvmTMB_mspl_prepare()` beyond
  `family_id %in% {0,1,2}`.
- Do NOT flip any cell to `admitted`.
- Do NOT write NEWS “covered”. Do NOT implement `se = TRUE`.
- Local oracles only; `OMP_NUM_THREADS=1`; no live hurdle MSPL fit.
- Never `git add -A`. Stage explicit paths. Never write repo-root `LOOP/`.
- Never edit `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding arc detail for this run.
- Programme constitution:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
  (delta/hurdle is listed under **Phase 5**; this lane is
  Phase-4-*style* prep only).
- Tape contract (read-only): `src/gllvmTMB.cpp` fid 12 / 13
  (shared η; `dbinom_robust` + lognormal / Gamma positive part).

## Definition of done

1. Research note pins shared-η hurdle weights
   \(W=\pi(1-\pi)+\pi/\sigma^2\) (lognormal) and
   \(W=\pi(1-\pi)+\pi/\varphi^2\) (Gamma), and names why
   Bernoulli / Poisson / Tweedie atoms do not transfer.
2. Pure-R oracles E1–E10 + no-live fence; no live
   `estimator = "mspl"` fit.
3. Registry: four `planned` / `phase4_prep` ordinary q1/q2 rows;
   none `admitted`. Prepare fence still `{0,1,2}`.
4. LOOP checkpoint frozen; after-task; commit + push + **draft** PR.

Finish line is **planned prep**, not admission.
