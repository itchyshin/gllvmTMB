# Design 50 - M3.3b surface-admission and diagnostic-report gate

**Maintained by**: Ada (orchestration), Fisher (inference policy),
Curie (simulation evidence), Florence (figures), Grace (CI and
artifacts), Rose (scope honesty), and Shannon (coordination).
**Status**: Active design contract, added 2026-05-20.
**Issues**: #217 (surface admission) and #218 (M3 diagnostic
visualization / Florence gate).
**Backed by**: validation-debt rows EXT-13, CI-08, and CI-10.

## 1. Purpose

M3.3b is now the admission gate between the failed M3.3 production
run and the next moderate or production grid. It does not run broad
compute by itself. It decides whether a family/rank/target surface is
well enough specified to enter an r50 pilot or an r200 promotion run.

The gate exists because the 2026-05-19 production run passed compute
but failed the statistical gate, and the 2026-05-20 NB2 diagnostics
showed that three things were entangled:

- the public promotion target, total `Sigma_unit[tt]`;
- the diagnostic `psi` profile target;
- NB2 dispersion estimation and link-residual scale.

The next broad run must not mix those targets again. Every admitted
surface names its estimand, fit mode, interval method, failure ledger,
and diagnostic report before scaling.

## 2. Surface identity

Each candidate surface gets one row in a surface register before any
r50 or r200 run. Required fields:

| Field | Meaning |
|---|---|
| `surface_id` | Stable label such as `nbinom2-d1-baseline-phi1`. |
| `family` | One of the M3 families, or `mixed` with the family mix named. |
| `d` | Latent rank. |
| `n_units`, `n_traits` | Simulation size. |
| `scenario` | Human-readable scenario name, including variance and dispersion regime. |
| `lambda_scale`, `psi_scale` | DGP latent and unique variance scales. |
| family nuisance truth | For example NB2 `phi`, when present. |
| `run_stage` | `smoke`, `r50_pilot`, or `r200_promotion`. |

The first active surface is NB2 `Sigma_unit_diag` under estimated
versus known `phi_nbinom2`. Known-phi evidence is diagnostic only until
the bootstrap or profile refit path preserves the same fixed-phi
estimand.

## 3. Estimand and method contract

Every row in the M3 diagnostic grid must carry explicit target and
method labels:

| Field | Required rule |
|---|---|
| `target` | `Sigma_unit_diag` for the primary promotion target; `psi` only as a diagnostic target. |
| `ci_method` | `bootstrap`, `profile`, `wald`, or `none`. |
| `ci_level` | Usually 0.95. |
| `fit_phi_mode` | `estimated`, `known`, or `not_applicable`. |
| `link_residual` | `none` for latent + unique `Sigma_unit_diag` promotion checks. |
| `n_boot`, `n_cores_boot` | Explicit even when `n_boot = 0`. |
| `seed_base` | Seed family for reproducibility. |

`Sigma_unit_diag = diag(Lambda Lambda^T + Psi)` is the primary M3.3
promotion target, with `Psi = diag(psi)` under the project notation.
`psi` remains useful because it explains which part of the
decomposition is unstable, but a profile-`psi` coverage pass is not
enough to promote CI-08 or CI-10.

Known-phi point diagnostics use `ci_method = "none"` and `n_boot = 0`.
They can move a surface from "mystery" to "diagnosed", but they cannot
move a surface to "covered".

## 4. Fit and interval ledger

Each replicate-level row must preserve the fit-health and interval
ledger. Failed fits stay in the long grid instead of disappearing from
summaries.

Required fit fields:

- start strategy;
- optimizer and optimizer arguments;
- `n_init` and jitter settings;
- `se`;
- convergence code and message;
- maximum gradient;
- `pdHess`;
- `sdreport` status and error;
- selected restart;
- restart count;
- objective spread;
- boundary flags.

Required interval fields:

- `truth`;
- `estimate`;
- `ci_lo`, `ci_hi`;
- `covered`;
- `ci_available`;
- `ci_failed`;
- `miss_side`;
- bootstrap failures, attempts, and failure rate;
- runtime.

The long grid is the source of truth. Summary tables may be rendered,
but they must not be the only artifact.

## 5. Admission thresholds

The current `m3_pilot_status()` thresholds are the admission floor:

- coverage at least 0.90 for an r50 pilot to scale;
- CI-missing rate at most 10 percent;
- fit-failure rate at most 20 percent, except mixed-family surfaces
  allow at most 30 percent;
- bootstrap-failure rate at most the same family-specific failure
  limit;
