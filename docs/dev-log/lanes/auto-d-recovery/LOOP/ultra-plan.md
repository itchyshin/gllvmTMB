# ultra-plan: auto-d-recovery (frozen 2026-09-30)

G0: Shinichi waived a separate plan-mode round ("just get the set goal done", 2026-09-30). GOAL.md is the contract; this file adds the arc order. The simulation design is `../design.md` (ADEMP), and it binds the DGP, conditions, replicates and verdict rule.

Model routing: the conductor (Opus) keeps design, verification and verdict. Script writing, log reading and table assembly go to Sonnet 5.5 subagents (Shinichi, 2026-09-30: "use Sonnet 5.5 as much as possible").

## Arcs
1. Kit move (done) and ADEMP design (`../design.md`).
2. Scripts under `../sim/`: `0_grid.R` (design grid + seeds), `sim_dgp.R`, `1_run.R` (one dataset per task, per-dataset RDS, resumable, `sessionInfo()`), `2_summarise.R` (recovery table + MCSE). Local smoke on 2 tiny datasets per family.
3. Pre-run test on Totoro: 3 datasets per cell for the costliest cells, plus 5 datasets checking `select_lv()$selected_d == gllvmTMB(d = "auto")$select_lv$selected_d`. Measure seconds per dataset, project the full run. State the estimate.
4. GATE if the projection is over 3 hours: present plan + pre-run results, wait. Otherwise run the campaign on Totoro (≤150 workers, OPENBLAS_NUM_THREADS=1).
5. Summarise: recovery table (`../results/recovery-table.csv` + `.md`), verdict per family under the pre-stated rule. Any bug: minimal reproducer in `../bugs/`.
6. Handover + after-task; commit on this branch. No push, no merge (gates).

## Fences
Test only: no edits to R/, man/, NAMESPACE, NEWS.md, inst/COPYRIGHTS, docs/dev-log/check-log.md. No push, no PR, no public claim.
