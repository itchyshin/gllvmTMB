# After Task: Paper 1 SPDE-slope gauge no-fit parent gate

**Branch**: `codex/isdm-bfgs-exact-gradient`
**Date**: 2026-08-15
**Roles (engaged)**: Ada, Noether, Rose

## 1. Goal

Add a provenance-valid, non-scientific parent gate around the isolated SPDE-slope
gauge no-fit child.  The gate must retain only evidence that is actually
materialized, preserve the frozen MSPDE V3 predecessor, and never fit, optimise,
or claim ecological/numerical admission.

## 2. Implemented

The parent now launches the child under a 1,800-second `processx` deadline,
requires the exact `Rscript --vanilla` argument vector and parent/child PID
bindings, and atomically seals a sibling-staged root only after rereading a
manifest-bound receipt.  The root validator independently checks the frozen
MSPDE V3 packet and historical closeout-validator MD5, source/materializer
hashes, process receipt, child audit, 44 fixed FD records, transformed replay,
and status taxonomy.  Missing, corrupt, malformed, or timed-out child output is
an infrastructure hold; no callback result is inferred.

## 3. Files Changed

- `dev/isdm-package-recovery/spde-slope-gauge-nofit-contract.R` — parent-root
  schema, evidence recomputation, exact process and source bindings.
- `dev/isdm-package-recovery/materialize-paper1-spde-slope-gauge-nofit-gate.R`
  — private staged parent materializer and supervised child launch.
- `dev/isdm-package-recovery/run-paper1-spde-slope-gauge-nofit.R` — binds the
  historical validator to frozen bytes and shares audit validation.
- `dev/isdm-package-recovery/2026-08-15-paper1-spde-slope-gauge-coordinate-design.md`
  — lifecycle taxonomy, inventories, deadline, and provenance boundary.
- `tests/testthat/test-paper1-spde-slope-gauge-nofit-contract.R`,
  `tests/testthat/test-paper1-spde-slope-gauge-nofit-runner.R`, and
  `tests/testthat/test-paper1-spde-slope-gauge-nofit-materializer.R` —
  production-shaped receipt, timeout, corrupt output, staging, and tamper tests.
- `docs/dev-log/check-log.md` and this after-task record — internal audit trail
  for the source-only phase.
- Status inventory: `README.md`, `NEWS.md`, `ROADMAP.md`,
  `docs/dev-log/known-limitations.md`, vignettes, roxygen, generated Rd, and
  `_pkgdown.yml` were not changed; this is private developer infrastructure.

## 3a. Decisions and Rejected Alternatives

- **Decision:** use a separate non-scientific root and a supervised child.
  **Rationale:** it isolates the TMB external-pointer lifecycle and leaves all
  consumed MNCB/BFGS roots immutable.  **Rejected:** in-process replay or a
  retry/recovery root.  **Confidence:** high.
- **Decision:** discard unreadable child output before manifesting a no-result
  infrastructure terminal.  **Rationale:** an unreadable RDS is not admissible
  callback evidence and cannot remain as an unbound extra file.  **Confidence:** high.

## 4. Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-paper1-spde-slope-gauge-contract.R", reporter = "summary"); testthat::test_file("tests/testthat/test-paper1-spde-slope-gauge-nofit-contract.R", reporter = "summary"); testthat::test_file("tests/testthat/test-paper1-spde-slope-gauge-nofit-runner.R", reporter = "summary"); testthat::test_file("tests/testthat/test-paper1-spde-slope-gauge-nofit-materializer.R", reporter = "summary"); for (p in c("dev/isdm-package-recovery/spde-slope-gauge-contract.R", "dev/isdm-package-recovery/spde-slope-gauge-nofit-contract.R", "dev/isdm-package-recovery/run-paper1-spde-slope-gauge-nofit.R", "dev/isdm-package-recovery/materialize-paper1-spde-slope-gauge-nofit-gate.R")) parse(file = p); cat("FOCUSED_PARSE_OK\\n")'
git diff --check
```

All four focused files passed; all four R surfaces parsed; diff check was clean.
No TMB object, child process, fit, optimiser, preflight, simulation, or smoke
was run.

## 5. Tests of the Tests

The timeout, malformed child, zero-exit/missing-output, stale-stage-token,
wrong-command/PID, manifest/materializer, and coordinated evidence-HOLD tests
are boundary and failure-path tests.  The corrupt-output test exposed the real
`unlink()` return-code mistake before it was corrected; the final dynamic test
then executes the production child-loader-to-sealer path.  The complete-root
test is the matching acceptance case.

## 6. Consistency Audit

```sh
rg -n "SPDE_SLOPE_GAUGE_NOFIT|PAPER1_SPDE_SLOPE_GAUGE|MNCB|BFGS" dev/isdm-package-recovery docs/dev-log/check-log.md docs/dev-log/after-task
rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design
rg -n "meta_known_V|gllvmTMB_wide|in prep|in preparation" README.md NEWS.md docs vignettes
```

The first scan found the intended private gauge boundary and historical records
only.  The package-API and legacy-term scans found existing unrelated package
surfaces/history; this lane adds no user-facing syntax, covariance keyword, or
capability wording.

## 7. Roadmap Tick

**Roadmap tick:** N/A — no public roadmap row changed; this is an internal,
non-scientific lifecycle gate.

## 7a. GitHub Issue Ledger

`gh issue list --state open --limit 30` was inspected.  No relevant open issue
was advanced and no issue was created: this is a private Paper 1 provenance
slice, not a package capability.

## 8. What Did Not Go Smoothly

The first parent contract treated a timed-out child and a malformed reporting
child as compatible states.  Independent review required them to be mutually
exclusive.  A second review found that corrupt output was detected but left in
the stage; the finalizer now removes that untrusted file before choosing the
no-result inventory.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept the new gauge root outside frozen MNCB/BFGS roots and restricted
verification to pure/contract tests.

**Noether:** required status to be forced by retained evidence, especially the
timeout-versus-reporting-child boundary.

**Rose:** found the terminalization gap where unreadable child bytes would have
survived staging as an unmanifested extra artifact; the test now drives that
exact loader/sealer combination.

## 10. Known Limitations And Next Actions

This commit creates no gate root and has no scientific result.  `processx` is a
private materializer prerequisite and fails closed if unavailable.  The next
action is a fresh clean-commit review, followed—only under the already declared
separate gate—by non-scientific materialization/validation of this no-fit root.
Neither this phase nor that gate authorises a trust-region fit, ecological claim,
MNCB/BFGS retry, recovery, or public capability statement.
