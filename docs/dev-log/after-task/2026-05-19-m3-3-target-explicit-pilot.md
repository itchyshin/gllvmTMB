# After Task: M3.3 Target-Explicit Pilot Implementation

**Branch**: `codex/m3-3-target-explicit-pilot-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Fisher / Curie / Gauss / Grace / Rose / Shannon`

## 1. Goal

Implement the next M3.3 pilot slice so the DGP grid records which
interval target is being validated. The old profile path remains as a
`psi` diagnostic; total `Sigma_unit[tt]` is added as the primary
bootstrap target for the next smoke/pilot/promotion sequence.

## 2. Implemented

- `dev/m3-grid.R` now accepts `targets`, `n_boot`, and `ci_level`.
- `target = "psi"` rows keep the existing profile-CI path on
  `theta_diag_B`, transformed as `exp(2 * x)`.
- `target = "Sigma_unit_diag"` rows use `bootstrap_Sigma()` on
  `extract_Sigma(level = "unit")$Sigma` diagonals.
- Each target row records `truth`, `estimate`, `ci_method`, `ci_lo`,
  `ci_hi`, `covered`, `ci_available`, `ci_failed`, `miss_side`,
  `n_boot`, and `n_boot_failed`.
- `m3_summarise()` remains backward-compatible for old artifacts and
  now reports target-specific `coverage`, one-sided miss counts,
  median estimate/truth ratio, bootstrap failure counts, and
  `pilot_status`.
- The M3 driver no longer passes `cluster = "unit"`. That call made
  `unique(0 + trait | unit)` register in both `diag_B` and
  `diag_species`; the fixed path leaves `cluster` at the default
  placeholder so the intended `latent + unique` unit-tier DGP is fit
  and unconditional bootstrap simulation is available.
- `dev/precompute-m3-grid.R` now exposes `--targets=`,
  `--n-boot=`, and `--ci-level=` and saves those fields in artifact
  metadata.

## 3. Files Changed

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `docs/design/42-m3-dgp-grid.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-m3-3-target-explicit-pilot.md`

## 3a. Mathematical Contract

| Validation target | Simulated truth | Estimate in code | CI path | Role |
|---|---|---|---|---|
| `psi_t` | `truth$psi[t]` | `fit$report$sd_B[t]^2` | `tmbprofile_wrapper(name = "theta_diag_B", transform = exp(2 * x))` | diagnostic |
| `Sigma_unit[tt]` | `diag(tcrossprod(Lambda_true) + diag(psi_true))[t]` | `diag(extract_Sigma(fit, level = "unit")$Sigma)[t]` | `bootstrap_Sigma(level = "unit", what = "Sigma")` percentile CI | primary pilot |
| Bootstrap family gate | family IDs in fitted `family_id_vec` | `m3_bootstrap_supported()` | allow IDs `0:5`; block ordinal ID `14` with unavailable CI rows | scope honesty |
| DGP grouping | unit-tier `latent + unique`; no cluster tier | `fit$use$diag_species == FALSE` after leaving `cluster` default | `.check_simulate_unconditional(fit)$can_redraw == TRUE` | bootstrap validity |

## 3b. Decisions and Rejected Alternatives

**Decision**: keep the existing `covered_prof` columns and add
target-explicit long-form columns.
**Rationale**: old artifact review scripts remain readable while the
next pilot uses the correct target/method columns.
**Rejected alternative**: replace `covered_prof` in place.
**Confidence**: high.

**Decision**: treat high bootstrap refit failure as `COMPUTE_FAIL`.
**Rationale**: a percentile CI can be numerically present while too
many refits failed to make the interval trustworthy.
**Rejected alternative**: rely only on `ci_available`.
**Confidence**: high.

**Decision**: fix the M3 driver by leaving `cluster` at the default
placeholder rather than changing engine semantics for `unit == cluster`.
**Rationale**: this pilot's DGP has no third clustering tier; a broader
engine guard belongs in a separate API/diagnostic slice if needed.
**Rejected alternative**: patch `fit-multi.R` during this pilot PR.
**Confidence**: medium-high.

## 4. Checks Run

