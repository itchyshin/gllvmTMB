# Arcs — gllvmTMB-cran-path-a-0.6.1

Source: approved ultra-plan slices S0–S12. Status updated as arcs finish.

| ID | Arc | Status | Gate | Dep |
| --- | --- | --- | --- | --- |
| S0 | Vault: amend D-89 (+ D-66 clarifying note for 0.6.1 upload identity) | DONE | — | — |
| S1 | RECON — cleanup inventory from `origin/main` | DONE | — | parallel with S0 |
| S2 | Honesty / reader fences (D-112) | DONE | — | S1 |
| S3 | Version bump → **0.6.1** | DONE | — | S1 (landed with S2) |
| S4 | `cran-comments.md` draft skeleton for 0.6.1 | DONE | — | S3 |
| S5 | pkgdown prep | DONE | — | S2–S3 |
| S6 | Candidate freeze packet | OPEN GATE | 🛑 Shinichi freeze | S2–S5 |
| S7 | Exact-tag D-49 ceremony (M5-a..e) | pending | 🛑 after S6; tags gated | S6 |
| S8 | Submit-ready artefact (M5-f) | pending | — | S7 |
| S9 | MECHANICAL-VERIFY | pending | — | S8 |
| S10 | Rose claim-fence closeout | pending | — | S8–S9 |
| S11 | RECONCILE (Melissa) | pending | — | S9–S10 |
| S12 | After-task + check-log | pending | — | S11 |

**PAUSE at:** S6 (freeze) — **NOW**. Later M5 tags; **never** M5-g CRAN upload.

**Batches:** (B0) S0∥S1 DONE → (B1) S2∥S3 DONE → (B2) S4+S5 DONE → **STOP freeze** → (B3) S7 → (B4) S8 → (B5) S9∥S10 → (B6) S11+S12.
