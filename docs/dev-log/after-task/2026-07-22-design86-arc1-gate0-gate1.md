# After Task: Design 86 EVA Arc 1 — Gate 0 coordinate freeze and Gate 1 prototype

**Branch**: `codex/design86-arc1-20260722`
**Date**: `2026-07-22`
**Roles (engaged)**: Ada, Noether, Gauss, Rose

## 1. Goal

Build and verify only the approved Design 86 Gate-0/Gate-1, sparse-binary EVA
feasibility slices.  The deliverable is a private, standalone measurement
prototype; it is not a package method, marginal-likelihood implementation, or
admission to later gates.

## 2. Implemented

- Froze the one Gate-1 fixture schema/value file and recorded its SHA-256 in
  the contract.
- Added an independent R scalar oracle for the Bernoulli-logit EVA objective,
  including the `+q` KL constant, and a test-only Gaussian identity branch.
- Added a standalone TMB prototype and unexported driver with `random = NULL`.
  It supports complete, arbitrarily ordered long rows and a full log-Cholesky
  `A_i` for q=1 and q=2 fixtures.
- Added the q=1 adaptive-GHQ marginal measurement using `.va_r3_gh_rule`; its
  signed value is a frozen internal drift diagnostic, not directional evidence.
- Reproduced the fourth-derivative/remainder calculation and tested its local
  small-variance Monte-Carlo sign condition.

Gate-0 apparatus receipt: direct code reuse is only `.va_r3_gh_rule()` from
`R/va-r3-proto.R` at `c38b3e8c87d1210ec7d3be90bdb95ee84a76a3a7`.  The stable
softplus and log-Cholesky apparatus were re-derived from the contract and
implemented independently; no Design-85 C++/R softplus or expectation code was
copied.  The independent oracle plus q=2 and permuted-row tests form the
fresh equation-to-code audit.  No parked Phase-1 source was copied:
`origin/claude/va-phase1-proof:R/va-proto.R` and
`origin/claude/va-phase1-proof:inst/tmb/gllvmTMB_va.cpp` were inspected only
to enforce the no-copy boundary.

## 3. Files Changed

Implementation and focused tests:

- `inst/tmb/gllvmTMB_eva.cpp`
- `R/eva-proto.R`
- `tests/testthat/test-eva-gate1.R`

Frozen fixture and design records:

- `docs/design/86-eva-gate1-parameters.json`
- `docs/design/86-eva-sparse-binary-admission-contract.md`
- `docs/design/86-gate1-build-brief.md`
- `docs/dev-log/handover/2026-07-22-codex-handover-design86-gate1.md`
- `docs/dev-log/2026-07-22-design86-arc1-ultra-plan.md`
- `docs/dev-log/check-log.md`
- this report

No NAMESPACE, DESCRIPTION, NEWS, `man/`, `vignettes/`, LOOP, or CLAUDE pointer
changed.  `src/gllvmTMB.cpp` is byte-unchanged against `origin/main`.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the q=1 AGHQ result as a frozen internal numeric-drift
diagnostic only.  **Rationale:** it is a marginal comparison and has no
general pre-specified sign implication.  **Rejected:** an expected-direction
claim.  **Confidence:** high.

**Decision:** provide Gaussian only as a test branch.  **Rationale:** it gives
an exact algebraic identity without expanding the supported family surface.
**Rejected:** a public Gaussian EVA feature.  **Confidence:** high.

**Decision:** use a full q=2 log-Cholesky fixture rather than q=1-only
validation.  **Rationale:** it tests off-diagonal packing, trace, logdet, KL,
and row ordering independently.  **Rejected:** diagonal-only coverage.
**Confidence:** high.

## 4. Checks Run

```sh
Rscript --vanilla -e 'source("R/va-r3-proto.R"); source("R/eva-proto.R"); testthat::test_file("tests/testthat/test-eva-gate1.R", reporter = "summary")'
```

