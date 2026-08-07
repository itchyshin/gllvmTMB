# After-task — truncnb2 + delta_lognormal Totoro n-ladders (B only)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s4-gh-hard/` (sibling wave)  
**Scope:** Shinichi B — Totoro n-ladders for `truncated_nbinom2` and `delta_lognormal`. No Arc-1 merge / fence / PR.

## Outcome

| Family | Registry | Status | Σ recovers? | Prefer |
| --- | --- | --- | --- | --- |
| truncnb2 | `truncated_nbinom2` fid 11 | **DONE** | yes (pass_abs → 1 at n=1000) | VA mild abs edge; LA OK at large n |
| delta_ln | `delta_lognormal` fid 12 | **DONE** | yes (pass_abs = 1 at n≥400) | **LA** (tied abs, ~30× faster) |

gllvm N/A (same as ztpois / delta_gamma siblings). No fence/`auto`.

## Artefacts

- Scripts: `lanes/va-s4-gh-hard/scripts/probe-s4-family-nladder.R`, `launch-totoro-s4-nladder.sh` (families added)
- Audit: `docs/dev-log/audits/2026-08-07-va-truncnb2-delta-ln-nladder.md`
- D-50 pulls: `/private/tmp/va-s4-truncated-nbinom2-nladder-20260807/`, `/private/tmp/va-s4-delta-lognormal-nladder-20260807/`
- Totoro: `…/va-s4-truncated-nbinom2-nladder-20260807/`, `…/va-s4-delta-lognormal-nladder-20260807/`

## Checks

- Local 1-seed smokes OK; Totoro smoke then full (12 seeds × {120,400,1000} × 12 cores) both DONE.
- Summary MD5s match Totoro ↔ local (recorded in audit).
- Deliberately not run: fence, Arc-1 merge, NEWS, `devtools::test`.

## Follow-up

**C** (Arc-1 merge/fence on a new lane) only on explicit go — not started here.
