# CI-11 categorical `simulate()` hardening — after-task report

## Task goal

Complete native categorical bootstrap simulation for the Ayumi CI-11 QC path, expose failed/effective bootstrap draws, and make non-finite profile endpoints visible.

## Mathematical contract

No likelihood, formula grammar, or parameterisation changed. For ordinal probit, simulation now follows the fitted likelihood exactly: `z ~ N(eta, 1)` and `y = k` when `tau_(k-1) < z <= tau_k`, with `tau_1 = 0` and remaining fitted thresholds. Multinomial remains the existing baseline-category softmax: one draw over `{0, eta_2, ..., eta_K}` per group, with all-zero contrasts for baseline.

## Files changed

`R/methods-gllvmTMB.R`; `R/extract-correlations.R`; regenerated `man/extract_cross_correlations.Rd`; `tests/testthat/test-cross-family-intervals.R`; `docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md`; `docs/dev-log/2026-07-18-cross-family-interval-hardening-map.md`; and this report. `README.md`, `NEWS.md`, `ROADMAP.md`, vignettes, `_pkgdown.yml`, and design docs were inspected and not changed: this is a bounded plumbing/diagnostic repair, not a coverage or advertised-capability upgrade.

## Checks run

- `devtools::document(quiet = TRUE)` regenerated the affected Rd file.
- `pkgdown::check_pkgdown()` passed.
- `NOT_CRAN=true Rscript --vanilla ... test_file('tests/testthat/test-cross-family-intervals.R')` completed with no failure output.
- Live R/TMB check: multinomial + ordinal-probit fit (`N = 60`, three repeats) converged; `simulate()` returned ordinal values in `1:3` and valid multinomial contrast rows; direct `bootstrap_Sigma(what = "cross_corr", n_boot = 8)` returned `n_failed = 0`, eight effective draws, and finite `multiple_r` bounds.
- `git diff --check` passed.

## Consistency audit

`rg -n 'family_id = 14|ordinal_probit|family_id = 16|multinomial|bootstrap_n_failed|multiple_r_n_effective|profile_status' R/methods-gllvmTMB.R R/extract-correlations.R man/extract_cross_correlations.Rd tests/testthat/test-cross-family-intervals.R docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md docs/dev-log/2026-07-18-cross-family-interval-hardening-map.md` confirmed the code, test, generated help, and CI-11 notes use the same family IDs and diagnostic names.

## Tests of the tests

The regression directly asserts `bootstrap_Sigma(..., what = "cross_corr")`, `n_failed == 0`, and eight effective `multiple_r` draws; it separately verifies the public wrapper diagnostics. A namespace mock returns non-finite profile endpoints and proves both profile status fields become `non_finite`.

## What did not go smoothly

The first test only covered bootstrap indirectly and did not assert the exact live counts. Fresh D-43 review caught both omissions; the final test now covers them directly.

## Team learning and process

**Noether** confirmed the ordinal threshold sampler and grouped softmax share the TMB likelihood’s encoding. **Curie** tightened the regression from “some bootstrap success” to exact draw-accounting assertions. **Rose** required explicit non-finite profile status coverage. **Grace** confirmed regenerated Rd and pkgdown checks. Fresh D-43 was DONE after remediation by all three independent lenses.

## Design and documentation updates

The CI-11 register proposal and hardening map now record the repair, its exact local evidence, and the unchanged no-coverage-upgrade boundary. Generated Rd describes the new diagnostics.

## Roadmap tick

N/A — no roadmap status changes; CI-11 remains route-specific and fenced as recorded in the proposal.

## GitHub issue ledger

Inspected: Ayumi-495/BIRDBASE_pcm#1 from the handover. No issue was closed. A re-test invitation is ready only after the uncommitted repair is published to a branch Ayumi can install; do not ask her to test an inaccessible local worktree.

## Known limitations and next actions

This verifies simulator/bootstrapping plumbing, not interval calibration or ordinal category-frequency recovery. CI-11 remains unupgraded. Publish the bounded repair, then invite @Ayumi-495 to rerun the same setup and report `bootstrap_n_failed`, effective-draw columns, and any `profile_status = "non_finite"` rows.
