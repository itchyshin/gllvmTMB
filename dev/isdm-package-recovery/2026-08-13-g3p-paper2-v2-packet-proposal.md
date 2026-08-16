# G3P Paper 2 V2 packet/root proposal — no execution

**Status:** design proposal only. It creates no result root and authorises no
runner mode.

## Identity

- packet ID: `G3P_P2_SMOKE_V2`;
- fresh root: `dev/isdm-package-recovery/results/G3P_P2_S6_C360_R3_V2/`;
- committed generic runner: `run-g3-paper2-smoke.R` with explicit `--packet`,
  `--source-gate`, and `--root-id` values;
- source baseline: `fdcb05cd`; the eventual V2 packet must name this exact
  commit (or a later independently reviewed replacement commit) explicitly.

The V2 invocation must bind its own packet MD5 (the supplied packet path is
diagnostic), source-gate label,
all-attempt schema, `--root-id G3P_P2_S6_C360_R3_V2`, root name, and explicit
time-estimate/time-limit arguments. It must not accept V1's packet or root.
The runner implementation and focused no-fit tests are built
and independently reviewed before a V2 packet binds their exact commit SHA.
The V1 historical root remains terminal `INVALID_PROVENANCE` and immutable.

## Frozen model contract

Retain the V1 Paper 2 fixture (`seed = 86302L`, `S = 6`, `C = 360`, `r = 3`),
GBIF Poisson plus three-visit PA cloglog likelihood, rank-one `Lambda`, free
diagonal `Psi`, `theta_diag_B = log(psi)`, recovery map, GBIF-only bias,
DGP, maps, transforms, bounds, controls, selected-start rule, and G3
thresholds. No estimator component changes.

## Required gates

1. Build and commit the parameterised V2 runner path; then record that exact
   commit SHA in the V2 packet.
2. Gauss/Noether review of the V2 runner/packet binding, followed by Rose
   cross-artifact review and Fisher no-inference review.
3. Explicit Gate-B approval to create only the packet and ignored root.
4. A separate mode-specific approval for preflight, then another for exactly
   one smoke with a fresh 15–25 minute estimate and 25-minute hard stop.

## Negative space

This proposal does NOT authorise validation, preflight, smoke, retry, profile,
recovery, campaign, remote compute, model/DGP/map/threshold change, or public
claim.
