# Interval-calibration terminal campaign evidence

Date: 2026-08-25

This receipt freezes the completed evidence and the failed-closed dispositions
for the approved CI-08--CI-15 campaign envelope. An interval route being
callable is not treated as calibration evidence. Scientific failures remain in
their frozen denominators; infrastructure and provenance failures remain in
the all-attempt ledger but do not masquerade as scientific misses.

## Archive custody

| Root | Bytes | SHA-256 | Meaning |
| --- | ---: | --- | --- |
| Totoro original | 338,350,080 | `0402b3e1484f56c92fa40cf362c4bb30b5c1de7feba221250261ad907d89c396` | Invalid first deployment; 85,000 attempts lacked `assertthat` and are infrastructure-excluded. |
| Totoro corrected r2 | 1,386,240,000 | `88cc79fe6ffd23f85c6bbbd5cc3417a0eb90666487f4b8d6dc7581c086b5b92b` | PVT-02, CI-09, and CI-13 scientific results; CI-14 provenance failures; CI-15 absent. |
| Fir CI-10 cost | 133,120 | `edcff3d5a437452402fd7f034edf64675d7892bfb5a3e55b0149fde5298ab3a8` | Eighteen valid-environment cost-preflight attempts. |

The corrected archive was verified both remotely and after local mirroring. Its
tar member scan found no absolute or parent-traversal path. The adjudicated
PVT-02 evidence object has SHA-256
`22933f7eb3edafd39d309320c76c52680f04d21aca5cd9b8530be415bb019c95`.
It validates the V2 post-guard receipt against the mirrored shard, replaces the
later duplicate, and contains exactly 5,000 canonical rows.

## All attempts

The complete compact ledger is
`2026-08-25-all-attempt-ledger.csv.gz` (150,019 data rows; SHA-256
`f8c1f33308b0ccb9bed684a99a746f415d79f090875756a6eba752e577dfbe4a`).
It was regenerated from the immutable roots by
`dev/interval-calibration/remote/build-terminal-attempt-ledger.R` and then
read back successfully.

| Attempt class | Rows | Canonical scientific rows |
| --- | ---: | ---: |
| Original Totoro infrastructure-excluded | 85,000 | 0 |
| Corrected PVT-02, CI-09, and CI-13 | 55,001, including one excluded duplicate | 55,000 |
| Corrected CI-14 provenance-gate failures | 10,000 | 0 |
| Fir CI-10 cost preflight | 18 | 18 cost-preflight rows, not a coverage campaign |
| **Total** | **150,019** | **55,018** |

For PVT-02 replicate 50001, all three executions remain visible. The original
missing-dependency result is `infrastructure_excluded`; the first
valid-environment post-guard result is canonical; the later valid-environment
campaign execution is `duplicate_excluded`. Both valid executions ended in
`fit_failed`, so the overlay does not change the numerical summary, but it does
enforce the pre-registered first-valid-attempt rule.

## Independent target recomputation

The 18 target rows are retained in
`2026-08-25-target-recomputation.csv` (SHA-256
`3d204c754d9cada7858c656341a7d8234c018af9a7c874772b666632018f9047`).
They were recomputed from retained rows with the packet-specific frozen source
trees embedded in the corrected archive. Eligible-fit interval failures count
as misses. Availability is reported but is not a promotion threshold.

| Packet | Exact result | Campaign-level gate |
| --- | --- | --- |
| PVT-02 / CI-08 | Trait 1: 1,032/1,081 covered, coverage 0.954672, MCSE 0.006330, lower band 0.942012. Trait 2: 1,037/1,081 covered, coverage 0.959297, MCSE 0.006013, lower band 0.947271. Availability 1,081/5,000 = 0.2162; 3,919 base-fit failures; zero CI failures. | Both exact targets pass. `MEASURED, CERTIFICATE CANDIDATE` pending the independent panel. |
| CI-09 | Six cells retained 5,000 rows each. Coverage is 0, 0.302215, 0, 0, 0.319953, and 0; lower bands are 0, 0.276372, 0, 0, 0.297280, and 0. Availability ranges from 0.2528 to 0.3886. | All six cells fail. No certificate. |
| CI-13 | Cell 1 targets have coverage/lower bands 0.941081/0.934367 and 0.931735/0.924545. The other eight targets pass both thresholds. Cell availability is 0.9844, 0.9882, 0.9338, and 0.9618. | Exact campaign fails because every target must pass. No certificate. |
| CI-10 | All 18 valid-environment rep-3 base fits failed before the 499-bootstrap stage. | Successful nested-bootstrap cost remains unmeasured; the full campaign was not authorised or run. |
| CI-14 | The exact 10,000-row manifest produced 10,000 identical frozen-source guard failures, zero canonical scientific rows, and no aggregate. | `BLOCKED -- PROVENANCE`; no calibration estimate. |
| CI-15 | The corrected sequence stopped after CI-14. No CI-15 root or scientific attempt exists. | `BLOCKED -- PREDECESSOR`; no calibration estimate. |

Stored and recomputed packet summaries were identical for PVT-02, CI-09, and
CI-13. PVT-02's corrected campaign verdict is `TRUE`; CI-09 and CI-13 are
`FALSE`. CI-14 and CI-15 are not scored as coverage failures because no valid
scientific campaign ran.

## Claim boundary

This evidence can support only the exact enumerated cells and targets. It does
not certify a neighbouring sample size, rank, tier, family, slope construction,
rotated loading, bootstrap method, or nonlinear profile. CI-11/12 remain typed
refusals. Prediction, missing-data, MSPL, and new interval APIs remain outside
this programme.
