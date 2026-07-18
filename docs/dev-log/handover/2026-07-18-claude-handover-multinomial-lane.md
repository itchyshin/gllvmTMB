# Multinomial lane — handover to FINISH the arc (Totoro certification + the deferred menu)

**Meta:** 2026-07-18 · Claude→Claude · the **multinomial cross-family lane**. Branch
`claude/cross-family-intervals-20260718` (**PR #766**, awaiting maintainer merge to `main`). This
consolidates the whole multinomial lane so the next session can *finish it* — the headline remaining
task is the **Totoro coverage-certification campaign**. Supersedes the arc-scoped
`2026-07-18-claude-handover-cross-family-intervals-build.md` (read that for the build's internals) and
closes the loop on `2026-07-18-claude-handover.md` (whose "NEXT = calibrated cross-family intervals" is
now built).

## 0. NEXT-LANE MISSION — validate the interval / SE machinery
The follow-up goal is to **validate the confidence-interval / standard-error machinery** on
`extract_cross_correlations()`, so we can eventually state — honestly, with evidence — that **every
interval route (`wald`, `bootstrap`, `profile`) has validated coverage**, closing the register **CI-11**
debt. **This is NOT true yet** — the intervals ship UNCALIBRATED; the next lane *earns* the claim. Two
feeders, **both required** before any "validated" statement:

1. **Totoro coverage certification (§2) — the primary evidence.** Does each route cover the
   analytically-known truth `Σ_total_true` at the nominal rate across N and ρ? gate → pilot → confirm →
   aggregate → **D-43 panel** (≥2 NOT-DONE withholds). This is what makes "coverage validated" a fact
   rather than a hope.
2. **Ayumi's real-data bug-hunt — the robustness evidence.** The uncalibrated intervals are in Ayumi's
   hands (see `docs/dev-log/2026-07-18-cross-family-intervals-USAGE-for-Ayumi.md`; install via
   `remotes::install_github("itchyshin/gllvmTMB@claude/cross-family-intervals-20260718")`). Her findings —
   crashes, `NA`/absurd intervals, intervals that don't bracket the point estimate, especially on partner
   families beyond gaussian/binomial, large K, or few units — feed **straight back into hardening the
   SE/interval code**. Track her reports and fix them here.

**The "SE errors validated" claim requires BOTH** certified coverage (D-43) **and** a clean real-data
pass. Until then every surface carries **MEASURED / NOT certified**; do NOT promote CI-11 or touch NEWS.

## 1. What is SHIPPED (multinomial cross-family)
- **#758** item 1: the matrix `(π²/6)(I+J)` softmax link residual for a multinomial trait in
  `extract_Sigma`/`extract_Omega` (McFadden 1974). On `main`.
- **#761** item 2a-ii: a `multinomial()` trait shares an ordinary `latent(0+trait|unit,d)` with
  Gaussian/binary/count/ordinal traits; new export `extract_cross_correlations()` — `multiple_r`
  (reference-invariant multiple correlation) + `contrast_r` (per-contrast vector). On `main`.
- **#762** `unique = TRUE` default works for cross-family; the categorical contrast between-unit Ψ
  auto-suppresses (Link Residual Contract). On `main`.
- **PR #766 (awaiting merge)** — **calibrated cross-family INTERVALS**:
  `extract_cross_correlations(method = "wald" | "bootstrap" | "profile")` returns per-estimand interval
  columns, and `simulate.gllvmTMB_multi` now draws the multinomial softmax response (fence removed →
  the parametric bootstrap works). **Intervals are UNCALIBRATED — coverage NOT certified.** The `wald`
  route (fast Fisher-z, any partner family, always returns) is the robust first pass for real data
  (shipped for Ayumi). Tests: 12-file regression 0 fail. Build internals + install/usage in the
  arc-scoped handover + `docs/dev-log/2026-07-18-cross-family-intervals-USAGE-for-Ayumi.md`.

## 2. THE thing to finish — the Totoro coverage-certification campaign ("the totoro campaign")
The intervals ship **uncalibrated**. To make them **certified** (the 0.6→1.0 headline, register row
**CI-11**), run the multi-seed coverage study on Totoro. It is **fully staged** — no re-build needed.

### Harness (built + smoke-verified)
- `dev/cross-family-coverage.R` — measures coverage of the intervals against an **analytically-known
  truth** `Σ_total_true = ΛΛᵀ + diag(ψ) + R_link` (with a hard truth-assertion that
  `extract_Sigma(…,"none")` == the analytic latent Σ, so truth ≡ what the estimator targets).
  coverage = covered/converged; `ci_failed`/NA = MISS; 2·MCSE-lower-band vs the 0.94 gate; both
  estimands; per-cell power vs 0.95; worst-case (non-converged = not-covered) sensitivity.
- `dev/xfc-aggregate.R` — combines shard `.rds` across shards → per-cell coverage table.

### Totoro deploy state
- Deployed to **`~/gtmb_work/xfam-intervals`**; the NEW package is in a **private lib**
  `~/gtmb_work/xfam-lib` (NOT the shared `~/R/lib`, which the profile/main lane uses).
- 🔴 **CRITICAL env gotcha:** every invocation MUST set
  `export R_LIBS=/home/snakagaw/gtmb_work/xfam-lib:/home/snakagaw/R/lib` (R_LIBS, not R_LIBS_USER) —
  otherwise `library(gllvmTMB)` loads the **stale 0.5.0** without the new code (this exact bug produced
  a false 0/8 gate before it was caught).
- ⚠️ **Re-`rsync` the worktree `dev/` before resuming** — the deployed copy predates the `--grid=lean`
  edit and PR #766.

### The run — gate → pilot → confirm → aggregate
```bash
# on Totoro, after re-rsyncing dev/:
cd ~/gtmb_work/xfam-intervals && export R_LIBS=/home/snakagaw/gtmb_work/xfam-lib:/home/snakagaw/R/lib

# 1. GATE (~5 min, cheap) — refit-convergence feasibility; PROCEED/ABORT if <~0.8
XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=gate --seed-base=20260718

# 2. PILOT — a first coverage signal (launch shards detached: `setsid nohup … &`, ≤100 cores)
#    (a) LEAN, ~20-40 min, N<=150, multiple_r — plumbing-scale, catches GROSS miscoverage only:
XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=pilot --grid=lean \
    --n-sim=200 --n-boot=49 --shard=$S --n-shards=72 --seed-base=20260718 --out-dir=pilot-results
#    (b) FULL certified, ~5-9 h:  --grid=certified --n-boot=99 --n-shards=90

# 3. CONFIRM (certification-grade) — MULTI-DAY:
#    --grid=certified --n-sim=13000 --n-boot=499 --n-shards=~100  (inflate n-sim for attrition)

# 4. AGGREGATE (any stage):
Rscript dev/xfc-aggregate.R <out-dir>     # writes AGGREGATED.rds + prints the per-cell coverage table
```
Results LOCAL only (**D-50** — never GitHub artifacts).

### Compute reality (why certification is not one session)
- Per-fit ≈ 0.8 s at N=150; the **N=500 cells + the `contrast_r` profile (uniroot) are ~5-8× heavier**.
- **Lean pilot** ≈ 20-40 min → a coarse signal (n_sim=200 ⇒ 2·MCSE≈0.03: can flag gross undercoverage,
  cannot separate 0.92 from 0.95).
- **Full pilot** (18 cells × both estimands) ≈ **5-9 h**.
- **Confirm** (n_sim≥5000) ≈ **multi-DAY** — bootstrap-dominated, tens of thousands of CPU-hours. **This
  is the real cost of certification.** Best run as a SLURM array or long detached job; aggregate later.
- Practical order: **lean pilot for a signal → if roughly right, launch the multi-day confirm → aggregate.**

### Discipline (non-negotiable)
- Every reported number carries the **"MEASURED, NOT certified — awaiting D-43 panel"** banner.
- Conditional-on-convergence DISCLOSED; report the worst-case sensitivity alongside.
- **Rose + a D-43 panel (≥2 NOT-DONE withholds) BEFORE any register CI-11 flip / NEWS / roxygen change.**
  **CI-11** = the multinomial cross-family interval row — NOT CI-08/CI-10 (the profile/main lane's).

## 3. The rest of the multinomial deferred menu (carried from `2026-07-18-claude-handover.md`; do NOT lose)
- **item-3 — one-per-unit recovery certificate** (deepest, compute-heavy): one-per-unit *phylo*
  among-category recovery is data-hungry (grid-wide boundary railing at accessible N). Harness +
  MCMCglmm are staged on Totoro `~/gtmb_work` (`phylo-multinomial-recovery-harness.R`). Needs larger-N +
  a ridge arm + a ρ-ladder + K=4 + a D-43 panel. gllvmTMB is ~unbiased at scale; **MCMCglmm is
  persistently biased low** (its own issue — likely prior shrinkage / c² back-transform, an open
  question, not gllvmTMB's).
- **replication-aware contrast-Ψ** (Rose check-6): keep the categorical contrast Ψ when replicated data
  identifies it (mirror the multi-trial-binomial `n_trials` gate). Engine change; currently suppressed
  as a conservative simplification.
- **multiple multinomial traits per fit / structured cross-family**: a multinomial sharing a
  `phylo_latent`/`spatial_latent` with other traits. Fenced fail-closed; deferred.
- **small pkgdown cross-refs** (low-effort, Lane A's turf): a `multinomial()` row in
  `response-families.Rmd`; add `gllvm-vocabulary` to `covariance-correlation.Rmd`'s See-also; scope the
  binomial single-trial-vs-replicated claim there.

## 4. Coordination + how to resume
- **Lane A note** posted in `docs/dev-log/check-log.md` (2026-07-18): PR #766 edits `R/profile-derived.R`
  (which the main/profile lane reads) — `profile_ci_correlation()` gained `diag_resid` + a reconstruction
  self-check. CI-11 is ours; CI-08/CI-10 stay theirs.
- **Merge PR #766 first** (maintainer's click — the agent is safety-blocked from merging to `main`), then
  cut a fresh worktree off `main` so the certification session includes the intervals.
- Rehydrate: this doc → the arc-scoped build handover → the plan `~/.claude/plans/do-we-need-to-functional-zebra.md`
  (GOAL block + v3 resolution). Open the capability widget (`CLAUDE.md` step 0). **Spawn Rose before any
  covered claim; D-43 default NOT-DONE.**

**One-command resume** (paste in an authenticated terminal, after #766 is merged, at a fresh `main` worktree):
```
claude "Rehydrate from docs/dev-log/handover/2026-07-18-claude-handover-multinomial-lane.md. MISSION: VALIDATE the cross-family interval/SE machinery (wald/bootstrap/profile) toward an honest 'all routes have validated coverage' (register CI-11). Two feeders, both required: (1) run the Totoro coverage-certification campaign (re-rsync dev/, R_LIBS export, gate->pilot->confirm->aggregate per section 2); (2) triage Ayumi's real-data bug reports and harden the SE/interval code. MEASURED-NOT-certified banner on every number; Rose + a D-43 panel (>=2 NOT-DONE withholds) before any CI-11/NEWS flip. Then the deferred menu (item-3 recovery, replication-aware contrast-Psi, structured cross-family, pkgdown cross-refs)."
```

## Mission control — multinomial lane
| thread | state | where | next |
|---|---|---|---|
| item 1 / 2a-ii / unique=TRUE | ✅ SHIPPED (#758/#761/#762) | `main` | — |
| **calibrated cross-family intervals** | ✅ built, **UNCALIBRATED** | **PR #766** (merge pending) | merge → validate |
| **VALIDATE all SE/interval routes → CI-11** | ▶ **NEXT-LANE MISSION** | — | certification + Ayumi feedback → D-43 → CI-11 flip |
| ├ Totoro coverage certification | ▶ staged, not run | Totoro `~/gtmb_work/xfam-intervals` | gate→pilot→confirm→aggregate |
| └ Ayumi real-data bug-hunt | ▶ in her hands | `install_github(@…)` + usage guide | triage reports → harden SE/interval code |
| item-3 one-per-unit recovery certificate | 🔴 in-progress evidence, NOT covered | Totoro `~/gtmb_work` | larger-N campaign + D-43 |
| replication-aware contrast-Ψ | 🟡 deferred (Rose check-6) | fenced | engine change if in scope |
| multiple-multinomial / structured cross-family | 🟡 deferred, fail-closed | fenced | future |
| pkgdown cross-refs | 🟡 low-effort | — | Lane A |
