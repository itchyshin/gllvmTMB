# Claude → Claude session handover — 2026-07-31

**from Claude (Fable 5) · TARGET = Claude · 6 PRs merged, 1 open and NOT mergeable yet**

> **⚠ MULTI-LANE REPO.** This is ONE lane. `docs/dev-log/handover/2026-07-25-active-lane-split.md`
> is authoritative for ownership. **An AGHQ estimator-validation lane was opened by Shinichi during
> this session** (brief: `2026-07-31-aghq-estimator-validation-new-lane.md`) and the VA/EVA lanes
> remain Codex-owned. I deliberately did **not** refresh the `CLAUDE.md` snapshot pointer: with two+
> lanes live, repointing it at this doc would orphan theirs.

## Mission control

| | |
|---|---|
| repo / branch | gllvmTMB · `claude/851-scale-aware-start-20260731` (pushed, PR #873 **open, do not merge**) |
| merged this session | #864 #865 #866 #867 #868 + the #862-era doc fix — all on `main` |
| CI / suite | 🔴 **`main` itself is NOT green**: 18 failures + 3 errors, 16 of them `test-m3-pilot-manifest.R`. Independent of this work; sits under the 0.6 rung |
| claim state | **no public capability claim moved.** One NEWS entry on the open branch only |
| compute | **Totoro is set up** at `~/gllvm_work` — suite in ~15 min vs ~5 h locally |
| blocked on | nothing. 5 test regressions remain on the open branch |
| plan by leverage | #851 finish (5 failures) → #872 flatness → `main` not-green → #855/#847/#848 |

## Critical context — read or you will redo refuted work

1. **#856 was a false-premise arc and is CLOSED.** Shinichi closed it as "filed on a false premise"
   **20 minutes before that branch's first commit**; 17 commits were built on it. The pooled scalar
   `sigma_eps` is **deliberate**. Do not reopen. See
   `2026-07-31-856-halted-premise-withdrawn.md`. Its adversarial evidence (13/20 silent boundary
   collapse) argues *for* his decision.
2. **#851's fix works and is measured.** Single-tier `latent()` is now exactly scale-equivariant
   (~1e-05 at k = 100 and k = 5000, every law). **Both comparators fail where it passes**, 8 seeds:
   gllvm 3/16 violations (worst 0.998), glmmTMB 14/16 (worst 2.00), gllvmTMB 0/16 (worst 0.0105).
3. **Ψ scaling is BOTH necessary for the fix and the cause of the regressions.** Removing score
   seeding changes nothing; removing Ψ scaling fixes convergence but collapses the scale laws
   (Λ 0.301, Σ 0.459). A real trade-off, not a slip.
4. **Always run a MAIN BASELINE.** Raw failure counts are meaningless without it: 25 failures on the
   branch decomposed into 18 pre-existing + 7 mine.

## What was accomplished

- **#856 halted and closed out honestly** — handover, bannered after-task, reconciliation
  (11 adaptive / 4 drift / 2 unclear), evidence landed to `main` **without** the rejected code (#866).
- **#864** stale Gamma doc claim (false since July), `--as-cran` 0E/0W/1N.
- **#865** re-audit of the six "CONFIRMED" twin divergences: **2 of 6 do not survive**. Claim 1 was
  purely R-internal, already fixed. **Claim 5 is live** (GLLVM.jl #135) — the W-tier drops
  cross-trait covariance in Julia, so the two packages fit *different models* whenever `K_W ≥ 1`
  with >1 trait, silently invalidating cross-package comparison.
- **#867** revived the AGHQ auto k-ladder — it was dead code returning `k = 9` for every family and
  tier because a family object hit a bad coercion inside a `try()`. Same defect twice
  (`.aghq_optimizer_table` too). **Any prior `"auto"` evidence was taken at k = 9.**
- **#868** the AGHQ validation lane brief.
- **#851 in progress** — engine fix + comparator study + 2 of 7 regressions fixed on merit.
- **#872 filed** — two-tier flatness split out (see Gotchas).

## Current working state

**Working:** everything merged; `main` clean of my changes.
**In progress:** PR #873. **5 test regressions remain**: `test-traits-keyword.R` (1),
`test-coevolution-two-kernel.R` (2), `test-canonical-keywords.R` (1), `test-lv-factor-runtime.R` (1,
gradient 0.00337 vs a 0.003 absolute threshold). Two are undiagnosed.
**Blocked:** nothing.

## Key decisions & rationale

- **Do not merge #856's code.** Maintainer closed it; the arc's own evidence agrees.
- **Fix tests on their merits, never by relaxing convergence.** Bolker (vault, 2026-07-28) names
  agent "cheating" — relaxing checks to force convergence — as a first-class risk. Two tests were
  fixed because the failing assertion was *incidental to what the test is for*; no tolerance was
  widened. If the remaining 5 can't be fixed that way, **escalate — do not absorb**.
- **Split #872 rather than close #851 over it.** Different mechanism; no start value addresses it.
- **Verification runs on Totoro.** 15 min vs 5 h — which is what makes a baseline affordable.

## Files created / modified

**Package** — `R/fit-multi.R`, `R/init-warmstart.R` (branch only) · `R/aghq-control.R`,
`R/unique-keyword.R`, `man/diag_re.Rd` (merged)
**Tests** — `tests/testthat/test-start-method-residual.R`, `test-traits-keyword.R` (branch only)
**dev/** — `dev/851-scale-equivariance-comparators.R`
**docs/** — `NEWS.md` (branch only); handovers `2026-07-31-856-halted-premise-withdrawn.md`,
`2026-07-31-aghq-estimator-validation-new-lane.md`,
`2026-07-31-851-scale-aware-start-continuation.md`, **this doc**; audits
`2026-07-31-twin-review-claim-recheck.md`, `2026-07-30-856-*`; `plan-actual/2026-07-30-856-sigma-eps.md`

## Next immediate steps

1. **Diagnose the 5 remaining #851 failures** — start with `test-coevolution-two-kernel.R` (2) and
   `test-canonical-keywords.R` (1), which are undiagnosed. Fix on merit or escalate.
2. **Re-run on Totoro with a main baseline** (recipe in
   `2026-07-31-851-scale-aware-start-continuation.md`), then merge #873 or write the decision not to.
3. **Raise `main`'s 18 failures / 3 errors** with Shinichi — separate from all of this, under 0.6.

## Blockers / open questions

- **Needs Shinichi:** whether `main` not being green is known-and-accepted; and, if the remaining 5
  can't be fixed on merit, whether `singular convergence (7)` with an identical objective and a PD
  Hessian is acceptable given profile/bootstrap sidestep the Hessian.
- **Cross-lane:** #873 touches `R/fit-multi.R`; the AGHQ lane works in the same file (~:6360). Low
  conflict risk, but tell them.

## Gotchas / failed approaches — do NOT redo

- **Ψ started at the residual REMAINDER instead of the total scale.** Principled, mirrored an
  existing idiom, looked right on *every* targeted check — and the full suite was **36 fail / 16
  error against 25 / 3**. Reverted at `43377d14`.
- **Scaling Λ alone** — non-PD Hessian in `test-getlv-se.R`. **`start_method = "res"` as default** —
  retired on 89 fits. **W-tier symmetry** — implemented, measured, bought nothing, reverted.
- **`getNamespaceExports()` cannot prove a FORMULA KEYWORD absent.** I wrote off `glmmTMB::rr()`
  that way and was wrong; it exists and became the most informative comparator.
- **A green targeted check is not a green suite.** This bit twice in one session.

## How to resume

Read this doc → the lane split → `2026-07-31-851-scale-aware-start-continuation.md` → PR #873.
Claude runs the planning/refactor/prose and the logic tests here; live fits ran fine on this
platform, and heavy verification belongs on **Totoro**. Spawn Rose before any public claim.

**One-command resume — paste in your own authenticated terminal, from the repo root:**

```
claude "Rehydrate from docs/dev-log/handover/2026-07-31-claude-handover.md + the active-lane split, then continue with the Next Immediate Steps — diagnose the 5 remaining #851 regressions, fixing on merit or escalating, never by relaxing a convergence check."
```
