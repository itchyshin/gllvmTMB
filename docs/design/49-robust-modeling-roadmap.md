# Design 49 — robust modeling roadmap: convergence, starts, Hessian, and evidence

**Maintained by**: Ada (orchestration), Fisher (inference policy),
Curie (simulation evidence), Gauss (numerical/TMB path), Boole (R API),
Pat (reader workflow), Grace (CI/HPC), Rose (scope honesty), and
Shannon (coordination).

**Status**: Active roadmap. The first implementation slice adds
restart provenance, protected `sdreport()` handling, and a
machine-readable fit-health table. The start methods are opt-in and
contract-tested; default-policy and convergence-rate claims remain
evidence-pending until the target-explicit M3.3/M3.4 pilots run.

## 1. Why this roadmap exists

M3.3 showed that the next problem is not simply whether `gllvmTMB`
can fit stacked-trait latent-variable models. The package must also
help users decide whether a difficult fit is trustworthy, whether a
different start value is needed, whether `pdHess = FALSE` is an
optimizer problem or an identifiability problem, and which uncertainty
target is scientifically interpretable.

The roadmap therefore treats robust modeling as a package feature:
diagnostics, start provenance, optimizer provenance, target-explicit
inference, comparator evidence, and reader-facing guidance all move
together.

## 2. Standing team responsibilities

| Member | Roadmap role | Main question | Concrete deliverable |
|---|---|---|---|
| Ada | Orchestrator and integrator | Are code, math, docs, tests, roadmap, CI, and git state aligned? | Own sequencing, branch split, final integration, and done calls. |
| Boole | R API and formula reviewer | Are controls and diagnostics memorable and documented? | Review `gllvmTMBcontrol()`, start arguments, diagnostic API, examples, and roxygen. |
| Gauss | TMB likelihood and numerical reviewer | Is the likelihood path numerically stable and correctly wired? | Review optimizer plumbing, `sdreport()`, gradients, Hessian behavior, and parameter mapping. |
| Noether | Mathematical consistency reviewer | Do symbolic targets match implementation and interpretation? | Audit `Lambda`, `psi`, `Psi`, `Sigma`, rotation, communality, repeatability, and coverage targets. |
| Darwin | Ecology/evolution audience reviewer | Does this answer real biological questions? | Shape examples around behavioural syndromes, morphometrics, abundance traits, and repeated measures. |
| Florence | Scientific figure editor | Are diagnostic and simulation plots publication-quality? | Review convergence, coverage, interval, trait-level, and variance-allocation plots. |
| Fisher | Statistical inference reviewer | Are uncertainty claims justified? | Define Wald/profile/bootstrap policy, acceptance thresholds, target choice, and comparator logic. |
| Pat | Applied PhD user tester | Can a new user understand what to try next? | Review pkgdown article, troubleshooting ladder, examples, warning messages, and interpretation prose. |
| Jason | Landscape and source-map scout | What should we learn from related packages? | Maintain external evidence map and translate lessons into `gllvmTMB` tasks. |
| Curie | Simulation and testing specialist | Do simulations recover the intended target under realistic stress? | Design M3.3a pilot, family stress grids, bootstrap/profile simulations, and CRAN-safe tests. |
| Emmy | R package architecture reviewer | Are object structures and S3 methods coherent? | Review fit objects, diagnostic return objects, extractor compatibility, and plotting APIs. |
| Grace | CI, pkgdown, CRAN, reproducibility engineer | Will this pass locally, on CI, and on larger compute? | Own CI pacing, manual Actions, local multicore, Slurm/Canada Compute workflow, and artifacts. |
| Rose | Systems auditor | What claims are stale, unsupported, or inconsistent? | Audit validation-debt rows, roadmap claims, README/pkgdown consistency, and after-task reports. |
| Shannon | Cross-team coordination auditor | Are parallel branches and agents coordinated safely? | Check open PRs, shared-file collisions, branch state, dev-log entries, and handoff completeness. |

## 3. Evidence base

- Local `gllvmTMB` implementation: `gllvmTMBcontrol()`,
  `sanity_multi()`, `gllvmTMB_diagnose()`, `coverage_study()`,
  `profile_targets()`, `dev/m3-grid.R`, and
  `dev/precompute-m3-grid.R`.
- `drmTMB` convergence design: diagnostic tables, optimizer presets,
  and explicit separation of optimization problems from uncertainty
  interpretation.
- McGillycuddy, Popovic, Bolker & Warton (2025), JSS 112(1), and
  maintainer correspondence with McGillycuddy: use multiple starts,
  residual starts with jitter for reduced-rank models, simpler-model
  starts for complex Gaussian two-level models, and `optim`/BFGS as an
  explicit fallback.
- `glmmTMB` covariance and troubleshooting vignettes: reduced-rank
  starts, Hessian diagnostics, and boundary-parameter workflow.
- `lme4` convergence guidance: gradients, scaling, optimizer
  comparison, and false-positive convergence warnings.
- `gllvm`, `galamm`, and ASReml-style strategies: comparator and
  design inspiration, not substitutes for `gllvmTMB` evidence.

## 4. Implemented now

This slice implements the first robust-modeling infrastructure:

1. `fit$restart_history` records one row per optimizer start with
   start method, jitter scale, optimizer, objective, convergence code,
   message, elapsed time, and selected-restart flag.
2. `fit$start_provenance` records the initialization path:
   default, residual, independent/simpler, single-trait warmup, manual
   `start_from`, and selected restart.
3. `TMB::sdreport()` is wrapped so a failure records
   `fit$sdreport_error` and lets the fitted object remain available
   for point summaries and diagnostics.
