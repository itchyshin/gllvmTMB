# G3P Paper 2 provenance-amendment packet — no-fit Gate B

**Packet ID:** `G3P_P2_PROVENANCE_V1`  
**Status:** immutable no-fit proposal. It does not authorise a replacement
smoke, profile, recovery run, or any model execution.

## Purpose

The retained `G3_P2_S6_C360_R3_V1` root is terminal
`INVALID_PROVENANCE` because `devtools::load_all()` placed byte-identical DLLs
in different temporary directories. This amendment distinguishes stable
content/runtime identity from that diagnostic path. It does not reclassify or
alter the retained root.

## Binding identity

Before a future smoke, receipt and observed identity must agree exactly on:

- commit, runner, fixture, and packet MD5s;
- `fit-multi.R`, `isdm-developer-fit.R`, TMB source, and loaded DLL MD5s;
- CPU architecture, R version, TMB version, and gllvmTMB package version.

The loaded DLL path is retained in the field-by-field receipt comparison but is
non-binding. A path-only difference yields `MATCH` with
`path_only_difference`; any binding mismatch or missing field yields terminal
`INVALID_PROVENANCE` before optimizer entry.

## Preserved model contract

The future packet, if separately approved, must retain the exact Paper 2
GBIF-Poisson plus three-visit PA-cloglog likelihood, rank-one `Lambda`, free
diagonal `Psi`, `theta_diag_B = log(psi)`, `exp(2 * theta_diag_B)` recovery
map, GBIF-only bias covariate, DGP, maps, bounds, controls, selected-start rule,
and G3 thresholds. The amendment changes no estimator component.

## Required no-fit evidence

The contract tests must retain: equal stable identity with different temporary
paths; changed DLL/source hash; changed ABI/runtime metadata; missing required
fields; and the full expected-versus-observed field table. The existing P1/P2
result roots remain untouched and historical protected HOLDs remain unchanged.

## Gate B

Gate B may approve only creation of a later, versioned, fresh smoke packet and
root. A new smoke still requires explicit approval, a new time estimate, clean
committed source, independent review, and all-attempt retention. This packet
supports no numerical-admission, recovery, Psi, spatial, empirical, scale,
reader, or public claim.
