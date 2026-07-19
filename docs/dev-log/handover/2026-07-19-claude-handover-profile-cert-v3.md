# Session Handoff — Profile-route coverage: B3b COMPLETE, certificate WITHHELD (provisional); ONE open item = the formal D-43 panel (deferred by tooling)

**Meta:** 2026-07-19 · from Claude (Opus 4.8, ultracode) · TARGET = Claude or Codex · branch `claude/profile-coverage-remeasure-20260718` (off `claude/release-0.5.0`). Supersedes `2026-07-18-claude-handover-profile-cert-v2.md`. Plan: `~/.claude/plans/jazzy-frolicking-shamir.md` (this session's resume/remote-control plan) + `~/.claude/plans/memoized-gliding-dongarra.md` (v2 arc).

## TL;DR — the arc is essentially DONE; the compute answered the question
- **B3b (the last open slice) COMPLETE.** Gaussian Bartlett re-score, MAIN 32/32 chunks, n_sim≈4000/cell, 0 errors, Totoro `~/gllvm_work/results/B3-bartlett-main`, results LOCAL (D-50). Full RAW table in `docs/dev-log/after-task/2026-07-18-profile-cert-v2-DRAFT.md` and `scratchpad/B3b-RAW-aggregate.md`.
- **ANSWER: the opt-in Bartlett correction HELPED but did NOT earn a clean 0.95.** n≥150 lifted from uncorrected 0.9455–0.9474 to **0.9486–0.9529** (closes ~half the gap; modest honest widening factor 1.02–1.04; 0.94 floor held everywhere) — but the four n≥150 2·MCSE lower bands are **0.9455 / 0.9452 / 0.9456 / 0.9497, all < 0.95**. **Certificate WITHHELD at 0.95. Nothing promoted.**
- **Register (CI-08/CI-10) updated NON-PROMOTINGLY** with the Design-73 `profile_total` disambiguation + the measured WITHHELD result. After-task filled (kept `-DRAFT` pending the formal panel).

## Formal panel — DONE (2026-07-19) → WITHHELD, and a NEGATIVE result
The formal 4-lens D-43 panel (Rose/Fisher/Efron/Gelman, Opus) ran once the classifier outage cleared (`scratchpad/panel-FORMAL-verdict.md`). **Verdict: certificate WITHHELD at 0.95, UNANIMOUS for every n≥150 cell.** The only <2-NOT-DONE cell is `gaussian-d1-n50-sig0.5` — an n=50 REML-lever cell, +0.0003 above the band, which all lenses say does NOT carry the certificate. Nothing promoted. **Two findings beyond a bare withhold:** (1) at n≥150 the corrected coverage is within MCSE of the uncorrected χ²₁ baseline — the correction does no demonstrable in-regime work (so "closes ~half the gap" overstates it); (2) the panel read the n=400 anchor b̂=318 as the b-estimator mis-scaling with n — but a follow-up diagnostic (`scratchpad/anchor-Wdist-RESULT.md`) REFUTED that: a fresh n=400 b-estimation is normal (W_mean=1.019, b̂=7.46, like n=150), so the 318 was a POOLING OUTLIER (one rogue rep among 20), not systematic; the small-n b̂ are NOT impeached. **The Bartlett route is a negative result on EFFICACY** (finding 1 stands; the WITHHELD verdict rests on the coverage bands, not the anchor). The provisional read (`panel-PROVISIONAL-verdict.md`) is superseded by this formal panel.

## Other open flags (Needs-you)
1. **[DIAGNOSED] n=400 anchor b̂=318 = a POOLING OUTLIER, not systematic mis-scaling.** The confirming W-distribution diagnostic (`dev/anchor-Wdist-diag.R` → `scratchpad/anchor-Wdist-RESULT.md`) shows a fresh n=400 b-estimation is normal (W_mean=1.019, b̂=7.46, in line with n=150's 1.024/3.67) — so the campaign anchor's 318 came from ONE pathological base-fit rep among the 20 pooled reps injecting inflated W. The mean-W formula is CORRECT (χ²₁ median≈0.455≠1, so median-W would be a bug). **Fix = outlier-robustness in `.pool_bartlett_b`** (drop/winsorize a rep whose per-rep W_mean is a gross outlier), NOT median, NOT constrained-convergence. Small-n b̂ NOT impeached; the WITHHELD verdict is unaffected (rests on coverage bands, not the anchor).
2. **[DECIDED 2026-07-19: do NOT commit] Bartlett worktree stays UNCOMMITTED** (maintainer's call, given the panel's negative result). Worktree `.claude/worktrees/agent-a1b37d9e4b149949e` remains available if the b-estimator is later fixed (convergence check) and the route revisited. The R/ change was safe (opt-in, byte-identical: `.qchisq_threshold(level, bartlett_b=NULL, n=NULL)`; `R/z-confint-gllvmTMB.R` zero diff), but the correction does no demonstrable work + the estimator is unstable, so it was left out of the branch.
3. truth_psi emission-column rewire (harness hygiene). Correlation-estimand shortfall (own arc). Phase B (pin-Ψ=0 binomial; AGHQ+Cox–Reid) = 1.0 + sign-off.

## Landing State (git ledger)
| Artifact | Committed | State |
|---|---|---|
| after-task `2026-07-18-profile-cert-v2.md` (finalized: results + FORMAL panel WITHHELD + negative-result findings) | n | **written, uncommitted** (`-DRAFT` dropped — formal panel ran) |
| register `docs/design/35-validation-debt-register.md` CI-08/CI-10 (non-promoting disambiguation) | n | **written, uncommitted** |
| this handover + Melissa reconcile `docs/dev-log/plan-actual/2026-07-18-profile-coverage.md` + check-log entry | n | **written, uncommitted** |
| Bartlett R/ worktree (`R/profile-ci.R`, `R/profile-derived.R`, ...) | n | CARRIED-OVER — maintainer's commit call (Discussion-Checkpoint) |
| B3b Totoro results | n/a | LOCAL (D-50), never committed |

**Commit staging discipline:** when committing, stage the profile-lane docs (after-task, register, handover, plan-actual) + the 6 `dev/` files — **NOT** the Tier-2a append in `docs/dev-log/check-log.md` (lines ~45604–45628, Lane C multinomial). Never-commit: `.claude/`, tier2a drafts, `results/profile-pilot-*`.

## Remote-control note (for the resume machinery)
The `b3b-poll.sh` gate used `mw==0` (zero workers) which stuck on 2 zombie processes for ~6h after MAIN was actually complete (DONE marker + 32/32 chunks at 23:44 on 2026-07-18). **Fix for next time: gate on `DONE + all-chunks-present`, not process count.** No correctness impact (results intact); latency only.

## How to resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-19-claude-handover-profile-cert-v3.md. B3b is COMPLETE; the certificate is WITHHELD at 0.95 (provisional). The ONE open item: run the formal 4-lens D-43 panel (briefs at scratchpad/panel-briefs-DRAFT.md; RAW table at scratchpad/B3b-RAW-aggregate.md) to confirm WITHHELD, then drop -DRAFT from the after-task. Also flag: n=400 b̂=318 anomaly; the Bartlett-worktree commit Discussion-Checkpoint. Do NOT re-run B3b."
```
