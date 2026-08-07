# Arcs — va-s0a-gaussian

Status legend: `PENDING` | `IN_PROGRESS` | `DONE` | `BLOCKED` | `SKIPPED`

| ID | Arc | Gate? | Status | Notes |
| --- | --- | --- | --- | --- |
| A0 | SCAFFOLD LOOP/ + protocol + launch wrapper | no | IN_PROGRESS | Commit LOOP + protocol docs; never push |
| A1 | Totoro preflight: root, checkout@022b4eab, Gate-E, runtime, smoke | OPEN (compute authorised for S0a) | PENDING | Reuse estimator rev; new campaign root |
| A2 | Plan + run fresh Gaussian q∈{2,5} (seeds 10001:10300, n=300) | compute authorised | PENDING | 1200 rows = 300×2q×{va,laplace} |
| A3 | Export/summarise + scientific absolute-first ledger | no | PENDING | SCIENTIFIC_* under default+alternate caps |
| A4 | After-task + check-log + plan Actuals; assert Arc-2 labels untouched | no | PENDING | |
| G0b | STOP — ask Shinichi open S0b? | **OPEN GATE** | PENDING | Do not start poisson/lognormal/gamma |

## Seed count (chosen)

**n_seeds = 300**, range **10001:10300** (disjoint from Arc-2 `1:500`).

Justification: Design 110 confirmation used 500 for coverage MCSE; S0a primary is
absolute β/Σ recovery where Arc-2 already showed large β margin and moderate Σ
margin. 300 is in the G0 200–500 band, keeps MCSE for rates ~0.027, and yields
1200 Totoro rows (~1/30 of the 36k confirmation) while remaining decisive for
abs caps 0.35 / 0.50.
