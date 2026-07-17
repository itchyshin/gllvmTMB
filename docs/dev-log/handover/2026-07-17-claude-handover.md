# Handover → next Claude lane: Sigma_unit coverage arc (WITHHELD) + fresh-seed lift run IN FLIGHT

**Date:** 2026-07-17 · **From:** Claude (Lane A) → **you, the next Claude** · **Branch:** `claude/release-0.5.0`
You are picking up the gllvmTMB **coverage-certificate lane**. Read this, the committed after-task, and
the corrected inflight handover before touching anything.

## 🔴 CRITICAL CONTEXT — read first

1. **The gaussian n≥150 `Sigma_unit` diagonal coverage certificate is WITHHELD, not earned.** This is
   Shinichi's **committed** decision:
   - After-task: `docs/dev-log/after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md` (commit `f0f17333`).
   - Directed Lane-A note: `docs/dev-log/check-log.md` §"2026-07-17 → Lane A … WITHHELD" (commit `1d862396`).
   - **Why:** d1-n150 is certify-grade; **d2-n150 fails on rorqual (0.9398 < 0.94)** under the
     **COMMITTED conservative MCSE** (`m3-pilot-report.R:554` = `sqrt(p(1−p)/n_sim)` ≈ 0.0032 at N=5000).
2. **A prior in-session analysis WRONGLY concluded "EARNED"** using the looser trait-level ~0.0015 MCSE
   and no cross-hardware check, and got as far as applying — then fully **reverting** — a public flip.
   Nothing was committed; nothing public was touched. **Lessons that must stick:**
   - **Diff the repo before acting.** A concurrent Lane-A session committed WITHHELD to this branch
     *during* the session and I missed it. Keep Lane A single-threaded; `git log`/diff first.
   - **Use the COMMITTED MCSE convention (rep-level ~0.0032), NOT the clustered ~0.0015.**
3. **IN FLIGHT — the fresh-seed lift run (Option A, Shinichi-approved). This is your #1 continuation.**
   By the time you read this it has very likely **already finished** (it was ~1–1.5 h and had been
   running a while at hand-off) — so **check `FRESHSEED_DONE` FIRST**; you may go straight to aggregate.
