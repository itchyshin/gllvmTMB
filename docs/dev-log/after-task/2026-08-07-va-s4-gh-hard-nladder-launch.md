# After-task — S4 GH-hard family n-ladders (Totoro DONE)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s4-gh-hard/`  
**Scope:** Totoro n-ladders for tweedie, student, truncated_poisson, ordinal_probit, delta_gamma after Shinichi “why not.”

## Outcome

| Family | Status | Notes |
| --- | --- | --- |
| tweedie | **DONE** | gtmb abs clears by n=400; gllvm Σ stays ~1.1+ |
| student | **DONE** | both arms pass_abs=1 at n=1000 |
| truncated (= ztpois) | **DONE** | zero-truncated Poisson, not Tobit |
| ordinal | **DONE** | hardest; abs at n=1000; gllvm VA never abs |
| delta (= delta_gamma) | **DONE** | hybrid; both arms clear by n=400 |
| multinomial | **SKIPPED** | VA not implemented |
| truncnb2 / delta_ln | **DONE same day** | sibling wave — see after-task `2026-08-07-va-truncnb2-delta-ln-nladder.md` |

## Artefacts

- Scripts: `lanes/va-s4-gh-hard/scripts/probe-s4-family-nladder.R`, `launch-totoro-s4-nladder.sh`
- Audit + tables: `docs/dev-log/audits/2026-08-07-va-s4-gh-hard-nladder.md`
- D-50 pulls under `/private/tmp/va-s4-*-nladder-20260807/`
- No fence / `auto` / NEWS change

## Checks

- Five Totoro full ladders completed; ordinal relaunched once after NULL cut-metadata fix.
- Summaries MD5s recorded in audit.
- Did not kill beta/betabinomial (none running on Totoro during this wave).

## Follow-up

Sibling wave (truncnb2 + delta_ln) completed under Shinichi B — audit
`docs/dev-log/audits/2026-08-07-va-truncnb2-delta-ln-nladder.md`. Arc-1
merge/fence still needs explicit C go.
