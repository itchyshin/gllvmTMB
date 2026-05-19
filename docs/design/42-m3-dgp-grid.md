# Design 42 — M3 DGP grid for inference completeness

**Maintained by**: Fisher (validation design lead) + Curie (DGP
fixtures lead). **Active reviewers**: Boole (parser correctness),
Rose (pre-publish + scope honesty), Ada (coordinator).
**Status**: Active — Phase M3.1 (in progress 2026-05-17).
**Closes**: M3.1 gate in `ROADMAP.md`. Coverage evidence feeds
validation-debt rows **CI-08** (`coverage_study()` empirical
coverage) and **CI-10** (mixed-family inference).

## 1. Goal

M3 is the milestone that turns "the engine fits a family-aware
model" into "the engine's confidence intervals hit nominal
coverage". The DGP grid is the empirical surface against which
that claim is verified. Concretely:

> For each (family × latent-rank × sample-size) cell, the 95 %
> target-appropriate CIs computed by `gllvmTMB` must contain the
> true target parameter ≥ 94 % of the time across R = 200 simulated
> replicates.

The 94 % gate is the audit-1 exit criterion (Fisher, 2026-05-14);
it's the standard threshold for "nominal up to Monte Carlo noise
at R = 200". Cells that fall short are flagged in the validation-
debt register as **partial** or **blocked** rather than papered
over.

## 2. Grid scope

Five family cells, three latent-rank cells, and one fixed sample-
size cell (n = 60 units, T = 5 traits, ~300 observations per fit).
The fixed-sample anchor matches the "moderate field study"
regime that motivates `gllvmTMB`; we are not claiming asymptotic
coverage at n = 10 000.

| Family cell | Engine path | Why included | Replicates |
|---|---|---|---|
| Gaussian | identity link, continuous | M1 baseline; should be the easiest cell | 200 |
| binomial (logit) | logit link, 1-trial Bernoulli | M2 baseline; tests the link-residual machinery | 200 |
| nbinom2 | log link, dispersion = φ | Common ecology count regime | 200 |
| ordinal-probit | probit link, K-1 cutpoints | Psychometrics regime; tests the cutpoint estimation | 200 |
| mixed-family | per-row family list (Gaussian + binomial + nbinom2 in the 2026-05-19 production run; ordinal-in-mixed needs an explicit later rerun) | The package's signature differentiator | 200 |

| Latent rank d | Why included |
|---|---|
| d = 1 | the simplest reduced-rank case; tests rotation-free Lambda |
| d = 2 | the canonical "shared + idiosyncratic" decomposition |
| d = 3 | tests whether spurious factors are caught at the M2.3 `check_identifiability()` boundary |

**Total cells**: 5 families × 3 dims = 15 cells.
**Total fits**: 15 × 200 = 3000 fits (plus convergence retries).

Each cell uses an independent set of 200 random seeds derived from
a single master seed (`m3_seed = 42L`). Reproducibility is verified
by committing the precomputed RDS artefact rather than re-running
on every render.

## 3. Per-cell DGP recipe

Each replicate `r ∈ 1..200` runs the following recipe:

1. **Sample truth.** For the chosen `(family, d)` cell, draw
   `Lambda_true ~ Uniform[-1.5, 1.5]^{T x d}`,
   `psi_true ~ Gamma(2, 2)^T`, and family-specific nuisance
   parameters (e.g. nbinom2 dispersion `phi ~ Gamma(5, 5)`,
   ordinal cutpoints `c_k = qnorm(k / (K+1))`).
2. **Simulate response.** Use `simulate_site_trait()` (M1 fixture
   API) extended with per-family responses; for ordinal, simulate
   K = 4 categories; for the current mixed-family production cell,
   alternate Gaussian, binomial, and nbinom2 across trait rows.
3. **Fit.** Run `gllvmTMB(..., family = ...)` with the same model
   structure as the DGP (no model-misspecification in M3.1; that's
   M3.4 work). The current M3 driver passes `unit = "unit"` and
   leaves `cluster` at its default placeholder. Do **not** pass
   `cluster = "unit"` for this grid: it makes
   `unique(0 + trait | unit)` match both the unit tier (`diag_B`) and
   the cluster tier (`diag_species`), adding a variance component that
   is not in the DGP and blocking unconditional bootstrap simulation.
