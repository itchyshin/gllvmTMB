# After Task: Propto Simulation Lambda Variance Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Noether / Fisher / Curie / Rose / Grace / Shannon`

## 1. Goal

Close issue #596 locally: unconditional `propto()` / `phylo_scalar` simulation
should redraw phylogenetic effects with covariance `lam_phy * Cphy`, not
`lam_phy^2 * Cphy`.

## 2. Implemented

- Changed `.simulate_eta_unconditional()` to multiply the standard
  phylogenetic draw by `sqrt(lam_phy)`.
- Corrected the local model comment to match the TMB likelihood:
  `p_phy ~ MVN(0, lam_phy * Cphy)`.
- Added a direct regression where `Cphy = I` and `lam_phy = 4`; the empirical
  latent-effect variance must sit near 4. The old bug would produce variance
  near 16.

## 3. Files Changed

- `R/methods-gllvmTMB.R`
- `tests/testthat/test-stage3-propto-equalto.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-propto-simulation-lambda-variance.md`

## 3a. Decisions and Rejected Alternatives

Decision: use an internal unit regression rather than a fitted bootstrap run.
Rationale: the bug is the random-effect redraw scale, which can be isolated
without optimizer noise. Rejected alternative: run a bootstrap coverage grid;
that belongs to CI-08 / CI-10 and would be too broad for this correctness slice.
Confidence: high for the scale contract.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/methods-gllvmTMB.R")); invisible(parse("tests/testthat/test-stage3-propto-equalto.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-stage3-propto-equalto.R")'
```

Outcomes:

- Parse check: `parse-ok`.
- `test-stage3-propto-equalto.R`: 17 pass, 0 fail, 0 warn, 1 existing
  glmmTMB non-PD skip.

## 5. Tests of the Tests

The test is a direct failure-before-fix guard: with `lam_phy = 4` and
`Cphy = I`, the old code simulated variance near 16 because it treated
`lam_phy` as a standard deviation. The fixed code simulates variance near 4.

## 6. Consistency Audit

Final audit command:

```sh
rg -n "lam_phy\\^2|sqrt\\(lam_phy\\)|issue #596|bootstrap interval calibration|source-specific.*lv|mixed-family CI" R/methods-gllvmTMB.R tests/testthat/test-stage3-propto-equalto.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-07-05-propto-simulation-lambda-variance.md
```

Verdict: found the fixed `sqrt(lam_phy)` code path, issue #596 notes, and
intentional before/after boundary text only. This slice does not promote
source-specific `lv`, mixed-family CI, or bootstrap interval calibration.

## 7. Roadmap Tick

N/A. This is a correctness repair for an existing route, not a roadmap status
change.

## 7a. GitHub Issue Ledger

- Inspected issue #596 and implemented the local fix. No GitHub comment or
  closure was made because this branch remains unpublished.

## 8. What Did Not Go Smoothly

No technical blocker. The main risk was avoiding an oversized bootstrap
calibration detour; the unit-scale test kept the slice focused.

## 9. Team Learning

Ada kept the task tied to the current uncertainty-safety tranche. Noether
aligned the simulation equation with the TMB prior. Fisher kept the distinction
between simulation-input correctness and interval calibration clear. Curie
favored a direct known-covariance regression over noisy refit evidence. Rose
blocked any wording that would imply bootstrap coverage moved. Grace recorded
the exact focused test command. Shannon left the public issue untouched until
the unpublished branch is reviewed or pushed.

## 10. Known Limitations And Next Actions

This does not calibrate bootstrap intervals, profile intervals, or phylogenetic
signal coverage. The next likely correctness candidates remain issue #611
(tree-path log-determinant sign) and the missing-data / mixed-family issue map.
