# A0 — Design-66 scaling-gate punch list (interval-coverage headline)

**Date:** 2026-07-13 · **Slice:** A0 (Fisher + Efron, Opus) · **Owner:** solo Claude
**Goal:** turn Design 66's 2026-06-23 scaling gate into concrete repair steps that unblock the
`n_sim=2000` Totoro coverage grid, under the maintainer's locked decisions (ordinal excluded from
the confirmatory core; full grid; solo Claude). Amendment recorded in
`docs/design/66-capstone-power-study.md` (2026-07-13).

## The confirmatory core for the 0.6 coverage certificate

**Core = `gaussian`, `nbinom2`, `binomial_probit`** (true-probit DGP `pnorm(eta)` + fit
`binomial(link="probit")`). Primary estimand = **`Sigma_unit_diag`** (rotation-invariant diagonal
of the between-unit covariance) via **parametric bootstrap**; `psi` stays diagnostic-only (profile).
Excluded from the core: `ordinal_probit` (Repair #2 by exclusion), `mixed` (CI-10, uncalibrated).

## The four repairs — status and action

Status is **code-verified** against the harness on `main` (2026-07-13).

### Repair #4 — MCSE + fit-health denominators on the decision surface — WIRING GAP (action)
- **Implemented** in the report reducer: `dev/m3-pilot-report.R` — `pilot_collect_cell()`,
  `pilot_binomial_mcse(p,n)=sqrt(p(1-p)/n)`, and explicit denominators (`n_converged_fits`,
  `n_pd_hessian`, `n_sdreport_ok`, `coverage_eligible_n` via `pilot_coverage_denominator()`).
- **Gap:** the live decision surface `run_next_pilot_batch → m3_summarise → pilot_status`
  (`dev/m3-pilot-launch.R:1358, 1422`) stores only bare `coverage_primary` — **no MCSE, no
  denominators**. `m3_summarise` (`dev/m3-grid.R:1824`) reports no MCSE column.
- **ACTION (A1a):** route the campaign's PASS/FAIL decision through `pilot_collect()` (the report
  reducer), or add its MCSE + denominator columns into the index that `pilot_status()` reads. The
  coverage certificate MUST carry MCSE + fit-health denominators — a bare point coverage is not a
  calibration claim (Efron).

### Repair #2 — ordinal-probit primary rows — RESOLVED BY EXCLUSION (action)
- **Cause:** `m3_bootstrap_supported()` (`dev/m3-grid.R:168-172`) returns `ok` only when every
  `family_id ∈ 0:5`. `ordinal_probit` = 14 → the `Sigma_unit_diag` bootstrap block yields
  `ci_available=FALSE`, `covered=NA`, `miss_side="unsupported_family_id_14"`. Ordinal contributes
  no coverage row.
- **Decision:** exclude `ordinal_probit` from the confirmatory core (do NOT extend the bootstrap
  this cycle — calibrated ordinal variance is Bar-3/AGHQ, 1.0).
- **ACTION (A1b):** drop `ordinal_probit` (and `mixed`) from the **core** family enumeration used
  for the certificate. `M3_FAMILIES` (`dev/m3-grid.R:36-41`) and `pilot_grid()`'s core list
  (`dev/m3-pilot-launch.R`, `PILOT_CORE4`) currently include them; the certificate core is the
  three true-continuous/count families. Ordinal remains available as a point-only diagnostic cell,
  clearly outside the certificate. Document the exclusion (done in the Design 66 amendment).

### Repair #1 — binary-logit artifact quarantine — MECHANISM DONE (action)
- **Done:** true-probit DGP (`dev/m3-grid.R:516-520`, `pnorm`) + fit (`:956`,
  `binomial(link="probit")`); `evidence_family`/`harness_family`/`link_intended`/`link_harness`
  metadata carried through `PILOT_CORE4` (`dev/m3-pilot-launch.R:104-110`) and the reducer
  (`dev/m3-pilot-report.R:432-455`).
- **Gap:** pre-2026-06-24 artifacts are still labelled `binomial_logit_harness` and the corrected
  true-probit harness has not been rerun at replication depth.
- **ACTION (A1c):** the campaign consumes **true-probit runs only** — assert
  `evidence_family == "binomial_probit"` on every ingested binomial cell; discard/ignore any
  `*_logit_harness` artifact. This is a data-hygiene assertion in the ingest path, not a rerun of
  old data.

### Repair #3 — signal=0 is zero-exclusion, not Type-I — DONE (no action)
- `dev/m3-pilot-report.R:395-409` reports `zero_exclusion_rate` and documents it is NOT a valid
  Type-I/power estimand for a positive `Sigma_unit_diag` target; `pilot_status()` splits signal>0
  vs signal==0 (`dev/m3-pilot-launch.R:1475-1490`). Keep as-is; verify it survives the A1a rewiring.

## Smoke ladder (before the n_sim=2000 grid)

Already scripted — run in order, do not skip:
`--mode=audit-mini` (manifest-only 4-cell smoke) → `--mode=audit-mini-run` →
`--mode=chunk` (one immutable RDS per planned chunk) → `--mode=chunk-audit` (every planned chunk
exists + non-empty) → `--mode=chunk-aggregate` (single-writer, rejects duplicate
`cell_id`/`rep`/`trait_id`/`target`). Wrappers: `dev/power-pilot-smoke.sh`,
`dev/power-pilot-slurm-smoke.sh`, `dev/power-pilot-drac-setup.sh` — but **run on Totoro, not
SLURM/Actions** for our campaign (Totoro has no queue).

## Gate to Phase 2 (the n_sim=2000 grid)

Launch the core grid ONLY when the 48-cell pilot returns `pilot_status == "PASS_TO_SCALE"` AND
Design 66's six quality gates hold on the pilot: coverage ≥0.94 (report 0.95 too); CI-missing ≤10%;
fit-failure ≤20%; bootstrap-failure ≤20%; no one-sided miss (≥80% one side); MCSE small enough to
separate 0.94 from 0.95 (why n_sim rises to 2000; pilot MCSE ≈1.54pp can't adjudicate).

## Register rows to promote only after the grid passes (Design 35)

`CI-08` and `CI-10` are `partial`. Promote **only** after the true-probit, MCSE-reported, ordinal-
excluded grid clears the gates — and only for the three core families. Adversarial coverage verdict
(Fisher/Efron/Gelman, default NOT-DONE, ≥2 NOT-DONE withholds the cell) before any promotion or any
widget/NEWS label flip (A3).

## A1 execution order (next)

1. A1a — wire the decision surface to the report reducer (`dev/m3-pilot-launch.R`).
2. A1b — exclude `ordinal_probit`/`mixed` from the certificate core enumeration.
3. A1c — true-probit-only ingest assertion.
4. A1d — 48-cell pilot + smoke ladder on Totoro (background), then the gate check.
