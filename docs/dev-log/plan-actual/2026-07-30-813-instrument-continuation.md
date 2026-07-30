# Plan vs actual — #813 instrument + fix the constrained refit

**Melissa · 2026-07-30 · plan `~/.claude/plans/drifting-scribbling-truffle.md` · lane `claude/813-instrument-20260730`**

Six axes: scope · evidence/verification · model routing · safety gates · public claims · handoff state.
Cosmetic differences are not drift.

## Slice-by-slice

| # | planned | actual | tag |
|---|---|---|---|
| S1 | commit instrumentation + audit script | done, `c9fe5db3` | as planned |
| S2 | **sequential continuation** (the plan's HEADLINE) | built, measured, adversarially reviewed, **DROPPED and reverted**; replaced by a one-line optimiser-budget change | **ADAPTIVE — the largest deviation in the arc** |
| S3 | adversarial review (Opus) | done; returned SHIP WITH CHANGES with 8 named defects | as planned |
| S4 | verify: audit + heavy regression | audit done; heavy regression pending at time of writing | as planned |
| S5 | pre-existing `profile_repeatability` failure | diagnosed to root cause; **filed as #837**, not fixed | as planned (plan allowed "fix or file") |
| S6 | CI-06 register row | checked; **no defect** — the row reads `blocked`, and the scan that prompted the slice was wrong | as planned |
| S7 | after-task + #813 comment + this reconcile | in progress | as planned |

## The material deviation — S2, tagged ADAPTIVE not DRIFT

The plan's headline and its pre-registered success criterion were:

> **Success criterion (falsifiable):** re-running the audit drops the "non-monotone steps" section
> from **8 rows to ~0**.

Continuation **met that criterion exactly (8 → 0)** and was still dropped. That is not the criterion
failing to bind; it is the criterion being **wrong**, and the arc correctly refusing to bank it:

- The 1e-6 detection threshold sits six orders of magnitude below the 3.84 χ²₁ cutoff, and the
  relaxation's fixed point is close to the condition that removes such drops — so the criterion
  scored the fix on the metric the fix optimises.
- Independent measurement showed a one-line budget change reproduces every CI-relevant number
  (χ²₁ crossing identical to 5 dp; unconverged 3→0; max constraint error 4.56e-4) at ~1/4 the cost,
  while also moving the *bounds* rather than only the curve.

**ADAPTIVE, and recorded as a plan-authoring lesson rather than an execution fault:** a pre-registered
criterion is only as good as its scale. This one was authored before the adversarial review existed
to challenge it. The corrective — the audit now reports two thresholds and labels the 1e-6 one a
noise detector, and reports the χ²₁ crossing directly — is committed, so the same criterion cannot be
re-run naively.

## Other deviations

| item | planned | actual | tag |
|---|---|---|---|
| fan-out budget | ≤6 children, ≤1 ceiling | 4 children, 1 ceiling (Opus S3) | as planned |
| tests | "tests for `.refit_improves()` and the `.details` shape" | `.refit_improves()` no longer exists (continuation dropped); shipped 15 light-tier tests for the surviving surface instead | ADAPTIVE — target changed with the implementation |
| cost | not budgeted in the plan | continuation ~8–11×; shipped change ~2× | ADAPTIVE — measured and recorded, was not a planned axis |
| compute | local, no Totoro | local only | as planned (D-50 not engaged) |
| residual defect | plan implied the drift would be fixed | **7 far-tail drops remain, explicitly NOT fixed** and stated as such in the after-task, the #813 comment, and the commit | ADAPTIVE — scope honestly narrowed, not silently dropped |

## Safety gates

- **D-43 panel:** correctly **not fired** — no milestone or capability claim was made.
- **Public claims:** none. `extract_communality(method = "profile")` still aborts; nothing exported;
  #813 remains OPEN. `NEWS.md`, the register and `capability-surface.html` untouched.
- **Never-worse property:** the shipped change alters an optimiser budget, not a selection rule, so
  the class of unprincipled-selection concerns the review raised does not apply to what shipped.
- **Lane hygiene:** worktree-isolated; the main checkout's 15 dirty files were audited and left
  untouched (none belonged to this lane).

## Verdict

**No DRIFT.** One large ADAPTIVE deviation (S2), fully evidenced, with the reversal and its reasoning
recorded in the commit, the after-task (§3, §8) and the #813 comment rather than quietly absorbed.
The one item worth escalating to Rose is not a deviation at all but a process finding:

> A falsifiable success criterion authored *before* the adversarial reviewer exists can encode the
> same blind spot as the implementation it is meant to check. Where a criterion is a *count of a
> pathology*, the plan should also state the scale at which that pathology matters.
