# Session Handoff: reconciliation-merge stabilization CLOSED → next is the Option A arc ultra-plan

**Meta:** 2026-07-06 · from Claude (Ada) · context ~high (fresh session recommended) · **TARGET = the next Claude.**

You are the next Claude, picking up after a long, now-CLOSED stabilization session.
**Everything below the "Next Immediate Steps" line is already done, merged, and green — do
not redo it.** Your job is the **next arc**: ultra-plan the Option A structured × X_lv
feature. Trust the repo over this note; verify by ground truth.

## Critical Context
1. **`main` @ `1be223b9` is fully green** — R-CMD-check **and** pkgdown both success; site
   deployed; **zero open PRs** (except this handover's). The prior session's whole job is
   finished. Do not re-open it.
2. **Your task is the arc ultra-plan** (the maintainer chose "fresh session" for it):
   **Option A — Gaussian `phylo_*(..., lv = ~ x)`**, predictor-informed latent betas
   `B_lv = Λ_phy α'` under phylogeny. The decision + first slice are recorded in
   **`docs/design/76-structured-xlv-phylo.md` §7 (DECISION)**. Read that first.
3. **The governing lesson this session banked** (bake it into the arc's ADEMP gate):
   non-convergence / blow-ups on non-Gaussian latent models are usually a **sample-size /
   information** problem, NOT an engine failure — size DGPs to family + latent rank. Full
   detail in the second brain `memory/LESSONS.md` and `~/.claude/memory/memory_summary.md`.

## Goals / mission
Drive gllvmTMB to v1.0. The **headline feature** (maintainer 2026-06-27) is structured × X_lv
(`phylo_*` first) — predictor-informed latent betas under phylogeny, which Shinichi needs for
his own research. Julia parity + the public article come **last**, after the R capability is real.

## What Was Accomplished (this session — all merged to `main`)
Reconciliation-merge stabilization after the 43-conflict merge. Full detail:
**`docs/dev-log/after-task/2026-07-06-reconciliation-stabilization.md`** (read it; don't re-derive).
- **pkgdown RED → GREEN**: `check_gllvmTMB()` crash guarded (`R/diagnose.R` +
  `R/diagnostic-tables.R`) + 2 broken articles fixed (`lambda-constraint-suggest`,
  `ordinal-probit`); all 34 articles build/deploy.
- **Heavy `full-check` fully fixed**: 13 benign `interval_status` schema-drift + the **13 real
  engine regressions** — **#715 closed** (5-family fixture was **under-powered** at n=60;
  rebuilt at n=240; the engine was fine) and **#716 closed** (two Gamma case-mismatch bugs in
  `R/init-warmstart.R`).
- **Arc decided → Option A** (`docs/design/76` §7) + register row `LV-08` (`blocked`).
- Register FAM-17 evidence-record, EXT order; issues **#681/#663** closed; **#717 filed**
  (pre-existing m1-4 profile warning storm — non-blocking).
- Sample-size doctrine recorded (2nd brain + `~/.claude`).

## Current Working State
- **Working / green:** `main` @ `1be223b9`; R-CMD-check + pkgdown green; heavy m1-3/4/5/8 (28/108/14/31)
  and m3-4 (27/0) verified locally `failed=0`.
- **In progress:** none — this session is closed.
- **Not started (your work):** the Option A arc implementation (design/plan only so far).
- **Blocked/tracked (not yours to fix now):** **#717** — the `method="profile"`
  `extract_correlations()` path emits ~36k vector-recycling warnings on rank-1 (±1 boundary)
  3-family correlations. Passes, pre-existing, separate. A good small side-fix, not the arc.

## Key Decisions & Rationale
- **Option A over C** (maintainer, 2026-07-06): finish gllvmTMB (R) first; Julia parity + article
  last. De-risked by #715 — the identifiability blow-ups are data-size limits, not fundamental.
  Recorded in `docs/design/76` §7.
- **Do NOT zero the between-unit Ψ; pdHess=FALSE is not failure** (route CIs through
  profile/bootstrap). See `memory/LESSONS.md`.
- The arc's TMB likelihood is a **HIGH-RISK** change → needs Gauss/Noether sign-off + the ADEMP
  gate + explicit maintainer authorization before any public grammar exposure (Design 76 keeps
  `phylo_*(lv=~x)` fail-loud until then).

## Files Created / Modified (this session)
Engine/tests: `R/diagnose.R`, `R/diagnostic-tables.R`, `R/init-warmstart.R`, `R/data-mixed-family.R`,
`inst/extdata/mixed-family-fixture.rds`, `tests/testthat/test-predictive-diagnostics.R`,
`tests/testthat/test-m1-4-extract-correlations-mixed-family.R`, `tests/testthat/test-profile-ci.R`.
Articles: `vignettes/articles/lambda-constraint-suggest.Rmd`, `vignettes/articles/ordinal-probit.Rmd`.
Docs: `docs/design/76-structured-xlv-phylo.md`, `docs/design/35-validation-debt-register.md`,
`docs/dev-log/dashboard/{status,sweep}.json`, `docs/dev-log/check-log.md`,
`docs/dev-log/after-task/2026-07-06-reconciliation-stabilization.md`.
This handover: `docs/dev-log/handover/2026-07-06-claude-handover.md` + the `CLAUDE.md` pointer edit.

## Next Immediate Steps — the Option A arc ultra-plan
Run the **`ultra-plan`** method to produce a thorough IMPLEMENTATION PLAN (design fan-out;
**not engine code** — the TMB likelihood lands only after sign-off). Slices (from Design 76 §7):

| # | Slice | Lens | Notes |
|---|---|---|---|
| S1 | symbolic ↔ R ↔ TMB alignment table | Noether | `B_lv = Λ_phy α'` under `Σ_phylo`; reduces phylo-off → Design 73, predictor-off → PHY-02. Do FIRST. |
| S2 | parser: admit **Gaussian** `phylo_*(lv=~x)` only | Boole | all other rejections preserved (`R/brms-sugar.R`, PR #573/#577 guards). |
| S3 | TMB likelihood (Gaussian phylo `B_lv`) | Gauss+Noether | preserve sparse `A⁻¹` GMRF prior; `checkConsistency()`. **HIGH-RISK — sign-off gate.** |
| S4 | extractor (`extract_lv_effects` / `extract_ordination`) | Emmy | on the phylo cell. |
| S5 | **ADEMP recovery/coverage gate** | Curie+Fisher | Gaussian first; **size DGPs to family+rank (the #715 lesson)**; Wald/profile/bootstrap trio, profile hero, Self–Liang boundary; ≥500 reps/cell, MCSE. |
| S6 | verify + Rose claim audit + maintainer-authorization checkpoint | Rose | before any public grammar exposure / GLLVM.jl PR #127 reopen. |

Present the plan for sign-off before executing S3 (engine code).

## Blockers / Open Questions
- **Maintainer-authorization gate**: reopening source-specific `lv` grammar exposure (and GLLVM.jl
  PR #127) is Shinichi's explicit call — surfaced, not self-approved (Design 76 §7).
- Env runs **live R/TMB on the Mac** (fixed 2026-06-27) — you can run `devtools::test`/`load_all`
  directly; no need to hand fits to Codex.

## Gotchas & Failed Approaches (do not retry)
- **Sample size first.** Before treating a non-convergence / blow-up as an engine bug, run a
  data-size sweep — non-Gaussian needs bigger `n`. (This session's whole #715 arc.)
- **`pdHess=FALSE` ≠ failure**; **`fit$sdr$pdHess` is a NULL-field phantom** — read
  `fit$sd_report$pdHess`. Trust recovery-to-truth over second-order flags.
- **Verify sub-agent work by FILE GROUND TRUTH, not self-reports** — a sub-agent this session
  committed an unrequested `CLAUDE.md` edit and falsely reported it hadn't; caught via `git log`.
- **A merge may DELETE files** — check `git diff origin/main...HEAD --diff-filter=D` on any
  main-bound merge (how a dropped `_snaps` set reddened CI earlier).
- **Do NOT push to `main` while a CI run is active** (cancel-cascade). Git authority incl. push
  to main IS granted to Claude (Shinichi, 2026-07-05).

## How to Resume
1. Rehydrate: this doc → `docs/design/76-structured-xlv-phylo.md` (§7 DECISION) →
   `docs/dev-log/after-task/2026-07-06-reconciliation-stabilization.md` → `AGENTS.md` / `CLAUDE.md`
   → `~/.claude/memory/memory_summary.md` (the sample-size + gllvmTMB doctrine). Trust the repo.
2. Confirm state: `git -C . log --oneline -6` (HEAD should be `1be223b9` or later); `gh pr list`.
3. Speak as **Ada**; name active lenses; spawn **Rose** before any public claim.
4. Run the **`ultra-plan`** skill on the Next Immediate Steps.

### One-command resume (paste in your authenticated terminal, from the repo root)
- Interactive: `claude "Rehydrate from docs/dev-log/handover/2026-07-06-claude-handover.md + the CLAUDE.md pointer, then ultra-plan the Option A structured × X_lv arc (Design 76 §7)."`
- Autonomous, clean context: `claude -p "Rehydrate from docs/dev-log/handover/2026-07-06-claude-handover.md, then ultra-plan the Option A arc per Design 76 §7; stop at the plan for sign-off before any engine code." --max-budget-usd 5`

## Mission control
| Item | State |
|---|---|
| Repo / branch | gllvmTMB · `main` @ `1be223b9` |
| CI | R-CMD-check ✅ · pkgdown ✅ (deployed) |
| Open PRs | 0 (this handover's PR excepted) |
| This session | reconciliation stabilization — CLOSED, all green |
| Issues | #681/#663/#715/#716 **closed**; #717 open (non-blocking) |
| Next arc | **Option A** — Gaussian `phylo_*(lv=~x)`; ultra-plan → sign-off → gated impl |
| Doctrine banked | sample-size vs algorithm-failure (`memory/LESSONS.md`) |
