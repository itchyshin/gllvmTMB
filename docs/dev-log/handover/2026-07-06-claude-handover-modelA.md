# Session Handoff: structured × X_lv arc RE-SCOPED to orthogonal Model A (already works) → build the B_lv CI

**Meta:** 2026-07-06 (later same day) · from Claude (Ada) · context ~high (fresh session recommended) · **TARGET = the next Claude.**

You are the next Claude, picking up an arc that got **dramatically smaller and lower-risk mid-session**.
The prior handover (`2026-07-06-claude-handover.md`) set up a HIGH-RISK new-TMB-likelihood arc for an
*interacting* phylo × X_lv model. **That framing is superseded.** Checking prior work (the maintainer's
instinct) plus one empirical test collapsed it. Trust the repo + **Design 76 §7 UPDATE** over the older
plan/S1 docs.

## Critical Context (read this or you'll redo dead work)
1. **The model is orthogonal "Model A", NOT the interacting model** that `docs/dev-log/2026-07-06-xlv-phylo-S1-alignment.md`
   and `...-execution-plan.md` describe. Predictor informs the **ordinary** latent (`z~N(0,I)`, the
   Design-73 `latent(...,lv=~x)` already in R); phylogeny is a **separate, orthogonal** term. `B_lv = Λ_B·α^T`
   is the ordinary estimand. Authoritative record: **`docs/design/76-structured-xlv-phylo.md` §7 UPDATE**
   (dated 2026-07-06 later same day). The interacting model is the **deferred alternative**.
2. **Model A ALREADY FITS + RECOVERS `B_lv` in R — no new likelihood, no grammar change.** Verified:
   `latent(0+trait|species, d=K, lv=~x) + phylo_latent(0+trait|species, d=Kφ)` converges and recovers
   `B_lv` (truth 0.90/0.72/−0.54/0.45/0.27 → 0.81/0.69/−0.46/0.44/0.25). The whole HIGH-RISK S3 slice is gone.
   S2 (parser grammar) was for the interacting model and is **reverted**.
3. **The only remaining work is the `B_lv` CI trio + ADEMP** — all R-side inference, low-risk. Profile is the
   hero, **with a t-based cutoff** (maintainer directive, said twice). Infra is **built + committed** (see below).
4. **Maintainer architecture note (2026-07-06):** profile already works for the **cluster and cluster2** tiers,
   and **unit/cluster/cluster2 can each carry two random effects (a `latent` + a `phylo_latent`)** — the Model A
   pairing is a general, supported per-tier pattern. So `profile_ci_lv_effects()` must be **tier-aware**, mirroring
   the existing tier handling, not hard-coded to unit.

## Goals / mission
Drive gllvmTMB to v1.0; the **headline feature** is structured × X_lv. Per the maintainer (2026-07-06):
**focus on finishing gllvmTMB (R) first**; Julia parity + the article come last.

## What Was Accomplished (this session)
- **Closed the prior session:** merged PR #718 to `origin/main` (`13686230`).
- **Prior-work sweep** (maintainer directive) — found the GLLVM.jl **Model A reference** (`src/confint_family.jl`
  `confint_lv_effects` Wald/profile/bootstrap; `likelihood.jl` lines 405-408/485-505 prove the orthogonal design),
  **D-12 / task #22** (`B_lv :profile` = "the one missing trio member"; boundary bug at `R/profile-ci.R`), and the
  frozen Julia Gate 0-3 evidence. Recorded the discipline durably (see Files).
- **Model decision → orthogonal Model A** (maintainer). **Empirically proved it already composes + recovers `B_lv`
  in R.** Reverted S2.
- **Built + validated the t-based profile CI infra** (committed `72de7240`): `.qt_threshold(level, df)` +
  a `crit` hook on `.profile_ci_via_refit` (backward-compatible). Scratch prototype confirmed the `B_lv` target is
  **exact** (direct-from-fixed-par diff = 0 vs report) and the t-cutoff widens correctly (df=8 → 2.66 vs χ² 1.92).
- **Updated Design 76 §7** with the Model A re-scope.

