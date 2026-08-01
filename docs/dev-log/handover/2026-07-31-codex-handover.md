# Session Handoff: AGHQ estimator lane → Codex

**2026-07-31 · from Claude (Fable 5) → a NEW Codex session · repo `gllvmTMB`**
**You are Codex, picking this up cold. You will never see the authoring chat — everything
you need is here or in the linked docs. Read `AGENTS.md` first (native to you), then this.**

---

## Critical Context

The **AGHQ estimator-validation lane**. Question: *does AGHQ produce better point estimates
than Laplace, and where?* A 12,000-fit ADEMP campaign ran and was adversarially verified.
Three engine fixes shipped. **The lane's headline is a negative and it is the important part.**

🔴 **NO PUBLIC CLAIM without Shinichi.** "AGHQ is better" is not a permitted sentence. Any
claim must name **its regime AND its population** — see the permitted sentence in the audit.

⚠️ **MULTI-LANE REPO.** `CLAUDE.md`'s snapshot points at an Active-Lane-Split. Other lanes are
live: the **VA/Gate-3 lane** was running 96 workers on Totoro today, and **#851** (scale
collapse) has an open PR. **Do not claim, edit, or absorb another lane's files.** This handover
covers the AGHQ lane only; the other lanes' pointers stand.

## What Was Accomplished

