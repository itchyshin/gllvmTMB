# After Task: G3P Gate-B packet/root materialisation

## 1. Goal

Materialise the approved V2 private packet and its fresh ignored root without
invoking any runner mode or altering the frozen model.

## 2. Implemented

Created `G3P_P2_SMOKE_V2` and the empty ignored
`results/G3P_P2_S6_C360_R3_V2/` root. The packet carries the reviewed
receipt/context contract and keeps all execution modes separately gated.

## 3a. Decisions and Rejected Alternatives

Gate B was interpreted exactly as create-only. Preflight, smoke, retry, and
any numerical result were rejected as out of scope. V1 remains immutable
`INVALID_PROVENANCE`.

## 4. Files Touched

- `dev/isdm-package-recovery/2026-08-13-g3p-paper2-v2-smoke-packet.md`
- `tests/testthat/test-g3p-paper2-smoke-packet.R`
- `docs/dev-log/check-log.md` and this report/handover.

## 5. Checks Run

Focused G3P contract/packet tests passed and the contract/runner files parsed.
The V2 root was confirmed empty and ignored by `.gitignore`.

## 6. Tests of the Tests

The packet test asserts the V2 ID/root, reviewed runner baseline, binding
packet content MD5, separate preflight approval, and absence of fitting or
remote-compute calls.

## 7a. Issue Ledger

No receipt-contract defect was found during materialisation. The previous
Gauss/Noether, Fisher, and Rose passes remain the review basis for this
approved creation-only action.

## 8. Consistency Audit

The V2 packet agrees with the prior proposal: frozen V1 design, V2-only
identity, and separately approved preflight/smoke. No public surface changed.

## 9. What Did Not Go Smoothly

No operational issue occurred. The approval boundary required retaining an
empty root rather than materialising a receipt or fixture.

## 10. Known Residuals

The root has no receipt, fixture, manifest, ledger, or result. A preflight
approval is required before any of those may exist.

## 11. Team Learning

Materialising an ignored root is a distinct reversible state change from
preflight; keeping it empty prevents an approval from being silently widened.

## 12. Cross-Product Coverage

This work covers only the V2 private packet/root. It does NOT cover a fit,
recovery, profile, campaign, remote compute, model change, or public claim.
