# Arc 1A ledger — internal provenance parity

Status values: `DONE`, `IN PROGRESS`, `PENDING`, `GATED`.

G0 APPROVED 2026-08-14. Do not re-plan. Do not implement Arc 1B or Arcs 2–8.

| ID | Status | Purpose | Exit evidence | Human gate |
|---|---|---|---|---|
| S0 | DONE | Recon / baseline freeze of `estimator_id` 0/1/2 sites + existing MSPL tests | Site inventory in checkpoint / after-task | none |
| S1 | DONE | Compatibility table + resolver in NEW `R/estimator-provenance.R` | File exists | none |
| S2 | DONE | Wire adapter in `R/fit-multi.R` / VA path; attach `fit$estimator_provenance` | Provenance attached; `estimator_id` derived 0/1/2 | C++ tape change = STOP |
| S3 | DONE | Parity tests | Tests can FAIL on drift / missing provenance | accepted-call change = STOP |
| S4 | DONE | Targeted test run + no-change receipt | LOG 75 + 223 PASS; no drift | none (fail-closed) |
| S5 | DONE | Gauss/Noether/Rose written review | PASS in after-task | none |
| S6 | DONE | After-task + check-log + stacked PR | https://github.com/itchyshin/gllvmTMB/pull/962 — do NOT merge | merge / NEWS = STOP |
| V | DONE | Mechanical verify | no C++ / NEWS / register / foreign-lane paths | none |
| R | DONE | Melissa plan-actual | `docs/dev-log/plan-actual/2026-08-14-mspl-arc-1a.md` | none |

## Adapter contract (locked)

```text
R resolver
  → criterion_id      = la_ml | la_mspl | reml | va_elbo   (descriptive)
  → numeric_kernel_id = legacy_ml | audited_stable_mspl | va
  → penalty_eval_id   = off | on | provenance_off
  → integration       = laplace | va | aghq   (resolved, not wished)
  → estimator_id      = 0 | 1 | 2             (EXISTING TMB integer; derived)
  → public_estimator  = ML | MSPL | REML      (current labels; may be coarse)

TMB tape unchanged: DATA_INTEGER(estimator_id) only.
estimator_id = 2 remains the penalty-off stable kernel at the MSPL point.
```

## Current encoding this adapter must preserve

| Call | Today | 1A must still do |
|---|---|---|
| implicit `gllvmTMB(...)` | `estimator_id = 0`, `fit$estimator = "ML"` | same numbers, same acceptance; provenance records Laplace + LA-ML + penalty off |
| explicit `estimator = "ml"` + Laplace | identical to implicit (existing test) | same |
| `estimator = "ml"` + `integration = "va"` | **accepted** (falls through; no typed error) | **still accepted**; provenance records `integration=va` and that public label `ML` is coarse |
| `estimator = "mspl"` + Laplace binary | `estimator_id = 1`; class `gllvmTMB_mspl`; second tape `estimator_id = 2` | same objectives, gradients, reports, warnings, errors |
| `estimator = "mspl"` + VA / AGHQ / REML / julia / ridge | abort (existing classes) | same abort, same class |
| explicit `estimator` + `REML = TRUE` | `gllvmTMB_estimator_reml_conflict` | same |
