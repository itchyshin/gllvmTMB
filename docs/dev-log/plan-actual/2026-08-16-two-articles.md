# Plan vs actual — two iSDM articles (2026-08-16)

Reconciler: Melissa. Plan: `~/.claude/plans/generic-giggling-tulip.md` (two-articles arc).
Lane: `claude/isdm-public-door-20260816` · PR
[#1016](https://github.com/itchyshin/gllvmTMB/pull/1016).

## Scope

**ADAPTIVE — article 2 moved from the nonspatial arm to the spatial one, mid-arc, after the
plan was approved.** The plan justified nonspatial on the grounds that Design 111's recovery
gates are cleared there. Reading the evidence file first — which the plan itself named as its
one fragility — showed the domain-growth law is measured on spatial-field recovery, so a
nonspatial article would have cited evidence that does not apply to what it shows. Recorded in
the plan file at the time of the change, not retrofitted, and surfaced to the maintainer in the
same turn.

**ADAPTIVE — two code fixes landed in an arc scoped as documentation.** Gauss's review of the
*previous* arc's change returned two blockers reachable through the public door. Fixing them
inside this lane rather than deferring was the right call (they are defects in code already on
the PR), but it is a scope expansion and is named as one.

**No DEFER item was touched.** Model 2, Kristen's staging articles, the A3 campaign, calibrated
intervals, #944, and any new simulation campaign all remained fenced. Article 2 cites the
existing campaign; it ran no new fits.

## Evidence and verification

**Clean, and stronger than planned.** The plan required render + `check_pkgdown()` + focused
tests + Rose + Pat. All ran. Gauss and Darwin additionally ran, and both found things.

**ADAPTIVE — attribution work not in the plan.** The Totoro check returned 46 failures. The plan
did not anticipate needing to attribute them; doing so (running the five affected files against
both the base commit and the lane head, then tracing the cause to `.Rbuildignore`) consumed
real time and produced the arc's most transferable finding. Worth planning for next time: *a
first-ever check on a long-lived branch will surface that branch's debt, not just your own.*

**DRIFT (disclosed) — the Totoro receipt is weaker than the plan implied.** The plan said the
check "replaces the CI that the stacked PR base prevents". It partially does: one Linux box,
and `_R_CHECK_FORCE_SUGGESTS_=false` because Totoro lacks seven Suggests, so every check needing
one of them — including all `vdiffr` visual snapshots — did not run. The receipt states this
plainly rather than letting "check ran" stand as "check passed".

## Model routing

**DRIFT (forced, second occurrence of a known class).** The plan routed S2 (article 1) to
Sonnet, S3 (article 2) to Opus, S4 to Sonnet, S5 to Haiku, S6 to Sonnet. Actual: article 1 ran
Sonnet, article 2 ran Opus, review ran Sonnet, and Gauss ran Opus. **S4 (figure pass) and S5
(mechanical verify) were absorbed inline** rather than dispatched — the article agents produced
their own captioned figures, and the mechanical checks were three commands. Absorbing a planned
Haiku slice into the orchestrator is exactly the Haiku-underuse leak the method warns about; it
is recorded rather than excused.

**Children: 4** (2 scouts + article 1 + article 2) **+ 2 review** (Gauss, Rose/Darwin) = 6, at
the authorised budget. Two ceiling children (article 2, Gauss) — one more than the default
allows; the plan pre-authorised one for article 2, and Gauss was added at the maintainer's goal
directive, which is a checkpoint.

*Repeat-class note:* the previous reconciliation recorded "a plan that names sub-agent models
cannot assume the dispatch will be permitted." This arc's variant is milder — dispatch worked —
but the same underlying pattern recurred: **planned slices get absorbed inline when they look
small.** Two occurrences now. If it recurs, the plan template should require a positive
statement that each planned slice was dispatched or an explicit note that it was absorbed.

## Safety gates

**Clean.** Preflight run and pasted. D-139 honoured: an estimate was stated before the Totoro
run (20–30 min; actual 12.5 min), and a 45-minute stop-and-report line was set. D-143 honoured:
Totoro was at 140 of 384 cores and the check is single-core. D-64 honoured: the existing
ControlMaster socket was used; no Duo prompt. No new register ID allocated (the arc reused
`ISDM-01`, avoiding the live duplicate-ID hazard the preflight flagged).

## Public claims

**Clean, and actively tightened twice during the arc.** No register codes on any reader-facing
surface (grepped). Every campaign number in article 2 verified line-by-line against its source,
with the extrapolation labelled as extrapolation in both. The `ISDM-01` row stayed `partial`;
nothing was promoted. Two claims were narrowed rather than defended: article 1's `pd_hessian`
WARN was localised by measurement instead of hand-waved, and article 2's `pd_rate = 0.555`
ceiling was moved from a table the reader had to interpret into prose.

**D-43 panel correctly not fired** — no capability promotion.

## Handoff state

**Clean.** Branch pushed, worktree clean, PR open. After-task, check-log, Totoro receipt, and
this reconciliation all landed. The `dev/`-dependent test failures were filed as separate work
rather than silently absorbed or silently dropped.

## For the drift ledger

1. **Planned slices absorbed inline when they look small** — second occurrence (see above).
2. **A first check on a long-lived unchecked branch surfaces that branch's debt.** Not drift,
   but a planning lesson: budget attribution time whenever a lane runs a check that has never
   run before on its base.
