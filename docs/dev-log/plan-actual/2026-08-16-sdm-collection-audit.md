# Plan vs actual — SDM collection audit + de-overlap + Paper×Items re-aim (2026-08-16)

Reconciler: Melissa. Plan: "SDM collection audit + de-overlap + Paper×Items re-aim"
(`generic-giggling-tulip.md`). Lane: `claude/sdm-repeated-survey-20260816` ·
[#1046](https://github.com/itchyshin/gllvmTMB/pull/1046) (commits `c1aafacd` + `e69792b4`).

## Scope

**ADAPTIVE (disclosed).** S0–S9 map cleanly onto the plan: repeated-visits article
added; two-source renamed "designed survey"; MSPL out of the SDM menu with its label
corrected; both missing descriptions written; `mspl-binary-jsdm.Rmd` rewritten per the
maintainer's direction. `git diff main...HEAD --stat` confirms docs/vignettes/dev-log
only — no `R/`, `src/`, `tests/`. One structural change beyond the plan's sketch,
disclosed on the PR after the reconciliation flagged it: the plan's S8 named AGHQ +
ridge as a live demonstration; the shipped article demonstrates the ridge live and
holds AGHQ to a prose mention with its large-n evidence boundary — because the probes
showed the loading-runaway pathology at this corpus size is remedied on the Laplace
path alone, and a live AGHQ demo would have implied a benefit the evidence does not
place at 60 papers.

## Evidence and verification

**Clean.** The reconciler spot-checked claims against actual diffs, not prose: ρ_s in
the two-source equation; both "more than two sources" corrections; the WARN-fit
comment replaced with the decision preserved in `decisions.md`; the Rose re-check
blocker (infinite_terms displayed where cited) fixed; seed-202 single-seed discipline
with claims resting on the cited internal calibration, not the draw.

## Model routing

**Clean.** Exactly the budgeted 6 children (Pat/Rose/Fisher/Florence audits + Rose
re-check + Melissa), 0 Opus, all read-only; builds inline per the pre-registered
fallback. Four other agent names visible in the session belong to prior arcs or an
unrelated task; confirmed not part of this budget.

## Safety gates

**Clean.** No package-code diffs; renders-only compute (D-139 not triggered); D-43 not
fired; merge authority handled more conservatively than planned (whole PR held for
the maintainer, who then directed the merge).

## Public claims

**Clean.** The re-aimed article's ridge claims carry their probit-vs-logit regime; AGHQ
carries its large-n boundary; MSPL fences restated; the ridge-does-not-fix-separation
negative result is shown, not asserted.

## Handoff state

**DRIFT found by the reconciler, resolved before merge.** At reconciliation time the PR
was unmergeable (a `check-log.md` two-lane append conflict) and — the load-bearing
find — **zero CI check-runs existed because GitHub's `pull_request` workflow cannot
fire on an unmergeable PR**. The union-merge push resolved the conflict and CI
attached immediately. The one-PR bundling of the two commits (vs the plan's split
self-merge) was disclosed in the PR body; the maintainer then authorized the merge
("resolve conflicts - merge it when you can").

## For the drift ledger

1. **An unmergeable PR silently gets no CI at all** — "waiting for CI" on a
   conflicting PR waits forever; check `mergeable` before trusting a pending state.
2. Pre-registered fallback routing again converted blocked dispatch into labelled
   ADAPTIVE (fifth occurrence; the pattern is now standard).
3. When a plan sketches a demo the probes later contradict, the demotion (live demo →
   prose mention) is itself a disclosure item, distinct from the rationale that drove
   it.
