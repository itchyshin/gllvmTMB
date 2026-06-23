# Mid-Term Capability And Compute Scout

Date: 2026-06-23

## Goal

Convert the mid-term council plan into a source-backed scout packet before
any dashboard refresh, compute launch, or capability promotion.

## Current Truth

- PR #537 has merged. `Xcoef_fixed` is implemented inside `MIS-34` for
  zero fixed-effect constraints in native ML fits and admitted Julia
  fixed-effect-X rows.
- PR #538 has merged at `475cd7a` after Shinichi approved the merge.
  `origin/main` now includes the JSDM screening scope polish.
- The validation register is the current source of truth: 202 rows,
  173 covered, 22 partial, 0 opt-in, and 7 blocked.
- Issue #340 and the local mission-control widget are stale operating
  surfaces. Refresh them only after the ledger typo/status sync lands.
- The power pilot is diagnostic only. It is not evidence to move `CI-08`
  or `CI-10`.

## Sibling-Team Lessons

### HSquared / HSquared.jl

Adopt the process lesson: measure the bottleneck before optimizing it.
The useful result from the HSquared lane was scale-aware convergence
diagnostics, not a blanket sparse-ordering dependency. `gllvmTMB`
should profile before considering METIS, OpenMP, or new sparse
dependencies.

Adopt the diagnostics pattern: record relative variance-component
movement, log-SD step size, objective movement, and false
non-convergence at large scale. These are diagnostics first; they do
not automatically change the estimator.

### DRM.jl / drmTMB

Adopt the caution: do not transfer AI-REML wording onto augmented,
q4, or non-Gaussian Laplace routes because the algebra looks similar.
For `gllvmTMB`, REML and AI-REML language stays Gaussian-only unless a
future derivation and validation row proves the exact estimand.

Adopt the linear-algebra discipline: selected inverse / Takahashi
methods are exact for diagonal or in-pattern entries and selected trace
terms. They are not a general shortcut for arbitrary dense covariance
blocks.

### drmTMB DRAC Planning

Adopt the shard ladder: dry-run contract, small multi-shard rehearsal,
then full dispatch. Simulation workers should write private immutable
chunks and logs. Aggregation should happen after all expected chunks are
present, with missing and duplicate chunks treated as errors.

### hsquared Comparator Runbooks

Adopt runbooks before evidence. A comparator note should name the
estimand, fixture, tool version, scale mapping, acceptance band,
blockers, and the phrase "protocol, not evidence" until it has been
run. For `gllvmTMB`, this applies to future comparisons with `gllvm`,
`glmmTMB`, `sdmTMB`, `MCMCglmm`, `Hmsc`, `galamm`, ASReml, WOMBAT, or
DMU.

## gllvmTMB Capability Boundaries

- Safe now: covered register rows at their named depth.
- Covered but caveated: rows that include partial sub-scope caveats,
  especially `MIS-34`.
- Partial: rows with useful but incomplete evidence, including `DIA-14`,
  `CI-08`, `CI-10`, and `JUL-01`.
- Blocked: rows that should not be advertised as supported, including
  `MIS-32`, `MIX-10`, mixture/gengamma families, delta/hurdle latent
  correlation, and proportional `meta_V`.

The fixed-effect-zero article can be linked as implementation-backed
after #537 because `MIS-34` covers zero constraints. It must still say
that `Xcoef_fixed` is trait-specific mean-structure control, not
variable selection, response deletion, screening, or loading
constraints.

The screening article should remain advisory: rare or duplicate binary
species are flagged for inspection and sensitivity fits, not automatic
removal.

## Power Pilot Audit Gate

Before broad compute:

1. Freeze the current pilot snapshot: source SHA, result branch SHA,
   workflow IDs, session info, seed ranges, and issue-board payload.
2. Resolve the `binomial_probit` label. Either make the DGP and fit path
   true probit, or relabel the cells as binomial-logit diagnostics.
3. Explain why ordinal-probit cells lack `coverage_primary`, or exclude
   ordinal from the confirmatory core until coverage rows exist.
4. Rename `signal = 0` diagnostics so they are not treated as Type-I
   error for positive `Sigma_unit_diag` targets.
5. Add MCSE to coverage, failure rate, nonPD rate, bootstrap-failure
   rate, bias, RMSE, CI width, and any future power/Type-I metric.
6. Report denominators separately: attempted, converged, PD-Hessian,
   sdreport-usable, bootstrap-usable, and coverage-eligible fits.
7. Keep failed fits in the tables. Do not silently drop them from the
   performance story.

## Compute Readiness

Use compute in three tiers:

- Totoro: package install/load, manifest parse, and tiny smoke fits.
- DRAC login nodes: login, environment, module, and submission checks
  only.
- DRAC SLURM jobs: actual simulation chunks.

Rules:

- No fitting on login nodes.
- No GPU lane in this phase.
- Use `/project` for R/Julia libraries and durable outputs.
- Use `/scratch` only for task-local temporary files.
- Set `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, and
  `MKL_NUM_THREADS=1`.

The SLURM design should be manifest-first. One array task writes one
immutable `(campaign_id, cell_id, chunk_id)` output plus a sidecar log.
No array task writes a shared `pilot-index.rds`. Aggregation runs as a
dependent job that validates missing and duplicate chunks before
computing summaries.

Smoke ladder:

1. Manifest parse only.
2. Two cells x two reps x `n_boot = 0`.
3. The same cells with `n_boot = 2`.

Only after those pass should the team run sentinel HPC cells, followed
by the corrected core at `n_sim = 2000` per cell.

## Dashboard Refresh Packet

After the ledger truth-sync PR lands, refresh mission control from these
sources in order:

1. PR #538 merged status.
2. Validation-register counts.
3. Power pilot issue #340 live status.
4. Active PRs and sibling-team watchlist.
5. Dashboard version and timestamp.

Add these dashboard groups:

- Safe now.
- Covered but caveated.
- Partial / use cautiously.
- Planned.
- Blocked / do not advertise.

Add the collaborator-facing capability table:

`Article | User question | Safe now | Partial caveat | Blocked/planned boundary | Evidence rows`

## Stop Gates

- Stop before merging future PRs unless their merge authority is explicit.
- Stop before any dashboard refresh if the ledger count typo is not
  settled.
- Stop before broad DRAC/Totoro simulations if pilot labels, MCSE, and
  denominators are not fixed.
- Stop before any non-Gaussian REML / AI-REML wording.
- Stop before any capability row promotion unless the evidence row,
  tests, prose, check-log, and after-task report all agree.