4. **⚠️ THE BRANCH IS UNPUSHED.** A sustained safety-classifier outage blocked every `git push` at
   hand-off. Local commits ahead of origin: `c5c56f41` (#18 fix), `f0f17333` + `1d862396` (Shinichi's
   WITHHELD), `42b2b0a1` (this handover). **PUSH FIRST so nothing is lost:**
   `git push origin claude/release-0.5.0`. (A concurrent Tier-2 lane has *uncommitted* work in the tree
   — a push sends commits only, so it's safe, but coordinate the lane overlap + CLAUDE.md pointer.)

## Goals / mission

Close the coverage certificate **honestly** for 0.6: either **EARN** the gaussian n≥150 certificate by
making d2-n150 clear 0.94 **with margin** on fresh-seed reps under the committed MCSE, or confirm it's
genuinely borderline and **DEFER to 1.0** (recovery-only for 0.6). **No public flip without Shinichi.**
0.6 is the release; 0.5 is the cover-everything dev cycle; the certificate is a maturity nicety, not a
release blocker.

## Current working state

- **RUNNING (Totoro, detached):** the fresh-seed run — 96 shards, reps **5001..20000** (15,000 FRESH,
  disjoint-seed reps that POOL with the original 1..5000), `--family=gaussian --n-units=150`,
  `--n-boot=10` (profile is the target, bootstrap skipped for speed). Out-dir
  `~/gllvm_work/profile_rescore_freshseed`; log `freshseed.log` (end marker `FRESHSEED_DONE`); launcher
  `~/gllvm_work/run_freshseed.sh`. ~1–1.5 h. A poller (`bgxcjy8wf`) was armed this session but will NOT
  survive into your session — re-check manually.
- **Working tree (`claude/release-0.5.0`), uncommitted:** `dev/totoro-profile-rescore.sh` (S1
  `$HOME`/OUTDIR + socket-path fix), `dev/profile-rescore-run.R` (fresh-seed `--rep-start/--rep-end` +
  `--family/--n-units` extension). Untracked dev-log docs (this handover + the inflight handover + the S5
  wording draft + S7 review + S8 backlog). **NON-MINE uncommitted (leave alone):** `R/bootstrap-sigma.R`,
  `R/methods-gllvmTMB.R`, `tests/testthat/test-stage3-propto-equalto.R`. **NEVER commit `.claude/`.**

## Next immediate steps (in order)

1. **Wait for the fresh-seed run.** `ssh totoro 'grep FRESHSEED_DONE ~/gllvm_work/profile_rescore_freshseed/freshseed.log'`
   (Totoro is passwordless `ssh totoro`, NO Duo). Health: `pgrep -fc rep-start=5001`;
   `ls ~/gllvm_work/profile_rescore_freshseed/shard-*.rds | wc -l` (expect 192 = 96 shards × 2 cells).
2. **Aggregate + POOL + re-audit under the COMMITTED MCSE.**
   - Aggregate fresh: `ssh totoro 'cd ~/gllvm_work/gllvmTMB && OPENBLAS_NUM_THREADS=1 R_LIBS_USER=/home/snakagaw/gllvm_work/Rlib Rscript dev/profile-rescore-run.R --mode=aggregate --out-dir=/home/snakagaw/gllvm_work/profile_rescore_freshseed'`.
   - **POOL** the fresh 15k reps with the original 5k (`~/gllvm_work/profile_rescore/` on Totoro) →
     N=20,000, for `profile_total × Sigma_unit_diag`, gaussian d2 n150 (and d1 n150). Coverage =
     mean(covered) over pooled reps; **MCSE = sqrt(p(1−p)/N)** (committed; ≈ 0.0016 at N=20k). Report
     **d2 lower band = coverage − 2·MCSE**. (Also re-audit conditional-on-convergence: dropped reps are
     non-converged base fits; disclose the rate.)
3. **Verdict + next:**
   - **d2 lower band ≥ 0.94 with margin** → certificate **EARNED (fresh-seed)**. Spawn **Rose** for a
     clean re-audit (committed MCSE only). Then present the flip to Shinichi with the **conditional-on-
     convergence** wording (`docs/dev-log/2026-07-16-sigma-coverage-flip-wording-DRAFT.md` — needs "for
     converged fits", measured ~0.948, NO methodology/rate on public surfaces). **If Shinichi approves:**
     apply the S6 confint wiring (SAFE recipe in the inflight handover — the S6 worktree is on a STALE
     base, do NOT merge wholesale) + the three-surface flip, `document()`, test, commit — S6+flip as one
     coherent commit (z-confint holds both).
   - **d2 stays marginal** → genuinely borderline → **DEFER to 1.0, recovery-only for 0.6.** Close the
     arc; note it in the after-task + check-log; consolidate.
4. **Cross-hardware caveat:** the original rorqual run was SAME-seed (no new precision). If d2 is still
   borderline at N=20k, a rorqual **fresh-seed** run is the fuller confirmation (DRAC recipe in the
   committed after-task §Artifacts).

## Key decisions & rationale

- **WITHHELD** (Shinichi, committed) — d2-n150 not robustly ≥ 0.94 under committed MCSE + cross-hardware.
- **Committed MCSE = rep-level `sqrt(p(1−p)/n_sim)`** (`m3-pilot-report.R:554`); the trait-level 0.0015
  is wrong for the gate.
- **disp_group (shared NB2 dispersion): DEFERRED** (supersedes an earlier merge-as-opt-in rec).
- **Fences (non-negotiable):** no public flip without Shinichi; binomial/nbinom2/ordinal/off-diagonal/
  n<150 fenced; **Lane B (X_lv) / Lane C (multinomial) files OFF-LIMITS.**

## Files created / modified (this session)

- **Committed:** `c5c56f41` — Ayumi #18 convergence-criterion fix (`R/bootstrap-sigma.R` +
  `tests/testthat/test-bootstrap-Sigma.R` + `man/bootstrap_Sigma.Rd`).
- **Uncommitted (commit with this handover):** `dev/totoro-profile-rescore.sh`, `dev/profile-rescore-run.R`.
- **Docs:** this handover; `docs/dev-log/handover/2026-07-16-claude-handover-nsim5000-inflight.md`
  (CORRECTED to WITHHELD — has the S6 safe-apply recipe + fresh-seed staging);
  `docs/dev-log/2026-07-16-sigma-coverage-flip-wording-DRAFT.md`; `…-held-signoffs-review.md`;
  `…-methods-backlog-0.6-to-1.0-scoping.md`.
- **External (GitHub):** Ayumi `#17` + `#18` replies posted; gllvmTMB tracking issue **#750**
  (unconditional RE redraw) opened.

## Gotchas / failed approaches

- **Repo is ground truth — diff before acting.** (The near-flip above.)
- **The S6 worktree `.claude/worktrees/agent-ae50a884b8bfbdef5` is on stale base `8ec261bb`** — wholesale
  merge deletes ~6,700 lines. Re-apply only the genuine wiring (recipe in the inflight handover).
- **Classifier flakiness:** the shell-safety classifier was intermittently down for long stretches; git/
  ssh tool-calls failed ~half the time. Retry; prefer idempotent commands; batch launch+poll into one
  background command to minimise classifier gates.
- **Totoro:** passwordless `ssh totoro`, no Duo, ≤100 cores, results LOCAL (never GitHub artifacts, D-50).
  Launcher redirect bug: `mkdir -p` the out-dir BEFORE the `setsid … > log` redirect.

## How to resume

1. Open the capability widget / Mission Control (CLAUDE.md step 0).
2. Read: this doc → the committed after-task `2026-07-17-sigma-coverage-nsim5000-confirm.md` → the
   corrected inflight handover → the check-log Lane-A note.
3. `git log --oneline -6` and `git status -sb` — confirm HEAD and the uncommitted set above.
4. Check the fresh-seed run (step 1 above); continue from step 2.
5. **Spawn Rose before ANY public coverage claim.** No flip without Shinichi.

### One-command resume (paste in your authenticated terminal at the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover.md + the CLAUDE.md snapshot, then continue the Next Immediate Steps: wait for the Totoro fresh-seed run (FRESHSEED_DONE), aggregate + pool to N=20000, and re-audit d2-n150 under the COMMITTED MCSE (sqrt(p(1-p)/N), m3-pilot-report.R:554 — NOT the clustered 0.0015). Coverage arc is WITHHELD until d2 clears 0.94 with margin. Do NOT flip any public surface without Shinichi; spawn Rose before any coverage claim."
```

## Mission-control summary

| repo · branch · CI | what shipped this session | next by leverage |
|---|---|---|
| gllvmTMB · `claude/release-0.5.0` | Coverage arc **WITHHELD** (repo truth; my "earned" was wrong — looser MCSE + no cross-hardware — flip reverted, nothing public). Ayumi **#18** convergence fix `c5c56f41` committed; **#17/#18** replies posted; tracking issue **#750** opened. Fresh-seed lift run (A) **launched on Totoro** (reps 5001–20000, gaussian n150). Runner extended for fresh rep windows; S1 launcher fix. | **1** wait `FRESHSEED_DONE` → aggregate + **pool to N=20k** → re-audit d2 under **committed MCSE** · **2** earn→Rose re-audit + present flip (Shinichi) / marginal→defer to 1.0 · **3** if earned + approved: apply S6 wiring (safe recipe) + flip · **4** 3 held sign-offs (disp_group DEFERRED) |
