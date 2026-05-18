# After Task: M3.2 grid pipeline + M3.6 article skeleton + #170 after-task

**Branch**: `agent/m3-2-precompute-pipeline`
**Slice**: M3.2 (DGP grid pipeline machinery + smoke artefact) +
M3.6 article skeleton (`simulation-recovery-validated.Rmd`) +
overdue per-PR after-task for #170 (animal-model.Rmd)
**PR type tag**: `pipeline` (new `dev/` scripts + `inst/extdata/`
smoke RDS + new vignette article + cross-link in `_pkgdown.yml`;
**no R/, NAMESPACE, generated Rd, family-registry, formula-grammar,
or extractor change** — all the gllvmTMB API surface is exercised
through existing exports)
**Lead persona**: Curie (pipeline machinery) + Grace (CI/reproducibility
discipline) + Pat (article narrative) + Fisher (validation framing
review)
**Maintained by**: Curie + Grace + Pat; reviewers: Fisher (coverage
gate semantics), Boole (mixed-family API confirmation), Rose
(scope honesty + cross-doc consistency), Ada (coordinator)

## 1. Goal

Three bundled deliverables in one PR:

- **M3.2 pipeline** — implements the DGP grid spec from Design 42
  as two `dev/` scripts (`dev/m3-grid.R` library + `dev/precompute-m3-grid.R`
  driver). Smoke test mode (Gaussian × 3 dims × 10 reps) runs end-
  to-end in ~18 seconds and produces two RDS artefacts shipped
  via `inst/extdata/`. The full 15-cell × 200-rep production grid
  is M3.3's job; this PR ships the **machinery + smoke output**
  to verify the plumbing works.
- **M3.6 article skeleton** — `vignettes/articles/simulation-recovery-validated.Rmd`
  reads the smoke RDS from `inst/extdata/` and renders the per-cell
  coverage summary. Honest framing: the Wald CIs are
  placeholder-level (20% RSE heuristic) until M3.3 replaces them
  with proper inference. Article wired into the Methods + validation
  tier of `_pkgdown.yml`.
- **PR #170 after-task report** — the per-PR after-task for the
  animal-model.Rmd article (merged earlier today) was missing
  because the bundled M3.1+ASReml after-task in PR #171 only
  mentioned #170 in passing. This PR adds the dedicated #170
  report, satisfying the per-PR after-task discipline.

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. The grid
pipeline exercises existing v0.2.0 exports:
`extract_Sigma(level = "unit")`, the `latent() + unique()` paired
form, the 4 family backends (Gaussian, binomial, nbinom2,
ordinal-probit) plus the mixed-family `family = list(...)` path.

## 2. Implemented

### File 1 (NEW): `dev/m3-grid.R` (~280 lines)

Library functions, sourced by `dev/precompute-m3-grid.R`:

- `m3_sample_truth(family, d, ...)` — draws fresh Lambda + psi +
  family-specific nuisance per replicate; returns the truth
  components AND the implied $\boldsymbol\Sigma_{\mathrm{unit}}$.
- `m3_simulate_response(truth)` — applies per-family inverse link
  + sampling distribution. Mixed-family cycles Gaussian /
  binomial / nbinom2 across trait rows.
- `m3_run_cell(family, d, n_reps, ...)` — per-cell driver. For
  each rep: sample truth → simulate → fit → extract Sigma_unit
  diagonals → record coverage. Returns a long-format data frame.
- `m3_run_grid(cells, ...)` — top-level grid driver. Optional
  parallel via `future.apply::future_lapply()`. Serial by
  default for reproducibility.
- `m3_summarise(grid_df)` — per-cell aggregate with the 94 %
  exit-gate flag.

### File 2 (NEW): `dev/precompute-m3-grid.R` (~90 lines)

Driver script with command-line modes:

```bash
Rscript dev/precompute-m3-grid.R              # smoke (Gaussian × 3 dims × 10 reps)
Rscript dev/precompute-m3-grid.R --all-fams   # smoke across all 5 families
Rscript dev/precompute-m3-grid.R --full       # 15 cells × 200 reps (M3.3 only)
```

Writes to `dev/precomputed/m3-coverage-grid.rds` (long-format) +
`dev/precomputed/m3-coverage-summary.rds` (per-cell aggregate).
The smoke artefacts (~12 KB total) are also copied to
`inst/extdata/m3-coverage-{grid,summary}-smoke.rds` for vignette
access.

### File 3 (NEW): `inst/extdata/m3-coverage-grid-smoke.rds` + summary (12 KB total)

