# After-task — VA lane reconciliation, board honesty, and three filed findings

Lane: `claude/design66-scoping-20260816` (Claude). Triggered by Shinichi
spotting on the live Mission Control board that VA appeared on only three
families — the second time he had caught the same thing.

## 1. Goal

Reconcile the VA situation end to end: explain why the board disagreed with
the code, fix the board, decide the fate of the dormant VA lane, and file
what the investigation turned up.

## 2. Implemented

- **VA ENGINE column corrected.** The board showed VA on gaussian / poisson /
  binomial only — a framing that predates `537e6da4` (2026-08-06, *promote H7
  GH across scalar families*). VA is admitted on **all 18 scalar family/link
  cells**. Wording taken from the VA lane's own reconciliation rather than
  hand-rolled, which corrected two errors in the first attempt: **Gamma and
  lognormal have analytic exact paths, not GH quadrature**. Multinomial stays
  LA-only with its reason (coupled softmax, non-scalar).
- **REML column now records a result, not an absence.** It read "later work";
  the non-Gaussian route was in fact pre-registered and tested (1,600 fits,
  2026-08-16) and K1 fired — Cox–Reid made bias worse. Recorded as a closed
  negative, never a checkmark, with the two tested families marked inline.
- **Gaps box reframed** from "0.5.0 → 1.0" to "at 0.7.0" per Shinichi (the aim
  is 0.7, not a 1.0 push; DESCRIPTION was already 0.7.0). Diagnostics count
  corrected 3 → 4 families (NB1 had landed and was never reflected).
- **VA lane reconciled: SALVAGE-8, then retire.** 485 files / 175 "unmerged"
  commits proved to be mostly a patch-id artefact of squash-merges — 33 files
  identical to main, ~444 superseded, 8 genuinely absent. All 8 salvaged.
- **Three issues filed:** #1079 (`simulate()` correctness), #1080
  (dispersion-naming traps), #1082 (the brown → green programme).

## 3a. Decisions and Rejected Alternatives

- **Did not take the VA branch wholesale** (110 insertions in the surface file
  alone) — it predates ten days of main. Took its ENGINE wording surgically.
- **Did not edit Mission Control's `status/gllvmTMB.json`.** Its `va_parity`
  block was already correct (all 18 cells, per-family rows); the skill's rule
  is to leave an exact status byte-identical rather than manufacture a no-op.
  The `now`/`next_safe_action` fields belong to the live MSPL lane.
- **Did not mark any family's REML as available.** The arc finished; the
  answer was negative. Finishing an investigation is not a capability gain.
- **Left three historical `0.5.0` references untouched** — they record what
  happened *at* 0.5.0 rather than stating a current target.

## 4. Files Touched

`docs/dev-log/capability-surface.html` (ENGINE column, REML column, gaps box,
version header) · `docs/design/85-highdim-nongaussian-va-formal-contract.md`
(containment hunk) · `docs/dev-log/2026-08-17-va-lane-reconciliation.md` (new)
· 7 salvaged files under `docs/dev-log/audits/`, `docs/dev-log/after-task/`,
`docs/dev-log/handover/`, `dev/va-usability/`, `tools/`.

## 5. Checks Run

Every claim verified against source before it was written or filed: the
integration fence's admitted cell list; `simulate()`'s `supported` vector and
its hard-coded `size = 1L`; the once-per-session warning cache; `phi_gamma`'s
shape semantics (confirmed by the package's own comment). The two subagent
findings were **re-verified by hand** before being filed as issues.

## 6. Tests of the Tests

The reconciliation's own method was checked: `git cherry` reporting 175
unmerged commits was falsified as a completeness measure by spot-checking that
`integration-fence.R` and `va-routing.R` are byte-identical to main. Patch-id
"unmerged" ≠ content absent.

## 7a. Issue Ledger

Opened #1079, #1080, #1082. #1082 is explicitly ordered **after** #1079.

## 8. Consistency Audit

Board vs code vs status JSON now agree on VA. The register's VA-06/09/13
citations resolve for the first time.

## 9. What Did Not Go Smoothly

- My first ENGINE fix was **wrong for two families** (Gamma, lognormal
  labelled GH when they are exact). The lane-check hook caught it by pointing
  at a branch that had already solved it properly. Hand-rolling a fix that
  another lane had already done correctly was the error.
- An earlier statement of mine — that the VA branch held "two unmerged doc
  commits" — was wrong by two orders of magnitude (485 files). It came from a
  handover note I repeated without measuring.

## 10. Known Residuals

- 🔴 The VA branch `codex/va-gh-all-families` can now be **deleted** — nothing
  of value remains. Shinichi's call.
- #1079 should land before any pip is promoted.
- The gaussian/lognormal shared `sigma_eps` is a genuine estimand question.
- `predict_missing.Rd` is regeneration-stale on main (another lane's).

## 11. Team Learning

**A board consulted daily must move when the capability moves — and when it
disagrees with the code, check which one is stale before believing either.**
Here the *code* was right, the *status JSON* was right, and only the
checked-in HTML was wrong; the board had been pinned to a branch that had the
correct column, so repointing it to main silently lost the fix. Also: when a
hook says another lane already did this, read their version first — mine had
two factual errors theirs did not.

## 12. Cross-Product Coverage

None — gllvmTMB only. GLLVM.jl untouched.
