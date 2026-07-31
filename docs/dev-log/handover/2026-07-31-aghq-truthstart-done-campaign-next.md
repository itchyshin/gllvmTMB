# Handover — #843 slice CLOSED; the lane's main campaign is next

**2026-07-31 · from Claude (Fable 5) → a FRESH Claude session · nothing blocked, nothing running**
**Supersedes the FIRST SLICE section of `2026-07-31-aghq-estimator-validation-new-lane.md`. That
brief's design guidance for the main campaign still stands and should be re-read in full.**

## Copy-paste opener

```
🎯 GOAL — gllvmTMB: establish (or refute) the AGHQ ESTIMATOR · solo platform: CLAUDE
STATE: the lane's FIRST SLICE (#843 truth start) is DONE — PR #870, open, awaiting Shinichi.
  Result: the AGHQ small-n runaway is an OPTIMISER FAILURE, not the MLE (16/16 on the
  catastrophic seeds), and the truth-free fix is already in the code, gated off.
DELIVERABLE NOW: the ADEMP-designed campaign the lane exists for — pre-registered estimand,
  defined truth, named regime, seeds justified by MCSE, acceptance rule fixed in advance.
🔴 READ FIRST, IT CHANGES THE DESIGN: `aghq_ridge = Inf` is the `aghq` arm of EVERY campaign in
  dev/aghq-evidence/, and that arm is now known to be single-start and optimiser-limited. So a
  campaign that measures "AGHQ alone" without fixing the start measures the START, not the
  ESTIMATOR. Decide the start rule BEFORE the campaign, or the campaign is wasted.
BLOCKED ON: nothing. But #843's ungating decision is Shinichi's, and it changes what the
  campaign should run. Ask before scoping the arms.
DISCIPLINE: pre-register before running. Compute = Totoro for anything bigger than ~200 fits.
  Results LOCAL (D-50). Closure = after-task report + a claim that names its regime.
🔴 NO PUBLIC CLAIM without Shinichi.
```

## What landed

**PR #870** (open) — `docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md` is the
evidence record; read it before doing anything in this lane.

The headline, because it changes how every existing AGHQ number reads:

> On the 16/40 seeds where the shipped AGHQ arm ran away catastrophically at n = 100
> (‖Λ̂‖/‖Λ‖ > 5), **the runaway is not the maximum-likelihood solution — unanimously 16/16.**
> Started at the truth, the same engine reaches a strictly better objective (1.14–12.94 nll)
> and median frob 16.23 → 2.12. The withdrawn "ties in 40/40" reproduces as 13/40 overall,
> **0/16** on the catastrophic seeds.
>
> The **truth-free** alternative start the engine already builds (`R/fit-multi.R:5296-5313`)
> is discarded under `aghq_ridge = Inf`. Run to convergence it recovers the optimum 16/16
> (median gap closed 1.00). Best-of-both takes catastrophic fits **16/40 → 1/40** and matches
> the truth start's objective without using the truth.

Also filed: **#871** (`aghq_multistart` is a dead control and mislabels
`19-warmstart-vs-flatness.R`'s "discriminating arm" — same class as D2/#844). Also routed a
finding to **#847** (the τ = 2 justification table is from the invalidated reference and its
direction is contradicted by the shipped engine).

## 🔴 The one thing that must be decided before the main campaign

**Which start rule is the campaign measuring?** This is now a live fork, not a detail:

- If Shinichi **ungates** the selection (#843's branch 2), the `aghq` arm becomes multi-start
  and every existing "AGHQ alone" number must be re-run before it can be compared to anything.
- If he **does not**, the campaign must either run the alternative start explicitly via the
  `control$aghq_start_par` hook, or state plainly that it is measuring a single-start AGHQ arm
  and cannot separate estimator from optimiser.

There is no third option where you ignore this and the numbers still mean something. **Ask
before scoping the arms.**

## Do not redo

- **Do not re-run #843's truth start.** 120 fits, done, committed
  (`22-truthstart.csv`, `23-altstart.csv`). Local, D-50.
- **Do not re-verify the integrator.** Six checks in #842; it is correct and that holds.
- **Do not use `dev/aghq-r-reference.R` for any comparative number** (`decisions.md:1706-1709`).
  This slice is a second, independent demonstration of exactly why.
- **Do not cite the 73%/47% n=100 headline** without the single-start caveat.
- **Do not re-run campaign 12.** Its O(1/T) premise is unsupported.

## Carried over / not done

- **PR #870 is OPEN, not merged.** It contains one source change (the `control$aghq_start_par`
  diagnostic hook, inert and not a `gllvmTMBcontrol()` argument), so it was deliberately left
  for Shinichi rather than self-merged under the low-risk rule. If he drops the hook, the two
  scripts go with it.
- **The fix is not applied.** Deliberately — a behaviour change for every `aghq_ridge = Inf` fit.
- **`sweep-control-fields.R` wants promoting to `tests/`** (#871 step 3), with the two
  intentional internal hooks allow-listed. Third instance of this defect class in one file.
- **The two misleading in-source comments are uncorrected** (#871 and #847 carry the detail).

## Method note that earned its place today

The handover named by the task **did not exist in the working tree** — it was on `origin/main`,
and the checkout was 40+ commits behind on an unrelated branch. `git fetch` and read handovers
from `origin/main`, not from whatever the working tree happens to be on.

And the sharper one: **the installed binary was 13 days stale.** A campaign labelled
"shipped-engine" that runs against a stale install is the same defect as one that runs against
a reimplementation — which is the defect this whole lane exists to correct. **Check the build
date of the installed package, not just the branch, before calling anything shipped-engine.**
`R CMD INSTALL` first, every time.