## Current Working State
- **Working / green:** `origin/main` @ `13686230` (R-CMD-check + pkgdown green). Model A composition fits +
  recovers `B_lv` locally. Infra (`.qt_threshold` + `crit`) loads clean; existing profile CIs unchanged (default
  `crit=NULL` → `qchisq`).
- **In progress:** `profile_ci_lv_effects()` — prototype validated in scratch
  (`scratchpad/blv-profile-proto.R`), **not yet promoted** to `R/profile-derived.R`.
- **Not started:** bootstrap leg; ADEMP at power; the doc revision (#14); extractor `method="profile"` wiring.
- **Blocked/tracked:** none blocking. The GLLVM.jl weak cell (`p=80,K=2,λ=0.5`) was **under-powered**, not broken
  (#715 lesson) — S5b just needs adequate `n`.

## Key Decisions & Rationale
- **Orthogonal Model A over the interacting model** (maintainer, 2026-07-06): it's what GLLVM.jl de-risked, it
  composes existing R capabilities, and it's identifiable. Interacting model deferred. (Design 76 §7 UPDATE.)
- **Profile = hero, t-based cutoff** (maintainer, 2x; D-12 / task #22; drmTMB#680 is the *separate* deferred
  cutoff-recalibration lane — do not conflate). Per-target/adaptive df is the DRM-thread refinement.
- **`pdHess=FALSE` here is not failure** — mild ordinary-vs-phylo latent-variance trade-off on the shared
  `species` grouping (a *supported* same-tier pairing); route CIs through profile/bootstrap.

## Files Created / Modified (this session)
Branch `claude/xlv-phylo-gaussian` (4 commits; **UNPUSHED** — see Blockers). vs `origin/main`:
- `R/profile-ci.R` — add `.qt_threshold(level, df)` (t-based cutoff).
- `R/profile-derived.R` — `.profile_ci_via_refit` gains optional `crit` arg.
- `docs/design/76-structured-xlv-phylo.md` — §7 UPDATE (Model A decision + re-scope).
- `docs/dev-log/2026-07-06-option-a-xlv-phylo-execution-plan.md` — the plan (**interacting model — needs Model-A revision, #14**).
- `docs/dev-log/2026-07-06-xlv-phylo-S1-alignment.md` — S1 alignment (**interacting model — needs revision, #14**).
- `docs/dev-log/after-task/2026-07-06-option-a-xlv-arc-plan.md` — after-task (pre-re-scope).
- This handover + the `CLAUDE.md` pointer bump.
**Hub (second brain, `~/Dropbox/Github Local/Shinichi/`, uncommitted but Dropbox-durable):**
`skills/ultra-plan/SKILL.md` (new **Phase 0.25 — Prior-work sweep**), `memory/LESSONS.md` (prior-work lesson).
**Scratch (not committed):** `scratchpad/modelA-compose-test.R` (composition+recovery), `scratchpad/blv-profile-proto.R` (profile prototype).

## Next Immediate Steps (ordered)
1. **Promote `profile_ci_lv_effects()`** into `R/profile-derived.R`: **tier-aware** (unit/cluster/cluster2 —
   mirror existing profile-tier handling), **general-rank** `B_lv` target (rank-1 is `theta_rr_B[t]·alpha_lv_B[j]`;
   d>1 needs the loading unpack — or `obj$fn(par)` then `report()`), **t-based crit** via `.qt_threshold(level, df)`
   with `df` default `n_units − d − 1` (pluggable; per-target/adaptive `df_eff` as refinement), then wire into
   `extract_lv_effects(method="profile")`.
2. **Give the constrained refit an analytic gradient** — `.fix_and_refit_nll` finite-differences the penalized
   objective and is **slow at realistic scale** (the prototype had to be killed). This is the practicality blocker.
3. **Parametric bootstrap leg** for `B_lv` (resample the phylo block; mirror the Julia `_lv_boot_fns` /
   any existing bootstrap machinery).
4. **ADEMP recovery/coverage at adequate `n`** (S5b) — profile hero, Wald/profile/bootstrap trio, ≥500 reps/cell,
   MCSE, per Design 76 §5; include the known-hard `p=80,K=2,λ=0.5` cell sized up.
5. **Revise S1 + the execution plan to Model A** (#14) — they describe the interacting model.
6. **S6:** `devtools::check()` + pkgdown local green; Rose claim audit; move `LV-08` only on delivered evidence.

## Blockers / Open Questions
- 🔴 **Needs Shinichi — UNPUSHED work.** Local `main` (`cbdec314`, plan/S1/after-task) and branch
  `claude/xlv-phylo-gaussian` are **not on `origin`** (an earlier `main` push was declined). The next session
  checks out a fresh tree — **this branch must be pushed** (this handover pushes it if permitted; else the human
  must). `origin/main` is still `13686230`.
- **t-df choice** for the profile cutoff (default `n_units−d−1` vs per-target/adaptive `df_eff`) — maintainer's call.
- **Profile performance** — needs the analytic gradient (Step 2) to be usable at scale.

## Gotchas & Failed Approaches (do not retry)
- **Do NOT rebuild the interacting model or re-add S2.** Model A composes existing capabilities; the predictor
  goes on the **ordinary** `latent(lv=~x)`, not `phylo_latent`.
- **`obj$report(fit$opt$par)` errors ("Wrong parameter length")** — `report(par)` wants the full internal
  (fixed+random) vector. `B_lv` is a pure function of the **fixed** params → compute it directly from `fit$opt$par`
  by name (`theta_rr_B`, `alpha_lv_B`), or `obj$fn(par)` then `obj$report()` (general but slow).
- **The profile constrained-refit is slow** (finite-differenced) — don't run a full multi-entry profile at S≥120
  without the analytic gradient; it will hang.
- **Check prior work FIRST** (this session's banked lesson — now ultra-plan **Phase 0.25**): sweep the repo,
  sister/twin repos (GLLVM.jl), and the brain before building. Twice nearly rebuilt what already existed.

## How to Resume
1. Rehydrate: **this doc** → `docs/design/76-structured-xlv-phylo.md` **§7 UPDATE** (the Model A source of truth)
   → the GLLVM.jl reference (`src/confint_family.jl`, `likelihood.jl` on branch `claude/phylo-xlv-modelA-20260627`)
   → `AGENTS.md`/`CLAUDE.md` → `~/.claude/memory/memory_summary.md` (D-12 profile doctrine). Trust the repo.
2. Confirm state: `git -C . log --oneline -6`; `git branch -a`; `gh pr list`. Ensure the branch is checked out.
3. Speak as **Ada**; spawn **Rose** before any public claim; profile/likelihood inference is correctness-critical.
4. Reproduce the composition fit from `scratchpad/modelA-compose-test.R` (or rebuild it) before promoting the CI.

### One-command resume (paste in your authenticated terminal, from the repo root)
- Interactive: `claude "Rehydrate from docs/dev-log/handover/2026-07-06-claude-handover-modelA.md + the CLAUDE.md pointer, then continue the Next Immediate Steps: promote a tier-aware t-based profile_ci_lv_effects() for the orthogonal Model A B_lv."`
- Autonomous, clean context: `claude -p "Rehydrate from docs/dev-log/handover/2026-07-06-claude-handover-modelA.md, then promote profile_ci_lv_effects() (tier-aware, t-based cutoff) for Model A B_lv; add an analytic gradient to the constrained refit; stop before ADEMP for sign-off." --max-budget-usd 5`

## Mission control
| Item | State |
|---|---|
| Repo / branch | gllvmTMB · `claude/xlv-phylo-gaussian` (UNPUSHED) · `origin/main` @ `13686230` |
| CI | R-CMD-check ✅ · pkgdown ✅ (on `origin/main`) |
| Arc | orthogonal **Model A** — composes existing R capabilities; **already recovers `B_lv`** |
| Was | HIGH-RISK new TMB likelihood + grammar change → **obsolete** (S2 reverted, S3 dropped) |
| Now | `B_lv` **CI trio** (t-based profile hero + bootstrap) + ADEMP at power — all R-side |
| Infra shipped | `.qt_threshold` + `crit` hook (`72de7240`); prototype validated, not promoted |
| Next | promote tier-aware `profile_ci_lv_effects()` + analytic gradient → bootstrap → ADEMP |
| Doctrine banked | prior-work sweep = ultra-plan **Phase 0.25**; t-based profiling (D-12) |
