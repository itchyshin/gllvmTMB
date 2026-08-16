# B1 harvest — table COMPLETE, hold-out sealed

**Date:** 2026-08-16
**Roles:** Gauss / Rose
**Lane:** Design 118 Phase B1 (Totoro full)
**Status:** **TABLE COMPLETE 7920/7920. G1–G5 NOT READ.**

This is the harvest receipt. The launch/D-139 receipt remains
`docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md` on
`origin/main`. Filling *this* table does not repeal that one, does
not admit public `se=TRUE`, and is **not** a coverage claim.

**Do not run `--holdout`.** Design 118 §5.7: freeze the calibrator
map in writing from the calibration split before anyone reads
H1 ∪ H2 ∪ H3.

---

## Harvest facts

| Field | Value |
|---|---|
| Status | **COMPLETE** — table filled; gate unread |
| Host | **Totoro** |
| Artifacts | `/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816/` |
| Shard tasks | **7920/7920** (132 cells × 60 shards) |
| Fatals | **0** (`FATAL`/`Killed`/`REPAIR-FAILED` = 0) |
| Sidecars | 7920 + 7920 |
| Completeness | `consolidate-b1.R --expect-full` OK (235980/237600 `ok` rows) |
| First job | pid `2779264` died at **7825/7920** (0 fatals) |
| Repair | `xargs -P 120` pid `3441729` filled the remainder and exited cleanly |
| Last shard | `B124-shard-031` (hold-out H3 cloglog π=0.03 `n_site=192`) written 2026-08-16T17:18:05Z |
| G1–G5 | **NOT read** — hold-out sealed until the calibrator map is frozen |
| Train-only preview | 63 PASS / 163 FAIL / 38 INDETERMINATE of 264 (cell, target) rows — **not the gate** |
| Second campaign | **no** |
| DRAC | not started (quota-blocked) |
| Actions campaign | **no** |
| SE covered? | **no** |
| Public `sdreport` / `vcov` / `confint` | **still withheld** |

Local watch scraps (not keepers): `/tmp/mspl-b1-consolidate-expect-full.txt`,
`/tmp/mspl-b1-watch.log`.

---

## What this is not

- Not G1–G5. Not B2. Not a frozen calibrator map.
- Not permission to treat the train-only 63/163/38 preview as the
  campaign result.
- Not a calibrated-SE, NEWS-covered, or other-family admit claim.
- Not a second Totoro or DRAC launch.

Next safe action: freeze the map from the calibration split, then
and only then unseal hold-out.

---

## Adjacent main state (not B1)

`origin/main` @ `3e18de94`. Registry: admitted binomial / gaussian /
poisson; planned nbinom1 / nbinom2 / gamma / lognormal / tweedie /
Beta / delta_*. Oracles-only without planned rows: student, ordinal,
betabinomial, truncated_*, multinomial. #1014 landed planned
Tweedie/Beta rows; public door stays closed (Beta Jeffreys invalid;
Tweedie hang). Sea-of-red drain CLOSED (#1026).
