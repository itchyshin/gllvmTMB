# Paper 2 A3 — Case-C same-objective candidate design packet

**Status:** `A3_CASE_C_NO_CANDIDATE__DESIGN_ONLY`.

## Decision

No same-objective Case-C candidate is defensibly specified from the retained
G2 evidence.  A prospective Case-C state remains
`NO_CANDIDATE` and is a numerical **HOLD**, not a failed use of the existing
boundary polish and not a permission to add a retry, Newton step, rescaling,
or control change.

This is the A3 answer to the question posed by G2k: the dominant residual
geometry is real enough to require an explicit decision, but the evidence does
not identify a safe new estimator.  The admissible next no-fit contract is
therefore to protect and validate the `NO_CANDIDATE` decision—not to implement
or exercise a Case-C repair.

## Evidence read and boundary

This packet is a no-fit successor of:

- `2026-08-12-g2k-gradient-diagnostic-decision.md`: 69 recovery-pass/raw-
  gradient holds are outside the existing named diagonal-boundary envelope;
  58 have maximum block `b_fix` and 11 `theta_rr_B`.
- `2026-08-12-g2n-numerical-admission-decision.md` and
  `2026-08-12-g2m-numerical-admission-protocol.md`: Case C is the strict
  non-boundary interval and is already prospectively recorded as
  `NO_CANDIDATE`/HOLD.
- `2026-08-12-g2o-postmortem-certificate.md`: the retained `b_fix` residual
  recurs but its within-block diagnostic does not identify stationarity or a
  new estimator; the diagonal-Psi finding is a separate question.
- `2026-08-12-paper2-case-c-psi-information-specification.md`: the private
  G2d likelihood, DGP, maps, transforms, thresholds, all-attempt record, and
  scale/recovery design are frozen.

Accordingly, this packet creates no candidate, implementation, TMB objective,
fit, profile, simulation, benchmark, or compute artefact.  It preserves
`G2N_LOCAL_PRERUN_HOLD`, `G2K_CALIBRATION_HOLD`, and
`G2C_SMOKE_ADMISSION_HOLD`.

## Frozen Case-C predicate and result

A fresh attempt can enter Case C only after the unchanged ordinary
prerequisites: exactly three retained raw restarts; finite objective and raw
gradient; optimizer code 0; positive-definite fixed Hessian; valid profiles;
the GBIF-only source gate; `nlminb`; no AGHQ; and no ridge.  The precise
predicate is

\[
10^{-3}<\max_j |g_j|<10^{-2},\quad
\text{no named }\texttt{near_zero_sd_B},\quad
\text{and a unique maximum in }\texttt{b_fix}\text{ or }
\texttt{theta_rr_B}.
\]

For this predicate the fixed record is:

| Field | Frozen value |
| --- | --- |
| `case` | `C` |
| `polish_status` | `NO_CANDIDATE` |
| numerical admission | HOLD |
| `candidate_method` | missing/`NA` because no candidate is attempted |
| recovery classification | separate and unchanged; it cannot override the HOLD |

The raw gradient threshold remains \(10^{-3}\).  The upper open bound
\(10^{-2}\) is a classifier boundary, not an alternate acceptance tolerance.
The scaled score, covariance-scaled score, and any local-Hessian movement are
descriptive fields only; none may recode Case C as stationary or eligible.

## Same-objective invariants

Any later proposal that calls itself a Case-C candidate must first show, in a
separate design and no-fit validation task, that it preserves every item below.
Until then it is not a candidate under this programme.

| Invariant | Required unchanged state |
| --- | --- |
| Objective and derivatives | The exact production `obj$fn` and `obj$gr`; no rebuilt, penalised, rescaled, surrogate, or alternative objective. |
| Estimand and DGP | The private GBIF Poisson plus three PA cloglog law, shared ecological state, GBIF-only bias covariate, rank-one `Lambda`, and diagonal `Psi`. |
| Coordinates and transforms | `b_fix`; `theta_rr_B`; `theta_diag_B = log(psi)` with Psi scored as `exp(2 * theta_diag_B)`; no rotation, reparameterisation, or coordinate replacement. |
| Data and latent structure | Identical data, random effects, source map, `NA` PA bias entries, offsets/exposures, and rank. |
| Map and bounds | Identical parameter map, fixed/free state, order and dimnames of `opt$par`, bounds, and internal scale. |
| Optimizer/control state | Identical `nlminb` controls, restart design and selection rule; no extra restart, tolerance, iteration/evaluation budget, AGHQ, ridge, or warm-start policy. |
| Numerical/recovery rules | Unchanged raw gate, Case A--D predicates, boundary predicate, profile contract, five recovery metrics, thresholds, and all-attempt denominator. |

These invariants make a proposed Case-C action an evaluation of the same
estimator/objective state.  Changing any one creates a different estimator or
evidence design and requires a new approval; calling it a "polish" does not
preserve it.

## Why no existing candidate transfers to Case C

The existing accepted polish is conditional evidence for Case B only: exactly
one named `near_zero_sd_B` under its existing G2i eligibility predicate.  It
does not cover a `b_fix` or `theta_rr_B` maximum and cannot be generalized by
analogy.

The retained alternatives also fail to constitute an admissible Case-C
candidate:

