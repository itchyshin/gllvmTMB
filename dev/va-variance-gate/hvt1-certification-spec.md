# HVT-1 certification specification: private adaptive `q = 2` truth oracle

**Status:** design-only, private research specification.  This document adds
no runner, fit, package test, public interface, or interpretation.  HVT-1 is a
repair of the *measurement instrument*, not a reopening of Design 85's closed
VA route.

## Purpose and boundary

The frozen product-Gauss--Hermite (GH) runner has a declared tail tolerance
`truth_tail_tolerance = 1e-3` on the **total** fixed-coordinate log marginal:
`abs(H801 - H501) <= 1e-3`.  It supplied stable values at observed projected
variance 4.613715, 5.987552, and 8.674338, but not at 22.190718 (tail spread
0.01636229).  The latter is `uninterpretable`; it is not a missing truth value.

HVT-1 may measure only the same fixed-coordinate, complete multi-trial
binomial-logit `q = 2`, `N = 10`, `T = 2`, `n_trials = 12` cells frozen in
`hvt1-source-lock.md`.  It may add an independently implemented adaptive
two-dimensional integration calculation of

\[
  \ell(\beta,\Lambda) = \sum_{i=1}^{N}
  \log\!\int_{\mathbb R^2}
  p(y_i\mid u_i,\beta,\Lambda)\,\phi_2(u_i)\,du_i,
\]

at the **fitted fixed** `beta, Lambda`; it neither refits nor changes the
coordinate system.  It must not consume AGHQ or Laplace values, calculate a
new fixture, use Bernoulli/missing cells, or tune a cell after seeing an
adaptive result.

`Lambda = 0` makes the q=2 integral analytic (the likelihood factor does not
depend on either coordinate).  An effective-q1 loading has a zero second
column and must reduce identically to the q=1 integral.  These are oracle
anchors, not model-recovery tests.

## Immutable admission record

Before evaluating even one unit, the measurement writes the following frozen
record and compares it byte-for-byte / SHA-256-for-SHA-256 with the source
lock.  Any mismatch is `ORACLE_NOT_CERTIFIED` and stops the entire requested
cell before an adaptive number is emitted.

| Required frozen item | Required value |
|---|---|
| frozen source base | `f22800812b123eb3e3dcf8e08db72769a45c10ae` is an ancestor of the recorded current head; every listed frozen input hash matches |
| `R/va-r3-proto.R` SHA-256 | `ecf5d4b76880339262d1e60c7937115848a43590033449212d39f36ff49acdf9` |
| `inst/tmb/gllvmTMB_va_r3.cpp` SHA-256 | `8f13267a27835592db8b9e63f4e86ca5a4fdb91cd425f22600df11317981e065` |
| existing runner SHA-256 | `7f9890fd33cf952c3a2742e9d05d398ef5c3f57c38a60f9662ba785748602c03` |
| calibration receipt SHA-256 | `4c3cf66914db44121f263a8cbd10426a023717eebf97077158427201e3b67d3e` |
| source manifest SHA-256 | `84a8b2a59314409c837cdc889aef8939bb07563fcc08e9177d120998b6210eec` |
| fixture contract | q=2; N=10; T=2; complete cells; binomial-logit; 12 trials; frozen seed/nominal target/observed band |
| fitted coordinates | exact packed `theta_rr`, unpacked `Lambda`, `beta`, row order, unit IDs and trait IDs from the unmodified runner result |

Record the SHA-256 digest of the adaptive-oracle source too, but it is a new
instrument and has no pre-existing lock value.  The result record must include
R version, TMB version, platform, all integration settings, and the full
per-unit attempts, including errors and non-finite values.

## Certification matrix

Each row is compulsory in order.  No later row rescues a failed earlier row.
All differences below are on the **total log-marginal** scale unless marked
per-unit.  `a - b` is evaluated without rounding and retained with both raw
values.