- `git status --short --branch`
  - Outcome: branch `codex/m3-3-target-explicit-pilot-2026-05-19`
    with only this lane's files modified.
- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,files --jq '.[] | {number,title,headRefName,files: [.files[].path]}'`
  - Outcome: no open PR collision before editing.
- `git log --all --oneline --since='6 hours ago'`
  - Outcome: recent M3 / CI merges inspected; no competing owner for
    this lane's files.
- `Rscript --vanilla -e 'invisible(parse(file = "dev/m3-grid.R")); invisible(parse(file = "dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  - Outcome: `parse ok`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); stopifnot(identical(m3_normalise_targets("all"), M3_INTERVAL_TARGETS)); stopifnot(m3_target_method("Sigma_unit_diag") == "bootstrap"); stopifnot(identical(m3_miss_side(1, 0, 2, TRUE, TRUE), "covered")); cat("helpers ok\n")'`
  - Outcome: `helpers ok`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); df <- data.frame(cell="gaussian-d1", family="gaussian", d=1L, rep=c(1L,1L,1L,1L), trait_id=c(1L,2L,1L,2L), converged=TRUE, fit_converged=TRUE, target=rep(c("psi","Sigma_unit_diag"), each=2), ci_method=rep(c("profile","bootstrap"), each=2), truth=c(1,2,3,4), estimate=c(1.1,1.8,2.9,4.2), ci_lo=c(.5,1.5,2.5,3.5), ci_hi=c(1.5,2.5,3.5,4.5), covered=c(TRUE,TRUE,TRUE,TRUE), ci_available=TRUE, runtime_s=1, miss_side="covered", n_boot=c(NA,NA,10,10), n_boot_failed=c(NA,NA,1,1), covered_prof=c(TRUE,TRUE,NA,NA)); print(m3_summarise(df), row.names=FALSE)'`
  - Outcome: two summary rows; bootstrap row reported
    `n_boot_failed = 1`, `n_boot_attempted = 10`,
    `boot_fail_rate = 0.1`.
- `Rscript --vanilla -e 'source("dev/m3-grid.R"); old <- data.frame(cell="gaussian-d1", family="gaussian", d=1L, rep=c(1L,1L), trait_id=1:2, covered_prof=c(TRUE,FALSE), converged=TRUE, runtime_s=c(1,1)); print(m3_summarise(old), row.names=FALSE)'`
  - Outcome: legacy no-`target` artifacts still summarise with the old
    `coverage_prof` / `passes_94pct_prof` columns.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); truth <- m3_sample_truth("gaussian", 1, n_traits=2, n_units=25, seed=1); sim <- m3_simulate_response(truth); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit), data = sim$data, family = gaussian(), unit="unit", cluster="unit", control=gllvmTMBcontrol(init_strategy="default")); cat("diag_species=", fit$use$diag_species, "\n"); print(gllvmTMB:::.check_simulate_unconditional(fit));'`
  - Outcome: explicit `cluster = "unit"` reproduces
    `diag_species = TRUE` and `can_redraw = FALSE`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); truth <- m3_sample_truth("gaussian", 1, n_traits=2, n_units=25, seed=1); sim <- m3_simulate_response(truth); fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit), data = sim$data, family = gaussian(), unit="unit", control=gllvmTMBcontrol(init_strategy="default")); print(fit$use); print(gllvmTMB:::.check_simulate_unconditional(fit));'`
  - Outcome: `diag_species = FALSE`, `can_redraw = TRUE`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); grid <- m3_run_cell("gaussian", d = 1, n_reps = 1, seed_base = 20260521L, n_units = 25L, n_traits = 2L, targets = c("psi", "Sigma_unit_diag"), n_boot = 2L, ci_level = 0.80, verbose = FALSE); print(m3_summarise(grid), row.names = FALSE)'`
  - Outcome: emitted separate `psi/profile` and
    `Sigma_unit_diag/bootstrap` summaries; both had zero bootstrap
    refit failures in that toy run.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --targets=Sigma_unit_diag --n-boot=2 --ci-level=0.80 --out-dir=/tmp/gllvmtmb-m3-target-pilot-smoke --out-prefix=smoke2`
  - Outcome: CLI driver completed and saved smoke RDS files under
    `/tmp/gllvmtmb-m3-target-pilot-smoke/`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); source("dev/m3-grid.R"); grid <- m3_run_cell("nbinom2", d = 1, n_reps = 1, seed_base = 20260522L, n_units = 25L, n_traits = 2L, targets = "Sigma_unit_diag", n_boot = 2L, ci_level = 0.80, verbose = TRUE); print(grid[, c("cell", "target", "ci_method", "trait_id", "fit_converged", "ci_available", "n_boot_failed", "miss_side", "runtime_s")], row.names = FALSE); print(m3_summarise(grid), row.names = FALSE)'`
  - Outcome: original fit converged; one of two bootstrap refits failed;
    summary labelled the toy cell `COMPUTE_FAIL`.