Passed: 23, failed: 0, warnings: 0, skipped: 0.  This compiled the standalone
EVA template in a temporary directory and checked oracle equality to 1e-10,
central finite-difference gradients to 1e-5, zero/epsilon variance continuity,
the AGHQ ladder/reference, and D4 finite-difference/Monte-Carlo conditions.

```sh
jq empty docs/design/86-eva-gate1-parameters.json
shasum -a 256 docs/design/86-eva-gate1-parameters.json
git diff --check
git diff origin/main -- src/gllvmTMB.cpp
git diff --name-only | rg '^(NAMESPACE|DESCRIPTION|NEWS|man/|vignettes/|LOOP/|CLAUDE\.md)$'
```

JSON was valid; the checksum was
`a3cb2b9302132b2a917639ac30ce070d5d0f67e9c21f50ffbcc232ead448b036`;
whitespace check and both guarded diffs were empty.

`devtools::load_all()` was attempted but not used as evidence: it tries to
compile the shipped `src/gllvmTMB.cpp` into the isolated worktree, which this
session is not permitted to write.  No full package check or compute campaign
was run; neither is required for this private Gate-1 fixture arc.

## 5. Tests of the Tests

The initial independent oracle exposed a missing-sign KL error before the
oracle was corrected; q=2 with nonzero off-diagonals guards the packing path;
a row permutation guards the prior implicit row-order assumption; zero versus
`1e-8` variance guards the small-variance limit; and an invalid `log_A_diag`
coordinate exercises the driver-level loud-failure guard.

## 6. Consistency Audit

```sh
rg -n 'EVA.*(bound|lower bound|marginal likelihood|ELBO)|ell_EVA.*log p' docs/design/86* docs/dev-log/2026-07-22-design86* docs/dev-log/handover/2026-07-22-codex-handover-design86-gate1.md R/eva-proto.R inst/tmb/gllvmTMB_eva.cpp tests/testthat/test-eva-gate1.R
rg -n 'gllvmTMB_eva|eva-proto|EVA_TAYLOR2|method=' README.md NEWS.md DESCRIPTION NAMESPACE R inst tests vignettes docs/design/86* docs/dev-log/2026-07-22-design86*
```

The first scan found the deliberate contract prohibitions and internal
diagnostic language only; no public bound/marginal claim was introduced.  The
second found only private prototype references, `random = NULL`, and no public
`method=` surface.

## 7. Roadmap Tick

N/A.  This approved feasibility arc has no ROADMAP row and does not advertise a
capability.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created.  The work is a scoped prototype
on the Design 86 branch, not a user-facing feature or release claim.

## 8. What Did Not Go Smoothly

The first pass had four real gaps: implicit long-row ordering, q=1-only
Cholesky coverage, an overgeneralised D4 sign statement, and an ambiguous D3
sign sentence.  The adversarial reviews withheld completion, and the repaired
fixture/test/design records now cover each gap.  Package loading was blocked by
the worktree’s write restriction on the shipped source; focused source-only
testing compiled only the standalone template instead.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept the work to Gate 0/Gate 1, preserved the frozen coordinate
receipt, and withheld all Gate-2/3/4 work.

**Noether:** found the row-order and mathematical-claim gaps; re-review returned
DONE once the full-q, permutation, and local-sign repairs were present.

**Gauss:** required full-Cholesky, live-coordinate validation, and stronger
small-variance/D3 fixtures; re-review returned DONE with 23 focused passes.

**Rose:** audits the final scope, prohibited surfaces, records, and stop point.

## 10. Known Limitations And Next Actions

This is only a frozen, tiny-fixture Gate-1 prototype.  It has no public API,
no package integration, no coverage simulation, and no general marginal
direction claim.  The maintainer must review this arc before assigning any
separate Gate-2 work.  Do not begin Gate 2 from this branch without that
dispatch.
