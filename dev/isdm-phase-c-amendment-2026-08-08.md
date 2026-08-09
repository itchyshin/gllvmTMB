# Phase C prospective instrument amendment — 2026-08-08

**Status:** prospective and binding for the corrected Phase C pilot and campaign.  
**Outcome access:** written before inspecting any corrected pilot statistics or any C-lite result.  
**Scope:** simulation and analysis instrumentation only. The scientific estimands, primary endpoint,
corruption criteria, attribution criterion, and refutation conditions in
`dev/isdm-phase-c-design.md` are unchanged.

## 1. Relationship to the original preregistration

`dev/isdm-phase-c-design.md` remains the historical preregistration. It must not be rewritten to
make this amendment look original. This document records prospective corrections needed to make
the planned instrument executable without ambiguous joins, aliased oracle columns, or
outcome-dependent pilot choices.

The following original commitments remain binding:

- common-random-number pairing against the `kappa = 0` null at the same seed (design D8 and E3);
- recovery-only arm comparisons, never likelihood or AIC comparisons (design M);
- the primary endpoint and all C1/C2/C3 thresholds (design P3-P4);
- the pre-registered failure handling (design P2); and
- the requirement to record, rather than filter on, optimiser and boundary diagnostics.

No outcome threshold is changed by this amendment. In particular, `0.10`, `0.05`, and `3 MCSE`
remain frozen, as do the primary endpoint and R1-R5. Corrected pilot results may choose only the
computational branches explicitly frozen below; they may not revise a scientific threshold.

## 2. Canonical stage, block, and row schema

`stage` and `block` are distinct variables:

- `stage` is one of `preflight`, `pilot_v2`, or `campaign`; the structural
  smoke is part of `preflight`, not a statistical stage;
- `block` is the design block (`G1` through `G6`) or the named preflight/smoke block.

The pilot therefore has `stage = "pilot_v2"` and `block = "G1"`; the production G1 run has
`stage = "campaign"` and `block = "G1"`. This prevents the pilot seeds from colliding with the
same seed numbers in production G1. A result row's canonical key is:

```text
stage, block, kappa, rho, omega, phi_x, phi_bias,
n, T_sp, d_fit, k, beta0_shift, seed, arm
```

Every logical result table must assert uniqueness of that key before analysis. `T_sp` is the
machine column; prose and tables may label it `T`, but the stored name does not vary.

## 3. Separate environmental and bias-field ranges

The original single `phi` parameter was used for both the environmental field `x` and the bias
fields. That makes the G6 smoothness ladder change two mechanisms at once. The corrected instrument
separates them:

- `phi_x = 0.15` is fixed in every pilot and campaign configuration;
- `phi_bias` controls only the standardised `g` and `h_j` bias fields;
- REF has `phi_bias = 0.15`;
- G6 varies `phi_bias` over `{0, 0.4}` while keeping `phi_x = 0.15`.

Both values are stored on every row and in every receipt. At `kappa = 0`, `rho`, `omega`, and
`phi_bias` are inert because no bias field enters the response; `phi_x` remains active and is not
collapsed.

## 4. Frozen null pairing and A6-null collapse

For a biased row, the unique paired-null lookup key is:

```text
stage, seed, arm, n, T_sp, d_fit, k
```

`block`, `rho`, `omega`, `phi_x`, `phi_bias`, and `beta0_shift` are deliberately absent. `phi_x`
and `beta0_shift` are frozen globally rather than being treatment axes. This lets campaign G6 reuse the
campaign G1 null while preventing pilot/campaign cross-pairing. The null table must be unique on
this key before it is joined. The biased row retains its full canonical configuration after the
join.

At `kappa = 0`, `bstar` is identically zero. Including `trait:bstar` would add
an all-zero block and test a rank-deficient design rather than the oracle model.
The corrected instrument therefore fits the logical A6-null row through the A5
right-hand side:

