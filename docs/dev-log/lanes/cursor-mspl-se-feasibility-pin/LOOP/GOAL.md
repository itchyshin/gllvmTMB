# GOAL — cursor-mspl-se-feasibility-pin (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (catch-up / gaussian / point-continue / phase4-prep-goal /
phase4-tapes-planned) are historical — do not reopen their GOALs except
a one-line pointer.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo platform: Cursor
Deliverable: read-only extract of the binary SE teacher + a local se=TRUE feasibility pin for Bernoulli and Poisson LA-MSPL; public door stays gaussian + bernoulli + Poisson; nobody admitted
HEADLINE: learn SE from the Codex binary lane, then pin whether Poisson can take se=TRUE — do not absorb their tree and do not call it covered
IN PARALLEL: Shannon lanes · binary-SE method extract · Poisson/Bernoulli SE oracles · Rose fence · handover
DEFER: planned→admitted · NEWS covered · public mspl on NB1/NB2/beta/Tweedie · gaussian SE campaign · Totoro>30min · EVA/VA/AGHQ-MSPL · copy-paste of Codex R/mspl.R helpers · second cpp editor
DISCIPLINE: verify=failing SE/oracle tests before any src/ · compute=local OMP=1 · closure=teacher note + se=TRUE pin + Rose PASS + still planned
```

## Headline

Learn SE from the Codex binary lane, then pin whether a named internal
curvature construction can be *formed* for Poisson and Bernoulli-logit.
Do not absorb their tree. Do not call it covered. Public `se = TRUE`
still withholds `sdreport()`.

## G0 answers (Shinichi 2026-08-15 — plan pre-approved)

From `docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md`
Ada defaults, locked by "everything in this plan is pre-approved":

- **Q1 = (a)** one internal, non-exported construction; availability +
  PD only; all public methods stay fail-closed. Not public `vcov()`.
- **Q2 = (a)** Poisson + Bernoulli **logit only**. No probit/cloglog
  (D-135). No Gaussian (pinned `sigma_eps`).
- **Q3 = (c)** both curvature constructions as separate typed
  diagnostics: penalised numerical Hessian on \(Q_P\), and penalty-off
  curvature \(Q_0\) evaluated (never optimised) at the MSPL point.

Overnight merge authority (later the same sitting): squash-merge #978
when CI green; open + squash-merge the SE-pin PR when CI green. Do
**not** merge #972–#976.

## Invariants

- Workspace ONLY
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Branch `cursor/mspl-se-feasibility-pin`. Base is the tapes tip until
  #978 merges, then treat `main` as the merge target.
- Lane LOOP only under
  `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/`.
- Never Dropbox. Never repo-root `LOOP/`. Never `git add -A`.
- Codex `codex/lane-b-mspl-interval-feasibility` is **PROTECTED**.
  `git -C` reads only. No checkout, absorb, helper copy, or rebase.
- Do NOT merge #972–#976.
- Do NOT flip any family `planned` → `admitted`.
- Public `estimator="mspl"` stays gaussian + bernoulli + Poisson.
- Do NOT write NEWS “covered”.
- Do NOT modify `R/fit-multi.R` MSPL `sd_rep <- NULL` withholding.
- Do NOT enable public `vcov()` / `confint()` / `standard_errors()`.
- Do NOT optimise the penalty-off tape \(Q_0\).
- Do NOT repair a non-PD Hessian.
- Do NOT call GLM-outer \(I_{LA}(\beta)\). Do NOT transplant \(c\).
- One cpp owner. Expected `src/` edits: **zero**.
- Failing tests before any `R/` or `src/` implementation.
- Local only; `OMP_NUM_THREADS=1`. Totoro >30 min is HARD STOP.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding G0-locked plan.
- Research plan:
  `docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md`
- Programme constitution:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Definition of done

1. LOOP kit committed on `cursor/mspl-se-feasibility-pin`.
2. Teacher note
   `docs/dev-log/research/2026-08-15-mspl-binary-se-teacher.md`
   from `git -C` only.
3. Estimand pick
   `docs/dev-log/research/2026-08-15-mspl-se-estimand-pick.md`
   names both Hessians; sandwich/profile deferred.
4. Failing-then-green tests:
   `tests/testthat/test-mspl-bernoulli-se-feasibility.R`
   `tests/testthat/test-mspl-poisson-se-feasibility.R`
5. Internal non-exported pin exists. Public door unchanged.
   Poisson registry stays `planned`. `sdreport` still withheld.
6. Rose fence: no admit, no NEWS covered, no Codex absorb.
7. After-task + Melissa plan-actual + checkpoint + morning brief.
8. SE-pin PR opened. Squash-merged only if CI green (authorised).

Finish line is **teacher + availability pin + still planned**, not
calibrated inference and not admission.
