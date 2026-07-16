# Session Handoff → next Claude: gllvmTMB coverage lane + next arc

**Meta:** 2026-07-16 · from Claude (Lane A, coverage/certificate lane) · to the next Claude ·
branch `claude/release-0.5.0` (21 ahead of `main`, 0 behind). You are picking up a repo where a
parallel **Codex "Lane B"** has also been committing — read this before acting.

## Critical Context (read or you WILL go wrong)

1. **The next coverage move is PROFILE / Wald-log-SD-with-t-df — NOT BCa.** The committed record
   and Lane B's bus note (`docs/dev-log/check-log.md`, 2026-07-15) say "your next move is the
   BCa/studentized bootstrap." **That is superseded.** On 2026-07-15 Shinichi steered this
   explicitly and we recalled the already-existing doctrine: for a bounded/skewed variance
   component, **profile likelihood is the star; Wald is saved by transformation (log-SD / logit /
   Fisher-z) + a t-quantile on `g−1` (Satterthwaite/KR) df; bootstrap/BCa is the LAST resort.** See
   **`~/shinichi-brain/memory/LESSONS.md`** (2026-07-15 entry) + **[[Small-sample variance-component
   interval corrections — cross-repo map]]** + `LEARNINGS-archive.md:38–39` + gllvmTMB#565 + D-12 +
   Design 73/75. `Sigma_unit_diag = ΛΛ' + Ψ` is **pure location-axis** → profile/t-df is the fix.
   Direct check confirmed it's **right-skew, not ML mean-bias** (ML Σ̂/truth 1.007 vs REML 1.014 at
   n=150 — REML barely moves it) and **not Laplace** (gaussian Laplace is exact). **Do not build BCa.**
2. **nbinom2 shared-dispersion (`disp_group=`) was already BUILT and it FAILS** (Lane B, Design 82
   §4.5/§4.6). Pooling φ does not recover Σ — even on the DGP that most favours pooling. The real
   nbinom2 problem is **φ-estimation bias** (freely-estimated φ ~0.5 vs true ~1.1), a separate,
   harder problem → bias-corrected/penalised φ (`brglm2::brnb`-style) or an informative prior.
   **nbinom2 stays fenced. Do not re-attempt shared dispersion as the Σ fix.**
3. **The n_sim=2000 grid LANDED → HOLD (no nominal certificate).** gaussian ~0.91, binomial ~0.92,
   both ~2–4pt below nominal 0.95 (percentile bootstrap under-covers, misses 4–11:1 truth-above-upper).
   No coverage cell flips to nominal-certified; the widget carries an "approx-calibrated, NOT
   nominal-certified" note. Coverage flips remain the Claude lane's (yours).

## What Was Accomplished (this session + committed Lane A/B work)

- **Gaussian coverage bug FOUND + FIXED + VERIFIED.** Harness DGP added `sigma_eps` (var 0.25)
  omitted from the scored truth → estimator consistent for `truth+0.25` → coverage *collapsed with n*
  (0.90@n50 → 0.54@n150). Fix: `dev/m3-grid.R` gaussian branch returns `eta` (no separate residual).
  Verified at n_sim=2000: coverage 0.54 → **0.91, correct n-direction**. (Committed `84aea3e8`.)
- **nbinom2 fully characterised** as the NB-dispersion/latent-variance ridge; literature-grounded
  (68-source NotebookLM synthesis, `docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`);
  shared-dispersion falsified (Design 82). Fenced with G2/G3 honesty caveats (roxygen + extract_Sigma).
- **n_sim=2000 core-2 grid** (24 cells, Totoro, ~40h through lab contention) → HOLD verdict, committed.
- **Repair #5** (`ci_missing_rate` denominator) fixed (`c01a888c`). **Gamma residual scale-clobber
  bug** found + fixed by Lane B (`f9102922`) in the D-slice code.
- **Durable lessons recorded** (so we stop circling): the coverage-interval doctrine; the
  "theory-forbidden direction = our-bug" n-direction principle (2026-07-13); ETA discipline (estimate
  from the slow tail, quote pessimistic). All in `LESSONS.md` + `memory_summary.md`.
- All 5 parallel slices (B4 cluster2 C++, E2 reml-bridge, D residuals, E3 delta, C1 nbinom1) verified
  **81 pass / 0 fail**.

## Current Working State
- **Working:** gaussian DGP fix (verified); all slices (81/0); grid verdict; honesty fences; Repair #5.
- **In progress / next:** the profile/t-df coverage re-score (below).
- **Blocked on Shinichi (in worktrees, NOT on branch):** `disp_group=` API sign-off (built correctly
  but does not deliver its motivating benefit — land as a legit modelling option or not?);
  family-breadth roxygen advertising; tweedie stays-gated + stale-`~44%`-rationale refresh.

