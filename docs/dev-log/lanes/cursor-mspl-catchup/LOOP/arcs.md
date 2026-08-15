# MSPL catch-up ledger — as much as this lane can fit

Status: `DONE` | `IN PROGRESS` | `PENDING` | `GATED`

Shinichi 2026-08-15: `/goal` to catch up ML-Laplace, then auto-merge #963.
This GOAL is **DONE**. 1B / campaign / new-family admission remain STOP.

| ID | Status | Purpose | Gate |
|---|---|---|---|
| 1A | DONE | Internal provenance parity | commits landed via stacked #963; this lane did not merge #962 |
| P2 | DONE | Bernoulli cell registry; same admits/aborts | `5f306119` on `main`; registry 13 / api 241 |
| P3-prep | DONE | Gaussian Heywood design + E1–E7 oracles; planned rows | do **not** admit Gaussian |
| S5 | DONE | After-task + Melissa + stacked PR #963 | artifacts on `main` |
| merge-963 | DONE | Land Phase 2 + Heywood prep on `main` | merge commit `fb6f9dae` |
| 1B | GATED | User-visible `estimator="ml"` outside Laplace | new G0 |
| P3-admit | GATED | Live Gaussian MSPL route | uniqueness / #856 + C++ + Shinichi |
| P4–P8 | GATED | Counts, ordinal, structures, inference, default | programme later |
| merge-962 | GATED | Arc 1A as its own PR | GitHub auto-closed when #963 stacked; do not treat as a separate merge act |
| merge-961 | GATED | Programme docs PR | same auto-close; not an independent merge from this lane |
