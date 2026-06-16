# After-task report: R bridge raw extractor payload matrix

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

## Scope

Added the first `EXT-JL-RAW` evidence slice from
`docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md`.

This is a test-only slice. It strengthens raw Julia bridge extractor evidence
for retained unit-tier covariance and ordination payloads without changing R
bridge behavior, public documentation, NEWS, formula grammar, TMB likelihoods,
Julia engine code, or validation status.

## What changed

- Added a pure-R fake payload helper for three-trait, two-axis raw extractor
  cases.
- Added a pure-R test matrix for:
  - fallback `Sigma = Lambda Lambda^T` reconstruction when no `Sigma` payload
    is present;
  - derived correlation fallback when no correlation payload is present;
  - explicit retained `Sigma` / correlation payloads;
  - trait and unit labels;
  - transposed score payloads from the engine side;
  - `shared`, `total`, and `unique` extractor parts;
  - bad Sigma, correlation, loading, score, and family payload gates.
- Strengthened live JuliaCall grouped-dispersion, ordinal-probit, and
  mixed-family postfit assertions for retained `Sigma`, correlation, loadings,
  and scores.

Still gated: native TMB extractor parity beyond invariant checks, family-aware
`link_residual = "auto"`, rotations, structured tiers, interval-bearing
extractors, mixed-family masks/X/CIs, `newdata`, and unconditional redraws.

## Mathematical contract

No likelihood or parameterisation changed. The test row checks only the retained
engine-scale covariance:

```text
Sigma_unit = Lambda Lambda^T
```

and the corresponding correlation, labels, and raw score/loading shapes. It
does not add residual-link augmentation or rotate the latent axes.

## Files touched

- `tests/testthat/test-julia-bridge.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-06-16-r-bridge-raw-extractor-payload-matrix.md`

## Definition-of-done review

1. Implementation: test-only strengthening of the existing Julia bridge raw
   extractor route.
2. Simulation recovery test: not applicable. No new likelihood, family,
   keyword, or estimator was added.
3. Documentation: validation-register notes, coordination board, check-log, and
   this after-task report updated. No roxygen/Rd change was needed.
4. Runnable user-facing example: not applicable; no public learning-path claim
   was added.
5. Check-log entry: added with exact commands and skipped checks.
6. Review pass: Ada kept the row scoped to `EXT-JL-RAW`; Emmy checked S3 shape
   and labels; Hopper checked bridge payload orientation and gates; Rose kept
   native parity, rotations, residual augmentation, and structured extractors
   out of the claim.

## Checks

- `air format tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures and `13` expected live-Julia skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures.

Post-documentation scans and whitespace checks are recorded in
`docs/dev-log/check-log.md`.

## Deliberately not run

- Full `devtools::test()`
- `devtools::document()`
- `devtools::check()`
- `pkgdown::check_pkgdown()`
- article renders
- `Pkg.test()`

The changed surface is one R test file plus developer ledgers. No generated Rd,
NAMESPACE, vignette, pkgdown navigation, public examples, TMB code, or Julia
code changed.

## Consistency audit

The strengthened tests support raw payload evidence only. They do not prove
native TMB extractor parity, link-residual augmentation, rotated ordination
semantics, interval-bearing extractor tables, or structured-tier payloads.

## GitHub issue ledger

No issue was closed or commented from this local test slice. The relevant
tracking issues remain `gllvmTMB#488`, `gllvmTMB#340`, and `GLLVM.jl#10`.

## Next action

After PR #489's active R-CMD-check completes, push this test-only slice. Then
continue with the next `EXT-JL-RAW` row only if the new CI cycle stays green.

