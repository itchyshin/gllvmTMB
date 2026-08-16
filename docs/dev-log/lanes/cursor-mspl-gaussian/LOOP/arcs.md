# arcs — cursor-mspl-gaussian (verify/close #967)

G0 LOCKED 2026-08-15: Q1 merge when CI green + Rose PASS · Q2 keep admitted/oracle_local · Q3 this LOOP kit.

| ID | Arc | Status | Gate? | Notes |
|---|---|---|---|---|
| S0 | Recon #967 vs origin/main | DONE | no | MSPL-only; 0 behind at merge |
| S1 | Pin pick C in Gaussian LOOP | DONE | no | catch-up GOAL untouched |
| S2 | Verify Hirose + R fence | DONE | Sol only if FAIL | PASS — no rebuild |
| S3 | Healthy + near-Heywood se=FALSE smoke | DONE | no | local failed=0 |
| S4 | Rose claim boundary | DONE | review | PASS — NEWS untouched; oracle_local |
| S4b | Fix stale heywood oracle fence | DONE | no | `aaac7701`; CI green |
| S5 | Melissa + merge #967 | DONE | merge | MERGED `834c4cb6` |
| V | Post-merge drift check | DONE | no | fix on main |
| R | Melissa reconcile | DONE | no | plan-actual SHA filled |

HARD STOP (never schedule here): campaign · SE/intervals · Poisson · NEWS covered · free-ε · #856 · binary Codex lane · repo-root LOOP/
