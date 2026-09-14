# Temporal dep/latent kernel admission: local evidence

Date: 2026-09-13

## Scope

This record covers two replicated Gaussian identity-link AR1 cells with one
fixed labelled `kernel_indep()` source:

- `temporal_dep(0 + trait | series, time = occasion, replicate = measurement)`;
- `temporal_latent(0 + trait | series, time = occasion, replicate = measurement,
  d = 1, unique = FALSE)`.

It does not widen any source-pair lifecycle or inference route.

## Passed

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
- `Rscript --vanilla -e 'devtools::test(filter = "temporal-program-dep-kernel", reporter = "summary"); devtools::test(filter = "temporal-program-latent-kernel", reporter = "summary")'`
- `Rscript --vanilla -e 'devtools::test(filter = "temporal-(sixth-source|program-(dep|latent)-kernel)", reporter = "summary")'`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`

The focused suites cover dense additive likelihood and central-gradient
oracles, product-covariance controls, admissibility and refusals. The latent
suite also covers long/wide conversion, labels, permutations, unconditional
simulation, and `update()` replay.

An independent Astra review found and this branch repaired two admission
defects in the dependent cell: ordinary covariance additions and all-even AR1
lags now refuse before fitting. The dependent oracle now evaluates every active
outer derivative at negative, zero, and positive persistence and asserts its
mapped temporal-Psi/random-effect membership. Its focused lifecycle checks
cover long/wide conversion, label permutations, unconditional simulation, and
`update()` replay. It intentionally has no `getLV()` temporal-score claim:
that extractor is a rank-one latent interface, not an unrestricted dependent
temporal state interface.

## Package check

`devtools::check(args = "--no-manual", quiet = TRUE)` reached the test stage
and failed in the pre-existing foreign test
`test-temporal-source-nuisance-information.R`. Its installed-package test
attempted to source a developer-only nuisance-information script that is not
present in the installed test layout. The check log records 3 failures there;
this record does not attribute them to either kernel cell. The check also
reported the repository's existing `ave` import note and vignette layout
warnings.

## Claim boundary

These cells remain partial local evidence. They do not support source-pair
forecasts, intervals, profiles, bootstrap, selection, broad recovery,
coverage, release, or cross-platform claims.
