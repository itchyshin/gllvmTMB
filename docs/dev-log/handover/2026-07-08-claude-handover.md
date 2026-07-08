# Session Handoff: `unique()` keyword-removal arc CLOSED + merged → next arc is the B_lv **coverage** campaign (the trio is already BUILT)

**Meta:** 2026-07-08 · from Claude (Ada) · context ~high (fresh session recommended) · **TARGET = the next Claude.**

You are the next Claude. The `unique()` arc is **done and merged**. Your arc is the `B_lv` CI **evidence**
campaign — **not** building the CI trio, which already exists on `main`.

---

## Critical Context (read this or you will rebuild finished work)

1. **The `B_lv` CI trio is BUILT, EXPORTED, and on `main`. Do not rebuild it.**
   - `4c7c7dd0` `profile_ci_lv_effects()` — the t-based `B_lv` profile CI (**D-12 / task #22, the "one
     missing trio member"**). Tier-aware; uses `.qt_threshold()`.
   - `4c22b721` **analytic gradient** for the constrained-refit driver (~9×). This was the 07-06 handover's
     *"practicality blocker"* — it is **fixed**.
   - `1f09dee2` `bootstrap_ci_lv_effects()` + unconditional `simulate` redraw of Model A tiers.
   - All three exported in `NAMESPACE`. Wald already existed via `extract_lv_effects()`.

2. **Branch names lied to me; do not repeat it.** `claude/blv-profile-ci` and `claude/xlv-phylo-gaussian`
   are **`ahead 0`** of `origin/main` (behind 26 / 35). `git diff main...claude/blv-profile-ci` is **empty**.
   They are *superseded*, not parked. Verify with `git rev-list --count origin/main..<b>`, never with
   `git branch -a` alone. (Banked in the brain: `memory/LESSONS.md`, 2026-07-08 entry.)

3. **Structured × X_lv is orthogonal "Model A" and ALREADY composes + recovers `B_lv` in R.**
   No new likelihood, no grammar change. Authoritative record: **`docs/design/76-structured-xlv-phylo.md` §7
   UPDATE**. The old "HIGH-RISK new-TMB-likelihood / interacting model" framing is **superseded** — do NOT
   re-add S2 or rebuild the interacting model. Predictor goes on the **ordinary** `latent(..., lv = ~ x)`;
   phylogeny is a **separate orthogonal** term.

4. **The real remaining work is calibrated-interval EVIDENCE.** `CI-08` / `CI-10` remain **open/failing
   coverage gates**; `docs/design/61-capability-status.md` explicitly forbids promoting them "until the pilot
   reports target-explicit coverage, MCSE, and failed-fit denominators." That is an ADEMP campaign, **heavy
   compute** → ask *"Totoro or DRAC?"* (standing default), not a laptop run.

---

## Goals / mission
Drive **gllvmTMB to v1.0**. The headline feature is **structured × X_lv** — maintainer approved **FULL scope
for v1.0** (2026-07-07). Per maintainer (2026-07-06): **finish gllvmTMB (R) first**; Julia parity + the public
article come **last**, after the capability is real. Point recovery ≠ calibrated intervals — keep separate.

## Plans / roadmap (beyond the immediate steps)
- **Now:** ADEMP coverage for the `B_lv` trio → close `CI-08`/`CI-10` → promote `LV-08` *only* on delivered evidence.
- **Then:** native-TMB `B_lv` CIs (#19), mixed-family `X_lv`, R↔Julia parity (F), the public article (G).
- **Post-1.0 (do NOT do now):** ELR (#24); boundary chi-bar-square cutoff (#23 — *document* the limitation for
  v1.0); exotic-family `X_lv` (ordinal/Tweedie/ZI/Student-t).

---

## What Was Accomplished (this session)
Closed the **`unique()` / `*_unique()` keyword-removal arc** and merged it.

- **[#728](https://github.com/itchyshin/gllvmTMB/pull/728)** merged (`95b56911`) — keyword removed from the
  taught + rendered surface; `unique =` **argument** preserved.
- **[#729](https://github.com/itchyshin/gllvmTMB/pull/729)** merged (`2307d81a`) — pre-existing
  `choose-your-model.Rmd` duplications + headerless table cleaned.
- Maintainer decision **"fully move to latent"**: standalone-augmented `phylo_unique`/`animal_unique`
  (ANI-11) and the two-Psi diagnostic **folded** to `*_latent(..., unique = TRUE)`. Both folds **live-verified
  to fit** before committing (the fold ≡ the *pair*, Design 77 §54 — it adds a low-rank axis; that is a real
  model change, accepted).
- Swept the keyword from **~45 user-facing runtime messages**, fixed a class of **deprecated→deprecated**
  redirects the arc itself created (`spatial()`/`spde`/`diag` → now point to `*_indep()`).
- **Print-label fix** (maintainer-approved): diagonal covstructs now print keyword-free `indep` labels
  (`phylo_diag`/explicit-`phylo_unique` → `phylo_indep`, `spde` → `spatial_indep`, `diag_*` → `indep_*`).
  A folded fit previously printed `"phylo_unique"`.
- CI on merged HEAD: **R CMD check ✓ · 6× recovery ✓ · recovery-depth ✓**.

Full detail: [`docs/dev-log/after-task/2026-07-07-unique-keyword-removal-closeout.md`](../after-task/2026-07-07-unique-keyword-removal-closeout.md).

---

## Current Working State
- **Working / green:** `origin/main` @ `2307d81a`. Keyword grep-to-zero holds on the taught surface (only the
  single deprecation notice at `api-keyword-grid.Rmd:65`). `profile_ci_lv_effects()`, `bootstrap_ci_lv_effects()`,
  `extract_lv_effects()` all defined + exported.
- **In progress:** nothing. The arc is closed.
- **Not started:** the ADEMP coverage campaign (below).
- **Stale docs (tracked, #14):** `docs/dev-log/2026-07-06-option-a-xlv-phylo-execution-plan.md` and
  `...-xlv-phylo-S1-alignment.md` still describe the **interacting** model. They must be revised to Model A
  or clearly marked superseded — they are a live re-derivation hazard.

## Key Decisions & Rationale
- **"Fully move to latent"** (maintainer, 2026-07-07) — accept the model change (fold = pair + low-rank axis)
  to get a genuinely keyword-free taught surface. Consequence: the folded form is **not family-general**
  (the standalone companion was); the docs no longer advertise family-generality for ANI-11.
- **Print labels keyword-free** (maintainer, 2026-07-08) — inverts a previously-documented "default = unique,
  surface indep when the user wrote it" design. User-visible string change.
- **Orthogonal Model A over the interacting model** (maintainer, 2026-07-06) — Design 76 §7 UPDATE.
- **Profile is the hero, with a t-based cutoff** (maintainer, said twice; D-12/#22). `drmTMB#680` is a
  *separate* deferred cutoff-recalibration lane — **do not conflate**.
- **`pdHess=FALSE` is not failure** for the Model A same-tier pairing — route CIs through profile/bootstrap.

---

## Files Created / Modified (this session — merged to `main` via #728 + #729)
Diff base `2fae2de5` → `origin/main` (**89 files**). Grouped:
- **`R/` (25):** `brms-sugar.R`, `fit-multi.R`, `methods-gllvmTMB.R`, `extract-sigma.R`, `extract-sigma-table.R`,
  `extract-correlations.R`, `extract-omega.R`, `extract-two-psi-cross-check.R`, `extractors.R`,
  `profile-derived.R`, `profile-derived-curves.R`, `phylo-signal-ci.R`, `communality-ci.R`, `julia-bridge.R`,
  `unique-keyword.R`, `animal-keyword.R`, `kernel-keywords.R`, `kernel-helpers.R`, `spde-keyword.R`,
  `traits-keyword.R`, `re-int.R`, `gllvmTMB.R`, `extract-cutpoints.R`, `extract-repeatability.R`,
  `simulate-unit-trait.R`
- **`man/` (37)** regenerated · **`vignettes/` (18)** · **`tests/` (3)**:
  `test-spatial-deprecation.R`, `test-canonical-keywords.R`, `test-scan-deprecated-namespace.R`
- **`docs/` (3):** `design/61-capability-status.md` (ANI-11 row → folded spelling, evidence `ANI-11 + PHY-17`),
  `dev-log/after-task/2026-07-07-unique-keyword-removal-closeout.md`, this handover
- **root:** `NEWS.md`, `README.md`, `_pkgdown.yml`
- **This handover also edits:** `CLAUDE.md` (handover pointer → this doc)
- **Brain (durable, outside repo):** `~/shinichi-brain/memory/LESSONS.md` — the 2026-07-08 ahead/behind lesson.

---

## Next Immediate Steps (ordered)
1. **Verify the frontier yourself** (60 seconds; do not skip — this is the arc's whole lesson):
   ```sh
   git grep -l "^profile_ci_lv_effects <- function" origin/main -- R/
   git show origin/main:NAMESPACE | grep -E "export\((profile|bootstrap)_ci_lv_effects\)"
   for b in claude/blv-profile-ci claude/xlv-phylo-gaussian; do
     echo "$b ahead $(git rev-list --count origin/main..origin/$b)"; done
   ```
2. **Design the ADEMP coverage campaign** for the `B_lv` trio (Wald / profile / bootstrap), per
   `docs/design/76-structured-xlv-phylo.md` §5: ≥500 reps/cell, **target-explicit** coverage, **MCSE**,
   **failed-fit denominators**. Include the known-hard `p=80, K=2, λ=0.5` cell **sized up** (it was
   *under-powered*, not broken — the #715 lesson). Use the `simulation-design` skill (ADEMP).
3. **Ask "Totoro or DRAC?" BEFORE running** (standing default). This is a multi-seed campaign, not a laptop
   job. Totoro = no queue, cap ≤100 cores, `OPENBLAS_NUM_THREADS=1`. DRAC = SLURM job arrays, one seed per
   `$SLURM_ARRAY_TASK_ID`. Stream results to disk per seed (never batch-write at the end).
4. **Settle the open t-df question** with the maintainer *before* the campaign: profile cutoff `df` default
   `n_units − d − 1` vs per-target/adaptive `df_eff`. It changes every interval you're about to measure.
5. **Only then**: close `CI-08` / `CI-10`; promote `LV-08` **strictly on delivered evidence** (Rose audit).
6. **Housekeeping:** revise (or mark superseded) the two stale interacting-model docs (#14); add a `NEWS.md`
   line for the **print-label** user-visible string change; triage the two stale open PRs below.

## Blockers / Open Questions
- 🔴 **Maintainer — t-df choice** (step 4). Blocks meaningful coverage numbers.
- 🔴 **Maintainer — compute venue** for the ADEMP campaign (Totoro vs DRAC).
- 🟡 **Stale open PRs**: [#724](https://github.com/itchyshin/gllvmTMB/pull/724) ("next arc = `*_unique`
  deprecation" — that arc is now **done**) and [#726](https://github.com/itchyshin/gllvmTMB/pull/726)
  (`unique=` fold after-task + Codex handoff). Both predate the merge; triage/close or merge.
- 🟡 **`choose-your-model.Rmd` level-1 table** (rows ~134/136, ~135/137) has near-duplicate rows differing in
  `latent` vs `indep` at `unit_obs`. Left untouched — may be intentional. Maintainer's call.
- 🟡 **`NEWS.md`** does not yet describe the print-label change (a user-visible string change).

## Gotchas & Failed Approaches (do not retry)
- **Do NOT rebuild the interacting model / re-add S2.** Model A composes existing capabilities.
- **Do NOT trust `git branch -a` as evidence of parked work** — measure `ahead/behind` (see Critical Context 2).
- **Do NOT trust an inherited handover's "Blockers" as state.** Both of the 07-06 blockers (unpushed branch;
  slow profile refit) were already resolved on `main`. Re-verify against the repo.
- **`gh pr checks --watch` can exit 0 on a STALE run.** Always re-read `gh pr checks <n>` (or
  `gh api repos/.../commits/$(git rev-parse HEAD)/check-runs`) for the **HEAD** commit before merging. This
  bit me: the watch said green while R CMD check on HEAD was red.
- **Grep BOTH keyword forms** when sweeping cli messages: the literal `keyword(` **and** the cli
  `{.fn keyword}` spelling. Missing the second form is what CI caught.
- **`obj$report(fit$opt$par)` errors ("Wrong parameter length")** — `report(par)` wants the full internal
  (fixed+random) vector. `B_lv` is a pure function of the **fixed** params → compute directly from
  `fit$opt$par` by name (`theta_rr_B`, `alpha_lv_B`).

---

## Mission control

| Item | State |
|---|---|
| Repo / branch | `gllvmTMB` @ `origin/main` = `2307d81a` |
| CI (merged HEAD) | R CMD check ✓ · 6× recovery ✓ · recovery-depth ✓ |
| Just shipped | `unique()` keyword removed from taught+rendered surface (#728) + `choose-your-model` dedup (#729) |
| `B_lv` CI trio | **BUILT + exported on main** — Wald ✓ · profile ✓ (`4c7c7dd0`) · bootstrap ✓ (`1f09dee2`); analytic gradient ✓ (`4c22b721`) |
| Structured × X_lv | **Model A already composes + recovers in R** (Design 76 §7) — no new likelihood |
| The actual gap | **Calibrated interval evidence** — `CI-08`/`CI-10` open/failing gates |
| Next arc (by leverage) | 1) settle t-df → 2) ADEMP coverage on Totoro/DRAC → 3) close CI-08/CI-10 → 4) promote LV-08 on evidence |
| Version | DESCRIPTION stays `0.2.0` until the 0.3.0 cut |

---

## How to Resume
1. **Rehydrate, in order:** this doc → `docs/design/76-structured-xlv-phylo.md` **§7 UPDATE** (Model A source
   of truth) → `docs/design/61-capability-status.md` (CI-08/CI-10 gates; register discipline) →
   `docs/dev-log/after-task/2026-07-07-unique-keyword-removal-closeout.md` → `AGENTS.md` / `CLAUDE.md` →
   `~/.claude/memory/memory_summary.md` (D-12 profile doctrine, compute defaults).
2. **Confirm state, don't assume it:** `git log --oneline -6 origin/main`; run the Next-Immediate-Step-1
   frontier check; `gh pr list`.
3. Speak as **Ada**. Spawn **Rose** before any public/register claim — profile & coverage inference is
   correctness-critical, and `LV-08` / `CI-08` / `CI-10` are register gates.
4. **Claude vs Codex:** design the ADEMP + write the runners + prose here; hand the **live heavy campaign**
   (real fits at scale, `R CMD check`, rendering) to **Codex** or straight to **Totoro/DRAC**.

### One-command resume (paste in your authenticated terminal, from the repo root)
- **Interactive:**
  ```
  claude "Rehydrate from docs/dev-log/handover/2026-07-08-claude-handover.md + the CLAUDE.md pointer. The B_lv CI trio is ALREADY BUILT on main — verify the frontier first, then continue the Next Immediate Steps: settle the profile t-df with me, then design the ADEMP coverage campaign for CI-08/CI-10 and tell me whether it should run on Totoro or DRAC."
  ```
- **Autonomous, clean context:** same prompt via `claude -p "…" --max-budget-usd <cap>`.
