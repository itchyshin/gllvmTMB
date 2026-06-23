# Power Pilot Run 144 Snapshot Audit

Date: 2026-06-23

Verdict: **diagnostic only**. Run 144 proves that the accumulation workflow can
advance the result store, but it does not support promoting `CI-08`, `CI-10`,
or any power-analysis claim.

## Frozen Snapshot

This note freezes the state immediately after run 144:

| Field | Value |
|---|---|
| Workflow | Power pilot sweep |
| Run number | 144 |
| Run ID | `28022283502` |
| Run URL | <https://github.com/itchyshin/gllvmTMB/actions/runs/28022283502> |
| Event | `schedule` |
| Source branch / SHA | `main` / `43e643b8a5fefefd43676a9c43723b2a955c5992` |
| Result branch / SHA | `power-pilot-results` / `6f0be9607ccaf507d42814c9371f614b3a3da946` |
| Result parent | `ac166a0cebfb8505ba4f4bfc7ae33d737b6de9d5` |
| Result commit time | `2026-06-23T14:19:01Z` |
| Jobs | `51 / 51` successful |
| Run window | `2026-06-23T11:17:06Z` to `2026-06-23T14:25:18Z` |
| Result store | `dev/m3-pilot-results` on `origin/power-pilot-results` |

Run 145 was already in progress during this audit. Treat run 144 as a frozen
snapshot, not the live latest forever.

## Current Counts

`pilot_accum_status(results_dir, n_sim_cap = 10000)` on the run-144 store:

| Quantity | Value |
|---|---:|
| Total cells | 48 |
| Started cells | 48 |
| Complete cells at cap | 1 |
| Replicates accumulated | 273,576 |
| Replicate target | 480,000 |
| Completion share | 57.0% |
| `ALL_COMPLETE` | `FALSE` |

`pilot_collect(results_dirs = run144_store)` returned 48 cells and 23 columns.
Each of the four pilot families has 12 cells.

| Summary | Value |
|---|---:|
| Signal cells with `coverage_primary` | 24 |
| Mean signal-cell coverage | 0.752 |
| Signal cells passing 94% gate | 3 / 24 |
| Signal cells passing 95% gate | 2 / 24 |
| Null cells with `coverage_primary` | 12 |
| Mean null-cell coverage-under-null | 0.424 |
| Flagged cells | 28 |
| Ordinal-probit cells with missing `coverage_primary` | 12 / 12 |

The 12 missing `coverage_primary` values are exactly the 12
`ordinal_probit` cells.

## Simulation-Check Critique

### 1. Inferential Target

The intended target is empirical interval coverage and detection behaviour for
the primary `Sigma_unit_diag` target across the Design 66 pilot grid. The run
currently reports coverage, zero-exclusion, failure, non-PD, convergence, and
bootstrap-failure diagnostics.

The target is not yet clean enough for power language. `signal = 0` cells still
have a positive `Sigma_unit_diag` target, so CI exclusion of zero is not a
Type-I error estimand for this target.

### 2. Data-Generating Process

The core grid is:

```text
family_label       harness_family    link_intended    link_harness
gaussian           gaussian          identity         identity
nbinom2            nbinom2           log              log
binomial_probit    binomial          probit           logit
ordinal_probit     ordinal_probit    probit           probit
```

The `binomial_probit` label is therefore not the actual fitted or simulated
path in run 144. `dev/m3-pilot-launch.R` documents this as an intentional local
pilot deviation, but the audit and dashboard should not abbreviate it as if a
true probit binary cell has passed.

### 3. Parameter Space

The pilot grid covers:

- families: Gaussian, nbinom2, binomial harness labelled as intended probit,
  and ordinal probit;
- latent ranks: `d = 1, 2`;
- unit counts: `n_units = 50, 150`;
- signal levels: `0.0, 0.2, 0.5`.

This is useful for pilot triage. It is not a confirmatory power design because
the binary link mismatch, missing ordinal coverage rows, high non-PD rates, and
incomplete cap all remain unresolved.

### 4. Estimator And Comparator Appropriateness

The pilot reuses the M3 harness and bootstrap interval path, which is sensible
for a diagnostic pilot. It does not yet include external comparators or a
target-aligned audit-mini design. The result store has per-replicate seeds and
fit-health fields (`rep_seed`, `seed_base`, convergence code, `pd_hessian`,
`sdreport_ok`, bootstrap failures), but it does not persist a compact session
info / source-provenance object per run or per store.

