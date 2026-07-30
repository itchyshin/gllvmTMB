# After-task — the psi face, and validating the stratified denominator (Arcs B–C)

Date: 2026-07-30. Agent: Claude. Lane: `claude/heywood-gate-20260730`.
Companion to `2026-07-30-heywood-gate-diagnose.md` (Arc A, the loading face).
Evidence: `docs/dev-log/2026-07-30-psi-face-heywood-and-rel-threshold.md`,
`docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md` §6.2.

## 1. Goal

Close the gaussian/Poisson gap left by Arc A, and validate Arc A's stratified
denominator on real mixed-family fits rather than a hand-built fixture.

## 2. Implemented

- **`psi_rel_thresh` default 0.001 → 0.01** in `check_gllvmTMB()`, with the
  calibration and its transport test recorded in the roxygen and NEWS.
- **A test for the relative arm** in the newly covered band (unique SD 0.005
  against siblings of 1.0), asserting WARN at the new default and PASS at the
  old, so it discriminates rather than merely passing.
- **No new check row, no new statistic, no new argument.**

## 3a. Decisions and Rejected Alternatives

- **Measured before wiring, and it inverted the plan.** The approved plan was to
  wire two free statistics (`communality > 1`, variance-normalised `‖G‖_F`).
  Measurement rejected both and pointed at retuning an existing row instead —
  a strictly smaller change.
- **REJECTED: `communality > 1`.** `psi = exp(theta) >= 0` always, so
  `c^2 = diag(LL')/diag(Sigma)` cannot exceed 1. **Maximum observed exactly
  1.000 over 360 fits; count above 1 = zero.** Wiring the literal classical
  criterion would have shipped a gate keyed on an impossible event — the same
  defect Arc A had just removed. It is also non-additive: for Poisson the
  link-implicit residual keeps `c^2` off 1, giving sensitivity 1.000 (gaussian)
  vs 0.000 (Poisson) on severe cases.
- **REJECTED: a new scale row.** `near_zero_psi_<level>` already reports
  56/56 (100%) of severe collapses at 0/151 false positives. It did not need
  replacing, only retuning.
- **Threshold 0.01, not 0.1.** 0.1 reaches sensitivity 1.000 on the homogeneous
  design and flags **19% of healthy fits** whose true unique variances differ by
  1000×. 0.01 holds at zero across every spread, margin 2.1×.
- **`rel_frob` on `Sigma` REJECTED as the label for this face.** Among collapsed
  fits it spans only [0.074, 0.880]; the loading absorbs the collapsed variance,
  so `Sigma` is recovered and the decomposition is not.

## 4. Files Touched

Modified: `R/diagnose.R`, `man/check_gllvmTMB.Rd`, `NEWS.md`,
`tests/testthat/test-sanity-multi.R`,
`docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md` (§6.2).
Created: `docs/dev-log/2026-07-30-psi-face-heywood-and-rel-threshold.md`,
`dev/heywood/psi-regime-probe.{R,csv}`,
`dev/heywood/psi-shipped-coverage.{R,csv}`,
`dev/heywood/psi-heterogeneous-fp.{R,csv}`,
`dev/heywood/mixed-family-validation.{R,csv}`, this file.

Not staged: `dev/heywood/fp-sweep-pilot*.csv` — superseded exploratory output
from an earlier schema, left untracked deliberately.

## 5. Checks Run

- `rcmdcheck --as-cran`: **0 ERRORS, 0 WARNINGS, 1 NOTE** (New submission).
- `test-sanity-multi.R`: 51 pass, 0 fail.
- 360-fit psi-regime probe; 360-fit shipped-coverage run; 480-fit heterogeneous
  transport test; 180-fit mixed-family validation. All local, ~20 CPU-minutes.

## 6. Tests of the Tests

The new relative-arm test asserts **both** directions: `WARN` at the new default
and `PASS` at `psi_rel_thresh = 1e-3`. Without the second assertion it would
pass under either default and prove nothing — the exact failure mode that hid a
real bug in Arc A.

