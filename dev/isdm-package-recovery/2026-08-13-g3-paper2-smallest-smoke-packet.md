# G3 Paper 2 smallest-smoke packet — execution not authorised

**Packet ID:** `G3_P2_S6_C360_R3_V1`
**Status:** immutable proposal for private Gate B; this document does not authorise a fit.

## Frozen design

| field | value |
| --- | --- |
| family | Paper 2 fixed two-source iJSDM |
| new fixture | `paper2-g3-smoke-86302` |
| seed | `86302L` (fresh; not historical seed `86122L`) |
| dimensions | `S=6`, `C=360`, `r=3`, `b=1`, `d=1` |
| candidate | full outer-vector Newton trials, `alpha=2^-(0:8)` |
| raw eligibility | code 0, finite objective, one maximum, no boundary flags, PD aligned Hessian, condition <= `1e8`, and `1e-3 < max(abs(g)) < 1e-2` |
| acceptance | same objective non-increase and `max(abs(g_candidate)) <= 1e-3` |
| retained historical comparator | `paper2-s6-86122`, Case C, `PAPER2_PRIVATE_STOP_HOLD` |

The GBIF Poisson plus three repeated PA cloglog likelihood, rank-one `Lambda`,
free diagonal `Psi`, `theta_diag_B=log(psi)`, `exp(2*theta_diag_B)` recovery map,
GBIF-only bias covariate, DGP, maps, transforms, bounds, controls, start panel,
selected-start rule, and thresholds are frozen. G3 is not a Psi repair and cannot
change the historical 0.2156398 diagonal-Psi variance error or any historical label.

## Immutable launch receipt

Before any fit, the runner must create a new ignored directory named exactly
`dev/isdm-package-recovery/results/G3_P2_S6_C360_R3_V1/` and stop unless it is
empty. It must retain hashes for the generated fixture, seed/DGP receipt, package
source and loaded DLL, commit SHA, `sessionInfo()`, and all objective/gradient/
parameter-order/map/data/random/bounds/scale/controls/starts/selection/source-gate
signatures. A dirty tracked source tree or a signature mismatch records one terminal
`INVALID_PROVENANCE` attempt; it cannot be repaired by a new start.

The all-attempt ledger retains all raw starts and the ordinary selected state, then
all nine G3 alpha trials in order. For every trial it retains coordinate vector,
objective, gradient, Hessian/condition state, objective/gradient status, selection,
maps, warnings/errors, wall time, and peak RSS. No profile, recovery metric, or
replicate is requested or permitted by this packet.

## Runtime decision

The re-measured conservative estimate is **15–25 minutes** wall clock on the
local development machine. The retained ordinary-fit receipt was 448.155 seconds;
the estimate permits one selected-state Hessian, up to nine same-objective `fn+gr`
evaluations, manifest/all-attempt writing, and a substantial safety margin. Stop
and report at 25 minutes. This is below the 30-minute line but still needs separate
Gate-B approval before execution.

This is one fresh numerical-admission experiment, not a recovery run. It supports
no Psi-recovery, spatial, count-survey, empirical, absolute-abundance, generic
zero-inflation, arbitrary-source, scale, or reader/public capability claim.
