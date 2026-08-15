# GOAL — cursor-mspl-phase4-beta (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (catch-up / gaussian / arc-1a / point-continue GOAL A+B+C)
are historical — do not reopen their GOALs. Sibling Phase-4 family
lanes (poisson / nbinom1 / nbinom2 / tweedie) own their own files.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: Beta logit LA-MSPL Phase-4 PREP — symbolic information
  atom + μ→0/1 and precision-boundary oracles + lane LOOP kit
HEADLINE: pin beta mean-boundary and precision algebra without
  transplanting Bernoulli, Poisson, or Gaussian atoms
DEFER: registry admit; prepare widen; C++ tape; live estimator="mspl"
  on beta; beta-binomial; SE; NEWS covered; campaigns
DISCIPLINE: planned only; se=FALSE; OMP=1; verify by logs; never
  git add -A; work only in /private/tmp/gllvmtmb-mspl-phase4-beta
```

## Headline

Earn a family-specific Beta (logit, mean-precision) Phase-4 prep
note and pure-R oracles. Do not transfer Design 88 Jeffreys/`V_loading`,
Poisson \(W=\operatorname{diag}(\mu)\), or Gaussian Hirose \(\Psi\).

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-phase4-beta`.
- Branch `cursor/mspl-phase4-beta`.
- Lane LOOP only under `docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/`.
- OWN: this LOOP kit, `docs/dev-log/research/2026-08-15-mspl-phase4-beta-prep.md`,
  `tests/testthat/test-mspl-beta-phase4-oracles.R`, plus the matching
  after-task. Do not edit `R/mspl.R`, `src/`, the shared registry, or
  sibling family notes/oracles.
- Do NOT flip any row to `admitted`. Do NOT widen
  `.gllvmTMB_mspl_prepare()` beyond `family_id %in% {0,1}`.
- Do NOT implement SE / intervals. Do NOT write NEWS “covered”.
- Uniqueness pick C and Codex Lane B stay untouched.
- Never `git add -A`. Never write repo-root `LOOP/`.

## Authoritative WHAT

- `LOOP/ultra-plan.md` — binding arc detail for this run.
- Programme constitution:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
  (Beta sits in §Phase 5; this lane is planned-only prep in the
  parallel family batch, not an admission or a Phase-5 start).
- Package Beta contract: `docs/design/03-likelihoods.md` (Beta).

## Definition of done

1. Research note pins logit \(\mu\to 0/1\) and precision \(\phi\)
   information, with a kill list for transplanted atoms.
2. Pure-R oracles E1–E8 pass; structured test counts recorded;
   no live Beta `estimator = "mspl"`.
3. LOOP kit + after-task + PR. Registry rows stay unlanded here
   (parallel-lane collision). Status remains **planned**, not admitted.
