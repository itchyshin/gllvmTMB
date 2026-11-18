# After Task: G3P provenance-amendment landing

## 1. Goal

Land and verify the private G3P receipt amendment without executing any runner mode.

## 2. Implemented

Commit `a4a12eab` makes content/runtime identity binding, DLL paths diagnostic,
and persists the full provenance comparison before optimizer entry.

## 3a. Decisions and Rejected Alternatives

The historical V1 root remains terminal `INVALID_PROVENANCE`. Reuse, rerun,
or reclassification was rejected; a later packet must use a distinct runner,
packet ID, and root.

## 4. Files Touched

- `dev/isdm-package-recovery/g3p-provenance-contract.R`
- `dev/isdm-package-recovery/run-g3-paper2-smoke.R`
- `tests/testthat/test-g3p-provenance-contract.R`
- `docs/dev-log/check-log.md`
- this report, paired reconciliation, checkpoint, and handover.

## 5. Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g3p-provenance-contract.R", reporter = "summary"); testthat::test_file("tests/testthat/test-g3p-paper2-smoke-packet.R", reporter = "summary"); invisible(parse("dev/isdm-package-recovery/g3p-provenance-contract.R")); invisible(parse("dev/isdm-package-recovery/run-g3-paper2-smoke.R"))'
# PASS.
```

No runner mode, fit, profile, simulation, remote compute, or public build ran.

## 6. Tests of the Tests

Focused tests cover exact and path-only matches, binding content/runtime drift,
malformed/non-MD5 fields, and static runner wiring before optimizer entry.

## 7a. Issue Ledger

Gauss/Noether and Rose's three receipt blockers are fixed. Fisher's prior
scope review remains: the amendment supplies no scientific inference.

## 8. Consistency Audit

`rg -n 'g3p_compare_identity|runtime_identity|INVALID_PROVENANCE|path_only_difference' dev/isdm-package-recovery tests/testthat`
confirmed one receipt vocabulary. No historical root or public surface changed.

## 9. What Did Not Go Smoothly

The audited patch was initially stranded in a detached checkout. It was
transferred deliberately to this branch before the landing commit.

## 10. Known Residuals

The landed runner still binds the historical V1 packet; it cannot be used for a
fresh V2 packet/root until a separately reviewed versioned runner design lands.

## 11. Team Learning

Memory receipt: prior G3P HOLD records required a fresh approval and no retry.
Golden Set: not run; no durable brain-index change was made.

## 12. Cross-Product Coverage

This work covers private receipt identity only. It does NOT cover a fit,
recovery, profile, campaign, remote compute, model change, or public claim.
