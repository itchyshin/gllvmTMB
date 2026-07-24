# After Task: Design 93 private EVA scalar algebra

## 1. Goal

Map and implement the released upstream Bernoulli-logit EVA observation term as
a minimal standalone comparator, without inferring a full model engine.

## 2. Implemented

The scalar comparator implements
\(\ell(y;\mu)-\tfrac12p(\mu)\{1-p(\mu)\}v\), the source-mapped form of
the upstream `method > 1` Bernoulli-logit branch when `cQ=v/2`.  Its tests
verify source-formula equality, the zero-variance limit, local convergence to
the exact Gaussian expectation, and malformed-input rejection.

### Mathematical Contract

This is only an observation-level Taylor surrogate.  It omits the full
variational covariance construction, KL/entropy terms, global parameter
optimization, and all package integration.  No gllvmTMB API, C++, TMB,
likelihood dispatch, grammar, or public claim changed.

## 3. Files Changed

- `docs/design/93-eva-scalar-algebra.md` — source map, equation, and scope.
- `dev/design93-eva-algebra/eva-scalar.R` — standalone comparator.
- `dev/design93-eva-algebra/run-tests.R` — deterministic checks.
- This report and the check log.

## 3a. Decisions and Rejected Alternatives

- **Decision**: implement only the source-visible scalar correction.
  **Rationale**: it is auditable against the released code.  **Rejected
  alternative**: reconstructing upstream's full `cQ` machinery would not be
  independently validated in this short, private slice.  **Confidence**: high.
- **Decision**: compare locally to exact quadrature rather than claim equality.
  **Rationale**: the formula is a Taylor surrogate.  **Rejected alternative**:
  treating a source match as inference correctness would overstate evidence.
  **Confidence**: high.

## 4. Checks Run

- `Rscript --vanilla dev/design93-eva-algebra/run-tests.R` — PASS.
- `git diff --check` — PASS.

## 5. Tests of the Tests

Source-formula equality and zero variance are boundary tests; decreasing-error
checks against high-order quadrature test the Taylor regime; invalid response
and negative variance are rejection tests.

## 6. Consistency Audit

The design document names `gllvmTMB`, upstream source, and inference only as
scope fences.  The implementation contains no package or TMB call.

## 7. Roadmap Tick

N/A — private research infrastructure only.

## 8. What Did Not Go Smoothly

Nothing reached a runtime or numerical stop.  The principal limitation is
intentional: the source term alone does not identify the complete EVA objective.

## 9. Team Learning

Jason — upstream source provides a precise local comparator but not a portable
proof of a full objective.  Noether — `cQ=v/2` is the necessary translation
between source notation and the scalar variance term.  Rose — keeping this
separate from Design 92 prevents a VA pass from being misrepresented as EVA
admission.

## 10. Known Limitations and Next Actions

No full EVA ELBO, q=2 EVA objective, optimizer, recovery test, upstream-fit
parity, or gllvmTMB integration exists.  A subsequent design must derive a
complete objective and independent oracle before any estimator is attempted.

## GitHub Issue Ledger

No issue was created or changed; this is private research work.