- fit A5 and A6 from the same deterministic starting stream and the same A5 formula;
- set `oracle_collapsed = TRUE` on the A6 row;
- retain `arm = "A6"` so every biased A6 row has a paired logical null; and
- verify exact equality of their model matrices and fitted parameter vectors in
  the contract check.

No biased A6 row is collapsed. A6 at `kappa > 0` must contain exactly `T_sp` non-constant
`trait:bstar` columns and is fit normally.

## 5. Corrected smoke is structural only

The corrected low/high smoke may establish only that the instrument works. It must verify:

- the intended low/high configurations and all six logical arms are present;
- canonical keys are unique and the null mapping is one-to-one before replication;
- all expected columns and provenance fields exist;
- every required headline field is finite on a completed row;
- throws are represented by `fit_error` rows rather than dropping rows; and
- the A6-null collapse and non-null A6 `trait:bstar` structure satisfy Section 4.

The smoke must not require `D_bias`, `dD_bias`, a sign-flip rate, or any other scientific outcome to
move in a specified direction or by a specified amount. The previous one-seed `0.05` movement check
is not an evidential gate and is superseded for the corrected run. This is an instrumentation
correction, not a change to C1, C2, C3, or R1-R5.

## 6. Conditional BETA0 calibration after the permitted prevalence check

The first corrected pilot starts at the planted `BETA0` shift of zero. After
structural integrity is verified, pooled PA prevalence is one of the four
prospectively permitted pilot summaries. If it lies inside `[0.25, 0.50]`, the
zero shift is frozen. If it lies outside that interval, calibration is
simulation-only and uses the fixed pilot seeds and configuration table. It does
not fit a model or inspect a recovery statistic; the pilot is then rerun in full.

Let `delta` be one common additive shift applied to every element of `BETA0`, and let
`pbar(delta)` be pooled realised PA prevalence over the fixed pilot simulations. Freeze `delta` by
deterministic bisection as follows:

1. Target `pbar(delta) = 0.375`.
2. Start with bracket `[-8, 8]`. Expand it deterministically and symmetrically only if it does not
   bracket the target.
3. Reuse the exact fixed pilot seeds, configurations, RNG streams, and draw order at every trial
   value; only `delta` changes.
4. Stop at `abs(pbar(delta) - 0.375) <= 0.005`, or after 30 bisection iterations.
5. If the tolerance is not met within 30 iterations, stop: the corrected pilot is NO-GO pending a
   recorded amendment. Do not choose a visually convenient shift.
6. Record the final common shift, achieved prevalence, bracket, iteration count, and calibration
   configuration hash. Freeze that one shift for all later Phase C runs.

This bisection is an implementation detail frozen before any recovery statistic
from the out-of-range pilot is interpreted. After `BETA0` is frozen, rerun the
full pilot from the beginning; no pre-calibration fit or statistic may be
combined with it. The rerun derives its shift from the immutable calibration
receipt rather than a free command-line value.

## 7. Pilot precision and compute decisions

The pilot precision decision is controlled by **A1 at REF**, where REF remains
`kappa = 1`, `rho = 0.6`, `omega = 0.5`, `phi_x = phi_bias = 0.15`, `n = 400`,
`T_sp = 8`, `d_fit = 2`, and `k = 3`.

For completed same-seed A1 pairs, calculate

```text
dD_bias_s = D_bias_REF,s - D_bias_null,s
sd_ref = sd_s(dD_bias_s)
projected_3MCSE_100 = 3 * sd_ref / sqrt(100)
```

The prospective decision is:

- if `projected_3MCSE_100 <= 0.05`, run full G1 with `S = 100`;
- if `projected_3MCSE_100 > 0.05`, run the **entire** G1 grid with `S = 200`.

The earlier option to remove `rho = 0` is withdrawn prospectively because it removes the frozen
primary endpoint. The fallback retains both `rho` levels, including `rho = 0`; budget pressure does
not alter the estimand. The decision, its input pair count, `sd_ref`, and projected MCSE are written
once to an immutable pilot receipt before any production result is inspected.

