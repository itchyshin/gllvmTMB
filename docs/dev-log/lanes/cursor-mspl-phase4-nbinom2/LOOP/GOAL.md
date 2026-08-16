# GOAL — cursor-mspl-phase4-nbinom2 (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`) and landed point-continue GOAL A+B+C stay
historical — do not reopen them to admit NB2.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: NB2 Phase-4 prep only — information/coercivity note
  (Var = μ + μ²/θ ≠ Poisson μ) + pure-R oracles + kill list
HEADLINE: pin why NB2 is not Poisson before anyone tapes a count atom
DEFER: registry admit; prepare widen; C++ tape; live estimator="mspl";
  SE; NEWS covered; NB1; truncated/hurdle NB; Poisson admit
DISCIPLINE: excluded / no planned NB2 rows; OMP=1; no src/;
  no R/mspl.R; closure=after-task+PR
```

## Headline

Write the NB2 information atom and the three named boundaries
(mean → 0, θ → 0, θ → ∞) so a later tape cannot treat NB2 as
Poisson.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-phase4-nbinom2`.
- Branch `cursor/mspl-phase4-nbinom2`.
- Lane LOOP only under `docs/dev-log/lanes/cursor-mspl-phase4-nbinom2/LOOP/`.
- Do NOT edit the Dropbox checkout or the point-continue worktree.
- Do NOT edit `R/mspl.R`, `src/`, other families, or widen prepare.
- Do NOT add planned or admitted nbinom2 rows. nbinom2 stays
  **excluded**.
- Do NOT write NEWS “covered”. Do NOT implement SE / intervals.
- Local tests only; `OMP_NUM_THREADS=1`; no campaign.
- Never `git add -A`. Never write repo-root `LOOP/`.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding detail for this run.
- Programme constitution Phase 4:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- Sibling Poisson prep (do not inherit its atom):
  `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`

## Definition of done

1. Research note
   `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md`
   with NB2 \(W=\mu\theta/(\theta+\mu)\), variance contrast, three
   boundaries, and a kill list.
2. Pure-R oracles
   `tests/testthat/test-mspl-nbinom2-phase4-oracles.R` (no live
   NB2 `estimator = "mspl"`).
3. After-task + check-log with structured test counts.
4. Commit, push, open PR. nbinom2 stays **excluded**; no planned
   NB2 rows; prepare fence unchanged.

## OPEN GATES (do not execute)

- Adding planned NB2 rows, or `excluded` → `planned` / `admitted`
- `.gllvmTMB_mspl_prepare()` widen beyond `family_id %in% {0,1}`
- C++ tape / live `estimator = "mspl"` on nbinom2
- SE / intervals (Codex Lane B PROTECTED; Gaussian SE also closed)
- NEWS covered / validation-register promotion
- NB1, truncated NB, hurdle/ZINB, mixed-family
- Poisson admit
