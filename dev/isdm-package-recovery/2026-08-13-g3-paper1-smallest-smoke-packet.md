# G3 Paper 1 smallest-smoke packet — execution not authorised

**Packet ID:** `G3_P1_S3_C360_R3_V1`
**Status:** immutable proposal for private Gate B; this document does not authorise a fit.

## Frozen design

| field | value |
| --- | --- |
| family | Paper 1 two-field spatial iSDM |
| new fixture | `paper1-g3-smoke-86301` |
| seed | `86301L` (fresh; not historical seed `86202L`) |
| dimensions | `S=3`, `C=360`, `r=3`, `b=1`, `d=1` |
| candidate | full outer-vector Newton trials, `alpha=2^-(0:8)` |
| raw eligibility | code 0, finite objective, one maximum, no boundary flags, PD aligned Hessian, condition <= `1e8`, and `1e-3 < max(abs(g)) < 1e-2` |
| acceptance | same objective non-increase and `max(abs(g_candidate)) <= 1e-3` |
| retained historical comparator | `paper1-spatial-b2-86202`, Case D, `PRIVATE_NUMERICAL_ADMISSION_HOLD` |

The likelihood, DGP, two SPDE-field map, GBIF-only bias exclusion from PA rows,
transforms, bounds, controls, start panel, selected-start rule, and thresholds are
the frozen Paper 1 contract.  G3 is added only after the ordinary selected state
has been recorded; it may not replace, retry, or relabel that state.

## Immutable launch receipt

Before any fit, the runner must create a new ignored directory named exactly
`dev/isdm-package-recovery/results/G3_P1_S3_C360_R3_V1/` and stop unless it is
empty. It must write, hash, and retain: the generated fixture; its seed and DGP
receipt; package source tree and loaded DLL hashes; commit SHA; `sessionInfo()`;
formula/map/data/random/bounds/controls/starts/selection signatures; all raw
starts; and the compiled G3-unit test receipt.  A dirty tracked source tree or
signature mismatch is a terminal `INVALID_PROVENANCE` attempt, not a retry.

The all-attempt ledger has one ordinary selected-state record, then exactly nine
ordered G3 trial rows. Each row retains alpha, full coordinate vector, objective,
gradient, objective/gradient evaluation status, rejection reason, Hessian/condition
receipt, map/signature identity, wall time, and peak RSS. No profile is requested
or permitted by this packet.

## Runtime decision

The re-measured conservative estimate is **10–15 minutes** wall clock on the
local development machine: retained ordinary-fit evidence was 12.324 seconds, and
the allowance covers construction, selected-start bookkeeping, one Hessian, nine
same-objective `fn+gr` evaluations, immutable receipt writing, and a safety margin.
The run must stop and report if it reaches 15 minutes. Under the standing rule it
is below the 30-minute line, but it still requires this separate Gate-B approval.

This packet establishes only a numerical-admission experiment for this one fresh
synthetic fixture. It supports no recovery, ecological–bias separation, spatial,
empirical, occupancy/detection, count-survey, scale, or reader/public claim.