| Proposed transfer | Decision | Reason |
| --- | --- | --- |
| Apply the boundary-only covariance-Newton helper | REJECT | Its invocation is gated by the Case-B boundary predicate; its retained checks do not establish symmetric, PD, well-conditioned, dimname-aligned covariance for Case C; applying it would be a new estimator choice. |
| Add an `nlminb` retry or choose a different raw start | REJECT | Changes the frozen three-restart/control/selection contract and is not a same-objective candidate already defined for this geometry. |
| Treat `cov.fixed %*% g` or a small local-SE movement as convergence | REJECT | It changes the numerical criterion; G2o establishes only a local diagnostic, not stationarity. |
| Change scaling, tolerances, map, bounds, AGHQ, ridge, or objective | REJECT | Violates a frozen invariant and confounds estimator, DGP, or numerical-admission evidence. |
| Borrow a candidate from the Psi-information experiment | REJECT | Psi calibration and Case-C numerical admission are distinct estimands/questions; no variance-partition experiment identifies an optimizer candidate. |

Rank-one loading sign symmetry is an additional reason that local positive
curvature alone cannot establish globally unique `theta_rr_B` coordinates.  A
candidate is therefore not selected separately for `b_fix` and `theta_rr_B`:
both remain `NO_CANDIDATE` under the current evidence.

## Mandatory NO_CANDIDATE conditions

Record `NO_CANDIDATE` and HOLD whenever any of the following applies:

1. The exact Case-C predicate holds and no separately approved candidate has
   passed its no-fit validation.
2. A suggested action is conditioned on an unnamed/non-diagonal boundary, a
   tied maximum, or a maximum in `b_fix`/`theta_rr_B` without a predeclared
   method-specific predicate.
3. The action would alter an invariant in the preceding table, including an
   extra retry or a changed optimizer control.
4. A covariance-based action lacks an exact coordinate match to `opt$par`,
   symmetry, positive definiteness, finite conditioning, and verified
   dimension/dimname alignment.
5. A candidate's raw/candidate state, method identity, error text, or exact
   map/data/random/bounds/scale/control signatures cannot be retained.
6. A proposed rationale relies on recovery success, a covariance-scaled score,
   profile shape, or a previous Case-B success instead of a predeclared,
   geometry-specific candidate specification.

Cases outside the exact Case-C predicate remain their frozen Case A, B, or D
states; `NO_CANDIDATE` must not become a permissive fallback for invalid or
nonfinite states.

## Adversarial no-fit rejection matrix

The future A4 no-fit contract must reject the following inputs before any
candidate call, optimizer call, or compiled Case-C path can exist.

| Fixture | Required outcome |
| --- | --- |
| `b_fix` unique maximum in the open Case-C interval, no named boundary | `NO_CANDIDATE`; no candidate route invoked. |
| `theta_rr_B` unique maximum in the open Case-C interval, no named boundary | `NO_CANDIDATE`; no candidate route invoked. |
| Raw pass with a boundary flag | Case A/`NOT_REQUIRED` if its normal prerequisites hold; never Case B/C. |
| Case-B boundary geometry with its named diagonal coordinate | Existing Case-B route only; it cannot exercise a Case-C candidate. |
| Tied maximum, maximum in `theta_diag_B`, more than one/no valid named boundary, nonfinite objective/gradient, non-PD Hessian, wrong optimizer, AGHQ, or ridge | Case D/invalid HOLD; no fallback candidate. |
| Non-symmetric, non-PD, ill-conditioned, misdimensioned, or dimname-misaligned `cov.fixed` supplied to a hypothetical covariance step | Reject before evaluation; retain reason; never silently coerce. |
| Any mismatch in objective identity, map, data, random effects, bounds, scale, controls, restart record, source gate, or parameter order | Reject before evaluation; retain every mismatch field. |
| An attempt to use a relaxed raw tolerance, scaled score, extra retry, changed start, map change, or rebuilt objective | Reject as an estimator/rule change; do not label it a candidate failure. |

No compiled objective test is authorized here.  A compiled-unit test remains
appropriate only for the already specified Case-B candidate; for Case C the
no-fit test asserts non-entry and retained provenance.

## All-attempt provenance and future handoff

Every future fresh attempt must retain the raw state before any decision:
source and protocol SHA-256 hashes; seed and immutable fixture manifest; all
three raw starts and selection; `opt$par` order/dimnames; objective; full
gradient and maximum block/index; optimizer code/control; fixed-Hessian and
boundary state; profile rows; maps; data/random/bounds/scale/control
signatures; all five recovery metrics; warnings/errors; package, DLL, TMB, and
R versions; and final file manifest.

If a later separate proposal is approved, its record must additionally retain
each candidate attempted—including an evaluation error/nonfinite outcome—with
method identity, input/output parameters, objective/gradient/Hessian,
acceptance predicate and reason.  Empty provenance is invalid; it cannot be
read as an accepted candidate.  The retained G2k/G2n/G2o ledgers are
evidence-only and may never be reclassified.

## A4 handoff and gate

The next permissible implementation proposal is narrower than a repair: add
no-fit tests that demonstrate mutual exclusivity/exhaustiveness of Cases A--D,
preserve the existing Case-B candidate, and prove Case-C non-entry with the
rejection matrix above.  It must not add a Case-C helper, alter the likelihood,
or call the iJSDM fitter/optimizer.

Only after a later, separately approved estimator design supplies an exact
geometry-specific method and passes the invariant and adversarial contracts
above may it request a distinct implementation approval.  This packet grants
neither that approval nor any local pre-run, recovery, scale, Totoro, DRAC,
reader, public-documentation, or package capability authority.
