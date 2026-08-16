# GOAL — cursor-mspl-phase4-tweedie (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`) are historical —
do not reopen their GOALs.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: Tweedie LA-MSPL Phase-4-style prep — symbolic power/dispersion + mass-at-zero note, pure-R oracles, paper-planned Phase-5 slot (no registry row; NOT admitted)
HEADLINE: pin that Tweedie zeros and (φ, p) are not the Poisson all-zero atom
DEFER: registry mutation; prepare widen; C++ tape; estimator=mspl on Tweedie; NEWS covered; Poisson/NB admit; SE; campaign
DISCIPLINE: paper-planned Phase-5 slot; no Tweedie registry row; no prepare widen; no src/; verify by logs; structured test counts
```

## Headline

Earn Tweedie on paper + oracles as a **paper-planned Phase-5 slot**
whose information atom and zero mechanism are *not* Poisson's.
E10 asserts **no** Tweedie `planned` or `admitted` registry row.
Do not admit. Do not widen `.gllvmTMB_mspl_prepare()`.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-phase4-tweedie`.
- Branch `cursor/mspl-phase4-tweedie`.
- Lane LOOP only under `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`.
- OWN: this LOOP kit;
  `docs/dev-log/research/2026-08-15-mspl-phase4-tweedie-prep.md`;
  `tests/testthat/test-mspl-tweedie-phase4-oracles.R`.
- Do NOT edit `R/mspl.R`, `R/mspl-registry.R`, `src/`, NEWS,
  validation-register, or sibling lane files.
- Do NOT add a Tweedie registry row (`planned` or `admitted`).
  Paper-planned ≠ registry-planned.
- Do NOT write NEWS “covered”. Do NOT reopen free-ε / pick B.
- Local oracles only; `OMP_NUM_THREADS=1`; no live Tweedie MSPL fit.
- Never `git add -A`. Stage explicit paths. Never write repo-root `LOOP/`.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding arc detail for this run.
- Programme constitution:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
  (Tweedie is listed under **Phase 5**; this lane is prep-style only).
- Poisson contrast (read-only):
  `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`.

## Definition of done

1. Research note pins Tweedie \(W=\mu^{2-p}/\varphi\), free
   \((\varphi,p)\), and \(\Pr(Y=0)=\exp(-\mu^{2-p}/(\varphi(2-p)))\)
   as **not** the Poisson all-zero path.
2. Pure-R oracles E1–E10 + no-live fence (structured count **62**);
   no live `estimator = "mspl"`.
3. Prepare fence still `family_id %in% {0,1}`; no registry mutation
   (E10: no Tweedie `planned`/`admitted` row).
4. LOOP checkpoint frozen; after-task; commit + push + PR.

Finish line is **paper-planned Phase-5 prep** (no registry row),
not admission.
