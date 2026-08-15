# arcs — cursor-mspl-gaussian (verify/close #967)

G0 LOCKED 2026-08-15: Q1 merge when CI green + Rose PASS · Q2 keep admitted/oracle_local · Q3 this LOOP kit.

| ID | Arc | Status | Gate? | Notes |
|---|---|---|---|---|
| S0 | Recon #967 vs origin/main | DONE | no | 3 ahead / 0 behind @ 813da14a; MSPL-only diff |
| S1 | Pin pick C in Gaussian LOOP | DONE | no | GOAL + arcs + ultra-plan; catch-up GOAL untouched |
| S2 | Verify Hirose + R fence | DONE | Sol/Opus only if FAIL | PASS — no rebuild |
| S3 | Healthy + near-Heywood se=FALSE smoke | DONE | no | `S3_SUMMARY failed=0` (registry + gaussian smoke) |
| S4 | Rose claim boundary | DONE | yes (review) | PASS — NEWS untouched; no SE bleed; oracle_local honest |
| S5 | Melissa + merge #967 | IN PROGRESS | **MERGE GATE** | plan-actual drafted; merge when CI green; do not double-merge |
| V | Post-merge drift check | PENDING | no | 0 behind main after merge |
| R | Melissa reconcile | PENDING | no | fill merge SHA in plan-actual |

HARD STOP (never schedule): campaign · SE/intervals · Poisson · NEWS covered · free-ε · #856 · binary Codex lane · repo-root LOOP/
