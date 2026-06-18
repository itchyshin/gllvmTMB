# After-task report -- COE-04 Poisson construction smoke

Date: 2026-06-18 14:46 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds the first non-Gaussian construction smoke for the latent-only
two-kernel Paper 2 path. It uses Poisson counts because that is the smallest
honest next step after the Gaussian recovery grid.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - added `.c3_make_poisson_two_kernel_fixture()`;
  - added a heavy two-seed Poisson smoke that fits two named
    `kernel_latent()` tiers, verifies convergence and finite log likelihood,
    keeps the near-orthogonal diagnostic live, and checks finite
    component-specific `Gamma` point blocks.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`, and
  `docs/design/65-cross-lineage-coevolution-kernel.md` now describe this as a
  construction smoke only.
- Dashboard `status.json` and `sweep.json` now show the Poisson smoke and
  updated pass counts.

## Scientific Boundary

This is not Poisson recovery evidence. It does not calibrate intervals, does
not validate mixed-family coevolution, and does not move `COE-04` to covered.
It only proves that the latent-only named two-kernel path can construct, fit,
diagnose, and return finite component `Gamma` point blocks for a bounded
Poisson count fixture.

## Checks

- `devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 9 | PASS 47`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 205`.
- `devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 12 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 325`.

## Review Roles

- Curie: fixture and heavy smoke shape.
- Fisher: no-recovery/no-coverage interpretation.
- Boole: no formula/API widening; latent-only path remains canonical.
- Rose: validation-row and dashboard wording stay partial.
- Grace: focused and aggregate test evidence recorded.

## Not Done

- No Poisson recovery gate.
- No mixed-family or broader non-Gaussian coevolution coverage.
- No `rho` estimation or interval evidence.
- No explicit two-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation.
- No bridge, release, or scientific-coverage gate closure.
