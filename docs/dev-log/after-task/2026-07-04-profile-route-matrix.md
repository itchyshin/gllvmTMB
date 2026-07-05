# After-Task Report: Profile Route Matrix Truth-Lock

Date: 2026-07-04 20:47 MDT

Branch: `codex/r-bridge-grouped-dispersion`

## Goal

Respond to the profile-likelihood forest problem: unit, unit_obs, cluster,
cluster2, source tiers, and augmented structural splits need one route policy
before new profile helpers are added.

## Files Changed

- `R/profile-route-matrix.R`
- `R/profile-targets.R`
- `tests/testthat/test-profile-route-matrix.R`
- `docs/design/73-profile-likelihood-route-matrix.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-profile-route-matrix.md`

## What Changed

- Added the internal route ledger `.profile_route_matrix()` and controlled
  route levels/statuses.
- Added explicit direct profile labels for `sd_cluster[...]` and
  `sd_cluster2[...]`; retained legacy `sd_phy_unique[...]`.
- Locked current boundaries:
  - direct SD profiles are covered where TMB parameter blocks exist;
  - `Sigma_cluster` and `Sigma_cluster2` matrix tokens are planned, not
    public profile routes yet;
  - cluster/cluster2 correlations are structural point-only zeros;
  - spatial and source-specific total-covariance routes remain partial;
  - augmented split profile routes remain blocked pending symbolic targets.

## Evidence

```sh
Rscript --vanilla -e 'parse("R/profile-route-matrix.R"); parse("R/profile-targets.R"); cat("parse-ok\n")'
```

Result: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
```

Result: 41 assertions passed, 0 failures.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
```

Result: 31 assertions passed, 0 failures.

```sh
git diff --check
```

Result: passed.

## Rose Verdict

OK as a truth-lock slice. It does not claim interval calibration, full
`Sigma_cluster` support, mixed-family CI support, source-specific `lv`
support, or augmented split profile support.

## Next

The next implementation slice should choose one route from the matrix:
either add diagonal-only `Sigma_cluster` / `Sigma_cluster2` matrix tokens,
repair hard-family `rho:unit` profile stability, or add missing denominator
components to profile proportions. Do not combine these in one PR.
