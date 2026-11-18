# Orchestrator spot-checks — independent verification of load-bearing Phase-A numbers

Date: 2026-08-15 · Run by the orchestrator (not by any producer agent), directly against
the primary sources, while A5 was in flight. Purpose: the three numbers the whole packet
stands on, re-derived from raw files with independent one-line queries.

Sources: `gate-map-108.tsv` (committed artefact dir, SHA-256 verified earlier this
session) and `outer-fit-rows.csv` (raw campaign root
`/private/tmp/mspl-coverage-production-8b23cfd2-eqLdNa`).

| # | Claim (source) | Independent query | Result |
|---|---|---|---|
| 1 | Exactly 6 genuine undercoverage rows among the 55 failures, using the per-method-correct coverage measure (A1 Q1) | awk over `gate-map-108.tsv`: `gate_pass=="FALSE"` and (wald→conditional, else unconditional) coverage < 0.92 | **CONFIRMED — 6 rows**: C007 probit bootstrap b2 0.879 · C009 cloglog bootstrap b3 0.906 · C011 cloglog bootstrap b1/b2/b3 0.855/0.358/0.010 · C012 cloglog bootstrap b3 0.913. All bootstrap-method rows. |
| 2 | C011 pocket coverages 0.855 / 0.358 / 0.010 with availability 1.0 (A1 Q1, plan headline) | awk over `gate-map-108.tsv`, bootstrap × cloglog × high_prevalence | **CONFIRMED** verbatim |
| 3 | b_fix_3 pins in 92.9% of C011 fits; modal value ≈ 1.5964 matching the analytic k=24 root 1.5964000447 to ~1.3e-6 (A1 Q5, A1b) | awk over `outer-fit-rows.csv` (col 5 case_id, col 19 b_fix_3, col 22 objective_role): window 1.5964 ± 1e-4 | **CONFIRMED — 929/1000 = 92.9%**, all rows role `penalised_outer_mspl_estimator_id_1`. Top modal 8-dp values 1.59639998/1.59640116/1.59640012 — per-dataset attractors scattering at ~1e-5, modal agreement with the analytic root at ~1e-6 as claimed. |

Note for A6/Melissa: a first pass with a ±1e-5 window on the derived `a1b_c011_full.csv`
gave 461/1000 — a verifier-side window artifact, not a discrepancy in A1b; resolved
against the primary as above. Lesson recorded so the packet's tolerance language stays
precise: "pinned" = within 1e-4 of an attractor; attractors are dataset-specific at 1e-5;
the MODAL attractor matches the analytic root at 1.3e-6.

Also cross-checked in passing: the 3 non-C011 undercoverage rows (0.879/0.906/0.913) are
exactly the "3 remaining undercovering cells after the fence removes C011" that A3's S3
rationale relies on. Consistent.
