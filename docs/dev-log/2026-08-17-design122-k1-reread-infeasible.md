# Design 122 K1 re-read against the stored rows is infeasible — memo (Fisher, 2026-08-17)

The 2026-08-17 Claude handover (branch `claude/handover-20260817`, commit
`b65192f3`, `docs/dev-log/handover/2026-08-17-claude-handover.md` — not on
`main`) asked in its item 3 that, after the #1092 fix (the
`aghq_ridge` penalty is applied at the R level, so the recorded
`max_abs_gradient` was the gradient of the *unpenalised* objective), Design
122's K1 criterion be re-read against the existing 21,600 campaign rows, on
the reasoning that "the data does not need re-running; the instrument does."
That claim is half right. The instrument is indeed fixed — the branch
`claude/fix-1092-penalised-gradient` adds `.gllvmTMB_penalised_gradient()`
(`R/fit-multi.R:266`) and routes it through `fit_health`
(`R/diagnose.R:30`), `sanity_multi()` (`R/methods-gllvmTMB.R:2035`), and the
AGHQ engine's stop reporting (`R/fit-multi.R:6302`, `:6366`), so future
campaigns record the penalised gradient automatically. But the stored rows
cannot be re-scored under the corrected instrument: the correction requires
per-fit vectors that were never persisted. What remains is a decision, not a
computation, and it is Shinichi's.

## What the stored data can and cannot support

The campaign schema defines the gradient column as a scalar.
`dev/campaign-admission/RESULT-SCHEMA.md` line 32:

> `max_abs_gradient` | numeric | `max(abs(gr(par)))` at the reported optimum
> (reuse `fit$fit_health$max_gradient` where available, per
> `dev/coxreid-ab/run-ab.R`).

The stored campaign rows conform to that schema. The header of
`dev/design122-campaign/results/chunk-001.csv` (and every other
`chunk-*.csv`; 24 files, 21,600 parsed rows per
`dev/design122-campaign/rowcount-check.csv` and `campaign-all-rows.rds`,
7,200 per arm) contains `max_abs_gradient` as a single numeric column. No
parameter vectors, no gradient vectors, and no fit objects were persisted —
the `results/` directory holds only the chunk CSVs.

The #1092 correction is `g[li] <- g[li] + par[li] / (ridge_tau^2)` on the
`theta_rr_B` block (`R/fit-multi.R:266-274`). Applying it retrospectively
requires, per fit, the loading sub-vector `par[li]` and the full unpenalised
gradient vector `g` — neither of which survives in a scalar `max(abs(g))`.
Therefore **L2's K1 gradient leg cannot be recomputed from the stored rows.**
The scalar is not merely imprecise; it is informationally insufficient for
the correction. Re-scoring L2 under the fixed instrument means re-fitting.

## What the adjudication already established

`dev/design122-campaign/ADJUDICATION.md` (§"K1 — optimiser artefact —
FIRED", lines 119–198) already contains the substantive arguments a re-read
would have been asked to confirm:

- **L2 (lines 172–181):** the 100% breach is diagnosed as an instrument
  mismatch, not an optimiser failure — the recorded value is the unpenalised
  gradient at the penalised optimum and "has no reason to be near zero."
  Independently of the gradient column, TEST A gives `c_hat` in
  `[1.0000, 1.0014]` on the pre-run and 7,200/7,200 passes in the campaign,
  which the adjudication reads as direct evidence that "the L2 optimum is
  genuinely stationary for the objective L2 actually optimises."
- **L0 (lines 182–192):** L0 is unpenalised (`ridge_tau = Inf`), so #1092
  changes nothing for it — the recorded gradient already is the gradient of
  the objective L0 optimised, and its 35.96% breach stands. The
  adjudication's diagnosis is scale: Design 122 declared `grad_tol = 1e-3`
  (an absolute bar, `docs/design/122-va-vs-laplace-recovery.md` §F1), ten
  times tighter than the package's own `.gllvmTMB_converged_gtol = 1e-2`
  (`R/diagnose.R:13`), which only 0.89% of L0 fits exceed. The breach
  concentrates at `n = 400` (53.3% vs 18.6% at `n = 100`) and in the ordinal
  cells (up to 76.7% at cell 21) — where the objective is largest —
  "consistent with an unscaled absolute tolerance being the wrong
  instrument, not with 36% of Laplace fits being non-stationary."

So the re-read's intended conclusion for L2 is already argued on other
evidence, and the re-read could never have altered L0's leg at all.

## The decision that remains (Shinichi's)

Three options, presented neutrally with their evidence status:

- **(a) Accept the adjudication's argument as it stands.** L2 stationarity
  rests on TEST A (7,200/7,200), a check that measures the right objective;
  the campaign's accuracy numbers stand with a documented caveat that K1's
  gradient leg fired on a mis-specified instrument and was never
  re-evaluated under a correct one. Zero compute; the caveat is permanent.
- **(b) Re-run some or all of Design 122 under the fixed instrument.** This
  is a compute campaign: D-139 applies in full (time estimate before
  anything runs, a pre-run test with results shown, Shinichi's approval
  before committing), and D-50 routes it to Totoro, never GitHub Actions.
  It is the only route to a clean, pre-registration-faithful K1 clearance.
- **(c) Re-run a small sentinel subset.** Re-fit a modest, pre-declared
  slice (e.g. a few seeds per L2 cell) recording the penalised gradient, to
  spot-check that the corrected instrument clears the 1e-3 bar where TEST A
  predicts it should. Cheap, likely under the D-139 30-minute line pending
  an estimate, but it validates the instrument rather than re-certifying
  the campaign.

**Fisher's recommendation (marked as such, not a decision):** (a), optionally
strengthened by (c). TEST A is a sufficient stationarity certificate for L2
because it evaluates the objective L2 optimised, and L0's leg is untouched by
#1092 under any option — a full re-run therefore purchases little inferential
gain over (a)+(c) at substantial cost. If any Design 122 number is later
promoted to a public claim, the caveat should travel with it.

## Related instrument question

Whether future campaigns should retire the absolute `grad_tol = 1e-3` bar in
favour of the package's own `.gllvmTMB_converged_gtol = 1e-2`
(`R/diagnose.R:13`) — or a scaled criterion — is a pre-registration
governance question, not a code change. The adjudication's L0 analysis
(`ADJUDICATION.md` lines 182–192) is the evidence base: an unscaled absolute
tolerance fires preferentially where the objective is large, which is a
property of the bar, not of the fits. Any change belongs in the
campaign-admission schema and the next design's §F1, decided before that
campaign's pre-run, so the bar is never again tightened past the package's
own definition of convergence without a stated reason.


---

## DECIDED — 2026-08-17, Shinichi

**Option (a): retain the existing adjudication with a permanent caveat.** No rerun, no
sentinel. The caveat: Design 122's K1 gradient leg fired on L2 as an instrument artefact
(#1092), its rows cannot be retrospectively corrected (only the defective scalar was
retained), and L2 stationarity rests on TEST A's independent 7,200/7,200 pass rather
than on the gradient column. L0's breach is a tolerance-choice finding, not an optimiser
failure. Any future campaign inherits the fixed instrument via
`fit_health$max_gradient` and must retain per-fit parameter and gradient vectors if a
gradient criterion is to be re-readable. A sentinel rerun remains available later as a
separately approved D-139 exercise; it is not commissioned.