4. `gllvmTMBcontrol(se = FALSE)` intentionally skips
   `TMB::sdreport()` for hard models where point estimates are needed
   and uncertainty will be obtained by bootstrap/profile workflows.
5. `fit$fit_health` stores the main optimizer, gradient, Hessian,
   standard-error, start, and boundary signals.
6. `check_gllvmTMB()` returns a stable table for simulations and
   tests. It is the machine-readable companion to
   `gllvmTMB_diagnose()`.

## 5. `pdHess` policy

`pdHess = FALSE` is an inference and identifiability warning. It is
not automatic proof that the fitted point estimates, likelihood,
predictions, or rotation-invariant covariance summaries are useless.

The standard triage order is:

1. Check optimizer convergence and gradients.
2. Inspect boundary variances, dispersions, and correlations.
3. Reduce latent rank or simplify covariance structure.
4. Standardize predictors and rescale offsets or traits.
5. Try multiple starts, residual starts, simpler-model starts, or an
   explicit optimizer fallback.
6. Profile suspicious targets or use bootstrap intervals for
   interpretable summaries.
7. If the target remains unstable, mark the capability partial rather
   than advertising robust inference.

## 6. Start-value policy

The current start ladder is opt-in:

| Strategy | User-facing control | Current status |
|---|---|---|
| Default start | `gllvmTMBcontrol()` | Default retained. |
| Multiple starts | `n_init = 5` to `10` | Implemented; restart history now recorded. |
| Jitter | `init_jitter`, `start_method$jitter.sd` | Implemented; bounded `log_phi_*` starts are re-clamped after jitter. |
| Single-trait warmup | `init_strategy = "single_trait_warmup"` | Implemented for phi-bearing families. |
| Residual starts | `start_method = list(method = "res")` | Implemented; most relevant to non-Gaussian reduced-rank fits. |
| Simpler independent starts | `start_method = list(method = "indep")` | Implemented for B/W tiers; especially relevant to Gaussian two-level fits. |
| Manual simpler starts | `start_from = simpler_fit` | Implemented for same-shaped TMB parameters. |
| Optimizer fallback | `optimizer = "optim", optArgs = list(method = "BFGS")` | Implemented as explicit user choice. |

No start strategy becomes the default until target-explicit M3 evidence
shows improved objective, recovery, and interval behavior without
creating worse local-basin failures.

## 7. Target-explicit inference policy

Raw/internal targets:

- `Lambda`
- latent scores
- raw `psi`
- unconstrained TMB parameters
- loading diagonals before rotation/sign conventions

Interpretable promotion targets:

- `Sigma = Lambda Lambda^T + Psi`
- `Sigma_unit_diag`
- trait correlations
- communality
- repeatability
- latent versus unique variance share
- between/within variance decomposition for two-level models

M3.3 promotion should prioritize interpretable targets. Raw `psi`
remains diagnostic until evidence shows that it is a stable public
inference target.

## 8. M3.3a pilot requirements

Pilot cells:

- Gaussian latent+unique, rank 2
- `nbinom2` latent+unique, rank 1
- mixed-family latent+unique, rank 2
- two-level Gaussian within/between latent+unique
- ordinal-probit latent+unique, rank 1, only after simulation support
  is valid for that path

Each replicate records family, rank, sample size, seed, start method,
optimizer, selected restart, objective spread, convergence code,
maximum gradient, `pdHess`, `sdreport()` status, interval method,
target, CI availability, miss side, CI width, bootstrap/profile refit
failures, and failure class.

Pilot acceptance before a larger rerun:

- `Sigma_unit_diag` bootstrap coverage at least 0.90
- CI missing rate at most 10 %
- fit failure at most 20 % (mixed-family pilot allowed up to 30 %)
- no one-sided miss pattern above 80 %
- if `psi` fails but `Sigma_unit_diag` passes, mark `psi` as weakly
  identified rather than treating the whole model as failed

## 9. Later implementation lanes

1. Family stress lanes: `nbinom2`, ordinal, mixed-family, and
   Gaussian two-level.
2. Comparator lanes: `glmmTMB`, `galamm`, `gllvm`, `lme4`, and
   `drmTMB`, with target matching declared before fitting.
3. Profile/bootstrap lanes: parallel profile over selected scalar
   summaries and bootstrap refit provenance.
4. HPC lanes: local multicore wrapper, manual GitHub Actions inputs,
   Slurm/Canada Compute shard manifests, reducers, and artifact
   schema.
5. Figure lanes: convergence, `pdHess`, coverage, CI width,
   objective-spread, selected-start, bootstrap-failure, trait-level
   heatmap, variance-allocation, and profile-curve plots.
6. Teaching lanes: `convergence-start-values.Rmd` first, then
   `simulation-diagnostics.Rmd` after result schemas stabilize.

## 10. Scope boundary

Implemented in this slice:

- restart history and selected-restart provenance;
- protected `sdreport()` failure status;
- fit-health object;
- `check_gllvmTMB()` table;
- diagnostics that treat `pdHess = FALSE` as an inference warning.

Partial:

- `sdreport()` failure protection is coded, but direct TMB failure is
  hard to trigger deterministically in a small unit test; the degraded
  object path is covered by a forced diagnostic object.
- convergence-rate and default-policy claims for start methods await
  target-explicit M3.3/M3.4 evidence.

Planned:

- convergence/start-values pkgdown article;
- profile/bootstrap target-parallelization;
- local multicore and Slurm-ready simulation wrappers;
- simulation diagnostic plot helpers.
