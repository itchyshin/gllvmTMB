# After Task: G2e observation-support diagnostic

## 1. Goal

Test, privately and locally, whether doubling only GBIF and PA observation
support changes the held G2d information pattern. No recovery campaign was in
scope.

## 2. Mathematical contract

G2e preserved the six-species, 120-cell, nonspatial relative-intensity model:
GBIF Poisson quadrature plus three PA-cloglog events sharing one cell/species
state, rank-one `Lambda`, free diagonal `Psi`, and GBIF-only bias. It changed
only `aG <- 2*aG` and `aS <- 2*aS`.

## 3. Protected state

G2c remains `G2C_SMOKE_ADMISSION_HOLD`; G2d remains `G2D_SMOKE_HOLD`. Neither
was rerun, overwritten, pooled, or reclassified.

## 4. No-fit checks

`run-g2e-information-diagnostic.R --mode=validate`, the dormant smoke-launcher
validation, and `devtools::test(filter = "g2e-information-diagnostic")` passed.
The final preflight root `g2e-preflight-20260811-005` serialized and re-read
the truth, root receipt, and manifest without fitting.

## 5. Local smoke

The first root `g2e-smoke-20260811-001` was retained incomplete and is not
interpreted. After explicit replacement authorization, the fresh root
`g2e-replacement-smoke-20260811-001` completed from commit `d90b0df8`.
It retained the three-restart fit, all six five-point profiles, stage ledger,
decision ledger, and manifest. No retry followed that replacement.

## 6. Result

`G2E_SMOKE_COMPLETE` with classification `PROFILE_LIMITED`:

- maximum GBIF-bias absolute error: `0.3325081`, improved from G2d's `0.371326`;
- lower profile delta-NLL: `3.6659, 0.0000, 0.8397, 0.6753, 1.3051, 0.0267`;
- all profile ledgers were finite, centered, and converged, but fewer than four
  exceeded the predeclared one-NLL improvement over G2d.

This is a one-fixture local information result, not synthetic recovery evidence,
not a public capability, and not authorization for Totoro, DRAC, or a campaign.

## 7. Independent review

Noether reviewed the support-only DGP, GBIF gate, no-fit contract, decision
partition, and smoke closure guards. Review-directed fixes prevented invalid
profiles or a fit error from being classified scientifically.

## 8. Scope audit

No empirical data, spatial model, detection parameter, count-survey outcome,
comparator, structural-zero component, public API, public documentation,
pkgdown, Issue #953, Totoro, DRAC, or campaign was run or changed.

## 9. Next decision

The evidence points to a separately designed within-cell PA-replication
diagnostic if the project continues. It does not justify a recovery campaign.