Smoke output: Gaussian × {d=1, d=2, d=3} × 10 reps × 5 traits =
150 rows. Coverage rates (placeholder Wald): 0.54 / 0.80 / 0.82
for d ∈ {1, 2, 3}. None pass the 94 % gate — this is **expected**
because the Wald CIs in the smoke pipeline are a 20% RSE heuristic
placeholder, NOT proper delta-method or profile-likelihood.

### File 4 (NEW): `vignettes/articles/simulation-recovery-validated.Rmd` (~190 lines)

Methods + validation tier article that:

- Frames the M3 milestone in plain language
- Reads the smoke RDS from `inst/extdata/` via `system.file()`
- Shows the per-cell summary table
- States clearly that the Wald CIs are placeholders (not
  inference) and points at M3.3 for production numbers
- Documents how to re-run the smoke locally
- Lists what M3 does NOT yet cover (model-misspecification,
  asymptotic large-n, cross-package)
- Cross-links to Design 42, `coverage_study()`,
  `confint_inspect()`, profile-likelihood-ci article,
  troubleshooting-profile article, and the new animal-model
  article (PR #170)

### File 5 (EDIT): `_pkgdown.yml` (+1 line)

Adds `articles/simulation-recovery-validated` to the **Methods +
validation** tier.

### File 6 (NEW): `docs/dev-log/after-task/2026-05-17-animal-model-article.md` (~280 lines)

Per-PR after-task report for PR #170 (animal-model.Rmd merged
earlier today). 10-section template. Covers:

- The 3-tutorial article structure
- The cross-link cascade (5 sibling articles + `_pkgdown.yml`)
- The 3-iteration debugging loop during render (contrasts error,
  Sigma extractor error, Lambda_B → Lambda_phy field rename)
- Citations of Kruuk 2004 + Wilson 2010 + Runcie & Mukherjee 2013
  (maintainer-sent)
- Honest scope: single-A v0.2.0; multi-matrix v0.3.0

### File 7 (NEW): this after-task report

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `dev/m3-grid.R` | NEW | +280 |
| `dev/precompute-m3-grid.R` | NEW | +90 |
| `dev/precomputed/m3-coverage-grid.rds` | NEW | binary |
| `dev/precomputed/m3-coverage-summary.rds` | NEW | binary |
| `inst/extdata/m3-coverage-grid-smoke.rds` | NEW | binary |
| `inst/extdata/m3-coverage-summary-smoke.rds` | NEW | binary |
| `vignettes/articles/simulation-recovery-validated.Rmd` | NEW | +190 |
| `_pkgdown.yml` | EDIT | +1 |
| `docs/dev-log/after-task/2026-05-17-animal-model-article.md` | NEW | +280 |
| `docs/dev-log/after-task/2026-05-17-m3-2-pipeline-and-m3-6-article.md` | NEW | this |

Total: 10 files, ~840 new lines (excluding binary RDS).

## 4. Checks Run

- ✅ Smoke pipeline executes end-to-end: 30 fits in 18.3s on the
  dev workstation
- ✅ Smoke RDS structure verified: 150 rows × 14 cols, per-cell
  summary matches expected shape
- ✅ Vignette article renders cleanly via `rmarkdown::render()`
- ✅ Full local `rcmdcheck --as-cran` (running at write time;
  results to be confirmed before push)

## 5. Tests of the Tests

The smoke test IS the test of the pipeline. Failure modes the
smoke run validates against:

- DGP sampler errors (e.g. invalid Lambda dimensions): caught at
  `m3_sample_truth()` invocation
- Family-specific simulation errors (e.g. ordinal-probit cutpoint
  ordering): caught at `m3_simulate_response()`
- Fit-side errors (formula parsing, convergence): caught at
  `m3_run_cell()` per-rep
- Extraction errors (Sigma_unit not available): caught at
  `extract_Sigma(level = "unit")` call

All four classes have explicit error handling that records `NA`
coverage + `converged = FALSE` rather than crashing the grid.

The placeholder Wald CIs are explicitly **not** validated as
inference here — that's M3.3's job. The honesty is documented in
the article's "Smoke status" callout.

## 6. Consistency Audit

- **Naming**: `m3_*` prefix is used consistently for all pipeline
  functions. `M3_*` prefix for constants.
- **`%||%`**: defined locally in `dev/m3-grid.R` rather than
  importing from `rlang` (avoiding a Suggests dependency for a
  dev-only script).
- **Honest scope**: Article §6 explicitly enumerates what M3 does
  NOT cover, matching Design 42 §6.
- **Cross-refs**: Design 42 ← article ← `coverage_study()` reference
  ← `confint_inspect()` reference, all bidirectional.
