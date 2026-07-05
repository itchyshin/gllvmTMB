# After-task: Gamma unit-tier rho profile canary refresh

## Task Goal

Verify whether the hard-family profile-stability note in Design 73 was still
live for Gamma unit-tier `rho` profiles, then record the current truth. This was
an evidence/status slice, not an implementation slice.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, TMB parameterisation, or
NAMESPACE change. The Gamma(log) unit-tier route remains:

```text
Y_it | eta_it ~ Gamma(mean = exp(eta_it), CV = sigma_eps)
rho_ij = Sigma_unit[i,j] / sqrt(Sigma_unit[i,i] * Sigma_unit[j,j])
```

The local heavy canary now proves the route runs non-skipped for the existing
Gamma unit-tier fixtures. It does not prove empirical CI calibration.

## Files Changed

- `tests/testthat/test-matrix-gamma-unit.R`: corrected a stale comment that
  still described the standalone Gamma `latent(d = 1)` rho profile as
  degenerate at the baseline.
- `docs/design/73-profile-likelihood-route-matrix.md`: changed the next gate
  from repairing Gamma unit-tier rho failures to broadening hard-family profile
  stability beyond the now-passing local canary.
- `docs/design/35-validation-debt-register.md`: added the exact 2026-07-05
  local heavy Gamma canary result to FAM-09.
- `docs/dev-log/check-log.md`: recorded command and outcome.

## Checks Run

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-gamma-unit.R")'
```

Outcome: 45 pass, 0 fail, 0 warn, 0 skip.

## Consistency Audit

Design 73 no longer tells the next agent to repair a Gamma unit-tier rho
failure that the branch already clears locally. FAM-09 now records that this is
route evidence, not calibration evidence.

## Tests Of The Tests

The same test file first skipped under the default CRAN-like environment, then
ran with `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`. That confirms the non-skipped
result came from the intended heavy gate rather than from default skip behavior.

## What Did Not Go Smoothly

The first run omitted `NOT_CRAN=true`, so `skip_on_cran()` skipped all six
Gamma cells. The corrected command ran the intended local heavy gate.

## Team Learning

Ada kept this as a live-evidence refresh after the cluster rho guard, not a new
feature. Fisher separated route finiteness from interval calibration. Curie
confirmed the actual heavy test rather than trusting stale comments. Rose kept
the wording from promoting Gamma interval coverage.

## Design-Doc Updates

Design 73 and FAM-09 were updated. CI-08 / CI-10 calibration rows were not
promoted.

## Pkgdown / Documentation Updates

No generated Rd or pkgdown files changed. This was an internal design/register
and test-comment refresh only.

## Roadmap Tick

N/A. No `ROADMAP.md` status changed.

## GitHub Issue Ledger

No issue was closed or created. This follows the Ultra-Plan / Design 73
hard-family profile gate rather than a dedicated GitHub issue.

## Known Limitations And Next Actions

- Broader hard-family profile stability still needs a selected grid across
  Beta, NB1/NB2, ordinal, and truncated families.
- Empirical profile-LR interval calibration remains CI-08 / CI-10 work.
- Totoro/DRAC are still reserved for multi-seed calibration after local route
  surfaces are clean.
