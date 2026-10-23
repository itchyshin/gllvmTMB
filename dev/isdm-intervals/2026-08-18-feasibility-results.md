# iSDM interval feasibility grid — results (2026-08-18)

Approved by Shinichi 2026-08-18 against
`docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md` (§5:
smoke → estimate → Totoro if < 30 min). Harness: `campaign-intervals.R`;
smoke receipts `smoke-output.txt` (local, 12 reps) and `smoke-remote.csv`
(Totoro, 1 rep × 16 cells). Run: **Totoro, 100 cores,
`OPENBLAS_NUM_THREADS=1`, 1,600 fits, 56.5 s wall / 45.1 core-min** — two
orders of magnitude under the D-139 line (a-priori estimate was 5–30 min).
Data: `campaign-intervals-results.csv` (1,600 rows, one per fit).

## Health

1,600/1,600 converged, 0 errors. `pd_hessian` PASS rate 0.888 overall
(0.81–0.90 by cell; the local smoke's 10/12 was representative). Wald SEs
finite/positive on 1,599/1,600; `predict(se.fit=TRUE)` succeeded on 1,421
(fails only on non-PD fits, where the package's classed refusal is the
certified behaviour). All coverage reads below are on PD fits only,
per-cell, per-species/per-arm — never pooled.

## E1 — env-slope Wald coverage (the headline feasibility question)

All 48 cell × species verdicts are **INDETERMINATE against the
[0.92, 0.98] Wilson band — by design**: at n ≈ 81–95 PD fits per cell the
Wilson 90% interval is ~±0.05 wide, and the proposal itself said 12–100 reps
cannot resolve the band (Design 118 needed n ≥ 580). What the grid CAN say:
per-species point coverages span **0.883–0.988**, with 43/48 in
[0.90, 0.98]; no cell approaches the K3 floor (< 0.80), so **K3 does not
fire**. The existing Wald SEs are in the defensible neighbourhood of nominal
everywhere measured.

**Feasibility verdict: a full pre-registered calibration campaign at
n ≥ 580 reps/cell is justified and correctly scoped** — nothing here
suggests the SE machinery is broken for estimand 1; nothing here certifies
it either (per the proposal's own fence, this grid is not the calibration
campaign and no claim ships from it).

## E4 — `predict(se.fit)` coverage of the TRUE linear predictor: a measured negative

Nominal-95% intervals `est ± 1.96·se.fit` cover the true `eta` at
**0.23–0.82** — never near 0.95 — and coverage FALLS with grid size
(150 cells: 0.48–0.82; 810 cells: 0.23–0.55) and is worse on the PO arm than
the PA arm in every cell. This is the documented conditionality made
quantitative: the SE is fixed-effect-only, and `eta`'s dominant error at
larger grids is the random-effect (latent/field) reconstruction the SE
ignores. **`se.fit` must not be offered as an eta/map interval in anything
user-facing.** This closes the loop with Design 126 §4.4: map-scale
uncertainty requires a construction that propagates RE uncertainty
(joint-precision or sample-based), not the existing delta SE.

## E2 — field amplitude: no interval machinery exists

`Lambda` is not ADREPORTed with an SE in any fit (`lam_report_se` FALSE on
1,600/1,600); only the raw `theta_rr_B` parameters carry SEs. An amplitude
interval is therefore a **new construction** (delta on the loading
transform, or ADREPORT + delta in C++), exactly as D-157 anticipated.

## E3 — intensity ratios: not measurable today (recorded, not dropped)

No row-pair covariance is exposed by any current surface, so no
between-cell ratio interval is computable at all. That absence is the
finding.

## What follows (each gated separately; nothing launched from this doc)

1. Full E1 calibration campaign: 16 cells × ≥580 reps ≈ 9,280 fits ≈ ~5–9
   min wall at 100 cores on these timings — needs its own pre-registration
   (grid, gates, MCSE) per the proposal's §4 fence, then Shinichi's launch
   approval.
2. E4 fix path: joint-precision eta SEs (the MIS-37 wave-1b machinery is the
   in-house precedent) — an `R/` change, maintainer-gated, belongs with the
   Design 126 predict work.
3. E2: ADREPORT Lambda (or document the theta-only surface honestly).

Register: ISDM-01/02/03 all stay `partial`; no register row moves on this
grid (pre-registered in the proposal §4).