| # | thing | where |
|---|---|---|
| 1 | **#843 answered** — the AGHQ small-n runaway is an **optimiser failure**, not the MLE (16/16 catastrophic seeds) | audit `2026-07-31-aghq-truthstart-shipped-engine.md` |
| 2 | **Three engine fixes merged** — #843 multi-start, #871 dead control, #874 convergence tolerance | PR #875 (merged) |
| 3 | **ADEMP campaign designed + run**: 12,000 fits on DRAC/fir, 2400/2400, 0 failures | `docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` |
| 4 | **Adversarially verified** — 10 claims in, **10 refuted as phrased**; corrected versions recorded | audit `2026-07-31-campaign-stage1-verified.md` |
| 5 | **Fit-time runaway warning** (Shinichi's "warn, don't auto-fix" call) | PR #877 (OPEN) |
| 6 | **#847 experiment run — hypothesis REFUTED** | `#847` comments; stage3 on fir |

### The scientific bottom line (read the audit, not just this)

- **Established**, all-fits population, σ_λ=3: paired Δ ρ-MAE **+0.115 / +0.146 / +0.169** at
  n=100/400/1600, ≥19 MCSE over δ=0.02, clearing Bonferroni over all 54 contrasts.
- **The effect is a runaway-avoidance signal, not broad accuracy.** At n=400 σ_λ=1 the median
  paired difference is **+0.00014** and exactly 50% of replicates favour each arm; 79% of the
  mean comes from 20 of 400 replicates. Where neither arm runs away, the arms are
  indistinguishable.
- 🔴 **The estimator question is NOT answered.** Both filter populations are invalid:
  `converged` is TRUE for **4800/4800** Laplace fits *including 49.1% that ran away*; the
  non-runaway filter drops **58.9–100%** Laplace-side with **zero** AGHQ-only drops at σ_λ=3.
  So only all-fits carries a verdict, and it measures the **AGHQ package** vs the **Laplace
  package**, not the estimator.

## Current Working State

**Working / landed (on `main`):** #843/#871/#874 engine fixes; the campaign harness; Stage 1
data (`dev/aghq-evidence/24-campaign-stage1.csv`, 12,001 rows); all audits.

**In progress (DRAC/fir, unattended):** Stage 2 (gaussian/poisson controls) at **403/800**
with an empty queue — **some tasks did not complete; investigate before using it.** Nothing in
the headline depends on Stage 2.

**Open PR:** **#877** — the fit-time runaway warning + draft user guidance. CI not yet checked.

## Key Decisions & Rationale

1. **Warn, don't auto-fix** (Shinichi, today). The remedy has a measured failure regime
   (`aghq_ridge = 2` still runs away in 67% at n=1600 σ_λ=3), and a fix users trust that
   silently fails is worse than none.
2. **The warning surfaces the EXISTING detector** (`.gllvmTMB_binomial_prevalence_loading_row`)
   and emits **its own message verbatim** — a new absolute constant would be another #857
   instance; a duplicated message drifts.
3. **Campaign on DRAC, not Totoro** — Totoro was fully committed to the VA lane (96 workers).
4. **`aghq_single` kept as an arm** so the campaign prices what multi-start bought.

## Landing State (the git ledger)

- Branch **`claude/runaway-user-guidance-20260731`** → **PR #877 OPEN**, pushed. Contains the
  warning, its tests, the draft user guidance, the #847 stage3 arm, and this handover.
- **`main` is green** (R-CMD-check success on `7a6b1eee`). PRs #870, #875, #876 merged.
- **CARRIED-OVER:** nothing uncommitted in this lane. The `handoff_gate.sh` also lists unpushed
  branches from *other* lanes (`missing-data-sim-impl`, `page-sweep`, `remove-unique-family`,
  worktree-agent branches) — **not mine, not touched, declared here so they are visible.**
- **DRAC results live on fir only** (`~/gllvmtmb-aghq/results/{stage1,stage2,stage3}`), plus
  Stage 1 merged into the repo. Results stay LOCAL — never GitHub artifacts (D-50).

## Next Immediate Steps — YOURS, Codex, because they need the LIVE toolchain

1. **Verify PR #877 and merge if green.** `R CMD check`, then the maintainer merges.
2. 🔴 **#847 — the scale-aware τ.** This is the highest-value open engineering task, and it is
   now the **only route for default-grammar users** (AGHQ cannot run on the default grammar).
   The calibration is **already done**: use the **unpenalised multi-start AGHQ** fit as the
   yardstick (τ̂ = `sqrt(mean(Λ̂²))`; τ̂/true = 1.18 / 1.07 / 0.97 at σ_λ=3).
   ⚠️ **Never use a plain Laplace pass as the yardstick** — it overestimates the loading scale
   by **5.5–8.6×** and is within 50% of truth in **0–1%** of fits, so it would set τ enormous
   and disable the ridge exactly when needed.
3. **Optional cheap test first:** extend the *data-driven* alternative start (loadings 0.3,
   empirical-logit intercepts — currently AGHQ-only) to the Laplace path and re-run the
   σ_λ=3, n=1600 cell. Jittered multi-start already failed (see Gotchas); a sane start is
   untested.
4. **Collect Stage 2** and find out why 403/800: `RESDIR=~/gllvmtmb-aghq/results/stage2
   NSIM=200 Rscript 27-drac-collect.R` on fir. The collector reports completeness first.

## Blockers / Open Questions

- **Is there a population that isolates the estimator at all?** Both designed filters are
  invalid. This is a **design** question, not a compute one — **more seeds will not fix an
  invalid filter.** Candidate: a criterion computed *identically for both arms* (e.g. the
  gradient of the *same* objective at each arm's solution).
- **Stage 2 is short 397 tasks** with an empty queue — cause unknown.
- **#843/#871/#874 left OPEN** deliberately: each has a residual that is not the engine change.

## Gotchas & Failed Approaches — read these, they cost me hours

1. 🔴 **`opt$convergence` is NOT the AGHQ convergence field.** On that path it records the
   optimiser's **per-pass iteration cap** and reports a limit on healthy fits. Use
   `fit$aghq$converged`. My first campaign runner got this wrong and reported 30–60%
   "non-convergence" that was pure artefact.
2. 🔴 **REFUTED: multi-start does not rescue `laplace_ridge`.** I predicted it would. Measured:
   70% runaway vs 65% — no better. **Limit:** I tested *jittered* restarts, not the
   *data-driven* alternative start; see step 3 above.
3. **Skipped ≠ passing, and the factor was 15×.** The AGHQ suite reports **105** assertions
   with skips active and **1571** with `NOT_CRAN=true`. A real regression hid in that gap.
   **Always run with `NOT_CRAN=true` and read the skip count.**
4. **Selection on an approximate criterion inherits its error.** At k=3 multi-start picked a
   *lower* AGHQ objective that was **0.107** from an independent oracle. Fixed by ranking on
   `(converged, objective)`. Generalises well beyond AGHQ.
5. **`git stash pop` restores changes UNSTAGED.** I pushed a branch missing two of my own
   fixes; CI went red while my local suite was green, because local was testing my working
   tree. **A green local suite says nothing about a tree you have not pushed.**
6. **DRAC:** `udunits`/`geos` are **hierarchical** — invisible to `module spider` until `gcc`
   loads. Full stack: `gcc/12.3` → `proj/9.2.0 udunits/2.2.28 geos/3.12.0 gdal/3.9.1` →
   `r/4.5.0`. Install on a **login node** (compute nodes have no internet).
7. **Right-size from `seff`, never from laptop timings** — mine were **50–60× over**.
8. **A `.frequency = "once"` warning makes a naive test ORDER-DEPENDENT.** My runaway
   test passed locally (each file = its own session) and **failed in `R CMD check`**, where
   the whole suite is one session and an earlier test had already consumed the once-per-
   session warning. Fix: `rlang::reset_warning_verbosity("<frequency_id>")` before each
   expectation. **A green `test_file()` does not imply a green `R CMD check`.**
9. **Check the installed build DATE, not the branch.** The local install was 13 days stale and
   Totoro's was 2 days stale; either would have made a "shipped-engine" campaign worthless.

## How to Resume

```
Rehydrate from docs/dev-log/handover/2026-07-31-codex-handover.md + the AGENTS.md snapshot,
then continue with the Next Immediate Steps.
```

**Live environment Codex needs (you run the real toolchain; Claude did not):**

```bash
cd <repo root>
export NOT_CRAN=true                 # or the suite silently skips ~15x its assertions
Rscript -e 'devtools::load_all(".")' # TMB compiles from src/
Rscript -e 'devtools::test()'        # full suite: expect ~9012 assertions, 0 failures
Rscript -e 'devtools::check()'       # before merging #877
```

**DRAC (fir) — live socket, no Duo needed if this morning's ControlMaster is alive:**

```bash
SOCK=$(ls ~/.ssh/cm-*fir* | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes fir
# on fir:
module load gcc/12.3; module load proj/9.2.0 udunits/2.2.28 geos/3.12.0 gdal/3.9.1; module load r/4.5.0
export R_LIBS=~/.local/R/${EBVERSIONR}
cd ~/gllvmtmb-aghq && bash 27-drac-submit.sh stage3   # gllvmTMB 0.6.0 built there 2026-07-31
```

Socket absent/expired → ask Shinichi to `ssh fir` once (Duo), then retry. Never open a fresh
login yourself.

## Mission control

| repo | branch / CI | what shipped | plan by leverage |
|---|---|---|---|
| gllvmTMB | `main` **green**; PR **#877 open** | 3 engine fixes (#843/#871/#874); 12,000-fit verified campaign; fit-time runaway warning | **1** #847 scale-aware τ (only route for the default grammar) · **2** merge #877 · **3** estimator-isolating population (design) · **4** Stage 2 collect |

## Claude ↔ Codex routing

**Yours (Codex):** `R CMD check`, PR #877 verification, the #847 τ implementation and its
live fits, DRAC re-runs, Stage 2 collection.
**Claude's:** the estimator-isolating-population design question, prose, audit write-ups.

## Read next

- `docs/dev-log/audits/2026-07-31-campaign-stage1-verified.md` — **the result + its addendum**
- `docs/dev-log/audits/2026-07-31-campaign-regate.md` · `2026-07-31-aghq-truthstart-shipped-engine.md`
- `docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` — the pre-registered design
- `docs/dev-log/after-task/2026-07-31-aghq-{truthstart-843,campaign-design,engine-fixes}.md`
- Issues **#847** (τ — start here), #843, #871, #874
