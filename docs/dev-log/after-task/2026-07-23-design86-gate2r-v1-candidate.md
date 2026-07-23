# After Task: Design 86 Gate-2R V1 strict readmission candidate

**Branch:** `codex/design86-arc2r-20260723`
**Base:** `403be73c150a44d3c6c325b194fbed2559b41965`
**Status:** CANDIDATE ONLY — Gate B unsigned; no smoke authority.

## 1. Goal

Create a maintainer-signable, private Gate-2R V1 candidate that preserves the
historical red Gate-2 evidence and makes any later one-seed smoke fail closed.

## 2. Implemented

Added a V1 fixture, an amendment, and private EVA/Laplace guards. The guards
require a unique Gate-B block, a real maintainer name, signature date, matching
fixture hash/status, reserved seed `86200002`, and the new output root before
truth or input construction.

## 3a. Decisions and Rejected Alternatives

The DGP, 500-seed receipt, starts, optimiser, health/acceptance/winner rules,
Schur interval, collapse rule, and all-failure semantics are unchanged. The
historical seed `86200001`, fixture, artifacts, and red result are immutable;
there is no historical winner or interval.

## 4. Files Touched

- `docs/design/86-eva-gate2r-v1-parameters.json`
- `docs/design/86-gate2r-v1-amendment.md`
- `dev/design86-gate2-eva-runner.R` and `dev/design86-gate2-laplace-runner.R`
- `tests/testthat/test-design86-gate2r-v1-guard.R` and the private input test
- `docs/dev-log/check-log.md` and this report

No public/package source, `NAMESPACE`, documentation surface, or shipped TMB
engine changed.

## 5. Checks Run

- Focused static guard test: 8 PASS.
- Revised private input-contract test: 26 PASS.
- R and JSON parsing: PASS.
- `git diff --check`: PASS.
- Arc-1 `R/eva-proto.R` and `origin/main` engine guards: empty.

The focused tests stop before DGP construction; no runner or historical replay
was invoked.

## 6. Tests of the Tests

The V1 static test compares the candidate with the historical fixture after
removing only authorization/provenance fields. The input-contract test now
asserts that unsigned input construction fails before any RNG draw.

## 7a. Issue Ledger

No issue or PR was created. The live `gh pr list` check was attempted before
editing but GitHub connectivity was unavailable, so no remote state was
inferred.

## 8. Consistency Audit

Rose verified scope, parser isolation, and historical fences. Gauss verified
unchanged numerical rules and prospective provenance. Noether found and then
cleared signer-placeholder, duplicate-field, and alternate-fixture-path
authorization bypasses. All returned DONE for the packet only.

The amendment records exact candidate source hashes and an explicit no-public,
no-compute, no-Gate-3/4 fence. The candidate output root is distinct from the
historical artifact root.

## 9. What Did Not Go Smoothly

The initial Markdown parser accepted a placeholder maintainer, decoy fields,
and the default fixture hash for a supplied path. Independent review found all
three; the repaired parser trims and rejects placeholders, requires unique
fields in the Gate-B block, and hashes the actual fixture path.

## 10. Known Residuals

Gate B is unsigned. No one may invoke either private runner, construct inputs,
or run seed `86200002` until the maintainer completes the final signature block
and rechecks the listed hashes on a clean tree.

## 11. Team Learning

Rose required that authorization reject placeholders and parse only the unique
Gate-B block. Gauss confirmed that the numerical contract remained unchanged.
Noether found the duplicate-field and alternate-fixture-path bypasses, which
the final guard closes before truth or RNG construction.

## 12. Cross-Product Coverage

This covers only private prospective authorization/provenance. It does NOT cover estimator recovery, the Laplace comparator, intervals, scoring outcomes, campaigns, Totoro/DRAC, Gate 3/4, public API, or shipped-engine work.

## Next safe action

The maintainer either rejects the candidate or completes Gate B after the
recorded hashes and clean-tree condition are independently rechecked. A signed
Gate B authorizes only a later, separate one-seed smoke arc; it does not
authorize that smoke here.