## Landing State (git ledger)
| Artifact / branch | Committed | Pushed | State |
|---|---|---|---|
| `claude/release-0.5.0` (Lane A+B body, 21 ahead of main) | y | **unknown — verify** | LANDED locally |
| `dev/m3-grid.R` gaussian fix, reml-bridge, diagnostics (`84aea3e8`) | y | ? | LANDED |
| Repair #5 (`c01a888c`), Gamma fix (`f9102922`), Design 82 (`4c2e2e02`) | y | ? | LANDED |
| `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md` (profile/t-df correction) | **NO — this session's edit** | n | **carried → commit with this handover** |
| `docs/dev-log/handover/2026-07-15-parallel-lane-handover.md` (Item 0 profile/t-df) | **NO** | n | **carried → commit with this handover** |
| `disp_group=` API | worktree `worktree-agent-a6930931ce81e02da` | n | CARRIED-OVER (Shinichi sign-off) |
| family-breadth roxygen | worktree `worktree-agent-a001dee2509c89dc2` | n | CARRIED-OVER (Shinichi sign-off) |
| tweedie refresh | worktree `worktree-agent-a33d0cc868dd580a0` | n | CARRIED-OVER (Shinichi sign-off) |

**🔴 Push status is unverified — confirm `git push` state before assuming a fresh-checkout / Codex
resume sees this branch. For a same-machine Claude resume the local commits suffice.**

## Next Immediate Steps (ordered)
1. **Profile/t-df coverage re-score** (THE certificate path). Re-score the same core cells
   (gaussian + binomial) on **(a)** the direct log-SD **profile** route (already "covered", Design 73)
   and **(b)** Wald-on-log-SD with a **t-quantile on `g−1`** df — per-target (t for location VCs;
   NOT for dispersion φ; ρ→Fisher-z). Compare to the bootstrap column in `~/gllvm_work/grid2000/`.
   Expect ~nominal (drmTMB profile hits 0.948–0.956 at adequate g). Where: `R/profile-ci.R` /
   `profile_targets()`; the m3 scorer `dev/m3-grid.R` currently routes `Sigma_unit_diag` to bootstrap.
2. **If profile/t-df reaches nominal → flip ONLY gaussian+binomial coverage cells** on widget/NEWS
   (A3); nbinom2 + ordinal stay fenced.
3. **Resolve the 3 Shinichi sign-offs** (disp_group / family-breadth / tweedie worktrees).
4. **Page-by-page doc-honesty review WITH Shinichi** — the standing pre-0.6 / pre-CRAN gate.
5. nbinom2 φ-bias (bias-corrected/penalised φ) is a deferred 1.0 methods lane, not 0.6.

## Blockers / Open Questions
- Push state of `claude/release-0.5.0` (verify).
- 3 worktree items await Shinichi's sign-off (above).
- The doc-honesty review is inherently with-Shinichi.

## Gotchas & Failed Approaches (do NOT retry)
- **BCa/studentized bootstrap** — the false lead in Lane B's bus note + the committed widget/finding.
  Superseded by profile/t-df. Not the fix.
- **Shared dispersion (`disp_group=`) as the nbinom2-Σ fix** — built, validated, FAILS (Design 82).
- **ML→REML as the gaussian/binomial coverage fix** — tested; REML barely moves Σ̂ (1.007→1.014); the
  gap is right-skew, not mean bias.
- **Optimistic compute ETAs** — the Totoro grid ran ~40h through lab contention; estimate from the
  slowest unit's observed rate, quote the pessimistic end (LESSONS 2026-07-15).

## How to Resume
Read, in order: this doc → the Mission Control GLLVM board (`http://127.0.0.1:8823/p/gllvmTMB/`,
`start.sh` in `…/mission-control/live/`) → `docs/dev-log/after-task/2026-07-13-coverage-diagnosis-gaussian-fix.md`
→ `docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md` → `docs/design/82-shared-dispersion.md` →
`docs/dev-log/check-log.md` (Lane A/B bus). Load the coverage doctrine from `LESSONS.md` (2026-07-15)
+ the cross-repo map BEFORE any interval work. Spawn Rose (claims/scope) before any public coverage claim.

**One-command resume (paste in an authenticated terminal at the repo root):**
```
claude "Rehydrate from docs/dev-log/handover/2026-07-16-claude-handover.md + the Mission Control GLLVM board, then continue with the profile/t-df coverage re-score (Next Immediate Step 1). Do NOT build BCa; do NOT re-attempt shared dispersion."
```

## Mission-control summary
| repo · branch · CI | what shipped this arc | next by leverage |
|---|---|---|
| gllvmTMB · `claude/release-0.5.0` (21 ahead) | gaussian coverage bug fixed+verified (0.54→0.91); grid→HOLD; nbinom2 shared-dispersion falsified; Repair #5 + Gamma bug; coverage doctrine recorded | **1** profile/t-df re-score (cert path) · **2** flip earned cells · **3** 3 Shinichi sign-offs · **4** doc-honesty review · **5** nbinom2 φ-bias (1.0) |
