# Session Handoff → next Claude (2026-07-09)

**Meta:** 2026-07-09 · from Claude (Ada) · **TARGET = the next Claude.** Two things carry over:
a **finished-but-unshipped** arc, and a **prepared-but-unrun** compute campaign. Nothing is
merged; two local branches hold all the work. Spawn **Rose** before any register/public claim.

---

## Goals / mission
1. **Ship the "second-order-flag" fix** — the test/CI suite no longer trusts `fit$opt$convergence`,
   `pd_hessian`, or an eigenvalue sign; it uses one scale-free convergence verdict. Done + verified,
   **not pushed** (maintainer said hold).
2. **Drive gllvmTMB to v1.0** — the headline gate is the **B_lv calibrated-interval (ADEMP)
   coverage campaign** under orthogonal Model A (`latent(lv=~x) + phylo_latent`). Runner rebuilt +
   validated tonight; **not yet run at production scale** (compute pending).

## Critical context (read or you will redo work)
1. **Everything is on two UNPUSHED local branches. `origin` does not have it.** A fresh checkout
   sees `main` only. **Push is the maintainer's call** — do not push without asking.
   - `claude/converged-verdict` — 61 files, 4 commits: the flag-class fix (P1/P2/P3). **Verified.**
   - `claude/blv-coverage-campaign` — 2 files, 1 commit (`a1d9f36e`): the rebuilt coverage runner +
     Totoro launcher. Off `origin/main`; uses an **inline** verdict so it needs no unmerged code.
2. **Today's merges are already on `origin/main`** (`e755ae39`): #733 (aliased diagonals + H²=1),
   #734 (docs), #735 (phylo-q locale/convergence). The converged-verdict branch builds on that.
3. **The #733 fix changed the campaign.** Post-fix, Model A fits at `unit==cluster` with a **PD
   Hessian**, so `extract_lv_effects()` returns a **finite Wald** arm again (Design 76 §7 called it
   "structurally absent" — that was the alias). The estimand B_lv is still profile-only per entry;
   Wald is axis-scale (rotation-dependent), not a per-entry B_lv interval.

---

## What was accomplished (this session)
- **Merged** #733 / #734 / #735 (three defects fixed: aliased species-level diagonals corrupting
  variance readouts; `extract_phylo_signal()` reporting H²=1 in crossed designs; the phylo-q
  convergence test asserting a locale-flipping status code).
- **Built + verified the converged-verdict arc** (branch `claude/converged-verdict`):
  - **P1** `feat(diagnose)`: `fit_health$converged` + `scaled_gradient` (= `max|grad|/(1+|obj|)`,
    threshold `1e-3`). `pd_hessian` is dropped from the verdict (its sign near zero is FD noise).
    Validated on a known-truth battery 6/6 + a 12-assertion test-of-the-test.
  - **P2** `test(infra/migrate)`: `.fit_converged()` predicate + `expect_converged()` delegate;
    migrated **47 guard-bearing test files** (123 skip-guards) from `!conv||!pd` to the verdict, and
    their coupled `expect_true(pd_hessian)` / `expect_equal(convergence,0L)` asserts.
  - **P3** `ci(recovery)`: vacuity guard on 8 recovery workflows — a gate that skips **all** its cells
    now fails instead of reporting green (audit found `spatial-dep-slope-nongaussian` green with 7/7
    skipped).
  - **Heavy verify (46 files):** `PASS 2503 · FAIL 0 · ERROR 0 · SKIP 9`. Baseline was 2464/0/18 →
    **+39 passes, 0 regressions, 9 genuine-non-convergence skips remain** (spatial_dep ×7, m2-2a
    ordinal, spatial_unique — all correct). The class is retired at the source.
- **Prepared the B_lv coverage campaign** (branch `claude/blv-coverage-campaign`):
  - Rebuilt `dev/lv-effects-ci-coverage.R`: all `T×n_pred` B_lv entries per rep (was `[1,1]`),
    verdict-gated (honest failed-fit denominators), `pd_hessian`+`wall_s` recorded, resume-safe,
    `bench` mode, per-entry + pooled coverage/MCSE. Added the S400-K1 n-ladder cell and the
    **never-run** S200-K2-hard cell. Fixed a rank-2 index bug (`B_lv` is `T×n_pred`, not `T×K_B`).
  - `dev/lv-effects-ci-coverage-totoro.sh`: `xargs -P` launcher, ≤100-core courtesy cap, resume-safe.
  - **Totoro is set up:** `~/gllvmtmb_work/gllvmTMB` fast-forwarded to `e755ae39`, **gllvmTMB built**
    (R 4.5.3, TMB 1.9.21). Runner + launcher copied there. Old/mixed results archived.
- Banked LESSONS 0c (second-order flags) in the brain.

