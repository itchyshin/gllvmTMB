# G2f PA-replication local-smoke reconciliation

| Approved requirement | Evidence | Status |
| --- | --- | --- |
| Work from frozen G2f state | root receipt records fixture/protocol/decision hashes, seed 86101, six visits, and smoke SHA `128d2d60` | met |
| Exactly one fresh local smoke | `results/g2f-smoke-20260811-001`; one optimizer-entered stage sequence | met |
| Three retained initializations | decision ledger: `three_restarts=TRUE`, `one_selected_restart=TRUE` | met |
| Exact fit and six profiles retained | `fit.rds`; six five-offset profile tables; all profile validity flags TRUE | met |
| Frozen decision classification | `NONRESPONSIVE`: profile rule FALSE; GBIF-bias rule FALSE | met |
| Failure placeholders and manifest | wrapper contains tested no-fit closure path; this complete root has receipt/ledger/manifest checksums | met |
| No retry/campaign/public widening | no second smoke root, Totoro/DRAC job, or public/package change | met |
| Numerical smoke admission | `G2F_SMOKE_HOLD`; maximum gradient 0.001056337 exceeds 0.001 | held |

The scientific classification is a one-fixture diagnostic only. It does not
justify a recovery claim or any campaign; the next action requires a separate
maintainer decision.