| Order / measurement | Construction and comparison | Pass criterion | Failure status and consequence |
|---|---|---|---|
| 0. Source and scope lock | Admission record above; assert no refit and fixed q=2 coordinates. | Every hash/configuration field exact. | `ORACLE_NOT_CERTIFIED`; stop cell. |
| 1. Zero-loading analytic anchor | Set both loading columns to zero while retaining the frozen response and beta.  Compare adaptive total with `sum(dbinom(y, n, plogis(X %*% beta), log=TRUE))`. | absolute difference <= `1e-10`; all unit values finite. | `ORACLE_NOT_CERTIFIED`; stop cell. |
| 2. Effective-q1 exact dimension-reduction anchor | Set column 2 of Lambda exactly zero; evaluate the q=2 adaptive integral and an independently coded one-dimensional adaptive integral using column 1. | absolute total difference <= `1e-8`; corresponding per-unit maximum <= `1e-9`. | `ORACLE_NOT_CERTIFIED`; stop cell. |
| 3. Stable-cell external comparator | On the unchanged frozen observed-band 4 cell, compare adaptive result with the existing product-GH H801 result **only if** its recorded H501--H801 tail is <= `1e-3`. | absolute difference <= `1e-3`. | `ORACLE_NOT_CERTIFIED`; stop all high-cell interpretation.  This is an instrument disagreement, not an ELBO result. |
| 4. Sum-of-units identity | Retain each `log I_i`; independently recompute the total by summing the retained unit values in ascending and descending unit order. | each sum agrees with reported total within `1e-10`. | `ORACLE_NOT_CERTIFIED`; stop cell. |
| 5. Forward/reverse nesting | Integrate `(u1 | u2)` and `(u2 | u1)` with independently ordered outer/inner routines, identical declared controls, and log-scale stabilization. | absolute total difference <= `1e-8`; no unit error/non-finite in either direction. | `ORACLE_NOT_CERTIFIED`; stop cell. |
| 6. Tolerance tightening | Baseline adaptive integration: `rel.tol = abs.tol = 1e-10`, `subdivisions >= 1000`; tightened: `rel.tol = abs.tol = 1e-12`, `subdivisions >= 2000`.  No tolerance may be relaxed after inspection. | absolute baseline--tightened total <= `1e-8`; every per-unit difference <= `1e-9`. | `TRUTH_UNINTERPRETABLE_ADAPTIVE`; retain attempts, emit no ELBO--truth gap. |
| 7. Centered/scaled coordinate check | Re-evaluate the same integral after an explicit affine change of variables (centering at a declared finite point and scaling by declared positive finite scales), including the Jacobian; repeat it with a second declared centering/scale choice. | each transformed total agrees with tightened baseline within `1e-8`; all attempts finite. | `TRUTH_UNINTERPRETABLE_ADAPTIVE`; retain attempts, emit no ELBO--truth gap. |
| 8. Target-cell measurement | Run rows 4--7 on each frozen requested observed band (4, 6, 10, 20); do not substitute a newly calibrated fixture. | all applicable rows pass for that cell. | see exact stop rule below. |

The analytic tolerance is deliberately much tighter than `1e-3`: no
quadrature approximation is necessary at zero loadings, and effective-q1 is a
dimension-reduction identity.  `1e-10`/`1e-8` permit ordinary double-precision
summation and independently stabilized nesting without laundering an
integration error into an exact identity.  The `1e-8` numerical-consistency
threshold is stricter than the existing GH `1e-3` tail rule because it compares
the same adaptive calculation under deliberately changed numerical routes.
The looser `1e-3` is retained only for the independent GH comparator, whose
predeclared certification is itself H501--H801 <= `1e-3`.  Neither tolerance
may be widened post hoc.

## Exact status and stop rule

The only permitted cell statuses are:

| Status | Meaning | Permitted reported quantity |
|---|---|---|
| `ORACLE_NOT_CERTIFIED` | source lock or an analytic, stable-comparator, sum, or nesting check failed | diagnostic attempts only; no truth value and no ELBO gap |
| `TRUTH_UNINTERPRETABLE_ADAPTIVE` | source/anchors passed but tightening, transformed-coordinate agreement, or finiteness failed | retained attempted values and failure reason only; no truth value and no ELBO gap |
| `TRUTH_CERTIFIED_ADAPTIVE` | every matrix row passed for this unchanged cell | certified fixed-coordinate adaptive log marginal and its numerical diagnostics; an ELBO gap may be calculated as a **private numerical measurement** |
| `NOT_RUN` | cell deliberately not requested | no inference |