## Current working state
- **Working / verified:** `claude/converged-verdict` — non-heavy + 46-file heavy suites green,
  `devtools::check()` NOT yet run. `claude/blv-coverage-campaign` — runner validated locally.
- **In progress / blocked:** the coverage campaign has **not run at production scale**. One
  Totoro launch tonight was a **false start** (see Gotchas) and was killed + cleaned; Totoro carries
  **no processes of ours**. Only 1 local smoke CSV exists — **no real campaign results yet.**
- **Not started:** `devtools::check()` on the verdict branch; the LR-pivot; the follow-ups below.

## Next immediate steps (ordered)
1. **Decide + (if approved) ship the flag-class arc.** `git push -u origin claude/converged-verdict`
   → PR → CI green on HEAD → **maintainer merges** (high-risk suite-wide test change; do NOT
   auto-merge). Run `devtools::check()` locally first (expect 0E/0W, 2 pre-existing notes).
2. **Run the campaign's fast rank-1 cells** when a machine is free (Totoro was busy tonight — see
   below). On Totoro, attach over the live master and:
   `cd ~/gllvmtmb_work/gllvmTMB && OPENBLAS_NUM_THREADS=1 ./dev/lv-effects-ci-coverage-totoro.sh gauss-S200-K1 500 5 <width>`
   (repeat for `gauss-S60-K1-smalln`, `gauss-S100-K1`, `gauss-S400-K1`). Fast: 14–90 s/rep.
   **Courtesy: keep our width ≤100 cores; if load ≥300, wait** (maintainer's rule). Then
   `Rscript dev/lv-effects-ci-coverage.R summarise results/lv-effects-ci-coverage`.
3. **Build the LR-at-truth pivot — this is the opener that unlocks the hard cell.** The rank-2
   `gauss-S200-K2-hard` cell is **~7300 s/rep (122 min)** with profile root-finding (8 entries ×
   ~120 constrained refits) — intractable for 500 reps. Store `LR_at_truth = 2(ℓ_max −
   ℓ_constrained(B_lv=truth))` via **one** constrained refit per entry (reuse
   `.profile_ci_via_refit` / `make_target` in `R/profile-derived.R` at the fixed truth value). Then
   coverage under **any** df/level is a free post-hoc recomputation — and the empirical LR
   distribution answers the open **profile t-df question** (`n_units−d−1` vs `n_units−n_pred`)
   without settling it blind. ~15–25× faster → K2 becomes tractable.
4. **Then** run K2 + the df-separating cells; close CI-08/CI-10's *actual* estimands and promote
   LV-08/LV-09 strictly on delivered evidence (Rose audit).

## Blockers / open questions
- 🔴 **Maintainer — push the two branches?** Both are local/unpushed. `converged-verdict` is
  verified and ready; the maintainer said "hold" earlier tonight. Nothing ships until pushed.
- 🔴 **Compute venue.** DRAC (fir/nibi/rorqual/trillium/narval/vulcan/killarney) all have **dead
  ControlMaster sockets** — a fresh connect needs **Cisco Duo MFA** the human must approve; a
  headless session **cannot** establish DRAC. **Totoro** is the only live connection (master pid
  alive), but tonight it was **busy with others** (`hq7` ~192 cores, load 300+). Maintainer also
  mentioned an **18-core fallback machine** (use ≤18) — connection details not captured.
- 🟡 **Profile t-df** default is `n_units − d_B − 1` (`R/profile-derived.R:1259`); first-principles
  argues `n_units − n_pred`. The LR pivot (step 3) turns this into a campaign *output*, not a
  pre-decision.

## Gotchas / failed approaches (do not retry)
- **`pkill -f <pat>` self-matches its own command line** → it killed its own ssh shell mid-run
  (every "no output"). Use the bracket trick: `pkill -9 -f "[l]v-effects-ci-coverage"`. And the R
  **worker** cmdline is `…--file=dev/lv-effects-ci-coverage.R --args run …` — there is ` --args `
  between `.R` and `run`, so a pattern `…coverage.R run` matches the `Rscript` wrapper but **not**
  the worker. Match the broad token.
- **Stale results + resume = schema mixing.** The old runner wrote `[1,1]`-only rows with fewer
  columns; the new runner writes per-entry with `pd_hessian`/`df`. The resume logic (`skip if task
  CSV exists`) will mix schemas. **Archive/clear `results/lv-effects-ci-coverage/` before a fresh
  campaign** (done on Totoro tonight).
- **The K2 cell is intractable without the LR pivot** (122 min/rep). Don't launch a 500-rep K2 run
  with profile root-finding.
- **A timed-out `ssh totoro '…Rscript…'` leaves the remote Rscript orphaned** (keeps running,
  ~95 cores tonight). Clean up with the bracket-trick pkill afterward.
- **Attach to Totoro without MFA** over the live master:
  `SOCK=~/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22; ssh -o ControlPath="$SOCK" -o ControlMaster=no totoro '<cmd>'`.
- **`extract_lv_effects()` is axis-scale Wald** (rotation-dependent) — NOT a per-entry B_lv
  interval. Profile is the estimand's method. A delta-method per-entry Wald arm is a follow-up.
- **Do NOT trust an inherited handover's "blockers" as state** — re-verify against the repo (this
  session disproved three from the 2026-07-08 handover: CI-08/CI-10 were a different estimand, the
  B_lv trio was already built, and the campaign was already partly run).

