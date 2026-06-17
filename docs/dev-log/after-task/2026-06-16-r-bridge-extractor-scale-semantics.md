# After Task: R Bridge Extractor Scale Semantics

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Emmy, Fisher, Rose, Shannon, Grace

## 1. Goal

Separate public `extract_Sigma()` semantics for `gllvmTMB_julia` objects from
the raw retained GLLVM.jl covariance payload. The immediate bug was that
Gaussian bridge payloads from GLLVM.jl include `sigma_eps^2` on the diagonal,
while native `gllvmTMB::extract_Sigma(..., link_residual = "none")` targets the
ordinary unit-tier `Lambda Lambda^T` block when no `unique()` term is present.

## 2. Implemented

- `R/julia-bridge.R` now reconstructs `Lambda Lambda^T` from retained loadings
  for `link_residual = "none"` and for `part = "shared"`.
- Default `link_residual = "auto"` uses the retained residual-augmented
  GLLVM.jl `Sigma` / `correlation` payload where available, but resets
  Gaussian/lognormal rows to the native no-op residual diagonal.
- Raw retained `Sigma` / `correlation` payloads remain visible on the fitted
  object and in `summary.gllvmTMB_julia()`; public covariance extractors now
  apply native scale semantics.
- `tests/testthat/test-julia-bridge.R` now includes a fake retained payload
  with an explicit residual diagonal and a live Gaussian TMB-vs-Julia
  covariance/correlation parity check under `link_residual = "none"`.
- Public roxygen/Rd wording and the validation/coordination ledgers now state
  the scale split and the remaining gated boundaries.

## 3. Files Changed

- R bridge implementation: `R/julia-bridge.R`
- Public extractor docs: `R/extract-sigma.R`, `man/extract_Sigma.Rd`,
  `man/gllvmTMB_julia-methods.Rd`
- Tests: `tests/testthat/test-julia-bridge.R`
- Ledgers/specs: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

## 3a. Decisions and Rejected Alternatives

Decision: Public `extract_Sigma(..., link_residual = "none")` must follow the
native extractor contract, not the raw GLLVM.jl payload.

Rationale: Native `gllvmTMB` is the R-facing oracle. Keeping the residual
diagonal under `link_residual = "none"` would make `extract_Sigma_B()` and
`getResidualCov()` disagree with native TMB fits on Gaussian rows despite
matching log-likelihoods.

Rejected alternative: Rename the public result as a retained engine-scale
matrix and leave the behavior unchanged. That would preserve the previous
tests but weaken R/TMB parity and hide the distinction between raw payload
retention and user-facing extractor semantics.

Confidence: High for Gaussian and synthetic residual-diagonal behavior; partial
for all-family native `auto` parity until residual-split tests are added for
each family row.

## 4. Checks Run

- `gh pr list --state open --json number,title,headRefName,isDraft,updatedAt,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent commits were the current Codex bridge stack only.
- `gh pr view 489 --json headRefOid,mergeStateStatus,statusCheckRollup`
  -> `5420620` was clean with R-CMD-check ubuntu-latest and coevolution
  recovery passed before a follow-up push.
- `rg -n "sigma_y_site|correlation\\(|Sigma =|link-residual|latent-scale trait covariance|bridge payload" ../GLLVM.jl-integration/src/bridge.jl R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> found the GLLVM.jl payload-scale drift.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `extract_Sigma.Rd`; later wrote `gllvmTMB_julia-methods.Rd`.
- `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `13` expected live-Julia skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.
- `rg -n "retained engine scale|link-residual augmentation remain gated|auto' is not applied|auto\" is not applied|retained unit-tier covariance on the engine scale" R man docs/design docs/dev-log/audits docs/dev-log/coordination-board.md tests || true`
  -> no hits in current R, Rd, validation register, coordination board,
  extractor spec, or tests.
- `rg -n "JUL-01A|EXT-JL-LINK-RESIDUAL|EXT-JL-NATIVE-POINT|Lambda Lambda\\^T|Gaussian/lognormal" docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md docs/dev-log/coordination-board.md R/julia-bridge.R R/extract-sigma.R man/extract_Sigma.Rd tests/testthat/test-julia-bridge.R`
  -> expected updated row/status wording and remaining partial/gated boundaries.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

Failure-before-fix was demonstrated by a live Gaussian probe: log-likelihood
and df matched native TMB, but the Julia bridge public covariance differed by
`sigma_eps^2` on the diagonal under `link_residual = "none"`.

The fake-payload test now makes that failure mode explicit by adding a
synthetic residual diagonal to the retained payload. It proves that
`link_residual = "none"` returns `Lambda Lambda^T`, while default `auto` uses
the retained residual payload after applying the native Gaussian/lognormal
no-op rule.

## 6. Consistency Audit

- Stale wording scan:
  `rg -n "retained engine scale|link-residual augmentation remain gated|auto' is not applied|auto\" is not applied|retained unit-tier covariance on the engine scale" R man docs/design docs/dev-log/audits docs/dev-log/coordination-board.md tests || true`
  -> current source/docs/ledgers clean.
- Scope scan:
  `rg -n "JUL-01A|EXT-JL-LINK-RESIDUAL|EXT-JL-NATIVE-POINT|Lambda Lambda\\^T|Gaussian/lognormal" docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md docs/dev-log/coordination-board.md R/julia-bridge.R R/extract-sigma.R man/extract_Sigma.Rd tests/testthat/test-julia-bridge.R`
  -> capability row, spec, board, implementation, docs, and tests agree.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This updates `JUL-01A` in
`docs/design/35-validation-debt-register.md` and the richer extractor spec.

## 7a. GitHub Issue Ledger

No issue was closed or commented. This is evidence for the bridge/extractor
lane under PR #489 and validation row `JUL-01A`; issue actions should wait for
the next live issue-ledger pass.

## 8. What Did Not Go Smoothly

The first live parity scout found a subtle scale drift: GLLVM.jl's contract
comment said latent-scale covariance, but Gaussian and mixed routes used
`sigma_y_site()`, which can include residual diagonals. The earlier raw-payload
tests were too permissive because they did not include a retained residual
diagonal different from `Lambda Lambda^T`.

## 9. Team Learning

- Ada: Keep raw payload admission and public extractor semantics as separate
  rows; otherwise a green bridge test can still mislead users.
- Hopper: The R-Julia payload contract needs scale labels, not just matrix
  shapes.
- Emmy: Public S3 extractors should reconstruct native public semantics even
  when the fitted object retains richer engine payloads.
- Fisher: Gaussian native covariance parity is now tested; all-family
  `auto` parity still needs per-family residual evidence.
- Rose: Stale wording scans must include generated Rd and capability notes, not
  only design ledgers.
- Shannon: CI pacing worked; PR #489 reached clean state before any follow-up
  push.
- Grace: Targeted no-Julia and live Julia bridge tests passed; full package
  check remains a later release-gate check.

## 10. Known Limitations And Next Actions

- `unit_obs`, structured tiers, augmented slopes, cluster tiers, rotated
  ordinations, interval-bearing extractor tables, and broad native parity
  across all admitted families remain gated.
- Full residual-split reporting is still absent for Julia bridge covariance
  extractors; this slice only corrects the public scale split.
- Next extractor lane should add family-by-family native `link_residual =
  "auto"` parity tests for Poisson, Bernoulli binomial, NB2, NB1, Beta, Gamma,
  ordinal, and mixed-family rows before promoting broader wording.
