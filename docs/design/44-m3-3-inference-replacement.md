# Design 44 — M3.3 inference-replacement strategy

**Maintained by**: Fisher (inference-method lead) + Curie
(pipeline-side integration). **Active reviewers**: Gauss
(TMB-side numerics), Boole (R API surface), Rose (scope honesty),
Ada (coordinator).
**Status**: Active design record — historical method comparison plus
the current target-explicit pilot plan before the next production
dispatch.
**2026-05-20 naming update**: `M3.3b` now names the surface-admission
gate in `docs/design/50-m3-3b-surface-admission.md`. The older
profile-likelihood subset below is retained as historical method
context only.
**Implementation update (2026-05-18/19)**: M3.3a has since moved to
the profile-primary path recorded in
`docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`.
The candidate-method comparison below is retained as historical
rationale; the production workflow dispatches the current
profile-CI grid with the post-M3.4 `init_strategy` option rather
than adding another inference method.
**Closes**: gap between M3.2 smoke (placeholder Wald) and the M3
exit gate (≥ 94 % empirical coverage at 95 % nominal).
**Backed by**: validation-debt rows **CI-08** (`coverage_study()`
empirical coverage) and **CI-10** (mixed-family inference).

## 1. Goal

The M3.2 / M3.2b / M3.2c smoke pipeline runs end-to-end on the
full 15-cell × 10-rep DGP grid (5 families × 3 latent ranks). The
CIs reported in the smoke are a **placeholder 20% RSE heuristic**
on `extract_Sigma(level = "unit")$Sigma` diagonals. That heuristic
is intentionally crude — not a real inference, just a smoke test
of the plumbing.

M3.3 replaces the placeholder with proper inference. The 94 %
coverage gate (audit-1) is the milestone goal.

## 2. Three candidate inference methods

The M3 grid currently records (truth, point estimate, CI bounds,
covered) for each `Sigma_unit_tt` diagonal. The three credible
ways to compute proper CIs on those diagonals:

### Method A — Parametric bootstrap (`bootstrap_Sigma()`)

Already-implemented, battle-tested via M1 mixed-family extractor
work. For each rep's fit:
1. `simulate(fit, nsim = B)` draws B parametric-bootstrap replicates.
2. Each replicate is refit (same formula).
3. `extract_Sigma(level = "unit")$Sigma` is collected across B refits.
4. Percentile CI bounds on each diagonal.

**Pros**:
- Production-quality machinery already shipped (`R/bootstrap-sigma.R`).
- Mixed-family aware (works on the M3.2c mixed cells).
- Honest about boundary regimes: if the original fit is at the
  boundary, the bootstrap distribution shows it.

**Cons**:
- O(B × n_reps × t_fit) compute. With B = 100, n_reps = 200,
  and avg 1.5 s/fit on a smoke-scale 5-trait × 60-unit fit:
  100 × 200 × 1.5 × 15 cells = 450 000 s ≈ 125 h serial. Brutal.