## 7a. Issue Ledger

None opened or closed. PR #838 carries all three commits.

## 8. Consistency Audit

- Ran the **shipped** `check_gllvmTMB()` on the collapsed fits rather than
  reasoning about its thresholds. That is what overturned the prior claim that
  `near_zero_psi_*` is not the psi-side detector — it is, at 100% of severe
  cases and 0 false positives. Reasoning from a summary would have repeated
  the day's dominant error.
- Verified `.gllvmTMB_relative_collapse()` computes `min/max < thresh`
  (`R/diagnose.R:112-122`) before sweeping it offline.
- Confirmed the absolute arm is untouched, so nothing previously flagged stops
  being flagged.

## 9. What Did Not Go Smoothly

- The first psi probe labelled degeneracy by `Sigma` recovery, found zero
  degenerate fits, and nearly concluded the pathology was absent. It was
  present in 58% of fits — the label was wrong, not the phenomenon. This is
  the same category substitution that made Arc A's sweep report "zero
  degenerate gaussian fits".
- The plan's two proposed statistics were both wrong, and one would have
  shipped a gate that cannot fire. Measuring first cost twenty minutes.

## 10. Known Residuals

- **8 collapsed fits still missed** at 0.01, and the residual band has no
  instrument.
- **One DGP family**: p = 6, true q = 1, gaussian and Poisson, one spread
  pattern. Not swept: p, true q > 1, binomial with `unique = TRUE`, the
  `unit_obs`/`phylo`/`spatial` tiers, missing data.
- **58% incidence is a property of a design chosen to generate the pathology**
  by over-factoring. It is not an estimate of real-world frequency — though
  users do routinely guess the rank.
- **Mixed-family detection is 59.5% at ×100 scale**, up from 0%, not high. The
  remaining misses degenerate without a single-trait runaway.
- **This is a behaviour change**; fits that passed will now warn. Maintainer
  decision, not self-merged.

## 11. Team Learning

**Measure before wiring.** The plan named two statistics on good reasoning; both
were wrong, and one was structurally incapable of firing. Twenty minutes of
measurement replaced a new API surface with a one-line default change.

**Whenever a statistic is a ratio, sweep the heterogeneity of whatever sits in
its denominator.** Homogeneous truth flatters a ratio every time. It hid the
sparse-loading transport failure in Arc A, and it would have hidden this one:
the threshold with the best sensitivity on a homogeneous design flags 19% of
healthy fits when unique variances genuinely differ. Same lesson, second
instance, one day apart.

**To learn what a shipped diagnostic does, run it.** The claim that
`near_zero_psi_*` was not the psi-side detector came from reading its thresholds.
Running it showed 100% sensitivity on severe cases at zero false positives.

## 12. Cross-Product Coverage

| Dimension | Covered | Not covered |
|---|---|---|
| Face of the pathology | loading runaway (Arc A), psi collapse (Arc B) | a *common* inflation of all loadings — invisible to a within-fit ratio by construction, and no scale statistic is wired |
| Family | gaussian, Poisson (psi face); binomial (loading face); mixed gaussian+binomial | binomial with `unique = TRUE`; Gamma, nbinom, Beta, Tweedie, ordinal |
| Tier | `unit` (`Lambda_B` / `sd_B`) | `unit_obs`, `phylo`, `spatial`, `kernel` — every templated row is exercised at `unit` only |
| Rank | true and over-specified (d = q+1, q+2) | under-specified; true q > 1 |
| Traits `p` | 6 | the loading face's tail rises with p and was swept to 25; the psi face was not swept on p at all |
| Link | logit, identity, log | probit, cloglog |
| Data | complete, balanced | missing responses, unbalanced grids |

The largest untested cell is **binomial with `unique = TRUE`**, where both faces
could occur at once and neither instrument has been measured.
