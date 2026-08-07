# After-task — NB2 2×2 LA/VA × gllvm smoke (Totoro)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Scope:** Start locked non-exact family **nbinom2** with fair 4-arm panel
(gtmb LA / gtmb VA-GH H=7 / gllvm LA / gllvm VA). Process C hybrid — extend
ladder; no full ultra-arc. Binary dig left parked (yes-with-conditions).

## Mathematical contract

No public API / likelihood / grammar / family / fence change. Probe-only
known-truth scoring vs Design-110 DGP. Registry: NB2/log = **GH** (not exact).

## Outcome

- Script + Totoro launcher under `lanes/va-s2-nbinom2/scripts/`.
- Totoro 16-seed panel on confirmation `022b4eab`; local D-50 copy
  `/private/tmp/va-s2-nbinom2-2x2-smoke-20260807/` (raw CSVs not staged).
- Audit: `docs/dev-log/audits/2026-08-07-va-nbinom2-2x2-smoke.md`.
- **Recommendation:** prefer **gtmb LA** for NB2 default on this smoke;
  VA slight β/Σ edge only, 2.45× cost, abs Σ fail shared; gllvm VA collapses Σ.

## Checks

```sh
ACTION=full PROBE_N_SEED=16 PILOT_CORES=16 \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-2x2.sh
# EXIT 0; summary MD5 07264299454492a90c4a7bd87b2d059a
```

Deliberately not run: fence/`auto`, H change, package tests, Totoro q=5.

## Follow-up

- Optional Totoro q∈{2,5} / larger N if ranking needs precision.
- Next locked family after maintainer go: **betabinomial → beta**.
