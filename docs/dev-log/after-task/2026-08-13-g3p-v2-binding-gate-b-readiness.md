# After Task: G3P V2 binding, Gate-B request readiness

## 1. Goal

Make a later V2 packet/root proposal technically receipt-safe without creating
a root or executing a runner mode.

## 2. Implemented

The pinned runner baseline `fdcb05cd` accepts explicit V2 packet, source-gate,
root, attempt, and time inputs. It binds the preflight receipt's schema,
source gate, root ID, attempt ID, time estimate, and hard stop before package
loading or optimizer entry. Packet content MD5 is binding; its supplied path is
diagnostic.

## 3a. Decisions and Rejected Alternatives

V1 remains immutable `INVALID_PROVENANCE`. A duplicate V2 runner was rejected
in favour of one parameterised runner with receipt-bound invocation context.
Non-V1 time arguments must be explicit, but may repeat a separately approved
15–25 minute / 1,500-second budget; arbitrary distinct spellings were rejected.

## 4. Files Touched

- `dev/isdm-package-recovery/g3p-provenance-contract.R`
- `dev/isdm-package-recovery/run-g3-paper2-smoke.R`
- `tests/testthat/test-g3p-provenance-contract.R`
- `dev/isdm-package-recovery/2026-08-13-g3p-paper2-v2-packet-proposal.md`
- `docs/dev-log/check-log.md` and the paired reconciliation/checkpoint/handover records.

## 5. Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g3p-provenance-contract.R", reporter = "summary"); testthat::test_file("tests/testthat/test-g3p-paper2-smoke-packet.R", reporter = "summary"); invisible(parse("dev/isdm-package-recovery/g3p-provenance-contract.R")); invisible(parse("dev/isdm-package-recovery/run-g3-paper2-smoke.R"))'
# PASS.
```

No runner mode, fit, profile, simulation, remote compute, or public build ran.

## 6. Tests of the Tests

Focused contract tests cover exact identity, path-only DLL relocation,
malformed fields, content/runtime drift, execution-context mismatch, and a
time-limit mismatch. Static runner tests assert comparator wiring before the
optimizer path.

## 7a. Issue Ledger

Gauss/Noether, Fisher, and Rose independently reviewed `fdcb05cd` and the
durable records. All final verdicts passed. Their earlier blockers—packet/root
defaults, invocation context, time-budget binding, and stale handoff state—are
addressed.

## 8. Consistency Audit

The V2 proposal, reconciliation, checkpoint, and handover all name
`fdcb05cd` as the runner baseline and reserve preflight/smoke for separate
explicit approvals. No public surface was touched.

## 9. What Did Not Go Smoothly

Review exposed three successive receipt-boundary leaks: context labels, time
budget, and accidental literal-difference requirements. Each was corrected
before a runner mode could be considered.

## 10. Known Residuals

No V2 packet or ignored root exists. Gate B is the next authorization request;
even if granted, it would not authorize preflight or smoke.

## 11. Team Learning

Receipt identity must bind every later decision-relevant invocation field, not
just source content. Golden Set: not run; no durable brain-index change made.

## 12. Cross-Product Coverage

This covers private provenance and execution-context contracts only. It does
NOT cover a fit, recovery, profile, campaign, remote compute, model change, or
public claim.