### 5. Summary Statistics

The report layer has a coverage MCSE in the coverage plot, but the durable
status table still needs MCSE and denominators for every aggregate that will be
used in decision-making:

- coverage;
- failure rate;
- non-PD rate;
- convergence-failure rate;
- bootstrap-failure rate;
- bias;
- RMSE;
- CI width;
- any future power or Type-I metric.

Denominators should be reported separately for attempted fits, converged fits,
PD-Hessian fits, sdreport-usable fits, bootstrap-usable fits, and
coverage-eligible fits.

### 6. Strength Of Conclusions

Supported conclusion:

- The accumulation workflow can run 48 shards, rebuild a single index, push
  the result branch, and update issue #340.
- The pilot is already showing severe coverage and fit-health problems that
  must be understood before scaling.

Unsupported conclusions:

- `CI-08` is not covered.
- `CI-10` is not covered.
- The pilot is not a power study yet.
- The zero-exclusion panel is not Type-I error or power for
  `Sigma_unit_diag`.
- The `binomial_probit` cells are not true probit-link evidence in run 144.

## Audit Findings

### A. Cap Completion Logic Is Correct, But The Index Cache Is Misleading

`pilot-index.rds` has 48 rows with `status == "done"` because the rebuild helper
marks any existing per-cell result file as done. The cap-aware helper
`pilot_accum_status()` correctly ignores that interpretation and uses
`n_sim >= n_sim_cap`, giving 1 / 48 complete and `ALL_COMPLETE = FALSE`.

Recommendation: before production scaling, either rename the rebuilt index
status to a stored-data state or add an explicit `complete` column to avoid
human misreads.

### B. Binary Label Must Be Renamed Or The DGP Must Change

Run 144 cells labelled `binomial_probit` used `harness_family = "binomial"` and
`link_harness = "logit"`.

Recommendation: either rename the current pilot cells/reports to something like
`binomial_logit_harness` or implement and validate the true probit binary path
before confirmatory runs.

### C. Ordinal Coverage Is Missing For All Ordinal Cells

All 12 ordinal-probit cells have `coverage_primary = NA`. They still report
fit-health and non-PD diagnostics, but they cannot contribute to interval
coverage conclusions.

Recommendation: decide whether ordinal bootstrap coverage is unsupported in
this pilot, blocked by interval machinery, or a reporting bug. Document that
decision before any larger run.

### D. Zero-Exclusion Is Correctly Demoted But Still Easy To Overread

`zero_exclusion_rate` is 1.0 for every non-ordinal row in run 144, including
`signal = 0` rows. The plotting code labels it as diagnostic, not power, but
the status board should keep that language everywhere.

Recommendation: replace any "power" or "Type-I" summary with target-aligned
detection metrics only after the inferential target is defined.

### E. Fit-Health Is The Main Scientific Signal Right Now

Run 144 has 28 flagged cells. The most severe rows are nbinom2, with non-PD
rates up to 77%, fit-failure rates up to 18%, convergence-failure rates up to
18%, and bootstrap-failure rates up to 22%. Several binomial-harness rows also
show non-PD rates above 30%.

Recommendation: keep failure, non-PD, convergence, and bootstrap-failure rates
in all tables. Do not silently filter failed or non-PD fits out of coverage
summaries.

### F. Provenance Is Not Durable Enough For Production

Workflow metadata gives the source SHA and run ID, and per-cell rows carry
`rep_seed` / `seed_base`. The durable result store does not yet contain a
compact session-info manifest.

Recommendation: write a manifest into the result store before DRAC production:
source SHA, result SHA, workflow/run IDs, R version, package versions, platform,
grid definition hash, seed scheme, `n_boot`, `n_sim_step`, `n_sim_cap`, and
result schema version.

## Next Gate

Do not launch DRAC production. The next safe slice is an audit-mini repair:

1. Rename or implement the binary probit path.
2. Explain or repair ordinal coverage.
3. Rename zero-exclusion diagnostics everywhere they might be read as power.
4. Add MCSE and explicit denominators to the status table.
5. Add a durable run manifest.
6. Run four sentinel cells only: Gaussian, nbinom2, true binary-probit or
   renamed binary-logit, and ordinal-probit.

Only after that should Totoro/DRAC smoke jobs begin.