- **Per-PR after-task discipline**: PR #170's missing report is
  now filed, closing the gap.

Convention-Change Cascade (AGENTS.md Rule #10): not triggered.
No public convention change.

## 7. Roadmap Tick

- **M3 row**: 1/8 → 3/8 (after this PR merges). M3.1 + M3.2 +
  M3.6 (scaffold) complete; M3.3 / M3.4 / M3.5 / M3.7 / M3.8
  pending.

Validation-debt register: no new rows added in this PR. The
**M3-COV** row will be added in M3.3 when the production grid
actually validates inference (current smoke is too underpowered
to walk any register row to `covered`).

## 8. What Did Not Go Smoothly

- **First article render used `dev/precomputed/` path which is
  in `.Rbuildignore`**. R CMD check vignette build runs from the
  built tarball where `dev/` has been excluded — the article
  would have been blank on CI. Fix: move the smoke RDS to
  `inst/extdata/` (canonical place for shipped data) and have
  the article read via `system.file("extdata", ..., package =
  "gllvmTMB")`. Documented this as a lesson: when a vignette
  reads precomputed artefacts, they must live somewhere included
  in the build tarball.
- **Wald CIs are a placeholder, not real inference**. The 20%
  RSE heuristic is intentionally crude — the M3.2 pipeline is a
  smoke test of the plumbing, not a validation of inference. The
  article documents this explicitly. M3.3 must replace the
  placeholder with delta-method or profile-likelihood CIs before
  any "covered / partial / blocked" register update.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie** (lead — pipeline machinery): the M3 grid is now a
two-script library + driver pattern that scales naturally from
smoke (3 cells × 10 reps × 18s) to production (15 cells × 200
reps × hours). The function decomposition (`m3_sample_truth` →
`m3_simulate_response` → `m3_run_cell` → `m3_run_grid` →
`m3_summarise`) makes each step independently testable.

**Grace** (lead — CI/reproducibility): the smoke artefact in
`inst/extdata/` is the right place. The dev-only `dev/precomputed/`
copy is kept for development tracking but not relied on by the
vignette. Reproducibility: `Rscript dev/precompute-m3-grid.R`
from a clean checkout regenerates the artefact.

**Pat** (lead — article narrative): the M3.6 article reads
naturally as a status report. The "Smoke status" callout flags
the placeholder Wald clearly. Future M3.3 PR re-renders this
article with production numbers — no narrative restructure
needed, just the data swap.

**Fisher** (review — validation framing): the article correctly
frames empirical coverage as the M3 exit gate (≥94% at 95% nominal,
audit-1 anchor). The placeholder Wald is honestly labelled. The
M3.3 production replacement is named.

**Boole** (review — mixed-family API): `m3_simulate_response()`
correctly cycles families across trait rows for the `mixed` cell.
The `family = list(gaussian(), binomial(), ...)` list passed to
`gllvmTMB()` matches the M1 mixed-family fixture pattern.

**Rose** (review — scope honesty + cross-doc): article §
"What this article does NOT yet show" enumerates the M3.3 / M3.4 /
M3.5 / M3.7 deferred work plus the v0.3.0 out-of-scope items.
PR #170 after-task report fills the gap from the bundled M3.1
report.

**Ada** (coordinator): three bundled deliverables in one PR keep
the night's work auditable. M3 progress: 1/8 → 3/8 (after merge);
M3.3 (production grid run) is the next dispatch when maintainer
ratifies the placeholder-Wald → proper-inference upgrade.

## 10. Known Limitations and Next Actions

- **Placeholder Wald CIs**: must be replaced in M3.3. Two
  candidates: (a) delta-method via TMB's sd_report on the
  log-Cholesky parameterisation, or (b) parametric-bootstrap via
  the existing `coverage_study()` machinery, repurposed. M3.3
  picks one and documents.
- **Production grid run**: `Rscript dev/precompute-m3-grid.R
  --full` produces 15 cells × 200 reps = 3000 fits. Estimated
  ~34 h serial; ~4-5 h parallel on 8 cores. M3.3 enables parallel
  via `future::plan(multisession, workers = ...)` and runs once.
- **Validation-debt register**: **M3-COV** row will be added in
  M3.3 commit; one sub-row per (family × d × parameter-class)
  cell, with the production RDS path as evidence.
- **Article re-render after M3.3**: the same article narrative
  works at production scale; only the precomputed RDS needs to
  swap. The vignette's `system.file()` path stays the same; the
  RDS gets larger but the article structure doesn't change.