The existing timing boundary is unchanged: the corrected pilot's mean timed optimiser cost at
`n = 400` routes the campaign to Totoro when it is strictly greater than 10 seconds per executed
fit; otherwise local execution remains admissible.

## 8. G5 A2 rank-d separation

G5 deliberately sets `k = 1`. In A2, the per-trait unique diagonal is then not identified and is
mapped off, so its covariance target is not the full
`Lambda Lambda' + diag(psi)` target used elsewhere.

For G5 A2 only:

- require and report the expected `diag_B_skip > 0` state;
- score correlation recovery against the best positive-semidefinite rank-`d`
  approximation to the planted `R`, renormalised to a correlation matrix;
- store the result under explicitly suffixed rank-d metric names (for example,
  `rank_d_D_bias` and `rank_d_D_rmse`);
- do not place those values in the ordinary full-Sigma metric columns; and
- do not use G5 A2 in a cross-arm full-Sigma contrast.

All other G5 arms retain the ordinary target where identified. Tables must put G5 A2 in a separate
rank-d panel so a numerically similar value cannot be mistaken for the same estimand.

## 9. Failure and exclusion rules

The analysis cell is the canonical configuration without `seed`. The scheduled denominator is
fixed by the grid, not inferred after filtering.

- A throw or scoring/extraction failure is retained as a row with `fit_error` and excluded from
  the corresponding numerical estimator.
- Report `n_scheduled`, `n_completed`, `n_excluded`, and `exclusion_rate` for every cell.
- Flag every cell with exclusion rate greater than 5%; do not silently pool it with another cell.
- A completed row is never excluded for `convergence`, `pdHess`, `n_heywood_psi`, or
  `n_heywood_loading`.
- Every headline estimate is reported over all completed **pairs** and again over the subset where
  both members have `pdHess == TRUE`. If the summaries differ by more than one all-completed MCSE,
  report the discrepancy as a finding.
- A non-finite required headline value on a row without `fit_error` is a structural instrument
  failure. Stop rather than letting a helper silently remove it.
- Pairwise estimators use only complete pairs; their effective seed count is printed beside the
  estimate and MCSE.
- Boundary and Heywood counts are outcomes, never filters.

## 10. Immutable receipts and outcome firewall

Before reading scientific outcomes, write append-only, content-addressed receipts for calibration,
smoke, pilot structure, pilot precision/timing, and each campaign block. Each receipt records at
least:

- UTC timestamp, git commit, branch, and clean/dirty status;
- stage, block, canonical schema version, full configuration-table hash, and seed list;
- `phi_x`, `phi_bias`, frozen `BETA0` shift, arm list, package/session versions, optimiser control,
  backend, core count, and compute host;
- expected logical rows, expected optimiser calls, observed rows, executed calls, and unique-key
  verdict;
- null-key uniqueness, pair counts, A6-null alias count, exclusion counts, and non-finite checks;
- exact input and output paths plus SHA-256 hashes; and
- the one permitted decision, if applicable: calibration shift, `S = 100` versus full-grid
  `S = 200`, or local versus Totoro.

Receipts and raw result files are never overwritten. A rerun receives a new run identifier and new
hashes; analyses name the exact receipt and raw-result hash they consume. The outcome columns are
not read until the structural receipt passes. Pilot outcomes may not alter the grid, arms, primary
endpoint, scientific thresholds, pairing rules, exclusions, or reporting rules beyond the explicit
precision and compute branches in Section 7.

## 11. Corrected-run GO / NO-GO

The corrected pilot is GO only after the schema and null keys are unique, the structural-only smoke
passes, A6-null aliases are attributable, `BETA0` is frozen within tolerance, all required receipts
exist, and no unlabelled non-finite headline value remains. Production is GO only after the A1 REF
precision branch and compute route have been recorded immutably.

Any failure of those conditions is NO-GO for production compute. It is not evidence for or against
the scientific hypothesis. Repair requires a dated prospective amendment; it never licenses an
in-place threshold or outcome-rule change.
