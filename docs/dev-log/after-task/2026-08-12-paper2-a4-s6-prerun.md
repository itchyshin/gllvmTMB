# After-task report — Paper 2 A4 safeguards and S = 6 pre-run

## 1. Goal

Implement and independently verify only the no-fit A4 safeguards, then execute
one approved, immutable smallest local pre-run and adjudicate its all-attempt
evidence honestly.

## 2. Implemented

Added one Tier-1 pure-logic safeguard suite and landed it at `c7aa1f2c`. Bound
one S = 6 receipt at `57613984` and ran its single seed `86122` attempt.

## 3a. Decisions and Rejected Alternatives

The pre-run had retained historical timing of 444.587 seconds, so an 8–12
minute estimate with a 20-minute stop was appropriate. The completed attempt
is `PRIVATE_NUMERICAL_AND_RECOVERY_HOLD`: Case C / `NO_CANDIDATE` in `b_fix`,
Psi variance error 0.2156398 > 0.20, and weak lower profiles for sp2/sp5/sp6.
Rerun, seed substitution, threshold relaxation, repair, numerical
reclassification, and reader promotion were rejected.

## 4. Files Touched

- `tests/testthat/test-paper2-a4-no-fit-contract.R`
- `dev/isdm-package-recovery/2026-08-12-paper2-{local-prerun-receipt,s6-local-prerun-adjudication}.md`
- `lanes/isdm-paper2-evidence-reader/LOOP/{checkpoint.md,arcs.md}`
- this report and `docs/dev-log/check-log.md`

## 5. Checks Run

`devtools::test(filter = "paper2-a4-no-fit-contract")` passed (40
expectations). Existing `g2n-numerical-admission` and
`g2m-numerical-admission-protocol` focused tests passed. `git diff --check`
passed before commits. The post-run root audit verified both hash closures, all
16 outer artifacts, all three starts, valid profiles, and final Case-C/Psi
classifications.

## 6. Tests of the Tests

The A4 suite supplies adversarial tied, diagonal-maximal, upper-bound,
nonfinite, non-PD, wrong-optimizer, AGHQ, and ridge fixtures; each must be
Case D. It separately asserts Case-C non-entry for both permitted blocks and
scans the classifier body for fitter/optimizer/profile invocation.

## 7a. Issue Ledger

- `PRIVATE_NUMERICAL_AND_RECOVERY_HOLD`: Case C has no candidate; diagonal-Psi
  recovery misses its frozen threshold; three lower profile endpoints are weak.
- Protected G2N/G2K/G2C HOLDs remain unresolved by design.

## 8. Consistency Audit

The run receipt, stage file, root inventory, hash closures, adjudication, and
loop checkpoint agree: a single completed private numerical/recovery HOLD
exists. No package/public surface was touched.

## 9. What Did Not Go Smoothly

The tool initially returned control while the delegated process continued,
which briefly made the root look incomplete. Process-state polling and final
closures resolved that ambiguity; no result was interpreted before completion.

## 10. Known Residuals

No same-objective Case-C candidate, multi-replicate recovery evidence, measured
scale evidence, or reader-promotion verdict exists.

## 11. Team Learning

Process state and the final provenance closure, rather than an early wrapper
return, are the authoritative completion signal for an asynchronous local run.

## 12. Cross-Product Coverage

The A4 suite covers ✓ classifier decision logic, Case-C non-entry, and static
no-execution fencing. The one pre-run covers ✓ one fixed S=6 all-attempt
receipt. It does NOT cover ✗ multi-replicate recovery, scale, remote compute,
reader material, or a capability claim.
