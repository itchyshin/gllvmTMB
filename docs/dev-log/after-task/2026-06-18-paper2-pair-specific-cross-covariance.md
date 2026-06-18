# After Task: Paper 2 Pair-Specific Cross Covariance

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-18`
**Roles (engaged)**: `Ada / Boole / Emmy / Fisher / Curie / Grace / Rose`

## 1. Goal

Add the missing Paper 2 extractor surface for pair-specific cross-lineage
covariance in fixed dense kernel tiers, without widening the scientific claim.
The intended claim is narrow: for a fitted fixed-kernel component `r`, report
point covariance rows as `Gamma_shape_r * K_r[i, j]`. This is not a universal
total `Gamma`, not in-engine `rho` estimation, not interval evidence, and not
scientific coverage completion.

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## 2. Implemented

- Fixed multi-kernel fits now retain aligned dense `K_r` matrices in
  `fit$kernel_matrices`, named by component.
- `predict_cross_covariance()` is exported and documented.
- The helper defaults to host and partner levels when `K_r` comes from
  `make_cross_kernel()` metadata, and also accepts explicit row and column
  levels.
- For cross-kernel tiers, the helper multiplies `Gamma_shape_r` by the fitted
  `K_r[i, j]` entry. Because `make_cross_kernel()` already embeds fixed `rho`
  inside `K_r`, the helper deliberately does not multiply by
  `Gamma_effect_r`.
- Fast and real-fit tests cover the object contract.
- Dashboard, validation register, Design 65, NEWS, pkgdown, and check-log
  evidence were updated.

## 3. Files Changed

Code:

- `R/fit-multi.R`
- `R/extract-sigma.R`
- `NAMESPACE`
- `man/predict_cross_covariance.Rd`

Tests:

- `tests/testthat/test-coevolution-recovery.R`
- `tests/testthat/test-coevolution-two-kernel.R`

Documentation and evidence:

- `_pkgdown.yml`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-paper2-pair-specific-cross-covariance.md`

## 3a. Decisions and Rejected Alternatives

Decision: store fitted `K_r` matrices on the object.

Rationale: the extractor should use the exact aligned kernel matrix that the
fit used, rather than asking users to re-supply `K` and risk level-order drift.

Rejected alternative: ask `predict_cross_covariance()` callers to pass `K`.

Decision: compute pair-specific covariance from `Gamma_shape_r * K_r[i, j]`.

Rationale: for `make_cross_kernel()` tiers, fixed `rho` is already part of the
stored kernel entry. Multiplying by `Gamma_effect_r` would double count `rho`.

Rejected alternative: expose a single total `Gamma` across components.

Decision: keep the Paper 2 multi-kernel path latent-only in this slice.

Rationale: explicit `kernel_unique()` / `*_unique()` Psi is a poor first-wave
default for non-Gaussian and cross-family coevolution teaching, and the
surface should move into post-arc compatibility/deprecation or replacement
design.

## 4. Checks Run

- `/usr/local/bin/Rscript --vanilla -e 'invisible(parse(file = "R/extract-sigma.R")); invisible(parse(file = "R/fit-multi.R")); invisible(parse(file = "tests/testthat/test-coevolution-recovery.R")); invisible(parse(file = "tests/testthat/test-coevolution-two-kernel.R"))'`
  -> pass.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE` and `man/predict_cross_covariance.Rd`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-recovery|coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 75`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 12 | PASS 159`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 342`.
- `/usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> pass before the final evidence append; rerun after this report.

## 5. Tests of the Tests

The fake-fit test in `test-coevolution-recovery.R` is a direct contract test:
it builds a `make_cross_kernel()` object with metadata, supplies a fake fitted
object with known `Sigma`, and checks `kernel_value`, `gamma_shape`,
`covariance`, `rho`, and `kernel_includes_rho`.

The real-fit test in `test-coevolution-two-kernel.R` verifies that a fitted
two-kernel object stores named `K_r` matrices and that
`predict_cross_covariance()` returns finite component-specific rows using the
fitted object contract.

The tests are not recovery or interval tests. They are intentionally narrower:
they protect the pair-specific extractor semantics and the no-double-counted
`rho` rule.

## 6. Consistency Audit

Patterns used:

- `rg -n "Focused tests pass|COE-04|predict_cross_covariance|Laplace|VA|unique" docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json docs/dev-log/check-log.md docs/design/35-validation-debt-register.md docs/design/65-cross-lineage-coevolution-kernel.md NEWS.md _pkgdown.yml R tests man`
- `rg -n "Focused tests pass|PASS 47|PASS 142|predict_cross_covariance|Pair-specific|pair-specific" docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json docs/design/35-validation-debt-register.md docs/design/65-cross-lineage-coevolution-kernel.md`

Verdict: the new helper is named in code, tests, roxygen output, pkgdown,
NEWS, Design 65, validation rows, and dashboard evidence. The dashboard row
was updated from the older 47/142/325 test counts to the current
75/159/342 evidence for this slice.

## 7. Roadmap Tick

Design 65 C3.1/C3.3 and validation rows `KER-03`, `COE-03`, and `COE-04`
were updated. `COE-03` and `COE-04` remain partial.

## 7a. GitHub Issue Ledger

No issue was mutated. This respects the standing boundary not to mutate
GLLVM.jl #101 and not to push. The local evidence remains on the current
branch for PR #489.

## 8. What Did Not Go Smoothly

`air format` produced broad formatting churn outside the intended slice. That
churn was backed out, and the narrow extractor edits were preserved. This
branch should not receive a broad style pass as part of the coevolution gate.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: this closes a real Paper 2 usability gap while preserving the global
guard. The next decision is not "promote Paper 2"; it is which remaining
partial gate to close next.

Boole: the public API should teach `kernel_latent()` multi-component models
first. Explicit `kernel_unique()` / `*_unique()` remains compatibility syntax
for this arc and should move into post-arc lifecycle/deprecation or replacement
design.

Emmy: storing `fit$kernel_matrices` on the object keeps extractors aligned with
the fitted level order and avoids caller-supplied matrix drift.

Fisher: the helper returns point covariance only. It does not add `rho`
estimation, confidence intervals, Type-I calibration, or coverage evidence.

Curie: the added tests are object-contract tests, not recovery tests. The
existing COE-04 recovery ladder remains the scientific gate.

Grace: roxygen, pkgdown registration, focused tests, heavy kernel/coevolution
tests, and `pkgdown::check_pkgdown()` passed before the final evidence append.

Rose: the dashboard and register keep the claim boundary explicit. The guard
sentence remains visible.

## 10. Known Limitations And Next Actions

- No public Paper 2 promotion.
- No `rho` estimation or profile intervals.
- No interval coverage or calibrated Type-I/null threshold.
- No broader/harder moderate-overlap grid.
- No broad high-overlap truth-recovery/failure calibration beyond the current
  collapse-equivalence and warning gates.
- No non-Gaussian recovery or mixed-family Paper 2 coverage; the Poisson gate
  remains construction-only.
- No explicit Paper 2 multi-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation yet.
- No bridge completion, release readiness, or scientific coverage completion.