**Stop rule:** Process cells in predeclared order 4, 6, 10, 20.  A status
`ORACLE_NOT_CERTIFIED` stops the run immediately and marks every later cell
`NOT_RUN`; it also forbids any high-variance ELBO--truth comparison from that
run.  A `TRUTH_UNINTERPRETABLE_ADAPTIVE` stops interpretation for that cell,
retains it in the all-attempt denominator, and may continue only to a later
already-predeclared cell as an instrument-characterisation measurement.  It
must not trigger fixture/coordinate/tolerance repair, exclusion, averaging, or
replacement by GH, Laplace, or AGHQ.  A `TRUTH_CERTIFIED_ADAPTIVE` is not a
gate pass: it is necessary numerical evidence only.

## Minimal machine-readable result schema

One immutable top-level record plus one record per requested cell is sufficient.
Fields may be JSON/RDS equivalents but names and semantics must not drift.

```text
schema_version, campaign_id, created_utc, git_head,
source_sha256{va_r3_proto, tmb_template, runner, calibration_receipt, source_manifest, adaptive_oracle},
runtime{R, TMB, platform}, fixture{q,N,T,n_trials,observed_band,
  nominal_prior_target,seed,observed_variance_band,observed_max_projected_variance,
  response_sha256,coordinates_sha256,beta,Lambda},
controls{baseline,tightened,forward_reverse,transform_1,transform_2},
anchors{zero_loading,effective_q1,stable_gh},
unit_log_integrals{baseline,tightened,forward,reverse,transform_1,transform_2},
totals{baseline,tightened,forward,reverse,transform_1,transform_2,gh_H501,gh_H801},
diagnostics{sum_forward,sum_reverse,all_finite,absolute_differences,
  thresholds,attempts,errors}, status, status_reason, stop_triggered,
elbo_H61, elbo_minus_truth
```

`elbo_H61` and `elbo_minus_truth` must be `NA` unless status is
`TRUTH_CERTIFIED_ADAPTIVE`; retaining an `NA` is required, not a dropped row.
The campaign must retain every attempted unit/cell, controls, and error string
locally under D-50.

The top-level `final_decision` is deliberately an **arc-level** decision, not a
cell status: it is `CERTIFIED_FIXED_CELL` only when every requested cell is
`TRUTH_CERTIFIED_ADAPTIVE`; otherwise it is `ORACLE_NOT_CERTIFIED`.  Thus a
cell-level `TRUTH_UNINTERPRETABLE_ADAPTIVE` result is retained faithfully while
the overall HVT-1 decision remains `ORACLE_NOT_CERTIFIED`.

## Forbidden outputs

Even a `TRUTH_CERTIFIED_ADAPTIVE` result must not be reported as a Design 85
gate pass, an estimator validation, a threshold relaxation, a VA/EVA feature,
or evidence for Design 86 admission.  It must not generate `logLik`, AIC, BIC,
LRT/profile/model weights, rank selection, frequentist intervals/coverage,
Laplace-error rankings, a public claim, a validation-register row, NEWS,
documentation, export, or package test.  It cannot change the frozen `<= 4`
gate; that would require a separate maintainer-approved formal contract.

## Risks retained explicitly

1. Agreement of two numerical integration routes is evidence against a
   coding/numerical error, not a proof of exactness in the sparse high-variance
   tail.  The status therefore certifies this instrument only.
2. The stable GH comparison validates portability at the stable cell, not
   extrapolation to observed band 20.  The analytic anchors and transformations
   are required precisely because GH was not stable there.
3. Fixed fitted coordinates mean this work says nothing about optimisation,
   recovery, rank selection, covariance-component recovery, or the VA model's
   practical utility.
