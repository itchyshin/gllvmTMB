# After-task: restore nightly full-check to green (run #4, 2026-06-03)

**Scope.** The scheduled `full-check.yaml` run #4 on 2026-06-03
(run id 26880216038, head `ebf4ff0`) went RED with `[ FAIL 15 | WARN 3 |
SKIP 57 | PASS 8144 ]` on the ubuntu/windows jobs (15 on macOS). Every
failure was a STALE TEST expectation — fallout from this week's merged
non-Gaussian random-slope guard relaxations (#422/#424 phylo_dep,
#427 spatial_indep, #429 spatial_dep). NO engine change was made; the
engine is correct on all three paths. Branch
`claude/fix-nightly-run4-stale-tests`, DRAFT PR (do not merge).

Reference: #343 (CI health) / #341.

## Confirmed failures (quoted from the nightly job logs)

Three classes, consistent across all three OS jobs (so not flakes):

### A. Fail-loud probe stale (poisson now ADMITTED on the dep slope)

- `test-phylo-dep-slope-gaussian.R:398:3` — "non-Gaussian phylo_dep slope
  is deferred (fail-loud)": `Expected `suppressMessages(...)` to throw a
  error.`
- `test-relmat-dep-slope-gaussian.R:189:3` — "non-Gaussian relmat_dep
  slope aborts loud": `Expected `suppressMessages(...)` to throw a error.`
- `test-animal-dep-slope-gaussian.R:190:3` — "non-Gaussian animal_dep
  slope aborts with a clear error": `Expected `suppressMessages(...)` to
  throw a error.` (NOT in the task's named suspect list — found in STEP 1.)

All three probe the dep-slope guard with `family = stats::poisson()`.
#422/#424 (PHY-18) relaxed the shared `use_phylo_dep_slope` guard
(`R/fit-multi.R:883`) from gaussian-only to the per-family allowlist
`c(0L, 1L, 2L, 4L, 5L, 7L, 14L)`, which INCLUDES poisson (runtime id 2).
relmat_dep (`phylo_dep(..., vcv = A)`) and animal_dep
(`animal_dep(..., pedigree = ped)`) route through the SAME guard, so
poisson is admitted on all three and the fit no longer aborts → the
`expect_error` fails.

### B. spatial_unique smoke asserts the wrong report slots

- `test-matrix-slope-spatial-unique.R` lines 231, 258, 274, 288, 305, 322
  (binomial-probit, ordinal_probit, poisson, nbinom2, Gamma, Beta):
  `Expected `fit$tmb_data$n_lhs_cols` to equal 2L. actual: 1` and
  `Expected `length(sd_b)` to equal 2L.`

### C. spatial_indep health/diag asserts intercept-only slots

- `test-matrix-slope-spatial-indep.R:193:3`, `:263:3` (binomial-probit,
  Gamma; other families honest-skipped on non-convergence):
  `Expected `isTRUE(fit$use$spatial_indep)` to be TRUE. actual: FALSE`
  and `Expected `length(log_tau)` > 0L.` (where
  `log_tau <- fit$report$log_tau_spde`). NOT in the task's named suspect
  list — found in STEP 1.

## Diagnosis: all stale tests, no engine regression

### A (dep fail-loud)
The guard is intentionally relaxed. tweedie (runtime family id 6) is NOT
on the allowlist, so it stays reserved fail-loud. #429 already mirrored
exactly this in `test-spatial-dep-slope-gaussian.R` (poisson → tweedie).

### B (spatial_unique) — wrong report slots, not a regression
`spatial_unique(1 + x | site)` routes through the augmented SPDE slope
engine (`use_spde_slope`), which:
- sets `tmb_data$n_lhs_cols_spde == 2L` (intercept + slope SPDE field;
  `R/fit-multi.R:1986-1988`), and
- reports the 2×2 block as `report$sd_spde_b` / `report$cor_spde_field`
  with the direct parameter `log_sd_spde_b` (`src/gllvmTMB.cpp:1260-1267,
  483`).

The test asserted `tmb_data$n_lhs_cols` and `report$sd_b` / `log_sd_b`,
which are the SEPARATE **phylo_dep** correlated-slope slots
(`n_lhs_cols` defaults to 1L on a pure spatial fit; `R/fit-multi.R:2108`,
`src/gllvmTMB.cpp:1007-1009`). So the test was reading the wrong slot
family. The engine value `n_lhs_cols == 1` is CORRECT for a pure spatial
fit.

Why it never failed before: there is NO Gaussian cell in this file, and
before #427 the gaussian-only guard aborted every non-Gaussian fit, so
`run_slope_spatial_family()` honest-skipped at construction
(`test-...:212-217`) and the wrong assertions were never reached. #427
admitted the families → the fits now converge and hit the wrong slots.

Fix: point the smoke bar (`expect_slope_spatial_smoke`) at the SPDE slots
(`n_lhs_cols_spde`, `sd_spde_b`, `log_sd_spde_b`). Intent (2-column
augmented slope active + finite SDs + a CI-smoke branch) unchanged.

### C (spatial_indep) — intercept-only slots inactive on the augmented path
The augmented `spatial_indep(1 + x | coords)` rewrites
(`R/brms-sugar.R:2979-2989`) to an `spde` covstruct carrying
`.spatial_unique_augmented = TRUE` + `.spatial_indep_augmented = TRUE`,
NOT `.spatial_indep = TRUE`. Therefore:
- `is_spatial_indep` (`R/fit-multi.R:698-701`, keys on `.spatial_indep`)
  is FALSE → `fit$use$spatial_indep` FALSE **by design**; and
- `use_spde <- FALSE` on the slope path (`R/fit-multi.R:306`) maps
  `log_tau_spde` off (`:2744`) → `report$log_tau_spde` empty **by
  design**. The augmented diagonal field reports `sd_spde_b` instead.

The diagonal-indep constraint on this path is `use_spde_slope_indep`
(`atanh_cor_spde_b` pinned to 0 in the map, `R/fit-multi.R:2809`), and
`fit$use$spde_slope` is the live activation flag. So the test's
`isTRUE(fit$use$spatial_indep)` and `length(report$log_tau_spde) > 0`
were stale (intercept-only slots). The diagonal-by-construction
`rho:spatial` token assertion is unchanged and still valid.

Fix: assert `fit$use$spde_slope` (engine active) and per-field
`report$sd_spde_b` finiteness; the rho-token diagonal assertion is kept.
Also softened the now-stale "augmented intercept+slope LHS is phylo-only"
construction-skip message and the file-header "NO SPDE augmented-slope
path" block (both described the pre-#427 state).

## Fix applied (per test)

| File | Stale assertion | Fix |
|---|---|---|
| `test-phylo-dep-slope-gaussian.R` | `expect_error(... poisson())` | probe family `poisson()` → `tweedie()`; rename test + comment (poisson now admitted) |
| `test-relmat-dep-slope-gaussian.R` | `expect_error(... poisson())` | same: → `tweedie()`; rename + comment (shared phylo_dep guard) |
| `test-animal-dep-slope-gaussian.R` | `expect_error(... poisson())` | same: → `tweedie()`; rename + comment (shared phylo_dep guard) |
| `test-matrix-slope-spatial-unique.R` | `n_lhs_cols == 2`, `length(sd_b) == 2`, profile `log_sd_b` | → `n_lhs_cols_spde == 2`, `length(sd_spde_b) == 2`, profile `log_sd_spde_b`; header/comment updated |
| `test-matrix-slope-spatial-indep.R` | `isTRUE(use$spatial_indep)`, `length(log_tau_spde) > 0` | → `isTRUE(use$spde_slope)`, `length(sd_spde_b) > 0`; helper header + skip message updated |

No `R/` or `src/` change.

## CI evidence

Added `.github/workflows/nightly-stale-test-fixups-gate.yaml`: a heavy
`pull_request` gate (paths-filtered to the five touched test files + the
workflow) that runs them with `GLLVMTMB_HEAVY_TESTS=1` and `fmesher`,
failing on any failed/errored expectation (skips do not fail). It mirrors
`.github/workflows/spatial-indep-slope-nongaussian-recovery.yaml`. The
gate result is recorded on the PR.

(Local `R CMD check` not run — no R toolchain in the worktree; the heavy
cells are gated out of the standard PR check anyway, which is exactly why
this gate is needed.)

## Lesson (durable)

These failures were INVISIBLE to per-PR CI because the affected cells are
`skip_if_not_heavy()` / `skip_if_not_spatial()` and the narrow per-PR
recovery gates (#424, #427, #429) only ran their OWN new recovery files —
they did NOT re-run the pre-existing **fail-loud / smoke suites** that
encode the old (now-relaxed) guard behaviour. So each guard relaxation
silently invalidated a sibling test's `expect_error` probe (poisson) or
left a smoke bar reading slots that only become reachable once the guard
opens. The nightly full-check was the first run to exercise them.

**Future slope-guard relaxations must, in the SAME PR:** (1) re-point any
sibling fail-loud `expect_error` probe to a still-reserved family
(tweedie is the standard probe), and (2) confirm any sibling smoke/health
suite that becomes reachable reads the correct engine slot family
(SPDE slope → `*_spde_b` / `n_lhs_cols_spde`; phylo/animal/relmat dep
slope → `*_b` / `n_lhs_cols`). Adding the relaxed family's name to a
paths-filtered heavy gate is not enough if the gate only runs the new
recovery file.

## Maintainer decision needed

🔴 **Needs you:** `relmat_dep` and `animal_dep` non-Gaussian dep slopes
are now ADMITTED (poisson + the rest of the allowlist) purely as a
side-effect of the #422/#424 phylo_dep relaxation, because all three
share the single `use_phylo_dep_slope` family guard. The engine/math is
the same validated unstructured 2T×2T dep-slope path, so this is very
likely INTENTIONAL (relmat/animal dep = dense-`A` / pedigree-`A` variants
of the phylo dep slope). But unlike phylo_dep (PHY-18 recovery cells) and
spatial_dep/indep (#427/#429 recovery cells), I did NOT find dedicated
NON-GAUSSIAN recovery cells for `relmat_dep` / `animal_dep`. Please
confirm whether admitting them via the shared guard is intended as-is, or
whether they should get their own per-family recovery cells before the
allowlist is advertised for those keywords. This PR only fixes the stale
fail-loud probe; it does not change the admission.

## Follow-up

- Confirm the heavy gate passes non-skipped for the dep fail-loud cells
  (the spatial smoke cells may honest-skip on non-convergence at the
  small CI fixture sizes; that is allowed and does not fail the gate, but
  the dep fail-loud cells should PASS deterministically).
- Maintainer decision above on relmat_dep / animal_dep recovery coverage.
