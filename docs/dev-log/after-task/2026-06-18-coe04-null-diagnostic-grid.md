# After-task report -- COE-04 null diagnostic grid

Date: 2026-06-18 14:36 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice broadens the near-orthogonal null side of `COE-04` from three seeds
to a 12-seed diagnostic grid. It remains Gaussian, latent-only, fixed-kernel
evidence for the Paper 2 Option B path.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - the null side now loops over seeds `2301:2312`;
  - component `Gamma_shape` norms must stay near zero;
  - the full-vs-intercept likelihood-gain tail is explicit: median below `2`,
    at most two seeds above `3`, and maximum below `8`;
  - the medium-signal side stays in the same gate and still requires
    component-specific `Gamma_shape` recovery plus full-vs-one-component
    likelihood separation.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`, and
  `docs/design/65-cross-lineage-coevolution-kernel.md` now call this a
  12-seed null diagnostic rather than formal null calibration.
- Dashboard `status.json` and `sweep.json` now show the new gate and updated
  pass counts.

## Scientific Boundary

The exploratory probe found a real overfit tail under the block-null DGP: one
seed reached about `6.24` log-likelihood units for the full model over the
intercept-only comparator. This is why the committed gate records bounded tail
behavior rather than claiming Type-I/null calibration. `COE-04` remains
partial.

## Checks

- `devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 47`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 191`.
- `devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 311`.

## Review Roles

- Curie: null grid shape and deterministic seed gate.
- Fisher: overfit-tail interpretation and no Type-I calibration claim.
- Rose: validation-row and dashboard wording stay partial.
- Grace: focused and aggregate test evidence recorded.

## Not Done

- No formal null-threshold or Type-I calibration.
- No high-overlap truth recovery claim.
- No broader moderate-overlap calibration.
- No `rho` estimation or interval evidence.
- No mixed-family or non-Gaussian coevolution gate.
- No explicit two-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation.
- No bridge, release, or scientific-coverage gate closure.
