# After Task: Destination B S3b active-Julia replay

**Branch**: `codex/destination-b-s3b-receipt-hardening-20260909`
**Date**: `2026-09-10`
**Roles (engaged)**: Ada, Hopper, Rose

## 1. Goal

Re-run the controlled three-pair Gaussian S3b adapter check against the active
Destination B Julia integration commit, while preserving the existing frozen-R
binary contract and the closed-adapter boundary.

## 2. Implemented

The S3b receipt allowlist now includes this replay report and the two immutable
active-Julia receipts. The second receipt is created only after the allowlist
change is committed, so its runner hash binds the final clean source state.
No R/TMB likelihood, C++, formula grammar, public API, generic
`engine = "julia"` route, or Julia implementation changed.

## 3. Files Changed

- `tests/testthat/run-destination-b-s3b-native-pairs-isolated.R`
- `tests/testthat/test-destination-b-s3b-native-pairs-runner.R`
- `docs/dev-log/artifacts/2026-09-10-destination-b-s3b-native-pairs-active-gllvm-b6bd78bb.json`
- `docs/dev-log/artifacts/2026-09-10-destination-b-s3b-native-pairs-active-gllvm-b6bd78bb-r2.json`
- `docs/dev-log/check-log.md`
- this report

## 3a. Decisions and Rejected Alternatives

- **Decision:** retain a second, write-once receipt after committing its exact
  changed-path contract. **Rationale:** the receipt must bind the runner source
  actually present in a clean repository. **Rejected:** treating the first
  active-Julia replay as final after changing the runner allowlist.
- **Decision:** preserve both receipts. **Rationale:** evidence is append-only;
  the first is useful provenance, while the second is the current binding
  receipt. **Rejected:** overwriting a retained artifact.

## 4. Checks Run

```sh
Rscript --vanilla -e 'devtools::test_active_file("tests/testthat/test-destination-b-s3b-native-pairs-runner.R", reporter = "summary")'
# 16 expectations; no failures, errors, warnings, or skips

GLLVM_S3B_LIVE_ADAPTER_TESTS=1 \\
  GLLVM_DESTINATION_B_PROJECT=/private/tmp/destination-b-b1-integration-20260910 \\
  GLLVM_S3B_JULIA_HOME=/Users/z3437171/.juliaup/bin \\
  GLLVM_S3B_RECEIPT_PATH=docs/dev-log/artifacts/2026-09-10-destination-b-s3b-native-pairs-active-gllvm-b6bd78bb-r2.json \\
  Rscript --vanilla tests/testthat/run-destination-b-s3b-native-pairs-isolated.R
# 48 passed; 0 failed, skipped, errors, or warnings; 25.3 s
```

The live command required the normal Julia manifest-usage pidfile outside the
filesystem sandbox. It ran only after source snapshots passed and published a
new hard-linked receipt. SHA-256:
`bf8aa6438d97430808df7aa49111cc3c64a01c5ce3411da00e12c3698d5dd351`.
It binds clean GLLVM.jl `b6bd78bb0fe094b404a963d0fd65e93809cf5bd7` and runner
SHA-256 `ce405eef72abfe0352d174ae2102a20803cb7f834f5c807c56339567c11f5cfa`.

## 5. Tests of the Tests

The runner unit test asserts the complete, exact allowlist and rejects an
unapproved path. The write-once receipt test separately rejects replacement.

## 6. Consistency Audit

`rg -n "engine = \"julia\"|generic engine|stored intervals|recovery|coverage|0\\.7 parity|FRK" R/julia-bridge.R docs/dev-log/after-task/2026-09-10-destination-b-s3b-active-julia-replay.md docs/dev-log/artifacts/2026-09-10-destination-b-s3b-native-pairs-active-gllvm-b6bd78bb-r2.json`

Verdict: the runner receipt and this report consistently retain generic-engine,
private-adapter-interval, recovery, coverage, 0.7-parity, and FRK exclusions.

## 7. Roadmap Tick

N/A — this is retained validation evidence, not a roadmap-status change.

## 7a. GitHub Issue Ledger

No relevant issue action and no new issue. FRK remains parked at `#1275`; no
push, merge, release, or registry action was taken.

## 8. What Did Not Go Smoothly

The first replay necessarily predates the allowlist entry needed for later
clean-source replays. Its immutable record is preserved, and a second receipt
was used rather than mutating it. The sandbox denied Julia's ordinary
manifest-usage pidfile; an approved outside-sandbox run passed unchanged.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** evidence continuity requires a receipt to name the exact verifier
revision, not just the numerical payload.

**Hopper:** the R adapter remains a narrow transport and post-fit boundary;
the replay does not infer a broader R or Julia model route.

**Rose:** write-once evidence and an exact changed-path list prevent an
apparently successful rerun from silently escaping the approved bridge scope.

## 10. Known Limitations And Next Actions

The controlled Tree, sparse-pedigree, and dense-`vcv` Gaussian pairs are the
only result covered. They do not admit generic `engine = "julia"`, intervals
through the private adapter, recovery, coverage, other families, 0.7 parity,
or FRK. The next separate authorised action is the one Tree-only S4 public
workflow replay.
