# Arcs — va-s1-binomials

Status legend: `PENDING` | `IN_PROGRESS` | `DONE` | `BLOCKED` | `SKIPPED`

| ID | Arc | Gate? | Status | Notes |
| --- | --- | --- | --- | --- |
| C0 | SCAFFOLD LOOP/ + protocol + launch wrapper | no | **DONE** | 2026-08-07 |
| C0smoke | Local public-route binomial_logit VA smoke | no | **DONE** | n=120 q=2 seed 94001 |
| C1 | Totoro preflight + smoke | compute | **PENDING** | needs Shinichi go |
| C2 | Totoro full S1 plan (3 cells × q∈{2,5}) | compute | **PENDING** | after C1 |
| C3 | Export + absolute-first scientific ledger | no | **PENDING** | |
| C4 | After-task + check-log + plan Actuals | no | **PENDING** | |
| G1 | STOP — ask Shinichi open S2? | **OPEN GATE** | **WAITING** | Do not start S2 |

## Seed count (proposed; lock at Totoro go)

**n_seeds = 300**, range **10601:10900** (disjoint from Arc-2 / S0a / S0b).

Cells: `binomial_logit`, `binomial_probit`, `binomial_cloglog`.  
Geometry: n=120, p=8, q∈{2,5}, H=7 (GH), estimators `va,laplace`.  
Planned rows (VA+LA only): 3 × 300 × 2 × 2 = **3600**.
