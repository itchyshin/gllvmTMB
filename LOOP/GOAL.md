# GOAL — overnight Poisson MSPL W_* REPLACE (Cursor · ~10–12 h)

**IMMUTABLE for this run.** Re-read at the top of EVERY arc.
**Authority:** G0 SIGNED REPLACE — `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (#1102).
**Owner:** Cursor owns `src/` (Codex override). Shinichi 2026-08-17: **"I preapprove all"** → push PR + merge when CI green allowed; hard OUT still absolute.

## Mission
On this local-scratch worktree from origin/main, implement SIGNED G0 REPLACE: Poisson MSPL live weight `family_id==2` from `return eta` / `W=diag(mu)` → working logistic `W_* = gll_mspl_log_weight(eta, 0)` (Tweedie precedent). Rewrite #1064 W2/W7 (+ W8), rematch `R/mspl-poisson-atoms.R` + A6, update `03-likelihoods.md`, tmb-likelihood-review + simulation recovery. Secondary after rematch green: fence docs, #1077 draft-only, family-door PREP notes, mspl-api tests.

## Soft-gate defaults (preapproved)
- Admit: keep experimental `admitted` if rematch green; else park `planned`
- #1077 stays draft; no Design 125 fork smoke; SE doors PREP notes only

## Hard OUT (absolute even under preapprove)
- public se=TRUE / vcov / confint / NEWS covered
- undraft #1077 for public confint
- Totoro / Design 118 / Lane B / rebuild #1090
- KF2021 beyond binomial; git add -A; isdm-package-recovery

## Definition of done
- [x] A0 worktree
- [x] A1–A5 rematch/recovery/review green
- [x] A6–A7 fence/tests; A8 PR open (#1111)
- [x] PR pushed (#1111); merge when CI green
