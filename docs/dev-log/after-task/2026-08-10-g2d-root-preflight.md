# After Task: G2d no-fit writable-root preflight

**Branch**: `codex/isdm-g2d-six-species`  
**Date**: `2026-08-10`  
**Roles (engaged)**: Ada, Gauss, Rose

## 1. Goal

Make a replacement G2d smoke technically admissible without fitting: seal a
fresh private root before any fit and prove root receipt/sentinel
serialisation/read-back and hashing work.

## 2. Implemented

The private runner now provides `preflight` and `init` no-fit modes, writes a
root receipt before a smoke or fixture fit, requires that receipt to match the
command SHA and artifact hashes, and reports `G2D_SMOKE_PASS/HOLD` with the
protocol spelling. Campaign summaries now reject incomplete completed arms or
paired-identity drift before issuing PASS.

Mathematical contract: no DGP, estimand, target, likelihood, public API,
family, formula grammar, or user-facing documentation changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: require a separate no-fit root before a replacement smoke.
  **Rationale**: the first G2d smoke lost all output at post-fit serialisation.
  **Rejected alternative**: infer writeability from directory creation alone.
  **Confidence**: high.
- **Decision**: stop after P1 PASS. **Rationale**: P2 was explicitly a separate
  maintainer decision. **Rejected alternative**: automatically consume a
  replacement smoke. **Confidence**: high.

## 4. Files Touched

- Private runner and test: `dev/isdm-package-recovery/run-g2d-six-species-recovery.R` and `tests/testthat/test-g2d-six-species-harness.R`.
- Private protocol/decision: `dev/isdm-package-recovery/2026-08-10-g2d-six-species-{protocol,decision}.md`.
- Closure: this report, the P2 checkpoint, and `docs/dev-log/check-log.md`.
- Untouched: public R/src, README, NEWS, ROADMAP, vignettes, Rd, pkgdown,
  empirical data, Totoro, and Issue #953.

## 5. Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: 16 expectations; no fit.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=validate --output=dev/isdm-package-recovery/results/g2d-validate-probe --pkg="$PWD"
# PASS: G2D fixture/support/profile contract validation PASS (no fit).

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=preflight --output=dev/isdm-package-recovery/results/g2d-preflight-20260810-204000 --pkg="$PWD" --campaign-sha=27e75758a585839cc91c2edd255ae0a1169b24ed
# PASS: G2D_PREFLIGHT_PASS (no fit).
```

The preflight artifact audit confirmed `root-receipt.rds`, `root-receipt.md`,
`preflight-sentinel.rds`, `preflight-file-manifest.csv`, and
`preflight-receipt.md`, including sentinel read-back.

## 6. Tests of the Tests

The added preflight test is a failure-before-fix regression: it would catch the
post-fit root-path failure and both relative/absolute output-root resolution
errors without consuming a smoke seed.

## 7a. Issue Ledger

No issue was inspected, commented, created, or updated. Issue #953 remains
explicitly out of scope.

## 8. Consistency Audit

```sh
rg -n 'G2D_SMOKE_PASS|G2D_SMOKE_HOLD|G2D_PREFLIGHT_PASS|ensure_result_root' dev/isdm-package-recovery tests/testthat
```

Verdict: protocol and runner use the same G2D smoke labels; all new behavior is
private developer infrastructure.

## 9. What Did Not Go Smoothly

The first preflight invocation revealed that a relative output path was not
normalised to an absolute path, and the regression test then exposed the
reciprocal absolute-path prefixing error. Both stopped before any write/fit and
are now covered by the targeted test. A manual debug preflight wrote the
ignored `g2d-preflight-debug` root while the resolver repair was uncommitted;
it is retained but excluded from P1 admission evidence. The committed-root
preflight at `g2d-preflight-20260810-204000` is the sole P1 PASS receipt.

## 10. Known Residuals

P1 establishes only root/serialization provenance. It does not establish a
retained G2d fit, profile eligibility, recovery, campaign admission, Totoro
readiness, or Paper-2 evidence.

## 11. Team Learning

**Gauss** required complete retained arm artifacts before a campaign PASS,
closing a malformed-fixture loophole. **Rose** kept the earlier write-path
failure as an honest HOLD and required the replacement smoke to remain a new
approval.

## 12. Cross-Product Coverage

This phase does NOT cover a model fit, local smoke, panel, remote compute,
empirical data, count/comparator/spatial/source-admission work, detection,
absolute intensity, public API/docs, or Issue #953.
