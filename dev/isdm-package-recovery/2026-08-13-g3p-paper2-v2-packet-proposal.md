# G3P Paper 2 V2 packet/root proposal — no execution

**Status:** design proposal only. It creates no result root and authorises no
runner mode.

## Identity

- packet ID: `G3P_P2_SMOKE_V2`;
- fresh root: `dev/isdm-package-recovery/results/G3P_P2_S6_C360_R3_V2/`;
- dedicated future runner: `run-g3-paper2-smoke-v2.R`;
- source baseline: committed `a4a12eab` or its explicitly reviewed successor.

The V2 runner must bind its own packet path/MD5, source-gate label, all-attempt
schema, root name, and time estimate. It must not accept V1's packet or root.
The V1 historical root remains terminal `INVALID_PROVENANCE` and immutable.

## Frozen model contract

Retain the V1 Paper 2 fixture (`seed = 86302L`, `S = 6`, `C = 360`, `r = 3`),
GBIF Poisson plus three-visit PA cloglog likelihood, rank-one `Lambda`, free
diagonal `Psi`, `theta_diag_B = log(psi)`, recovery map, GBIF-only bias,
DGP, maps, transforms, bounds, controls, selected-start rule, and G3
thresholds. No estimator component changes.

## Required gates

1. Gauss/Noether review of the dedicated V2 runner/packet binding.
2. Rose cross-artifact review and Fisher no-inference review.
3. Explicit Gate-B approval to create only the packet and ignored root.
4. A separate mode-specific approval for preflight, then another for exactly
   one smoke with a fresh 15–25 minute estimate and 25-minute hard stop.

## Negative space

This proposal does NOT authorise validation, preflight, smoke, retry, profile,
recovery, campaign, remote compute, model/DGP/map/threshold change, or public
claim.