- no one-sided miss pattern where at least 80 percent of misses are on
  one side;
- `pilot_status = "PASS_TO_SCALE"` before an r50 result can justify an
  r200 promotion run.

Promotion to `covered` still requires the M3 exit gate: target-explicit
total `Sigma_unit[tt]` empirical coverage at least 94 percent at R =
200, with the coverage-rate matrix supporting the status change.

## 6. No-go cases

A surface does not enter r50 or r200 if any of these are true:

- only profile-`psi` coverage is available for a total
  `Sigma_unit_diag` claim;
- known-phi point ratios are treated as interval coverage;
- a bootstrap path silently refits estimated `phi` after the point fit
  fixed `phi`;
- `link_residual = "auto"` is mixed with `link_residual = "none"`
  without labels;
- failed fits, missing intervals, or bootstrap failures are dropped
  from plots or summaries;
- ordinal-probit bootstrap is requested before family-ID 14 simulation
  support is implemented;
- a surface has strong one-sided misses or clear target-scale bias.

## 7. Diagnostic report contract

Every admitted surface gets a tiny rendered diagnostic report before
larger compute. The first report is dev-facing; public articles wait
until the evidence is stable.

The report must include:

1. a surface header: `family`, `d`, `scenario`, `target`,
   `ci_method`, `fit_phi_mode`, start strategy, optimizer, `n_reps`,
   `n_boot`, `n_cores_boot`, seed, and artifact path;
2. a summary table by `(cell, target, ci_method, fit_phi_mode,
   scenario)`;
3. an admission forest showing coverage with 0.90 and 0.94 reference
   lines;
4. an estimate/truth ratio panel by trait, with a ratio = 1 reference
   line;
5. an NB2 `phi` and link-residual panel when NB2 is present;
6. a failure-ledger panel for fit failure, CI missingness, bootstrap
   failure, `pdHess`, and `sdreport`;
7. a one-paragraph verdict per surface: `PASS_TO_SCALE`,
   `TARGET_FAIL`, or `COMPUTE_FAIL`.

Report plots must use the long grid, not filtered summaries alone.
When the next run uses GitHub Actions or HPC shards, the grid should
carry `worker_id`, `artifact_id`, or equivalent provenance so a figure
can trace each point back to its compute source.

The first implementation is dev-only: `m3_source_map_dashboard_data()`
keeps the long-grid-derived trait ratios, failure ledger, and verdict
rows separate, and `m3_write_source_map_dashboard()` writes a PNG
contact sheet beside the Markdown diagnostic report for diagnostic
modes. Point-only cells are labelled `POINT_ONLY` and
`NOT_EVALUATED`, not plotted as coverage evidence.

## 8. Florence gate for M3 diagnostics

Florence can reject a diagnostic figure even when the underlying run
completed. A figure fails the M3 gate if it:

- hides weak cells behind averages;
- drops missing intervals without markers;
- omits denominators;
- presents `psi` as the promotion target;
- merges profile, bootstrap, Wald, and point-only diagnostics into one
  unlabeled column;
- lacks the 0.90 pilot, 0.94 promotion, or ratio = 1 reference lines
  where those references are relevant;
- uses unreadable labels at pkgdown or single-column manuscript size;
- relies on color alone when shape, line type, or labels are needed;
- looks like an unmodified default ggplot panel.

Minimum figure-quality standard: the rendered output has no
zero-scored figure-quality categories and scores at least 16/20 under
the project Florence rubric before it can support an r50 or r200
decision.

## 9. Documentation and tracker actions

Each M3.3b slice must update:

- this design when the gate changes;
- `ROADMAP.md` when the next admitted surface or status changes;
- issue #217 for inference/surface-admission decisions;
- issue #218 for diagnostic-report and Florence-gate decisions;
- validation-debt rows EXT-13, CI-08, and CI-10 only when evidence
  actually changes their status;
- the after-task report with a GitHub Issue Ledger.

Until the gate admits a surface and the r200 evidence clears the
promotion threshold, EXT-13 stays `covered` for Gaussian and `partial`
for non-Gaussian, while CI-08 and CI-10 stay `partial`.

## 10. Immediate next slices

1. Build the dev-facing M3 diagnostic-report scaffold.
2. Run the smallest NB2 point-only stress map that separates
   `fit_phi_mode`, variance scale, sample size, and rank.
3. Decide whether fixed-phi bootstrap needs a mapped-parameter refit
   path before any known-phi coverage claim.
4. Admit or reject the first NB2 r50 surface with a report and issue
   comment, not only a table.
