# After-task report -- COE-04 high-overlap near-duplicate gate

Date: 2026-06-18 14:25 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice broadens the `COE-04` high-overlap collapse-equivalence evidence
from one exact duplicate kernel pair to exact duplicate plus diagonal-shrink
near-duplicate cases. It remains Gaussian, latent-only, fixed-kernel evidence
for the Paper 2 Option B path.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - the high-overlap collapse-equivalence test now loops over two cases:
    exact duplicate kernels and a diagonal-shrink near duplicate
    (`K_non = 0.95 * K_phy + 0.05 * I`);
  - both cases check the separated fit warning, convergence, near-equivalence
    to one collapsed rank-2 kernel tier, warned component-specific
    `extract_Gamma()` calls, and quiet finite collapsed extraction.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`, and
  `docs/design/65-cross-lineage-coevolution-kernel.md` now describe this as
  duplicate and near-duplicate collapse-equivalence evidence.
- Dashboard `status.json` and `sweep.json` now show the new gate and updated
  pass counts.

## Scientific Boundary

This is deliberately not a high-overlap truth-recovery claim. The supported
interpretation is that highly collinear kernels should warn and collapse toward
one higher-rank component rather than invite component-specific biological
interpretation. `COE-04` remains partial.

## Checks

- `devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 47`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 171`.
- `devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 291`.
- JSON validation for `docs/dev-log/dashboard/status.json` and
  `docs/dev-log/dashboard/sweep.json` passed.

## Review Roles

- Curie: high-overlap fixture and heavy-test boundary.
- Fisher: collapse-equivalence interpretation and no truth-recovery claim.
- Boole: Paper 2 path remains latent-only; no `kernel_unique()` expansion.
- Rose: validation-row, NEWS, and dashboard wording stay partial.
- Grace: test and JSON validation evidence recorded.

## Not Done

- No high-overlap truth recovery claim.
- No broader moderate-overlap or null-threshold calibration.
- No `rho` estimation or interval evidence.
- No mixed-family or non-Gaussian coevolution gate.
- No explicit two-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation.
- No bridge, release, or scientific-coverage gate closure.
