# After-task — Poisson \(W\) G0 SIGNED — REPLACE

**Date:** 2026-08-17  
**Lane:** `cursor/mspl-poisson-W-REPLACE-signed`  
**Scope:** Docs / signature only. No `R/`, `src/`, NEWS, or register mutation.

## Outcome

- Card Status set to **SIGNED — REPLACE** with the #1096 §3 REPLACE paste.
- Prior PARK-from-approve-all marked **superseded**.
- Provenance note marked **RESOLVED — REPLACE**.
- Mirrored in `decisions.md` + `check-log.md`.
- Codex handover written; **implementation not started**.
- Clarified: REPLACE unlocks the tape programme; SE doors stay closed until rematch green.

## Checks

```sh
rg -n '^\*\*Status' docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
rg -n 'SIGNED — REPLACE|RESOLVED — REPLACE|superseded' \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md \
  docs/dev-log/research/2026-08-17-poisson-W-G0-signature-provenance.md \
  docs/dev-log/decisions.md docs/dev-log/check-log.md \
  docs/dev-log/handover/2026-08-17-codex-poisson-W-REPLACE.md
git diff --stat -- R/ src/ NEWS.md
# deliberately not: src/ tape edit, twin rematch, undraft #1077, public se, Design 118
```

## Follow-up

- Codex implements tape + twins + W2/W7 (see handover).
- Open PRs that still say PARK (#1101 / #1096 wording) updated or closed as superseded.
- #1077 stays draft; Lane B PROTECTED; no rebuild #1090.
