# Handover: Cross-Family Predictor-Informed LV Bridge

Date: 2026-08-27

## State

- Branch: `codex/cross-family-lv-predictor-bridge`
- Verified base: `870944744ff090fe8676e853ebc03957204571c0`
- Superseded reviewed candidate: `2350c5d0cd3c0a705a7fc0f1b01be06a19be9eff`
- Superseded tree: `6db28e1fc169783a59da2aaa903bff036e9bd793`
- Working state at draft: automatic-`Psi` identifiability repair, claim cascade,
  closeout files, and append-only check-log in progress
- Remote state: no push, PR, merge, or release claim yet

## What is now true

Registered native family/link rows compose in one complete-response ordinary
unit-tier `latent(..., lv = ~ x)` block. Loadings-only rank extends through the
number of logical responses; automatic `Psi` also has to pass a necessary
free-parameter-versus-covariance-moment guard. `B_lv = Lambda alpha^T` and shared correlations are available
together. Joint Gaussian/lognormal fits have separate raw/log family-scale
slots, while pure fits and within-family sharing retain their old contract.

The reader-facing article and internal status surfaces consistently call this
route compositionally admitted with all-family route health. They do not claim
general rank-2/rank-3 recovery or new interval calibration.

## Verification to rehydrate

- Focused source suites and downstream scale-consumer suites passed.
- Earlier automatic-`Psi` article render: superseded after the identifiability
  review. Corrected loadings-only render: pass, 93,452-byte HTML, convergence
  0, positive-definite Hessian, finite labelled outputs.
- `pkgdown::check_pkgdown()`: pass.
- First full check: 20m44.4s, five attributable built-package harness-path
  errors after 15,149 passes.
- Repaired source harness: 19 pass; synthetic built-package absence: five
  intentional skips.
- Repeat full check: 20m26.9s, 0 errors, 0 warnings, 3 notes.
- First post-repair full check: 20m36.8s, four attributable stale-fixture
  failures after 15,143 passes; focused repair passed 16/16.
- Final repaired full check: 21m23.1s, 0 errors, 0 warnings, 3 notes.
- After moving the dimension gate behind formula/design validation, the focused
  precedence replay passed 341/341 and the exact-current-source full check
  passed in 20m12.3s with 0 errors, 0 warnings, and the same 3 notes.
- Exact base-to-candidate `git diff --check`: pass after reviewer repair.
- Production r200: 400 planned, 0 started, 0 attempted; no remote compute.

Read first:

1. `docs/dev-log/after-task/2026-08-27-cross-family-lv-predictor-bridge.md`
2. `docs/dev-log/artifacts/cross-family-lv-predictor/engine-and-evidence-audit.md`
3. `docs/dev-log/artifacts/cross-family-lv-predictor/2026-08-27-r200-recovery-pre-run-receipt.md`
4. `docs/design/73-predictor-informed-latent-scores.md`
5. `tests/testthat/test-mixed-gaussian-lognormal-scale.R`

## Remaining landing sequence

1. Record the third exact-SHA review and run Unlazy `--reverify`.
2. Validate after-task and handover files.
3. Commit only closeout paths; confirm clean tree and exact branch.
4. Push one milestone branch and open one focused PR.
5. Wait for exact-head Ubuntu, macOS, and Windows package CI.
6. Merge normally without bypass.
7. Verify the exact merged `main` run.
8. Release the entire `codex:cross-family-lv-predictor-bridge` lease and send
   the merged-main SHA, exact-main run, and release receipt to the fixed-rho
   `phylo_coef()` lane.

## Boundaries and carried-over work

`CARRIED-OVER`: optional r200 recovery, source pin `1cb4d33a...`, because its
remote launch was not authorised for this exact campaign. It begins as a fresh
evidence task and must not be inferred from the two pre-run attempts.

Broad masks, missing or factor LV predictors, fixed `X + X_lv`, REML,
noncanonical links, extra tiers, structured-source `lv`, Julia interval
calibration, profile/bootstrap, and correlation intervals are not covered.

The fixed-rho `phylo_coef()` programme is mathematically distinct. It remains
fenced until this lane releases `R/gllvmTMB.R` and `R/fit-multi.R`; after the
release receipt, it may rebase its reviewed plan exactly once and begin TDD.

## Lane receipt

`LANE: START A FRESH TASK` after protected landing. Do not extend this lane
into structured-source LV or the coefficient programme.
