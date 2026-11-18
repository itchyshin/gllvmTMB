# G2n prospective numerical-admission implementation decision

**Status:** `G2N_NO_FIT_VALIDATION_PASS__LOCAL_PRERUN_APPROVAL_REQUIRED`

G2n implements the prospective G2m decision table at the exact G2m base
`3110075d`.  This is an implementation and no-fit/compiled-unit validation
result only.  It neither fits the six-species iJSDM nor changes a historical
ledger or recovery verdict.

## Reconciled contract

The G2m protocol SHA-256 is
`11b62af5817b7e6dac25c8da8f047970c6a149e6d8be0df42d540ee390bb5a9c`.
For a private iJSDM raw state with code zero, finite objective and gradient,
positive-definite fixed Hessian, `nlminb`, no AGHQ, and no ridge:

| Raw geometry | Stored decision | Admission |
| --- | --- | --- |
| `max(abs(gradient)) <= 1e-3` | A / `NOT_REQUIRED` | numerical pass |
| one named `near_zero_sd_B`, `1e-3 < max(abs(gradient)) < 1e-2`, existing G2i eligibility | B / `ELIGIBLE`, `ACCEPTED`, or `REJECTED` | pass only after the unchanged accepted candidate |
| no named boundary, unique maximum `b_fix` or `theta_rr_B`, within the same open interval | C / `NO_CANDIDATE` | HOLD |
| every other raw failure or invalid prerequisite | D / `INVALID_RULE_STATE` | HOLD |

The raw result is retained even after a selected candidate.  Candidate
provenance names the selected method and every attempted candidate; a
covariance-Newton evaluation error/nonfinite result is explicitly retained as
an unaccepted attempt with its reason and error text.  No Case-C candidate,
retry, control change, tolerance change, map change, or objective rebuild is
created.

## Evidence and boundary

- Pure decision-table tests cover Cases A--D, raw-convergence rejection,
  accepted/rejected B, the impossible raw-pass/boundary overlap construction,
  and both Case-C blocks.
- The compiled no-optimizer unit evaluates the production cloglog objective,
  obtains raw/candidate derivatives, and calls the production
  covariance-Newton candidate helper with an explicit SPD covariance.
- Independent numerical review returned PASS after correcting raw-convergence
  retention and all-attempt candidate provenance.

`G2K_CALIBRATION_HOLD` remains unchanged; G2n is not applied retrospectively
to its 150 attempts.  `G2C_SMOKE_ADMISSION_HOLD` remains unchanged.  No full
fit, profile, simulation, campaign, Totoro/FIR/DRAC job, detection extension,
public API/documentation/pkgdown change, or Issue #953 action occurred.

The next action is not automatic: request explicit approval for one fresh
local G2n pre-run under this exact implementation.  Article 1 remains
evidence-incomplete and Article 2 remains design-only.
