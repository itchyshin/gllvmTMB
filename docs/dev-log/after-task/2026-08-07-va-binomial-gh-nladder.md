# After-task — binomial GH large-N ladder (probit decision + logit park)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Branch:** `codex/va-gh-all-families`

## Scope

Measurement-only n-ladder for binomial **logit** and **probit** at
n∈{120,400,1000}, p=8, q=2, H=7, unique=FALSE, 12 seeds (`10901:10912`).
Private `.va_r3_fit`. No fence / `auto` / threshold change.

Shinichi park: **do not** expand into “make GH win on logit.” Prefer
finishing **probit β-vs-n**.

## Outcome

- Script: `lanes/va-s1-binomials/scripts/probe-binomial-gh-nladder.R`
- Results (D-50 local):
  - `/private/tmp/va-s1-binomial-gh-nladder-probit-20260807/`
  - `/private/tmp/va-s1-binomial-gh-nladder-logit-20260807/`
- Audit: `docs/dev-log/audits/2026-08-07-va-binomial-gh-nladder.md`

### Claim answers (yes/no)

| Claim | Probit | Logit |
| --- | --- | --- |
| GH β → match AC/JJ/gllvm as n↑? | **YES** (n=1000) | **YES vs JJ** (measurement; fix parked) |
| GH scale (trace) → 1? | **YES** (→1.03) | **PARTIAL** (→1.58) |
| GH Σ runaway die with n? | **YES** | **MOSTLY YES** (0.17 left) |
| AC attenuated while GH settles? | **YES** (AC collapses) | n/a (JJ on logit) |

## Checks

- Local 8 cores; probit wall ~733 s; logit wall ~460 s.
- No `R/` / `src/` / fence edits.
- LOOP arcs C0nladder → DONE; logit GH fix remains PARKED.

## Follow-up

- G0: nbinom dig vs Totoro S1 go — not logit-GH rescue.
- Optional: n=2000 only if Shinichi wants finer probit asymptotics (expensive).
