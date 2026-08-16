# MSPL catch-up ledger — as much as this lane can fit

Status: `DONE` | `IN PROGRESS` | `PENDING` | `GATED`

Shinichi 2026-08-15: catch-up GOAL closed via #963; KEEP GOING into
Gaussian LA-MSPL implement (point estimates). SE/intervals PROTECTED.

| ID | Status | Purpose | Gate |
|---|---|---|---|
| 1A | DONE | Internal provenance parity | commits landed via stacked #963 |
| P2 | DONE | Bernoulli cell registry; same admits/aborts | `5f306119` on `main` |
| P3-prep | DONE | Gaussian Heywood design + E1–E7 oracles | uniqueness pick C |
| S5 | DONE | After-task + Melissa + stacked PR #963 | artifacts on `main` |
| merge-963 | DONE | Land Phase 2 + Heywood prep on `main` | `fb6f9dae` |
| merge-964 | DONE | LOOP closeout docs | `d61929f8` |
| smoke-965 | DONE | Local Bernoulli pair smoke note | `66b2810c` |
| U | DONE / PR | Ψ uniqueness map (pick C) + E5b | #966 |
| G-impl | IN PROGRESS | Gaussian Hirose tape + fence + se=FALSE smoke | this branch; flip admitted |
| B-complete | PENDING | Cheap Bernoulli registry harden only | no SE reopen |
| compare-local | PENDING | Extra local binary point-estimate smoke | ≤30 min; admitted cells only |
| 1B | GATED | User-visible `estimator="ml"` outside Laplace | new G0 |
| P3-admit | DONE (point) | Ordinary gaussian q1/q2 registry admitted | `oracle_local`; not covered |
| SE/intervals | GATED / PROTECTED | Binary MSPL SE/CI | `codex/lane-b-mspl-interval-feasibility` |
| P4–P8 | GATED | Counts, ordinal, structures, inference, default | programme later |
| merge-962 | GATED | Arc 1A as its own PR | auto-closed with #963 |
| merge-961 | GATED | Programme docs PR | auto-closed with #963 |
