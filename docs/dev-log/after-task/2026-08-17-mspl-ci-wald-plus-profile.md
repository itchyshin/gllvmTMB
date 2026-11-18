# After-task: MSPL CI triad (profile signature + Wald quick + bootstrap asymmetry)

**Date:** 2026-08-17
**Branch:** `docs/mspl-ci-wald-plus-profile`
**Lane:** docs only — MSPL interval doctrine amendment after Shinichi paste

## Goal

Encode Shinichi’s *"try Wald as well though which will be the quickest but our signature error is profile"* into the D-157 new-construction path, without reopening Design 118 or unlocking public `se=TRUE`.

## Mathematical contract

No public API / likelihood / grammar / family / registry / NEWS change. Doctrine and G0 paste only.

## Brain citations (ask-brain)

- **D-12** — profile = featured/hero CI; Wald only in easy interior; speed order Wald ≪ profile ≪ bootstrap (`memory/DECISIONS.md`).
- **D-97** — drmTMB profile default accepted (sister-package house style).
- **D-157** — B1 PARK; later intervals = new construction (not Design 118 recalibration).
- **D-149** / Ranga — \(Q_0\) if/ever Wald SE; CI calibration separate from pin availability.
- Design 68 — gllvmTMB already lists `method="profile"` first on multi `confint`.

## Files

- `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` (new triad note)
- `docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md` (amended)
- `docs/dev-log/check-log.md`
- this after-task

## Checks

```sh
rg -n 'signature|D-12|Wald \(\\?Q_0\)|triad' \
  docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md \
  docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md
```

No Totoro. No Design 118 reopen. No `R/` / `src/` / NEWS.

## Follow-up

Mission Control `next_safe_action` → STOP for triad G0 paste. Merge docs PR when green.
