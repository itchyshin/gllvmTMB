# MSPL catch-up ledger — as much as this lane can fit

Status: `DONE` | `IN PROGRESS` | `PENDING` | `GATED`

Shinichi 2026-08-15: `/goal` to catch up ML-Laplace, then auto-merge #963.
Fence: reversible work already landed. 1B / #962 / #961 / campaign /
new-family admission = STOP. Merge #963 is the authorized closeout.

| ID | Status | Purpose | Gate |
|---|---|---|---|
| 1A | DONE | Internal provenance parity | #962 open; do not merge from here |
| P2 | DONE | Bernoulli cell registry; same admits/aborts | `5f306119`; registry 13 / api 241 |
| P3-prep | DONE | Gaussian Heywood design + E1–E7 oracles; planned rows | do **not** admit Gaussian |
| S5 | DONE | After-task + Melissa + stacked PR #963 | artifacts on branch |
| merge-963 | IN PROGRESS | Land Phase 2 + Heywood prep on `main` | authorized; wait CI then merge |
| 1B | GATED | User-visible `estimator="ml"` outside Laplace | new G0 |
| P3-admit | GATED | Live Gaussian MSPL route | uniqueness / #856 + C++ + Shinichi |
| P4–P8 | GATED | Counts, ordinal, structures, inference, default | programme later |
| merge-962 | GATED | Arc 1A provenance → main | Shinichi; not this lane |
| merge-961 | GATED | Programme docs PR | Shinichi; not this lane |
