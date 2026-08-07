# Audit note: S0 dual-report (abs-on-completed)

**Date:** 2026-08-07  
**G0:** Shinichi — dual-report only; do **not** relax Design 110 / Arc-2
reliability thresholds or rewrite `overall_point_route_verdict`.

## What changed

`lanes/va-s0b-exact/scripts/scientific-ledger.R` now emits both:

| Lane | Column | Rule |
| --- | --- | --- |
| **(A)** | `scientific_verdict_default` | Frozen Wilson / healthy conjunction (unchanged) |
| **(B)** | `abs_on_completed_verdict` | Abs caps 0.35 / 0.50 + avail ≥ 0.90 on finished fits (`status %in% {completed, unhealthy}`); no healthy / reliability gate |

**(B) is diagnostic only** — not a soft-PASS of Arc-2 and not a fence change.

S0a Gaussian: already healthy under (A); dual columns not re-emitted this slice.

## Headline cells

| cell | q | (A) scientific | reliability | (B) abs-on-completed | VA β / Σ (B) | LA (B) |
| --- | ---: | --- | --- | --- | --- | --- |
| gamma_log | 2 | SCIENTIFIC_FAIL | FAIL | **ABS_ON_COMPLETED_PASS** | 0.080 / 0.423 | PASS 0.077 / 0.402 |
| gamma_log | 5 | SCIENTIFIC_FAIL | FAIL | **ABS_ON_COMPLETED_PASS** | 0.125 / 0.459 | PASS 0.103 / 0.401 |
| poisson_log | 2 | SCIENTIFIC_FAIL | PASS | ABS_ON_COMPLETED_FAIL | 0.111 / 0.626 | FAIL 0.113 / 0.657 |

Gamma: abs recovery clears caps once unhealthy finishes are included; frozen
reliability still FAIL (51/300 and 235/300 unhealthy). Gamma LA is **not**
hopeless on recovery under (B) despite 0/300 healthy under (A).

## Paths

- Ledger: `docs/dev-log/audits/2026-08-07-va-s0b-exact-scientific-ledger.{csv,md}`
- Protocol: `lanes/va-s0b-exact/protocol/absolute-first.md`
- Export (local): `/private/tmp/va-s0b-exact-evidence-20260807/final-export-s0b.csv`
- Arc-2 CSV: unchanged MD5 `e57f8460fd98bd0eac43b4a6c014317d`
