# Ultra-plan — Poisson MSPL W_* REPLACE (G0 APPROVED; Shinichi preapprove-all)

See `docs/dev-log/research/2026-08-17-mspl-overnight-REPLACE-arc.md`.

A1 exact: `src/gllvmTMB.cpp` family_id==2 `return eta;` → `return gll_mspl_log_weight(eta, 0);`
Ship: push PR + merge when CI green (preapproved). Hard OUT unchanged.
