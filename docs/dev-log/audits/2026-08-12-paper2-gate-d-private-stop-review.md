# Paper 2 Gate D — private STOP/HOLD evidence review

**Decision:** `PAPER2_PRIVATE_STOP_HOLD`.
**Maintainer direction:** proceed with the recommended private STOP/HOLD route.

| Required predicate | Evidence | Gate result |
| --- | --- | --- |
| Frozen source/DGP/map/transform | S=6 root bound to seed 86122, exact runner/fixture hashes, GBIF-only source gate, and verified outer closure | preserved |
| Numerical admission | finite objective, code 0, PD Hessian, but raw max gradient 0.002726537 in non-boundary `b_fix` | Case C / `NO_CANDIDATE`; HOLD |
| Profile information | all six profiles finite/converged; lower endpoint deltas sp2=0.57087, sp5=0.42295, sp6=0.16194 | weak endpoints; HOLD remains |
| Known-truth recovery | beta, gamma, map, shared covariance pass; diagonal-Psi error 0.2156398 > 0.20 | recovery HOLD |
| All-attempt/provenance | one started replicate, three retained starts, all artifacts and both closures hash-verified | valid denominator `1`; no replacement |
| Reader progression | needs private numerical/recovery evidence that survives frozen gates | not earned |

The numerical and Psi failures may co-occur in this one replicate, but this
does not establish causation. Nor do the four passing metrics override either
failed predicate. S=20/S=60 would estimate descriptive frequencies only and
cannot reclassify Case C, establish a repair, or support a reader packet.

## Terminal scope

This closes the present Paper 2 evidence-to-reader programme with no staged
reader packet, public documentation, package capability claim, scale claim, or
new compute. The protected `G2N_LOCAL_PRERUN_HOLD`,
`G2K_CALIBRATION_HOLD`, and `G2C_SMOKE_ADMISSION_HOLD` remain historical and
unchanged. A later project may propose a genuinely new estimand/architecture or
an explicitly diagnostic campaign, but it is a fresh, separately approved
lane—not continuation authority for this one.
