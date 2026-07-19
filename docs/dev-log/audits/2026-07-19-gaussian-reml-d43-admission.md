# D-43 admission — Gaussian REML profile screen (2026-07-19)

**Decision: WITHHELD.** The 0.6 engine/oracle contract may remain documented as
Gaussian-only pilot support, but no public small-sample coverage or
ML-versus-REML improvement claim is admitted. This is not a release-ready
decision.

| Independent lens | Verdict | Load-bearing evidence |
| --- | --- | --- |
| Fisher — coverage/statistical evidence | NOT DONE | Both 150-unit fixtures fail the frozen 0.01 gradient health rule (six of 400 target rows). The 100-replicate lower confidence bounds are 0.887--0.915, far below 0.94; paired coverage changes direction across fixtures. |
| Grace — raw shards/reproducibility | NOT DONE | Independently recomputed 100 complete shards (1,200 raw / 400 profile rows): 3 `WITHHELD_optimizer`, 1 `NOT_READY_lcb`. The historic installed-package SHA is not bound to the declared source SHA, so the data cannot support a provenance-certified rerun. |
| Noether — claim-to-method alignment | NOT DONE for certificate; PASS for bounded engine contract | Patterson--Thompson oracle and total-variance profile scale align with the implementation, but point recovery and finite intervals cannot substitute for the stopped coverage certificate. |

The D-43 rule therefore withholds promotion: two or more fresh NOT-DONE verdicts
are sufficient even without considering the release blockers.

## Plan versus actual

| Planned gate | Actual receipt | Consequence |
| --- | --- | --- |
| 25 paired point pilot | 150/150 paired targets optimizer-healthy | promoted |
| 100 point screen plus stress | 900/900 paired targets optimizer-healthy | promoted |
| 500 point recovery, two anchors | 3,000/3,000 paired targets optimizer-healthy; REML point ratios nearer truth in this fixed 50-unit DGP | point-only evidence, not promotion |
| 25 profile pilot at 150 units | 100/100 predeclared profile rows available | route feasible |
| 100 profile screen at 150 units | all profiles available; six gradients 0.0101--0.0150 exceed frozen 0.01 threshold | STOP |
| 500/15,000 profile certificate | not run | correctly withheld; do not backfill after a failed screen |

## Melissa reconciliation

The approved funnel promised a 15,000-replicate certificate only after healthy
pilot, screen, and recovery gates. The implementation delivered the contract,
oracle, paired point ladder, profile-target route, raw audit, and the three
D-43 lenses. It deliberately did **not** substitute point recovery, finite
profiles, or a 100-replicate screen for the blocked 15,000-replicate result.
The divergence is therefore evidence-led termination at the predeclared screen
gate, not a scope cut or an incomplete campaign presented as complete.

## Required next state

Do not alter NEWS, README status, the validation register to advertise a
small-sample benefit, or release language. A later retry needs maintainer
approval of a new numerical-health contract, a clean installed-package SHA
receipt, disjoint seeds, and a fresh pilot; it cannot reuse these screen rows
as the certificate. The research-only non-Gaussian REML/AGHQ arc remains
deferred until this negative 0.6 outcome is handed off.
