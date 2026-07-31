# New lane — AGHQ estimator validation (a campaign, not a fix)

**2026-07-31 · from Claude (Fable 5) · TARGET = a FRESH session · nothing blocked, nothing running**

## Copy-paste opener

```
🎯 GOAL — gllvmTMB: establish (or refute) the AGHQ ESTIMATOR · solo platform: CLAUDE
DELIVERABLE: evidence that answers "does AGHQ produce BETTER POINT ESTIMATES than Laplace,
  and where" — an ADEMP-designed simulation campaign with a pre-registered estimand, a
  defined truth, a named regime, and a seed count justified by MCSE. NOT a bigger version
  of the existing dev/aghq-evidence runs.
HEADLINE: the DESIGN, not the compute. The audit's verdict is "the integrator is correct;
  the estimator is NOT ESTABLISHED" — six checks confirm the quadrature, and ZERO compare a
  point estimate to truth. Writing the design is the work; running it is the easy part.
FIRST SLICE: #843's truth-start experiment (n=100, shipped engine). Small, decisive, and it
  gates the campaign's interpretation — see below.
DEFER (fenced): #851 scale collapse, #855 standardisation, anything about flipping the
  `aghq` default. This lane produces EVIDENCE; it does not change a default.
DISCIPLINE: pre-register the estimand and the acceptance rule BEFORE running anything.
  Compute = TOTORO (384 cores, no queue) — decide this at scope time, not after a slow
  laptop run. Results stay LOCAL (D-50: never GitHub Actions artifacts). Closure =
  after-task report + a claim that names its regime.
🔴 NO PUBLIC CLAIM without Shinichi. "AGHQ is better" is a capability claim.
```

## Why this is a lane and not a ticket

`docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md` (#842) is the source. Its
headline:

> **The AGHQ integrator is correct. The AGHQ estimator is not established.**

Those are different claims and only the first has evidence. Six independent checks confirm the
quadrature does what quadrature should. **Not one test compares an AGHQ point estimate to a known
truth.** So the honest current position is: we have a correct integrator wired into an estimator
whose value is unmeasured.

That is not fixable by a patch. It needs a designed study.

## What must be decided BEFORE any compute

This is the actual work, and it is why this should not be started at the end of a long session.

1. **The estimand.** "Better" is not a target. Candidates, and they do not agree: bias of `Λ`
   (rotation-variant — needs Procrustes), bias of `Σ_unit` (rotation-invariant, probably the right
   one), correlation/communality recovery (the headline JSDM outputs users publish), interval
   coverage (a different and much more expensive question). **Pick one primary and say so.**
2. **Truth.** Simulate from the model, or from a mis-specified DGP? Both are defensible and answer
   different questions. AGHQ's claim is about integration accuracy, so the well-specified case is
   the fair first test.
3. **The regime.** The audit's live concern is **small n**. The known headline is 73% runaway under
   AGHQ vs 47% under Laplace at n = 100 — but see the trap below before treating that as a result.
4. **Seeds.** Justify by MCSE against the estimand, not by habit. A proportion near 0.5 needs
   ~1/(4·MCSE²); a bias needs the residual SD. State the number and its reason.
5. **The acceptance rule, pre-registered.** What result would make you say AGHQ helps? What would
   make you say it does not? Decide in advance — this repo has already been bitten by scoring a fix
   on the metric it optimises (#813's withdrawn continuation).

## First slice — #843's truth-start experiment

Do this before the big campaign. It is small, decisive, and it determines how every existing AGHQ
number should be read.

`R/fit-multi.R:5297-5305` selects the alternative start only when
`is.finite(aghq_ridge_tau) && aghq_ridge_tau > 0`. Under `aghq_ridge = Inf` that is FALSE, so the
Laplace warm start is kept. The in-source comment justifies this with a 40-seed investigation —
and `docs/dev-log/decisions.md:1706-1709` later **invalidated that investigation**, because it ran
on `dev/aghq-r-reference.R`, which reproduces the shipped *Laplace* arm but not the shipped *AGHQ*
arm. The design decision may still be right; its justification has been withdrawn and never
replaced.

**The experiment:** run a shipped-engine fit at n = 100 started at the TRUE parameters.
- If AGHQ stays there → the argmin is fine and the runaway is a start/flatness artefact.
- If it walks away → the estimator is biased, and that is the finding.

## 🔴 The trap — read before citing any existing AGHQ number

**`aghq_ridge = Inf` is exactly the `aghq` arm in every campaign in `dev/aghq-evidence/`.** So every
"AGHQ alone" number in the evidence base comes from a *single* start seeded at the Laplace optimum.

Compound that with measured flatness (`19-warmstart-vs-flatness.R:16-19`): sweeping k = 5/9/15/21 at
a converged optimum moves the objective by **< 0.01 nll** while the argmin's ‖Σ_B‖_F wanders
**13.3 / 45.5 / 119.3 / 38.6**. A near-flat objective, one start, and a frozen-node convergence test
is a live alternative explanation for the 73%-vs-47% headline — and no adjudication in the repo can
return it, because `20-why-laplace-wins.R:5-8` offers only *ridge over-shrinks* / *MLE biased up* as
branches.

**Therefore:** "AGHQ alone is worse at small n" must currently be read as *not separable from*
"AGHQ alone gets one start." Do not build on it.

## State of the code as of this handover

- **#844 is FIXED** (branch `claude/844-aghq-auto-k-ladder-20260731`, not yet merged). This matters
  to the campaign: `aghq = "auto"` was returning a hardcoded **k = 9 for every family and tier**
  because a family object hit a bad coercion inside a `try()`. The ladder is now live, so a gaussian
  B-tier fit starts at **k = 5**. **Any prior "auto" evidence was taken at k = 9** — check before
  reusing it. The same coercion bug also silently disabled the binomial-jj optimizer choice.
- **#843 is OPEN** and is this lane's first slice.
- **#842's D3/D4** (ridge `tau = 2` fixed when it should scale; partial penalised-fit disclosure)
  are open as #847/#848 and are adjacent — the ridge is on by default whenever AGHQ is on, so a
  campaign that ignores it is measuring AGHQ+ridge, not AGHQ. **Decide explicitly which you are
  measuring.**

## Compute

**Totoro** (`snakagaw@totoro.biology.ualberta.ca`, 384 cores, no queue, ≤100 cores by courtesy).
Decide this at scope time. Attach through the existing ControlMaster socket — find it with
`SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)`; do not open a fresh login. Results stay **local**; never
GitHub Actions artifacts (D-50). Smoke-first: one cell, confirm non-empty valid output, read the
first cell's result early and abort on garbage rather than waiting for the grid.

## Do not redo

- Do not re-verify the integrator. Six checks; it is correct. The audit says so and it holds.
- Do not use `dev/aghq-r-reference.R` for any comparative number — invalidated by decisions.md
  1706-1709 as not a valid model of the shipped AGHQ arm.
- Do not re-run campaign 12 (AGHQ T×n). Its O(1/T) premise is unsupported; σ-by-p is flat.
- Do not flip the `aghq` default as part of this lane. `R/gllvmTMB.R:1331-1335` records the intent
  to flip "when the evidence lands" — producing that evidence is this lane; flipping is a separate
  decision and Shinichi's.

## Method note, earned the hard way on 2026-07-30

Before decomposing, **re-read the live GitHub state of every issue this lane touches**, and again
before opening a PR. A 17-commit arc was built here on a premise the maintainer had closed twenty
minutes earlier, because the issue was read once at orientation and never re-checked. The
ultra-plan Phase 0.25 sweep has rows for git state, twin repos, the brain and external prior art —
it has **no row for live issue state**. Add one.

And the sharper half: if your own findings start contradicting the framing of the task, that is a
signal to stop and re-ask, not a footnote to file.
