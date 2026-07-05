# After-task: cluster rho route fail-loud guard

## Task Goal

Tighten the profile-likelihood route matrix around the peer diagonal tiers.
Shinichi flagged that profile routing needs to be thought through across
`unit`, `unit_obs`, `cluster`, and `cluster2`. The route matrix already marked
`cluster` and `cluster2` rho as `point_only`, but the public dispatcher did not
yet enforce that boundary with a route-ledger reason.

## Mathematical Contract

No likelihood, family, formula grammar, or TMB parameterisation changed.
`cluster` and `cluster2` remain diagonal-only covariance tiers:

```text
Sigma_cluster  = diag(psi_cluster)
Sigma_cluster2 = diag(psi_cluster2)
rho_ij = 0 for i != j by construction
```

Those structural-zero correlations are point-reporting boundaries, not
likelihood-profile targets. This slice prevents `rho:cluster:i,j`,
`rho:cluster2:i,j`, and direct `profile_ci_correlation(..., tier = "cluster" /
"cluster2")` from looking like accepted interval routes.

## Files Changed

- `R/profile-route-matrix.R`: added `.profile_abort_point_only_rho()`.
- `R/z-confint-gllvmTMB.R`: parser now recognises `cluster` and `cluster2` rho
  tokens and routes them to the fail-loud point-only guard.
- `R/profile-derived.R`: direct `profile_ci_correlation()` accepts
  `cluster` / `cluster2` as named boundary tiers and aborts with the same guard.
- `tests/testthat/test-profile-route-matrix.R`: added pure tests for
  `rho:cluster`, `rho:cluster2`, and direct helper calls.
- `man/profile_ci_correlation.Rd`: regenerated from roxygen.
- `docs/dev-log/check-log.md`: recorded commands, outcomes, and claim scans.

## Checks Run

```sh
Rscript --vanilla -e 'parse("R/profile-route-matrix.R"); parse("R/z-confint-gllvmTMB.R"); parse("R/profile-derived.R"); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
```

Outcome: 282 pass, 0 fail, 0 warn, 0 skip.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R")'
```

Outcome: 0 failures / 0 warnings / 11 expected heavy skips.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R")'
```

Outcome: 0 failures / 0 warnings / 35 expected heavy skips.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: regenerated `man/profile_ci_correlation.Rd`.

```sh
git diff --check
```

Outcome: clean.

## Consistency Audit

```sh
gh issue list --state open --search "rho cluster cluster2 profile confint" --limit 20
```

Outcome: no matching open issue; this is an Ultra-Plan route-matrix follow-on,
not a GitHub issue closure.

```sh
rg -n "rho:cluster|rho:cluster2|cluster correlations|structural-zero point|structural zero point|profile route matrix|point_only" R man tests/testthat docs/design docs/dev-log/check-log.md README.md NEWS.md ROADMAP.md | head -n 160
```

Outcome: new guard/tests/help hits plus intentional route-matrix and check-log
boundary wording.

```sh
rg -n "ready to expose|partial support|pdHess.*calibrated|mixed-family CI|source-specific lv|rho:cluster|rho:cluster2" R man tests/testthat docs/design docs/dev-log/check-log.md README.md NEWS.md ROADMAP.md | head -n 160
```

Outcome: no new promotion wording. Hits for mixed-family CI and
partial-support language are existing guard/historical wording; the new rho hits
are fail-loud tests.

## Tests Of The Tests

The added tests use a fake `gllvmTMB_multi` object and mocked-free dispatch
paths. They prove the boundary before any fitted object or TMB profile is
needed: `rho:cluster` and `rho:cluster2` now reach the route-ledger guard, and
`profile_ci_correlation(..., tier = "cluster")` cannot fall through to
`extract_Sigma()` or profile refitting.

## What Did Not Go Smoothly

The first parse command printed the parsed expression because `parse()` was not
wrapped in `invisible()`. It still succeeded, but the output was noisy. No code
correction was needed.

## Team Learning

Ada kept the slice small and aligned with the Ultra-Plan: improve the general
route machinery rather than add another one-off profile target.

Fisher clarified the statistical boundary: diagonal peer tiers have exact
structural-zero off-diagonal correlations, but the current `confint()` matrix
shape cannot label a degenerate row as `structural_zero`, so fail-loud is safer
than returning silent `0, 0` bounds.

Curie kept the evidence pure and cheap. The new tests assert the dispatch
contract without launching TMB fits or profile refits.

Rose blocked overclaiming. This patch does not promote cluster/cluster2
correlation intervals; it only prevents accidental interval-looking output.

Grace kept compute posture local. Totoro/DRAC are not needed for a route guard.

## Design-Doc Updates

No design-doc status changed. Design 73 and validation row CI-11 already marked
`cluster` and `cluster2` rho as `point_only`; this slice makes code enforce that
truth.

## Pkgdown / Documentation Updates

`devtools::document(quiet = TRUE)` regenerated
`man/profile_ci_correlation.Rd` so the helper usage and tier boundary match the
code. No pkgdown build was run because no article, navigation, or public status
claim changed.

## Roadmap Tick

N/A. No `ROADMAP.md` phase/status row changed.

## GitHub Issue Ledger

`gh issue list --state open --search "rho cluster cluster2 profile confint" --limit 20`
returned no matching open issue. No issue was closed or created. Related route
truth remains tracked by Design 73 / CI-11 and the Ultra-Plan profile route
matrix work.

## Known Limitations And Next Actions

- Empirical interval calibration is unchanged; CI-08 / CI-10 remain separate.
- Cluster and cluster2 variance proportions remain partial diagonal-only routes.
- `Sigma_cluster` / `Sigma_cluster2` off-diagonal covariance rows are already
  labelled `method = "structural_zero"` in the richer data-frame route; this
  patch only handles rho interval requests.
- Next useful Ultra-Plan slice: move from route-boundary enforcement into
  missing/mixed correctness or hard-family Gamma profile stability.
