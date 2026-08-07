# Arcs — va-s0a-gaussian

Status legend: `PENDING` | `IN_PROGRESS` | `DONE` | `BLOCKED` | `SKIPPED`

| ID | Arc | Gate? | Status | Notes |
| --- | --- | --- | --- | --- |
| A0 | SCAFFOLD LOOP/ + protocol + launch wrapper | no | **DONE** | Commit `5c381f13` |
| A1 | Totoro preflight: Gate-E, runtime, smoke | compute authorised | **DONE** | smoke seed 10001 healthy |
| A2 | Plan + run fresh Gaussian q∈{2,5} | compute authorised | **DONE** | 1200/1200 COMPLETE |
| A3 | Export + scientific absolute-first ledger | no | **DONE** | SCIENTIFIC_PASS ×2 |
| A4 | After-task + check-log + plan Actuals | no | **DONE** | |
| G0b | STOP — ask Shinichi open S0b? | **OPEN GATE** | **WAITING** | Do not start S0b |

## Seed count (chosen)

**n_seeds = 300**, range **10001:10300** (disjoint from Arc-2 `1:500`).

Justification: Design 110 confirmation used 500 for coverage MCSE; S0a primary is
absolute β/Σ recovery where Arc-2 already showed large β margin and moderate Σ
margin. 300 is in the G0 200–500 band, keeps MCSE for rates ~0.027, and yields
1200 Totoro rows (~1/30 of the 36k confirmation) while remaining decisive for
abs caps 0.35 / 0.50.
