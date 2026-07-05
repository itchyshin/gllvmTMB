# gllvmTMB Completion Arc Ultra-Plan

Date: 2026-07-04
Status: planning-only, no package capability change
Owner: Ada, with Rose/Fisher/Curie/Grace/Boole/Hopper/Shannon review roles

## Purpose

This plan turns the next phase into a package-completion arc for `gllvmTMB`
first. The Julia bridge and `GLLVM.jl` parity work stay quiet unless Shinichi
explicitly reopens that lane. The aim is to make the R/TMB package internally
consistent, tested, and honest across non-Gaussian models, structural
dependence, random slopes, missing data, mixed responses, and uncertainty
intervals.

This is not a broad compute sprint. It is a sequence of truth-lock and
capability-hardening slices. Each slice must either move a capability to
`covered` with direct evidence, keep it guarded/blocked, or make the public
claim narrower.

## ARIA Contract

No local canonical ARIA note was found during planning, so this plan uses ARIA
explicitly as:

- Aim: the concrete capability or truth state.
- Risk: the main way the slice can mislead users or break validation.
- Implementation: the smallest code/doc/test slice that moves the state.
- Assessment: the evidence gate before a claim changes.

Every slice below must carry all four elements before implementation starts.

## Council Review

Ada keeps the arc small enough to merge and broad enough to matter.

Rose blocks overclaiming. In particular, "partial support" language must not be
used to advertise phylogenetic Model A, mixed-family intervals, or broad
source-specific `lv = ~ env` support.

Fisher owns the uncertainty ladder: Wald is a scout and stable-parameter tool;
profile likelihood is the preferred likelihood-framework engine where feasible;
SAS-style estimated-likelihood intervals are diagnostics/canaries, not public
calibrated intervals; bootstrap and ADEMP simulation are final calibration or
rescue evidence.

Noether owns symbolic alignment before any new structural/non-Gaussian random
slope, missing-predictor, mixed-family, or delta/hurdle interval claim.

Curie owns focused recovery tests first. No DRAC/Totoro expansion until local
focused checks are green and denominators are designed.

Grace owns CI, pkgdown, Mission Control, and reproducibility. The current
branch state and dashboard truth must be refreshed before public claims move.

Boole owns parser/formula guardrails, especially malformed structural LHS,
duplicate slopes, and silently dropped latent arguments.

Hopper keeps R/Julia bridge wording narrow. This arc does not use Julia parity
as a requirement for finishing `gllvmTMB`.

Shannon owns issue batching, branch hygiene, and file-overlap coordination.

## Statistical Uncertainty Policy

The recommended uncertainty ladder is:

1. Wald intervals for fast scouting and fixed-effect-like targets where the
   local quadratic approximation is stable.
2. Estimated-likelihood / fixed-nuisance likelihood-ratio intervals as a cheap
   diagnostic for hard models when full profile is expensive.
3. Full profile likelihood-ratio intervals for key covariance, latent-derived,
   and boundary-sensitive targets when the target can be bracketed and refit
   reliably.
4. Bootstrap or ADEMP simulation for final calibration, public coverage claims,
   or rescue when likelihood curvature diagnostics disagree.

`pdHess = TRUE` is not enough for public interval claims. It only says the local
Hessian is positive definite at the fitted point. It does not prove that a
variance component, latent loading product, mixed-family correlation, or
boundary-sensitive derived target has calibrated coverage.

SAS-style estimated likelihood is worth implementing as an economical
diagnostic tier, especially for complex phylogenetic, spatial, and multilevel
models where full profiling may be too expensive. It must not be described as
equivalent to full profile likelihood because nuisance parameters are held at
their fitted values.

## Phase 0: Truth Lock And Issue Map

ARIA:

- Aim: know the current package truth before coding.
- Risk: starting feature work while a red full-check or stale Mission Control
  claim is hiding a larger inconsistency.
- Implementation: inspect current branch, dashboard, validation register, open
  issues, recent CI, and stale wording.
- Assessment: one short completion matrix naming `covered`, `partial`,
  `blocked`, and `planned` surfaces.

Inputs to re-check:

- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/57-mixed-family-link-residual.md`
- `docs/design/70-missing-data-simulation-design.md`
- `docs/design/68-missing-predictor-phase5-categorical.md`
- `docs/design/69-missing-predictor-phase3-phylo.md`
- Mission Control JSON under `docs/dev-log/dashboard/`

Exit gate:

- The next implementation PR is chosen from live evidence, not from memory.
- No dashboard wording says a blocked/partial route is ready.

## Phase 1: Inference Safety Gate

ARIA:

- Aim: make profile/Wald/bootstrap claims internally safe.
- Risk: intervals look available but have bad status, wrong baselines, ignored
  seeds, or misleading curvature.
- Implementation: repair focused CI bugs before adding new interval surfaces.
- Assessment: focused CI tests plus claim audit.

Priority issue cluster:

- Lambda/profile status shape bugs that corrupt data-frame output.
- Profile-to-bootstrap fallback respecting `nsim` and `seed`.
- Derived profile surface audit: verify that `profile_ci_*()`,
  `extract_*(ci = TRUE)`, `confint(parm = ...)`, and bootstrap summary
  collectors agree for each advertised tier. Ayumi-495/avian_trait_scales#14
  is the first real-world audit row: multi-tier phylogenetic signal must not
  return empty intervals when a Wald fallback exists, and phylogenetic
  communality must either route through `tier = "phy"` or fail/document
  loudly.
- tmbprofile versus Lagrange `delta_deviance` baseline consistency.
- Gamma/profile-CI failures from full-check or heavy-check surfaces.
- Mixed-family CI claims remain blocked unless coverage evidence changes.

Deliverables:

- A narrow inference repair PR.
- A derived-CI route matrix covering `icc`, `phylo_signal`, `communality`,
  `rho`, and `proportion` across admitted tiers and methods:
  `profile`, `wald`, `bootstrap`, plus explicit `unavailable` statuses.
- Updated validation-debt rows for the exact interval surfaces tested.
- Check-log entry with exact focused commands.

Stop rule:

- Do not scale profile or bootstrap compute while focused interval status is
  wrong or denominator tracking is unclear.

## Phase 2: Missing And Mixed Data Correctness

ARIA:

- Aim: complete the v1 observed-data and mixed-response correctness surface.
- Risk: masks, weights, family-list matching, or missing-predictor routing are
  silently wrong.
- Implementation: close correctness bugs before broadening model families.
- Assessment: known-DGP focused tests and extractor checks.

Priority issue cluster:

- Per-cell weight matrix under `missing = "include"` must retain the `na_mask`.
- Mixed-family lists should match data by names, not by sorted/level order.
- Missing-response and missing-predictor examples must state what is v1 versus
  planned v2.
- Multiple `mi()` terms, discrete missing predictors, MNAR, and broad
  missing-data calibration remain later slices unless directly implemented.

Deliverables:

- One missing/mixed correctness PR.
- A short user-facing scope statement: response missingness and one modelled
  predictor route are in; broader missing-data machinery is planned.

Stop rule:

- Do not claim complete missing-data support until the validation register has
  row-level evidence for each response/predictor/family surface.

## Phase 3: Structural Random-Slope Grammar And Extractors

ARIA:

- Aim: make structural random-slope syntax either work or fail loudly.
- Risk: `lv = ~ env`, malformed LHS, or duplicate slopes look accepted while
  being silently dropped or misinterpreted.
- Implementation: parser guards, extractor fixes, and focused tests by source.
- Assessment: parse/error tests and extractor shape tests across phylo,
  spatial, animal, kernel, and ordinary latent routes.

Priority issue cluster:

- Duplicate slope covariates in multi-slope LHS.
- Parenthesized or malformed augmented LHS not stripped/guarded correctly.
- Spatial malformed LHS reinterpreted as deprecated orientation.
- Augmented/dep phylogenetic tiers causing extractor non-conformability.
- Source-specific `lv = ~ env` remains guarded until direct implementation and
  validation exist.

Deliverables:

- One grammar/extractor PR.
- Clear error messages telling users what syntax is supported and what is not.

Stop rule:

- No source-specific latent random-regression advertisement from parser
  acceptance alone.

## Phase 4: Non-Gaussian Safety And Parameterization

ARIA:

- Aim: make the non-Gaussian surface safe before advertising breadth.
- Risk: residual, dispersion, link, or positivity assumptions borrow Gaussian
  semantics incorrectly.
- Implementation: close family-specific safety and parameterization issues.
- Assessment: focused tests per family plus likelihood/claim review.

Priority issue cluster:

- Positivity guards for lognormal and Gamma responses.
- Family-specific `VP()` residual handling; no fake Gaussian residual for every
  trait.
- Gamma dispersion truth across R/TMB and any Julia wording.
- Ordinal link boundary and R/Julia wording.
- Non-Gaussian `s >= 2` structural random slopes stay guarded until a pilot
  family has symbolic alignment and recovery tests.

Deliverables:

- One or more family-safety PRs.
- Updated docs and validation rows for each family surface moved.

Stop rule:

- No non-Gaussian REML claim. REML remains Gaussian-only unless separately
  derived and validated.

## Phase 5: Capability Promotion

ARIA:

- Aim: promote only the routes that direct evidence supports.
- Risk: a working point-estimate path becomes an unsupported interval or broad
  family claim.
- Implementation: choose one promotion target at a time.
- Assessment: direct tests, simulation or profile evidence where relevant, and
  Rose wording review.

Candidate promotion order:

1. Stabilize ordinary and structural Gaussian routes already close to complete.
2. Promote non-Gaussian single-slope structural routes only where tests already
   support the claim.
3. Add one non-Gaussian `s >= 2` pilot family after symbolic alignment.
4. Expand missing-predictor support only one predictor class at a time:
   continuous, phylogenetic Gaussian predictor, binary, ordered, unordered.
5. Keep mixed-family point/postfit support separate from mixed-family interval
   claims.

Deliverables:

- Small PRs, one hard surface each.
- Each user-facing claim references validation-debt row IDs.

Stop rule:

- Do not combine new family, new random-slope dimension, missing data, and new
  CI method in a single PR.

## Phase 6: Release Hardening

ARIA:

- Aim: leave `gllvmTMB` in a coherent v1-ready state.
- Risk: code, docs, NEWS, pkgdown, Mission Control, and validation register
  disagree.
- Implementation: synchronize docs and run release-level checks.
- Assessment: local checks and CI green before calling the arc complete.

Deliverables:

- Updated validation-debt register.
- Updated capability status doc.
- Updated Mission Control dashboard.
- NEWS and README scope-boundary statements if public-facing claims changed.
- Check-log and after-task report.

Minimum command gate:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Run focused tests first for each PR. Do not rely on full checks to discover
basic parser, extractor, or interval failures.

## First 12-Hour Execution Plan

Hour 0-1:

- Rehydrate branch, dashboard, validation register, and open issue clusters.
- Confirm whether the current full-check failure is still live.
- Choose the first implementation PR.

Hour 1-4:

- Work on the inference safety gate first if the Gamma/profile failure remains
  live.
- Otherwise work on missing/mixed correctness, because it blocks many v1 user
  claims.

Hour 4-6:

- Add focused tests and run only the relevant test files.
- Update validation-debt rows only for surfaces directly touched.

Hour 6-9:

- Fix second-order fallout or split the next PR queue.
- Avoid broad compute unless focused checks are green.

Hour 9-12:

- Update check-log and after-task notes for completed work.
- Refresh Mission Control if the operating truth changed.
- Prepare the next PR or handoff packet.

## Multi-Day Arc Estimate

12 hours:

- Truth lock plus one substantial focused PR, or two small guard/docs PRs.

2-3 days:

- Inference safety repairs and missing/mixed data correctness.

1-2 weeks:

- Structural grammar/extractor hardening plus non-Gaussian safety fixes.

3-6 weeks:

- Capability promotion, simulation calibration, pkgdown/NEWS/readme
  synchronization, and release-level hardening.

This estimate assumes small PRs and no broad DRAC/Totoro scaling until focused
local checks are green.

## Compute Escalation Plan: Local, Totoro, DRAC

The compute plan is staged. Local checks find code and claim bugs; Totoro finds
fast failure modes; DRAC supplies frozen-design claim evidence.

Local first:

- Run focused parser, extractor, CI, missing-data, family, and known-DGP tests
  before any remote compute.
- Use tiny profile/bootstrap smokes only to confirm routing, status payloads,
  seeds, and failure messages.
- Do not treat local smokes as calibration denominators or coverage evidence.

Totoro diagnostic tier:

- Use Totoro only after local focused checks are green and the run design has a
  fixed manifest.
- Intended use: quick-turnaround diagnostics, small seed-matched repros,
  profile/bootstrap timing, endpoint-failure scans, and canary grids such as
  R = 20 or R = 50 before claim-scale runs.
- Hardware posture from the brain runbook: passwordless `ssh totoro`, CPU-only,
  no queue/SLURM, roughly 384 cores and 1 TB RAM, but keep Shinichi's use at or
  below 100 cores. Prefer 48-96 workers unless a smaller diagnostic suffices.
- Always set thread caps such as `OPENBLAS_NUM_THREADS=1` and
  `OMP_NUM_THREADS=1` to avoid oversubscription.
- Record provenance columns for every diagnostic result: host, commit, seed,
  model surface, task id, fit status, `pdHess`, profile status, bootstrap
  status, elapsed time, and error text.
- Do not mix Totoro denominators with local or DRAC denominators unless the run
  design explicitly declares host as a permitted factor.

DRAC claim-evidence tier:

- Use DRAC for long queued, frozen-design evidence: R = 200/500/1000 coverage
  or recovery runs, large bootstrap/ADEMP calibration, and work that needs more
  than the agreed Totoro footprint.
- Never compute on login nodes. Use `sbatch` or `salloc`, with one seed or one
  grid cell per `SLURM_ARRAY_TASK_ID`.
- Every job script must set account, wall time, memory, CPU count, output/error
  logs, and an explicit array throttle.
- Keep R/TMB libraries and Julia depots on home or project storage, not scratch.
  Scratch is for temporary working files and must be copied back to durable
  project storage.
- For R/TMB jobs on GP clusters, load the compiler and R modules in the job
  script before installing or running package checks.
- DRAC denominators remain DRAC-only unless the analysis plan explicitly
  permits pooling with Totoro or local diagnostics.

Escalation gates:

- Local to Totoro: focused tests green, dry-run command recorded, parameter
  manifest frozen, output schema defined, and stop rules written.
- Totoro to DRAC: diagnostic convergence and endpoint behavior are sane, no
  obvious code bug remains, denominators are frozen, and check-log/after-task
  notes state exactly what claim the run can support.
- Any failed stop rule sends the slice back to local debugging, not to a larger
  compute budget.

No remote compute is launched by this planning update.

## Parallelization Plan

Use parallel work only when files and claims do not collide.

Safe parallel lanes:

- Rose/Shannon: read-only issue/dashboard/register audit.
- Fisher/Curie: inference test design and CI failure triage.
- Boole: parser and formula-grammar issue map.
- Grace: CI/workflow status and command reproducibility.

Avoid parallel edits to:

- `R/fit-multi.R`
- `R/brms-sugar.R`
- `src/gllvmTMB.cpp`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Non-Negotiable Boundaries

- No source-specific `lv = ~ env` promotion without explicit implementation,
  tests, docs, and maintainer sign-off.
- No mixed-family CI support claim until interval calibration is directly
  tested.
- No non-Gaussian REML claim.
- No "pdHess passed, therefore CI is calibrated" wording.
- No broad compute launch while focused failures remain unresolved.
- No Julia parity requirement inside this `gllvmTMB` completion arc.

## Reviewed Verdict

This Ultra-Plan is ready to use as the operating plan for the next arc. It is
economical because it starts from live blockers and issue clusters rather than
new model ambition. It is defensible because every capability must pass through
ARIA, validation-debt rows, focused tests, and Rose wording review before it
moves from planned/partial/blocked to covered.

The recommended next task is Phase 1: inference safety gate. If the current
Gamma/profile full-check failure has already been fixed elsewhere, move
immediately to Phase 2: missing and mixed data correctness.

## External Method Notes Consulted During Planning

- SAS GLIMMIX documentation, especially estimated likelihood interval concepts:
  <https://support.sas.com/documentation/onlinedoc/stat/930/glimmix.pdf>
- TMB overview and Laplace-approximation implementation context:
  <https://www.jstatsoft.org/article/view/v070i05>
- R profile-confidence interval convention:
  <https://stat.ethz.ch/R-manual/R-devel/library/stats/html/confint.html>
- ADEMP simulation framework:
  <https://pubmed.ncbi.nlm.nih.gov/30652356/>
- gllvm 2.0 context:
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC12704334/>