## Files created / modified
- **Branch `claude/converged-verdict` (61 files, 4 commits vs `origin/main`):** `R/diagnose.R`,
  `tests/testthat/setup.R`, `tests/testthat/test-fit-health-converged.R` +
  `test-expect-converged.R` (new), **47 migrated guard test files** (`test-matrix-*`, `test-tiers-*`,
  `test-spatial-*`, `test-cluster2-families.R`, `test-gamma-recovery-depth.R`,
  `test-m2-2a-binary-recovery.R`, `test-ordinal-recovery-depth.R`, `test-simulate-unit-trait.R`,
  `test-crosspkg-nbinom1-glmmTMB.R`, `test-phylo*-binary.R`, `test-matrix-slope-*`), 8
  `.github/workflows/*-recovery.yaml`, `NEWS.md`, `docs/dev-log/audits/2026-07-08-skip-on-flag-audit.md`,
  `docs/dev-log/after-task/2026-07-08-diag-tier-alias-fix.md`,
  `docs/dev-log/after-task/2026-07-08-phylo-q-convergence-locale.md`.
- **Branch `claude/blv-coverage-campaign` (2 files, 1 commit):** `dev/lv-effects-ci-coverage.R`
  (rebuilt), `dev/lv-effects-ci-coverage-totoro.sh` (new).
- **This handover:** `docs/dev-log/handover/2026-07-09-claude-handover.md` + the `CLAUDE.md` pointer.
- **Never commit:** the untracked `results/` dir (local smoke output). Totoro
  `~/gllvmtmb_work/gllvmTMB` is a separate checkout (its own `results/` archived, not this repo).

## Mission control

| Item | State |
|---|---|
| Repo | `gllvmTMB` @ `origin/main` = `e755ae39` (#733/#734/#735 merged) |
| Branch A | `claude/converged-verdict` — 4 commits, **verified** (46-file heavy: 2503P/0F/9 genuine-skip), **UNPUSHED** |
| Branch B | `claude/blv-coverage-campaign` — 1 commit, runner validated, **UNPUSHED** |
| Flag-class arc | **Done** — one scale-free verdict; suite no longer trusts `convergence`/`pd_hessian` |
| B_lv campaign | **Prepped, not run.** Totoro built + staged; fast cells ready; K2 needs the LR pivot |
| Totoro | live master; gllvmTMB built @ post-#733; **busy w/ others tonight** (hq7 ~192c); our procs = 0 |
| DRAC | all sockets **dead** — needs human Duo MFA to reconnect |
| Next by leverage | 1) push+PR the verdict arc → 2) run fast cells → 3) build LR pivot → 4) K2 + df + promote |
| Version | DESCRIPTION stays `0.2.0` |

## How to resume
1. **Rehydrate:** read this doc → `CLAUDE.md` / `AGENTS.md` → `~/.claude/memory/memory_summary.md`
   (D-12 profile doctrine, compute defaults, LESSONS 0c) → `docs/design/76-structured-xlv-phylo.md`
   §7 (Model A) → `docs/design/61-capability-status.md` (register gates).
2. **Confirm state, don't assume:** `git log --oneline -4 claude/converged-verdict`;
   `git log --oneline -1 claude/blv-coverage-campaign`; `git branch -vv` (both **ahead, unpushed**).
3. **Spawn Rose** before any register/public claim (profile & coverage inference is
   correctness-critical; LV-08/CI-08/CI-10 are register gates).
4. **Claude vs Codex:** design/refactor/prose + the LR-pivot code here; hand the **live heavy
   campaign** (real fits at scale on Totoro/DRAC) to Codex or straight to the cluster.

### One-command resume (paste in your authenticated terminal, from the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-09-claude-handover.md + the CLAUDE.md pointer. Two unpushed branches: claude/converged-verdict (verified flag-class fix, ready to push+PR on my OK) and claude/blv-coverage-campaign (coverage runner). Do NOT push without asking me. Then continue the Next Immediate Steps: settle whether to ship the verdict arc, then either run the fast rank-1 coverage cells on a free machine or build the LR-at-truth pivot that unlocks the rank-2 cell."
```
