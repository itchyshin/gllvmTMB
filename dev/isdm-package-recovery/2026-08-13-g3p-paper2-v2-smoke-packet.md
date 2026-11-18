# G3P Paper 2 V2 smoke packet — materialised, execution not authorised

**Packet ID:** `G3P_P2_SMOKE_V2`  
**Gate B:** approved only to materialise this packet and the fresh ignored root.

## Frozen design

This packet retains the Paper 2 fixture `paper2-g3-smoke-86302` with
`seed = 86302L`, `S = 6`, `C = 360`, `r = 3`, `b = 1`, and `d = 1`. It retains
the GBIF Poisson plus three-visit PA cloglog likelihood, rank-one `Lambda`,
free diagonal `Psi`, `theta_diag_B = log(psi)`, recovery map, GBIF-only bias,
DGP, maps, transforms, bounds, controls, selected-start rule, and G3
thresholds. No estimator component changes.

The historical V1 root is immutable `INVALID_PROVENANCE`. This is a distinct
V2 packet/root, not a repair, rerun, relabelling, or interpretation of V1.

## Receipt contract

The reviewed generic runner implementation baseline is `fdcb05cd`. A later
preflight must run from a clean committed package tree and retain the exact
current commit, runner MD5, fixture MD5, this packet's MD5, source/DLL MD5s,
and runtime identity. Packet content MD5 is binding; the supplied packet path
is diagnostic.

The V2 invocation must explicitly supply all of:

- `--packet=dev/isdm-package-recovery/2026-08-13-g3p-paper2-v2-smoke-packet.md`
- `--source-gate=G3P_P2_SMOKE_V2`
- `--root-id=G3P_P2_S6_C360_R3_V2`
- a V2-only `--attempt-id`
- `--time-estimate=15-25 minutes` and `--time-limit-s=1500`

Preflight records, and smoke compares before package loading, the schema,
source gate, root ID, attempt ID, time estimate, and hard stop. A mismatch is
terminal `INVALID_PROVENANCE`.

## Fresh root and execution boundary

The only created result location is the empty ignored root:
`dev/isdm-package-recovery/results/G3P_P2_S6_C360_R3_V2/`.

Neither this materialisation nor its root authorises `validate`, preflight,
smoke, retry, fit, profile, recovery, simulation, remote compute, or public
claims. Preflight requires a separate explicit approval. Exactly one local
smoke requires another separate explicit approval, a fresh 15–25 minute
estimate, and a 25-minute hard stop.
