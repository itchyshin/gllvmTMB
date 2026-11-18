# G3 marginal-curvature terminal adjudication

Date: 2026-08-14  
Branch: `codex/isdm-g3-marginal-curvature`  
Estimator commit used by final Paper 2 attempt: `bb5596f3`  
Estimator commit used by final Paper 1 attempt: `0e128ad4`

## Verdict

G3 is **HOLD for both frozen paper models**. Neither model is admitted to a
recovery campaign. The next lane is the separately identified exact-gradient
BFGS continuation; historical G2/G3 evidence must not be relabelled.

## Paper 2

Final root: `results/G3_P2_S6_C360_R3_V5`  
Terminal status: `G3_CURVATURE_INVALID`

- provenance and terminal ledger: valid;
- fit elapsed: 16.897 s; total elapsed: 28.605 s;
- convergence: zero; maximum raw gradient: 0.001626433;
- raw `sdreport_cov_fixed`: finite, PD, condition 757.8431, eigenvalue range
  0.001633169 to 1.237686;
- independent half-step gradient Jacobian relative antisymmetry:
  `7.250055e-10`, above the frozen `1e-10` gate;
- G3 alpha trials: zero.

V3 is telemetry-invalid because no terminal ledger was written. V4 is a
sealed infrastructure HOLD (`sdreport_positional_identity_failure`). Both are
consumed and are not numerical evidence.

## Paper 1

Final root: `results/G3_P1_S3_C360_R3_V3`  
Terminal status: `G3_RAW_INELIGIBLE`

- provenance and terminal ledger: valid;
- fit elapsed: 14.520 s; total elapsed: 14.804 s;
- convergence: zero; maximum raw gradient: 0.002431251466981631;
- raw marginal `pdHess`: false;
- G3 curvature calls and alpha trials: zero.

V2 is terminal-writer-invalid and consumed; its printed status is not used as
evidence.

## Evidence boundary

The implementation capability is established: a random-effects TMB objective
can use candidate-specific `sdreport$cov.fixed`, production directions are
`V %*% g`, and the exact-gradient finite-difference validation is operational.
The frozen paper models did not pass its gates. There is no numerical
admission, Psi recovery, source-separation recovery, map permission, empirical
analysis permission, recovery-campaign permission, or public package claim.

## Successor trigger

Both approved triggers fired: Paper 2 failed curvature validation despite a
valid covariance, and Paper 1 was cleanly raw-ineligible. Open a distinct
`BFGS_EXACT_GRADIENT_CONTINUATION` estimator lane from the retained best
`nlminb` solution. It must use the unchanged Laplace objective and exact
gradient, a separate packet/ledger/status taxonomy, pure and compiled tests,
one local smoke per paper, and independent review before recovery.
