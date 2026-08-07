# After-task — betabinomial + beta Totoro n-ladders

**Date:** 2026-08-07  
**Lane / worktree:** `codex/va-gh-all-families` @ `/private/tmp/gllvmtmb-va-gh-all-families`  
**Authority:** Shinichi — start both after NB2; Totoro standing permission; parallel OK.

## Scope

Locked-order families **betabinomial** then **beta**: Design-110-ish n-ladders
(n∈{120,400,1000}, p=8, q=2, unique=FALSE, ≥12 seeds), matched timing
(`n_starts=1`, `se=FALSE`, warm DLL), 2×2 comparator with N/A when gllvm refuses.

## Outcome

| family | Totoro job | Σ recovers with n? | Headline |
|---|---|---|---|
| **betabinomial** (trials=10, φ=3) | done ~10:14 | **yes** (gtmb VA+LA) | Prefer **LA**; gllvm VA/LA both **N/A** |
| **beta** (φ=5) | done ~10:15 | **yes** for gtmb; **no** for gllvm LA | gtmb pass_abs=1.0 at n≥400; gllvm LA Σ flat ~0.70 |

Audits:

- `docs/dev-log/audits/2026-08-07-va-betabinomial-nladder.md`
- `docs/dev-log/audits/2026-08-07-va-beta-nladder.md`

## Documented defaults

- **betabinomial trials=10** — Design-59 / `test-betabinomial-recovery.R` (not Bernoulli).
- **betabinomial φ=3**, **beta φ=5** — recovery-test defaults.

## Artefacts

| role | path |
|---|---|
| probes + launchers | `lanes/va-s3-betabinomial/scripts/`, `lanes/va-s4-beta/scripts/` |
| Totoro results | `…/va-s3-betabinomial-nladder-20260807/`, `…/va-s4-beta-nladder-20260807/` |
| local D-50 pull | `/private/tmp/va-s3-betabinomial-nladder-20260807/`, `/private/tmp/va-s4-beta-nladder-20260807/` |
| lane CSV copies | `lanes/va-s*/results/nladder-20260807-totoro/` |

## Checks

- Local 1-seed smoke both families (not blocked / not VA-NI for gtmb).
- Totoro full 12×3 launched in parallel; NB2 n-ladder already finished (not killed).
- No fence / `auto` flip. No PASS claim.

## Follow-up

- Optional: re-time with warm DLL already resident if secs_mean at small n looks noisy under Totoro contention (other S4 ladders were co-running).
- Next locked families remain later-list (tweedie / student / …) — other agents may already be probing those under separate `va-s4-*` names; coordinate before overlapping.
