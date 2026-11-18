# Ultra Plan: public `spatial_coef()`

```text
GOAL
Admit a public Gaussian `spatial_coef(formula, mesh, rho = 1)` response-column
random-intercept/slope API for long and traits-wide data by reusing the
released projected-SPDE coefficient engine. Preserve exact warning-free
`spatial_slope()` fits at the no-intercept endpoint, keep interior/estimated
spatial rho explicitly unadmitted, document the biological C3/C4 grand-mean
model, obtain independent method/API/recovery/portability review, and land
through exact-head three-OS CI, normal protected merge, exact-main CI, and
live pkgdown verification. Preserve every unrelated lane.
```

## Orientation and locked boundary

Base: verified kernel merge `eec9cdde4ec95fe8fb61911621f4620d69e204dc`.
The released SPDE block already supplies arbitrary basis width, full/diagonal
`Sigma_field`, estimated `kappa`, projected unit-diagonal `K_column`, and
Gaussian Laplace integration. The first public slice is therefore R-only and
fixes `rho = 1`. Interior or estimated spatial `rho` is not a smaller spelling
of the same model: it requires an IID coefficient field tied to the same
`Sigma_coef`, new TMB plumbing, and a joint rho-range identifiability gate.

## Dependent slices

1. RED grammar and endpoint tests: public formals, one labelled mesh,
   rho=1-only errors, both bars, and exact `spatial_slope()` identity.
2. R-only engine admission: spatial rewrite, intercept-aware `Z_spde_aug`,
   existing SPDE dispatch, `Sigma_field` extraction, and spatial metadata.
3. Long/wide and biological evidence: fixed C3/C4 intercepts/slopes plus
   plant-specific spatial random intercept/slope deviations; overlap guards;
   small recovery and edge cells.
4. Documentation cascade: roxygen/Rd, export/pkgdown navigation, Designs 01,
   130, 131, and new 133, validation-debt status, NEWS, API grid, worked
   article, check-log, and after-task report. Existing `*_slope()` APIs remain
   current, warning-free, and non-deprecated.
5. Independent Gauss/Noether, Curie, Rose/Boole, Pat/Darwin, and Grace gates;
   local focused/package/pkgdown verification; Unlazy reverify.
6. One CI-paced PR; routine plus manual Ubuntu/macOS/Windows exact-head checks;
   normal protected merge; exact-main R-CMD-check and live pkgdown verification.
7. Final programme audit; release spatial and umbrella leases; send the exact
   final `main` SHA and receipts to the iJSDM lane.

## Compute and authority

Routine fits and the optional bounded recovery script are estimated below 30
minutes and are pre-authorised by the approved programme. No coverage campaign
or GitHub Actions simulation is planned. Stop for an ownership collision,
protection bypass, unexpected C++ requirement, changed rho mathematics, or a
run projected above 30 minutes.

## Acceptance

The executable ledger is `.unlazy/spatial-column-coef/GATES.md`. No completion
claim is allowed until every gate is reverified against the exact candidate or
the exact merged `main` SHA named by that gate.
