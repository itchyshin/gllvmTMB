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
`a01298e4869be570bc7f6c6cd702651302309f03fa7b1e673d081fc1f353c4a3`.
It validates the V2 post-guard receipt against the mirrored shard, replaces the
later duplicate, and contains exactly 5,000 canonical rows.

The exact replay command is:

```sh
Rscript --vanilla dev/interval-calibration/remote/build-terminal-target-evidence.R \
  dev/interval-calibration/results/2026-08-25-retained-campaigns/totoro-r2/2026-08-25-r2 \
  dev/interval-calibration/results/2026-08-25-retained-campaigns/totoro-r2/derived/interval-adjudicated-evidence.rds \
  docs/dev-log/artifacts/interval-calibration/2026-08-25-target-recomputation.csv
```

A clean replay produced a byte-identical target CSV and a numerically identical
adjudicated object. The replay builder loads the packet-specific frozen source
trees from the archive and fails closed on the V2 binding, PVT overlay, stored
aggregate mismatch, CI-14 receipt count/message, or unexpected CI-15 output.

## All attempts

The complete compact ledger is
`2026-08-25-all-attempt-ledger.csv.gz` (150,019 data rows; SHA-256
`f8c1f33308b0ccb9bed684a99a746f415d79f090875756a6eba752e577dfbe4a`).
It was regenerated from the immutable roots by
`dev/interval-calibration/remote/build-terminal-attempt-ledger.R` and then
read back successfully.

| Attempt class | Rows | Canonical retained rows |
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
| PVT-02 / CI-08 | Trait 1: 1,032/1,081 covered, coverage 0.954672, MCSE 0.006330, lower band 0.942012. Trait 2: 1,037/1,081 covered, coverage 0.959297, MCSE 0.006013, lower band 0.947271. Availability 1,081/5,000 = 0.2162; 3,919 base-fit failures; zero CI failures. | Numerical gates pass, but `MEASURED, NOT CERTIFIED -- EXACT PROFILE CONTRACT UNVERIFIED`. The production penalty profile can accept a non-converged constrained refit, permits `abs(achieved-requested) <= 0.05` on `log(V_t)`, and may interpolate after failed interior refits. Retained endpoints lack the diagnostics needed to audit those cases. The same mechanism and evidentiary gap apply to the historical `n=150,d=1/2` campaigns, so every public row is now `route-only`. |
| CI-09 | Six cells retained 5,000 rows each. Coverage is 0, 0.302215, 0, 0, 0.319953, and 0; lower bands are 0, 0.276372, 0, 0, 0.297280, and 0. Availability ranges from 0.2528 to 0.3886. | `BLOCKED -- DGP/ESTIMAND IDENTIFIABILITY`. One Gaussian pair per site identifies `Sigma_B + sigma_eps^2 I`, not the scored unit-tier `Sigma_B` correlation. The extreme pattern is invalid calibration evidence, not six clean Fisher-z failures. |
| CI-13 | Cell 1 (`n=150,d=1`) structurally free strict-lower targets have coverage/lower bands 0.941081/0.934367 and 0.931735/0.924545. The other eight structurally free strict-lower targets pass both thresholds: cell 2 (`n=150,d=2`), cell 3 (`n=400,d=1`), and cell 4 (`n=400,d=2`). Cell availability is 0.9844, 0.9882, 0.9338, and 0.9618. | Cell 1 is a measured failure. The independent D-43 panel certifies the symmetric joint-delta Wald targets in cells 2--4 exactly; pinned diagnostic rows, Fisher-z Wald, arbitrary constraints, and rotated, unconstrained, or neighbouring cells do not inherit the result. |
| CI-10 | All 18 valid-environment rep-3 base fits failed before the 499-bootstrap stage. | Successful nested-bootstrap cost remains unmeasured; the full campaign was not authorised or run. |
| CI-14 | The exact 10,000-row manifest produced 10,000 identical frozen-source guard failures, zero canonical scientific rows, and no aggregate. | `BLOCKED -- PROVENANCE`; no calibration estimate. |
| CI-15 | The corrected sequence stopped after CI-14. No CI-15 root or scientific attempt exists. | `BLOCKED -- PREDECESSOR`; no calibration estimate. |

Stored and recomputed packet summaries were identical for PVT-02, CI-09, and
CI-13. The mechanical PVT verdict is `TRUE`, but Noether's profile-fidelity
review blocks promotion of that value to an exact LR certificate and withdraws
the historical `n=150,d=1/2` labels for the same mechanism-wide reason. CI-09's
mechanical verdict is `FALSE`, but Fisher/Noether classify the campaign itself
as invalid for its claimed estimand. CI-13's global verdict is `FALSE`; its
cell-specific target results remain explicit. CI-14 and CI-15 are not scored as
coverage failures because no valid scientific campaign ran.

## Independent completion verdict

Fisher and Noether verified the estimands, coverage arithmetic, and
replicate-clustered MCSE. Grace reproduced the target evidence from a clean
temporary output path and obtained byte-identical CSV and RDS artefacts. Rose
verified the attempt denominators and claim boundaries. A fresh Sol-high D-43
review then returned `PASS, narrowly`: it authorised certificates for only
the native pinned CI-13 cells `(n=150,d=2)`, `(n=400,d=1)`, and
`(n=400,d=2)`. It kept `(n=150,d=1)` and the global CI-13 route limited and
confirmed the separate PVT-02, CI-09, CI-14, and CI-15 blocks above.

The final fresh D-43 completion panel is recorded explicitly:

- Terra-high statistical/status review: `PASS` at `f68e6bba`; the callable
  CI-08 `route-only`, historical/callable `limited`, and PVT-02 campaign
  `blocked` distinction resolved its prior P1.
- Terra-high release/claim review: `PASS` at `884f0184` for the then-enumerated
  reader/release surfaces and exact 19-route/state oracle. Rose subsequently
  found stale CI-08 technical comments and row-local register history, so this
  release-wide verdict is superseded pending a post-repair candidate review.
- Sol-high load-bearing science review: `PASS -- narrowly scoped` at full SHA
  `884f01847848a698ccc1713cf042328c8456e228`; it independently recomputed the
  ledger/target arithmetic and authorized only the three exact CI-13 cells.
  Final claim-surface closure is rebound to the post-repair candidate below.

None of these verdicts widens the scope enumerated in the route census.

## Claim boundary

This evidence can support only the exact enumerated cells and targets. It does
not certify a neighbouring sample size, rank, tier, family, slope construction,
rotated loading, bootstrap method, or nonlinear profile. CI-11/12 remain typed
refusals. Prediction, missing-data, MSPL, and new interval APIs remain outside
this programme.