- Parametric bootstrap underestimates uncertainty in the truth
  used (the original fit's params), but for M3's "fresh truth
  per rep" design that's not a problem — we compare bootstrap
  CI vs the simulation's TRUE Sigma_unit, not vs the original
  fit's parameters.

### Method B — Profile-likelihood (`profile_ci_*()`)

The audit-1 gold standard. For each rep's fit:
1. `profile_targets(fit, ready_only = TRUE)` returns the set of
   parameters for which profile CIs are ready.
2. Profile each Sigma_unit diagonal via Lagrange fix-and-refit
   (existing `R/profile-derived.R` machinery).
3. CI is the parameter range where the profile log-likelihood
   stays within `qchisq(0.95, 1) / 2` of the maximum.

**Pros**:
- The CIs that the maintainer (Fisher's lane) actually wants
  reported.
- Respects skewness and boundaries; well-calibrated for
  non-Gaussian.
- Audit-1 explicitly called this out as the right approach.

**Cons**:
- Even slower per rep than bootstrap: typically 20–40× the fit
  cost for one parameter's full profile, because each profile
  point requires a Lagrange-fix refit.
- With T = 5 diagonals × 3 methods (lower, mid, upper) × ~10
  profile points each ≈ 150 fits per profile-CI run.
  150 × 200 × 15 cells × 1.5 s = 675 000 s ≈ 188 h serial.
- Even more brutal than bootstrap.

### Method C — Delta-method via `sd_report` (Wald, properly done)

TMB exposes a delta-method standard error on every reported
parameter via `TMB::sdreport()`. The M3.1 design note Section 3
mentioned this as a candidate.

**Pros**:
- Fast — one extra TMB call per rep, no refits.
- O(n_reps × t_fit) compute total. 200 × 15 × 1.5 ≈ 4500 s ≈ 75 min
  serial; ~10 min on 8 cores.
- Sigma_unit diagonals are derived quantities — needs a TMB-side
  `ADREPORT(diag(Sigma_unit))` declaration to expose SDs (one-line
  addition to `src/gllvmTMB.cpp` per Gauss; or compute via the
  existing `extract_Sigma(..., se = ?)` path if one exists).

**Cons**:
- Wald (symmetric) CIs under-cover near boundaries and on skewed
  posteriors. Documented gllvmTMB behaviour: rotation-invariant
  Sigma diagonals near zero, count-family dispersion near zero,
  etc., all violate symmetry assumptions.
- Method A or B is the proper validation step; C is more like
  "fast first pass to see if the engine is even close".

## 3. Historical recommendation: hybrid (A → B as time allows)

This section records the method comparison that led to the first
M3.3 production run. It is no longer the active dispatch order by
itself: the 2026-05-19 artifact review and target-scale audit showed
that the next slice must first make the interval target explicit.

Three-step rollout, dispatched as separate slices:

### M3.3a — Parametric bootstrap on Sigma_unit diagonals (default)

- **Engine work**: `dev/m3-grid.R` calls
  `bootstrap_Sigma(fit, n_boot = B, level = "unit",
  link_residual = "none")` per rep. Replace the 20% RSE placeholder
  with bootstrap percentile bounds on the fitted ordinary latent
  covariance target.
- **Compute trade-off**: smoke runs B = 30 (fast). Production
  M3.3a-full runs B = 100. Total smoke: 15 × 10 × 30 × ~1.5 s
  ≈ 6750 s ≈ ~2 h. Production: 15 × 200 × 100 × ~1.5 s ≈ 450 000 s.
- **Run strategy**: smoke locally; production runs in CI overnight
  or on a dedicated workstation. Save coverage RDS as before.

Closes the placeholder-Wald gap. **The M3.3a smoke output
matches the audit's "≥94% empirical coverage" wording so long
as the bootstrap CIs cover; if any cell falls short, M3.4
investigates that boundary regime.**

### Former M3.3b label — profile-likelihood subset (historical)

Only the d=1 Gaussian + binomial + ordinal-probit cells, R = 50
reps (not 200). Verifies that profile CIs hit ≥94% where bootstrap
does. The slice serves as a cross-validation of M3.3a's bootstrap
output. This is no longer the active meaning of M3.3b; profile subset
checks can return later as one admitted surface under Design 50. If
they agree to 1-2 pp, we have high confidence in the smaller-N
production grid. ~12 h compute.

### M3.3c — Delta-method Wald as the fast diagnostic

Implements the `sd_report` on Sigma_unit diagonals (TMB-side
ADREPORT addition + R-side `extract_Sigma(se = TRUE)` integration).
Used for `confint(fit, method = "wald")` on extractor outputs.
Independent of the M3 grid validation; lands as a separate
post-M3 polish PR. Maintainer's call on whether this is M3.3c or
deferred to v0.3.0.

## 4. Mixed-family + boundary regimes from M3.2c

The M3.2c smoke surfaced **two patterns** worth M3.3 investigating:

- **nbinom2 cells**: 5–10/50 reps fail to converge. Worth a
  retry-from-warmup pass before declaring non-convergence. Design
  43 Tier A #4 (single-trait warmup) is the candidate fix.
- **mixed-family d=2,3 cells**: 15/50 reps fail to converge.
  Higher complexity due to per-row dispatch. Same warmup fix
  hypothesised.

Both flagged for **M3.4 boundary-regimes** dispatch alongside
M3.3. M3.3 can either:
- (a) document failed reps in the coverage RDS as `NA` (smoke
  pattern); M3.4 addresses the cause; or
- (b) implement single-trait warmup as part of M3.3 (engine-side
  change in `R/fit-multi.R` to expose `init_strategy =
  "single_trait_warmup"` per Design 43).

Recommendation: (a) held for the first implementation wave — M3.3
stayed focused on inference while M3.4 shipped the warmup and phi
clamp. The current M3.3 pilot should use those mitigations without
turning this slice into a new convergence-engine PR.

## 5. Compute budget and CI plan

Compute estimates are anchored on M3.2c smoke runtimes and the
post-M3.4 warm-start mitigation lane. M3.3 production runs by
manual GitHub Actions `workflow_dispatch`, with one Linux matrix job
per family × dimension cell and per-cell RDS artifacts uploaded for
later aggregation.

| Run | Cells × reps × B | Estimated wall | Output |
|---|---|---|---|
| **Smoke M3.3a** | 15 × 10 × 30 | ~2 h serial / ~20 min ×8 cores | `inst/extdata/m3-coverage-grid-smoke.rds` refresh |
| **Production M3.3a** | 15 × 200 | Manual Actions matrix; bounded by slowest cell and `max-parallel` | Per-cell workflow artifacts; follow-up PR aggregates to `inst/extdata/m3-coverage-grid-production.rds` if the evidence is publication-ready |
| **Former profile-subset cross-validation** | 9 × 50 × N/A (profile) | ~12 h serial / ~2 h ×8 cores | `inst/extdata/m3-coverage-profile-subset.rds` |

The workflow PR only installs reproducible dispatch and artifact
capture. The production evidence is not claimed until a manual run
finishes, the artifacts are reviewed, and a follow-up PR records the
coverage summary, validation-debt status, and reader-facing figures.

## 6. Validation-debt register interaction

M3.3a smoke → `partial` (does not yet meet 94% gate at smoke
scale; the smoke is intentionally underpowered).

M3.3a production → walks per-family rows to `covered` if the cell
hits ≥94%, or to `partial` / `blocked` with the failure-mode
flagged.

**2026-05-19 production outcome.** Manual Actions run
26100827665 completed all 15 cells with `n_reps = 200` and
`init_strategy = "single_trait_warmup"`, but the artifact review
found that only 2/15 cells cleared the 94 % profile-psi coverage
gate. The review is filed at
`docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`.
No production RDS was promoted to `inst/extdata/`, and CI-08 / CI-10
remain `partial`.

The planned 15 sub-row production promotion is deferred until the
failure mode is diagnosed and a rerun supports the gate. The current
evidence points to profile-CI calibration / convergence triage rather
than publication-ready coverage.

**2026-05-19 target-scale follow-up.** The failure-mode ledger showed
that every uncovered converged row missed above the `psi` profile
upper bound. The target-scale audit then found that the production
grid's `covered_prof` column validates `psi`, while Design 42's
primary validation target is total `Sigma_unit[tt]`. The next M3.3
implementation slice should make the artifact target-explicit:
`psi` as a diagnostic target, total `Sigma_unit[tt]` as the primary
promotion target. The same audit also keeps `glmmTMB` as the direct
single-trait nbinom2 comparator and keeps `galamm` for multivariate
Gaussian/binomial/Poisson latent-loading comparisons, not nbinom2.

**Dispatch refinement after Gauss + Curie review.** Do not launch
the full 15-cell production rerun next. Add target-explicit columns
to the M3 grid first:

- `target = "psi"` with `ci_method = "profile"` for the existing
  profile-`psi` diagnostic rows;
- `target = "Sigma_unit_diag"` with `ci_method = "bootstrap"` for
  the primary total-variance rows, using the existing
  `confint(fit, parm = "Sigma_unit", method = "bootstrap")` /
  `bootstrap_Sigma(link_residual = "none")` path so the fitted
  target matches the DGP truth
  $\operatorname{diag}(\Lambda\Lambda^\top + \Psi)$ rather than the
  marginal latent response variance with family/link residuals added;
- optional `ci_method = "wald"` later as a fast diagnostic, not the
  M3.3 gate.

For ordinary `latent()` fits, total `Sigma_unit[tt]` is a nonlinear
function of rotation-equivalent loadings plus `psi`. A derived
profile fix-and-refit path is possible, but it is a larger numerical
slice than the next pilot. Bootstrap total-Sigma rows are therefore
the next safest primary target; derived profiles can follow if the
bootstrap pilot exposes a calibration problem.

Curie's pilot cells are:

1. `gaussian-d2` — checks the Gaussian d = 2 anomaly.
2. `nbinom2-d1` — checks the simplest count-family failure.
3. `mixed-d2` — checks the first nontrivial mixed-family rank.

`ordinal_probit-d1` waits until ordinal bootstrap simulation is
legitimate. The current simulator covers family IDs 0-5 and falls
back with a warning for unsupported family IDs; ordinal-probit is
family ID 14.

Artifact columns for the pilot should be:
`cell`, `family`, `d`, `rep`, `trait_id`, `target`, `truth`,
`estimate`, `ci_method`, `ci_level`, `ci_lo`, `ci_hi`, `covered`,
`ci_available`, `fit_converged`, `ci_failed`, `miss_side`,
`runtime_s`, `n_boot`, `n_boot_failed`, `init_strategy`,
`seed_base`.

Per-cell summaries should be:
`cell`, `family`, `d`, `target`, `ci_method`, `n_reps`,
`n_completed`, `n_failed`, `n_trait_rows`, `n_ci_missing`,
`n_boot_failed`, `n_boot_attempted`, `boot_fail_rate`, `coverage`,
`miss_below`, `miss_above`, `median_est_truth_ratio`,
`mean_runtime_s`, `pilot_status`.

Use `n_reps = 10` for smoke, `n_reps = 50` for pilot, and
`n_reps = 200` for promotion. Pilot labels are `PASS_TO_SCALE`,
`TARGET_FAIL`, and `COMPUTE_FAIL`.

Implementation guard: the M3 driver should pass `unit = "unit"` and
leave `cluster` at the default placeholder. Passing
`cluster = "unit"` double-registers `unique(0 + trait | unit)` as
both `diag_B` and `diag_species`, which adds an unintended cluster
variance component and makes `bootstrap_Sigma()` fall back to
conditional simulation.

## 7. Honest scope: what M3.3 does NOT do

- **REML-based CIs**: not in v0.2.0 (REML is post-CRAN per README).
- **Multi-matrix animal-model coverage**: ANI-09 follow-up
  (v0.3.0). M3.3 grid uses ordinary `latent()` only.
- **Random slopes coverage**: pre-engine-support; v0.3.0.
- **Cross-package agreement**: Phase 5.5.
- **Bayesian model comparison**: not in scope.

## 8. Cross-references

- Design 42 — M3 DGP grid specification.
- Design 43 — ASReml speed techniques (Tier A #4
  single-trait-warmup is now the implemented M3.4 mitigation for
  phi-bearing warm starts).
- `R/coverage-study.R` — per-fit parametric-bootstrap coverage
  (complementary; takes an existing fit and bootstraps from its
  parameters as truth).
- `R/bootstrap-sigma.R` — the existing machinery for
  bootstrap CIs on Sigma summaries.
- `R/profile-ci.R` + `R/profile-derived.R` — profile machinery for a
  future admitted profile subset.
- `inst/extdata/mixed-family-fixture.rds` — the M1 pattern the
  M3.2c integration mirrored.
- `vignettes/articles/simulation-recovery-validated.Rmd` — the
  user-facing article that re-renders when M3.3 ships proper CIs.

## 9. Open questions

- **Q-Fisher-1**: for target-explicit total `Sigma_unit[tt]`,
  should the pilot use `n_boot = 30` or `n_boot = 100`? Current
  recommendation: `n_boot = 30` for `n_reps = 50` pilot, then
  `n_boot = 100` only if the pilot reaches `PASS_TO_SCALE`.
- **Q-Gauss-1**: `ADREPORT(diag(Sigma_unit))` / delta-method Wald is
  useful as a fast diagnostic, but it should not replace bootstrap
  or profile evidence for the M3.3 promotion gate.
- **Q-Curie-1**: ordinal-probit bootstrap is blocked until
  `simulate.gllvmTMB_multi()` supports family ID 14 rather than
  falling back to Gaussian-on-link-scale simulation.
- **Q-Rose-1**: the smoke RDS should replace placeholder-Wald
  coverage with target-explicit rows; if the old columns remain for
  backward compatibility, their names must state the target.

## 10. Persona contributions to this draft

- **Fisher** (lead): three-method cost-benefit; A → B → C
  rollout sequence; 94% gate framing.
- **Curie** (lead, pipeline-side): smoke-vs-production split;
  RDS file naming + structure continuity with M3.2 series.
- **Gauss** (review, numerics): TMB-side ADREPORT requirements
  for delta-method (Q-Gauss-1 above); confirms the existing
  `bootstrap_Sigma()` machinery is the path of least resistance.
- **Boole** (review): `bootstrap_Sigma()` API surface fits cleanly;
  mixed-family integration confirmed via M3.2c precedent.
- **Rose** (review): scope honesty in §7; Q-Rose-1 above flags
  the placeholder-vs-replace decision.
- **Ada** (coordinator): original M3.3 method slicing; deferral of
  delta-method Wald work to post-M3 polish; cross-link to M3.4
  boundary work.
