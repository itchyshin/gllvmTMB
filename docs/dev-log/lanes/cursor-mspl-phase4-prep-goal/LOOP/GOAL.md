# GOAL — cursor-mspl-phase4-prep-goal (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-prep-goal/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`) are historical —
do not reopen their GOALs except a one-line pointer. Sibling family
kits (`cursor-mspl-phase4-poisson`, `-nbinom2`, `-nbinom1`, `-beta`,
`-tweedie`) own their science; this lane **verifies** them.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: Poisson + NB2 + NB1 + beta + Tweedie Phase-4 notes and oracles landed on stacked PRs; #971 closeout verified
HEADLINE: thicken count-family MSPL prep without admitting anyone
DEFER: admit, SE, NEWS covered, prepare widen, Totoro>30min, Codex interval lane
```

## Headline

Thicken count-family MSPL prep (Poisson, NB2, NB1, beta, Tweedie)
without admitting anyone.

## Invariants

- Conductor workspace ONLY
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` for this
  kit and #971 verification.
- Family verification runs on the named family worktrees, not on
  leftover untracked copies in the conductor.
- Branch `cursor/mspl-phase4-prep-goal`.
- Lane LOOP only under
  `docs/dev-log/lanes/cursor-mspl-phase4-prep-goal/LOOP/`.
- Never use Dropbox. Never write repo-root `LOOP/`. Never `git add -A`.
- Never touch `codex/lane-b-mspl-interval-feasibility`.
- Do NOT merge #971–#976 from this lane (Shinichi already merged #971;
  #972–#976 stay open).
- Do NOT flip any family `planned` → `admitted`.
- Do NOT widen `.gllvmTMB_mspl_prepare()` beyond `family_id %in% {0,1}`.
- Do NOT write NEWS “covered”. Do NOT implement SE.
- Local oracles only; `OMP_NUM_THREADS=1`. Totoro >30 min is HARD STOP.
- If a family PR is missing files or tests fail: fix on that family
  branch only; do not rewrite science that already passed.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding arc detail for this run.
- Programme constitution Phase 4:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Definition of done

1. LOOP kit committed on `cursor/mspl-phase4-prep-goal`.
2. #971 closeout verified (structured tests + TSV 64/64 + empty
   `src/` / `R/mspl.R` diff + PR body matches).
3. Each of #972–#976 verified on its worktree: files exist, oracles
   re-run, structured FAIL/ERROR/SKIP/PASS, PR open, no prepare
   widen, no NEWS admit/covered language.
4. Rose fence sweep: no NEWS covered, no planned→admitted, prepare
   still `{0,1}`.
5. After-task + Melissa plan-actual + checkpoint overwritten.
6. STOP at merge (human). Still no admit.

Finish line is **verified prep + human merge gate**, not admission.