- `git diff --check`
  - Outcome: clean.

## 5. Tests of the Tests

No new `testthat` tests were added because this is a dev-only
precompute pipeline under `dev/`, not code loaded by R CMD check. The
script-level checks satisfy the failure/boundary spirit of the test
contract: the `cluster = "unit"` reproducer showed `diag_species =
TRUE` and conditional-bootstrap fallback before the driver fix; the
fixed path showed `diag_species = FALSE` and `can_redraw = TRUE`; the
`nbinom2` smoke exercised a bootstrap-refit failure path.

## 6. Consistency Audit

- `rg -n 'profile-psi primary|profile.*primary target|M3-COV' ROADMAP.md docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md dev/m3-grid.R dev/precompute-m3-grid.R`
  - Outcome: no hits.
- `rg -n 'cluster\s*=\s*"unit"' dev/m3-grid.R docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md`
  - Outcome: hits are only the intentional implementation/design
    guard text; no active `gllvmTMB(..., cluster = "unit")` call
    remains in `dev/m3-grid.R`.
- `rg -n 'n_boot_failed|boot_fail_rate|n_boot_attempted' dev/m3-grid.R dev/precompute-m3-grid.R docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md`
  - Outcome: summary columns and Design 44 agree.

## 7. Roadmap Tick

M3 remains `3/8`. This implements the target-explicit pilot machinery
that the roadmap already named as the next M3.3 slice; it does not
promote CI-08 / CI-10 to covered.

## 8. What Did Not Go Smoothly

The first bootstrap smoke exposed the hidden `cluster = "unit"` problem:
the M3 fit had `diag_species = TRUE`, so `simulate()` fell back to
conditional simulation. That was not a bootstrap-method problem; it was
an M3 driver grouping bug. The second small catch was that summary
aggregation for all-`NA` bootstrap columns failed on non-bootstrap
targets; the mock summary caught it before commit.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the slice implementation-focused but stopped when the
bootstrap warning revealed a deeper DGP/fit mismatch.

**Fisher** kept the target distinction sharp: `psi` is still useful,
but total `Sigma_unit[tt]` is the promotion target.

**Curie** added the bootstrap-failure accounting so a numerically
available interval cannot hide an unstable resampling path.

**Gauss** shaped the grouping fix: remove the unintended `diag_species`
tier from the M3 driver before trusting bootstrap evidence.

**Grace** kept the CLI driver smoke in scope and confirmed the manual
precompute path writes artifacts.

**Rose** checked that Design 42 / 44 now say why `cluster = "unit"` is
wrong for this grid and that target columns match the implementation.

**Shannon** was applied as open-PR and recent-commit inspection before
editing shared files.

## 10. Known Limitations And Next Actions

- The next statistical run should be the real pilot, not a full
  production rerun: `gaussian-d2`, `nbinom2-d1`, and `mixed-d2`, with
  `n_reps = 50`, `n_boot = 30`, and
  `init_strategy = "single_trait_warmup"`.
- `ordinal_probit-d1` remains blocked for bootstrap until ordinal
  simulation supports family ID 14.
- `nbinom2` still looks fragile in the tiny smoke: the original fit
  converged, but one of two bootstrap refits failed. The new
  `COMPUTE_FAIL` pathway is doing its job; the pilot will tell us
  whether the failure rate persists at `n_boot = 30`.
- No validation-debt row changes were made in this PR.