4. **Compute CI for each explicit target.** Record the target and
   method for each interval row. The primary target is the diagonal
   of $\boldsymbol\Sigma_{\text{unit}}$ (per-trait unit-tier
   variance); `psi` is diagnostic; derived targets include
   communality $c_t^2$, family-specific dispersion (where present),
   and one representative loading-derived quantity (e.g.
   $|\Lambda_{1,1}|$ post-Procrustes alignment).
5. **Record.** Truth, point estimate, CI bounds, convergence
   flag, runtime, into a row of a long-format data frame.

**Target-scale update, 2026-05-19.** The production implementation
for run 26100827665 profiled `theta_diag_B` and therefore tested
`psi_t` coverage, while this design section's primary target is the
rotation-invariant total diagonal `Sigma_unit[tt]`. Treat `psi`
coverage as a diagnostic until a target-explicit rerun computes
total-variance CIs. See
`docs/dev-log/audits/2026-05-19-m3-3-target-scale-audit.md`.

Per-replicate runtime budgets (anchored on the
`agent/animal-model-article` workstation, Sun May 17 18:34 MDT 2026):

| Family | Mean fit time | Profile-CI time | Total/replicate |
|---|---|---|---|
| Gaussian | 5 s | 8 s | ~15 s |
| binomial | 15 s | 18 s | ~35 s |
| nbinom2 | 15 s | 18 s | ~35 s |
| ordinal-probit | 25 s | 25 s | ~55 s |
| mixed-family | 30 s | 30 s | ~65 s |

Aggregate: 200 × (15 + 35 + 35 + 55 + 65) = 41 000 s ≈ **11.4 h**
serial per (d) layer; across three d values, **~34 h serial**.

## 4. Computational strategy

Three honest options for fitting 34 h of compute into a sensible
turnaround:

**Option A — parallel local (recommended).** Use
`future::plan(multisession, workers = 8)` and run M3.2's pipeline
in parallel. On an 8-core machine the wall time drops to ~4-5 h —
fits within an overnight run. Requires no infrastructure changes;
adds `future` and `future.apply` to `Suggests` (already in).

**Option B — staged in two passes.** Phase 1 runs `d = 1` only at
n_rep = 200 (≈11 h serial → 1.5 h parallel). Phase 2 adds
`d = 2, 3` later. Used if Option A's wall time is unacceptable.

**Option C — reduce N per cell.** Drop to N = 100 per cell for the
default render; advertise N = 200 as the "research-grade" run.
This is what `simulation-recovery-validated.Rmd` (M3.6) will say
about itself. The trade-off is that the 94 % nominal-coverage gate
has wider Monte Carlo error at N = 100 (±5 pp at the 95 % level)
versus N = 200 (±3 pp).

The M3.2 pipeline (`dev/m3-grid.R` library +
`dev/precompute-m3-grid.R` driver) defaults to Option A on
`parallel::detectCores() - 1` workers, with N = 200, and graceful
degradation if a worker dies. Re-running is a single command:
`Rscript dev/precompute-m3-grid.R`.

## 5. Output

Two artefacts:

1. `dev/precomputed/m3-coverage-grid.rds` — long-format data frame
   with columns: `(cell, family, d, rep, trait_id,
   truth_diag_sigma, truth_psi, est_diag_sigma, est_psi,
   ci_prof_lo, ci_prof_hi, covered_prof, converged, runtime_s)`.
   Failed refits stay in this grid as one row per replicate with
   `trait_id = NA`, `covered_prof = NA`, and `converged = FALSE`.
   In the 2026-05-19 production artifact, `ci_prof_lo`,
   `ci_prof_hi`, and `covered_prof` are `psi` profile fields, not
   total `Sigma_unit` profile fields.
   The next target-explicit pilot adds `target` and `ci_method`
   columns before any production promotion.
2. `dev/precomputed/m3-coverage-summary.rds` — per-cell aggregate:
   `(cell, family, d, n_completed, n_failed, coverage_prof,
   passes_94pct_prof, mean_runtime_s)`. `n_completed` and
   `n_failed` count replicate fits; `coverage_prof` is computed on
   the converged `(rep, trait)` rows only.

Smoke artefacts are committed under `inst/extdata/` for the M3.6
article. Production artefacts are uploaded by the manual GitHub
Actions workflow and promoted to `inst/extdata/` only if the evidence
is publication-ready. The 2026-05-19 production run was not promoted
because the statistical gate failed.

