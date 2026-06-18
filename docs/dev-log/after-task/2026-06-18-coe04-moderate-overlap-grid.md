# After-task report -- COE-04 two-cell moderate-overlap grid

Date: 2026-06-18 14:13 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice broadens the `COE-04` moderate-overlap evidence from one
conservative moderate-edge fixture to a two-cell grid. It remains Gaussian,
latent-only, fixed-kernel evidence for the Paper 2 Option B path.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - the moderate-overlap test now loops over two cells:
    `non_association_blend = 0.30` at seed `2401`, and
    `non_association_blend = 0.35` at seed `2402`;
  - each cell verifies the full two-component model beats one-component fits,
    recovers both component `Gamma_shape` matrices, and keeps cross-component
    matches low.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`, and
  `docs/design/65-cross-lineage-coevolution-kernel.md` now call this a
  two-cell moderate-overlap grid.
- Dashboard `status.json` and `sweep.json` now show the new grid and updated
  pass counts.

## Scientific Boundary

An exploratory `non_association_blend = 0.40` cell degraded: phy
`Gamma_shape` recovery fell below the committed threshold and one cross-match
rose above the claim boundary. That cell stays outside the current evidence.
This slice does not close broad moderate-overlap calibration.

## Checks

- `devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 47`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 158`.
- `devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 278`.

## Review roles

- Curie: grid design and heavy-test boundaries.
- Fisher: moderate-overlap claim boundary and degraded 0.40 interpretation.
- Rose: partial validation-row wording.
- Grace: test evidence and dashboard update.

## Not done

- No harder moderate-overlap promotion beyond the two passing cells.
- No high-overlap truth recovery claim.
- No interval or `rho` estimation claim.
- No mixed-family or non-Gaussian coevolution evidence.
- No bridge, release, or scientific-coverage gate closure.