## 6. Honest scope

### What M3.1 (this design note) does

- Defines the cells and the DGPs.
- Locks the 94 % coverage gate.
- Locks the per-cell DGP recipe.

### What M3.2 does

- Implements `dev/m3-grid.R` and `dev/precompute-m3-grid.R`.
- Runs the grid (Option A by default).
- Ships the two RDS artefacts.

### What M3.3 does

- Sanity-checks the target-explicit CI accuracy on the precomputed
  RDS: total `Sigma_unit[tt]` is the primary promotion target and
  `psi` is a diagnostic target.
- Flags any cell that misses the 94 % gate.
- Updates CI-08 / CI-10 (covered / partial / blocked) with the RDS
  path and audit report as evidence.

### What M3 does NOT cover (intentional boundary)

- **Model misspecification.** M3.1-M3.3 fit the true model
  structure. Tests of mis-specified rank, omitted family, or
  unobserved confounder are M3.4 boundary-regime work.
- **Asymptotic large-n behaviour.** The grid is anchored at
  n_units = 60. n = 600 + n = 6000 cells are deferred to a v0.3.0
  scaling-study design note.
- **Bayesian model comparison.** Not M3. Wald intervals may be
  recorded as diagnostics, but they do not replace target-explicit
  bootstrap/profile evidence for the promotion gate. The broader
  Wald-vs-profile-vs-bootstrap differential is M3.5 derived-quantity
  work.
- **Derived-quantity coverage at multivariate scale.** Communality
  and repeatability are partially covered here (one per fit). The
  full 6-extractor coverage grid is M3.5.
- **Cross-package agreement.** Phase 5.5 work; not M3.

## 7. Open questions (route via reviewer named, capture answer in
   the next refresh)

- **Q-Fisher-1.** Should we keep `mixed-family` as one cell, or
  split into `mixed-Gauss-binom`, `mixed-binom-nbinom2`, etc.? My
  bias is to keep it one cell at M3.1 (gates "the API works") and
  split into per-pair cells in M3.5 if budget allows.
- **Q-Curie-1.** The 200-rep budget assumes serial-per-cell runtime
  estimates from a single-machine bench. Should M3.2 ship a 10-rep
  smoke pipeline first (~3 h locally) before committing the
  full grid (4-5 h with Option A)?
- **Q-Boole-1.** The mixed-family DGP needs the
  `family = list(...)` API to dispatch per row. Confirmed working
  in M1.3 unit tests, but the larger n_traits regime here may
  surface boundary cases — let's pin the M3.2 pipeline to call
  `family_to_id()` once and reuse the result.
- **Q-Rose-1.** The Option A parallel default depends on the user's
  cores. Should the script clamp to `min(8, available - 1)` to
  match the CI runner's actual capacity? My read: yes, advertise
  `min(8, parallel::detectCores() - 1)`.

## 8. Cross-references

- Validation-debt register rows **CI-08** and **CI-10** (covered /
  partial / blocked per evidence tier).
- Engine path: `R/profile-ci.R`, `R/profile-derived.R`,
  `R/coverage-study.R` (existing single-cell helper).
- Articles: M3.6 will be `vignettes/articles/simulation-recovery-validated.Rmd`,
  replacing the reverted legacy article. Reads from
  `dev/precomputed/m3-coverage-summary.rds`.
- Prior art: Wilson et al. (2010) Tutorial-style structure;
  drmTMB's Phase 6 coverage-study slices (drmTMB design 31,
  reviewed 2026-05-14 by Jason).
- Sibling design docs: 05-testing-strategy.md (two-tier validation
  framework), 35-validation-debt-register.md (the ledger), and
  41-binary-completeness.md (M2 sibling).

## 9. Persona contributions to this draft

- **Fisher** (lead): cell selection, 94 % gate ratification,
  coverage-rate Monte Carlo error math, profile-CI parameter list.
- **Curie** (lead): DGP recipe details, per-cell runtime budgets,
  Option A parallel strategy.
- **Boole** (review): mixed-family API confirmation
  (Q-Boole-1 above).
- **Rose** (review): scope honesty — explicit "What M3 does NOT
  cover" section per the Phase 0A discipline upgrade.
- **Ada** (coordinator): cross-refs to validation-debt register
  and M3.6 article slot.
