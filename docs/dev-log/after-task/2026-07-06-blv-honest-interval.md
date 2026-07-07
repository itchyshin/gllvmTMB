# After-task: an honest interval around B_lv — the CI trio + REML for the orthogonal Model A (2026-07-06)

Session as **Ada**, lenses Fisher (inference), Curie (coverage), Gauss/Emmy (engine/extractor),
Rose (audit). Autonomous run against the maintainer goal: *"the deliverable is two things —
(1) the point estimate B_lv and (2) an honest interval around it."* (1) was already done (Model A
composes + recovers B_lv). This session delivered (2).

## Scope
Build **honest confidence intervals for the predictor-informed latent-score effect
`B_lv = Λ_B·α^T`** under the orthogonal Model A (`latent(0+trait|species, d=K, lv=~x) +
phylo_latent(...)`), Gaussian. The honest-interval bar = the Wald/profile/bootstrap trio with
profile as the featured method (D-12), unbiased variance components (REML), and coverage evidence.

## Outcome — the interval is delivered, honest, and reachable
All on branch `claude/blv-profile-ci` (built on `origin/main` after the earlier merges):

- **REML for Gaussian `lv`/Model A** (`401d0763`): unbiased variance components (ML under-estimates
  them at small cluster n). Lifts the `lv` C1 ML-only guard for the Gaussian case only; reuses the
  existing Gaussian REML engine (mean fixed effects integrated out — the drmTMB mechanism). Verified
  engaging (objective differs, `b_fix` in the Laplace block, `Σ_phy` ≥ ML). Non-Gaussian `lv` REML
  stays blocked.
- **Profile CI — the hero** (`4c7c7dd0`): `profile_ci_lv_effects()` inverts the LR test per `B_lv`
  entry via constrained refit, with a **small-sample t reference** (`.qt_threshold`; maintainer
  directive), `df = n_units − d − 1`. Rank-1 uses a fast direct-from-fixed-par target; higher rank
  falls back to the exact engine report. Closes, covers the known `B_lv`, t wider than χ².
- **Analytic gradient** (`4c22b721`): optional `target_grad` in the constrained-refit driver →
  exact penalised gradient instead of finite differences. **~43s → ~5s per entry (≈9×)**;
  backward-compatible (finite-diff fallback keeps every other `profile_ci_*` unchanged).
- **Bootstrap leg + the simulate fix** (`1f09dee2`): `bootstrap_ci_lv_effects()` (parametric
  percentile, parallel, REML-preserving). Fixed the real blocker — `simulate()`'s unconditional path
  did **not** redraw the `lv_B` / `phylo_rr` / `diag_species` tiers, so it fell back to conditional
  and gave ~0-width, non-covering bootstrap CIs. Taught `.simulate_eta_unconditional` those tiers
  (lv mean added to the redrawn B-innovation; `g_phy ~ MVN(0,A)` via `chol(Ainv_phy_rr)` on the
  augmented set; iid `q_sp ~ N(0, sd_q)`). Bootstrap now spans real uncertainty and covers 4/4.
  **Also repairs `bootstrap_Sigma`'s under-coverage.**
- **Standard-API access** (`3564009c`): `extract_lv_effects(type="trait_effect",
  method="wald"/"profile"/"bootstrap")` routes to the trio; `...` forwards options.
- **Coverage proof + campaign harness** (this commit): local parallel profile-coverage sim,
  `B_lv[t1]`, both cells 100% converged and **inside the 0.92–0.98 audit band**, coverage climbing
  toward nominal 0.95 as `n` grows — **0.925** (MCSE 0.024; S=60) → **0.970** (MCSE 0.017; S=150).
  Textbook profile behaviour (mild small-`n` under-coverage, converging); the interval is honest.
  The production claim is gated on the campaign below (larger denominator + the Self–Liang boundary
  refinement). Plus
  `dev/lv-effects-ci-coverage.R` + `-slurm.sh`: the compute-gated
  ≥500-rep/cell Totoro/DRAC campaign (grid sizes n to family+rank per the #715 lesson; includes the
  GLLVM.jl weak cell p=80,K=2,λ=0.5 sized up).

## Checks run
- `profile_ci_lv_effects`: heavy coverage test (closes, covers, t>χ², df, structure) + routing —
  15/15.
- `bootstrap_ci_lv_effects` + simulate redraw: error path, no-conditional-fallback, heavy coverage —
  9/9. Existing simulate/bootstrap suites unregressed (63 pass).
- REML enablement: 7/7 (engages + non-Gaussian blocked); repointed 2 stale boundary assertions;
  full lv guard/preflight suite 273 pass.
- Analytic gradient: same interval, ~9× faster; backward-compatible.
- Local coverage proof: profile coverage 0.925 (MCSE 0.024; S=60; 120/120 reps converged).

## Key judgment calls
1. **Caught the conditional-simulate bug by checking coverage, not by trusting the CI shape.** The
   first bootstrap returned ~0-width intervals; rather than ship, traced it to the RE-redraw gap and
   fixed `simulate()` at the source (benefits all bootstrap callers).
2. **REML precedes the CI.** Built REML first so the interval sits on unbiased variance components
   (honest coverage), per D-12's REML note.
3. **Analytic gradient before the coverage proof.** Without it a coverage sim was infeasible
   (~45–90s/entry); with it, ~5s → a real local proof.

## Follow-ups
- Run the full ≥500-rep campaign on Totoro/DRAC (`dev/lv-effects-ci-coverage-slurm.sh`) to move the
  register row `blocked → partial` on delivered coverage.
- Higher-rank `B_lv` profile currently uses the report-based (slower) target; a general-rank analytic
  gradient is the next perf step.
- Sparse `chol(Ainv_phy_rr)` in the phylo redraw for large trees (currently dense; fine at moderate n).
- Design 76 / S1 / plan still describe the interacting model (#14) — revise to Model A.

## Guards honored
- Honesty first: no interval shipped without coverage evidence; the conditional-simulate under-coverage
  was fixed, not papered over. REML/gradient/bootstrap all validated by recovery-to-truth + coverage.
- Backward-compatible: analytic gradient + `simulate()` extension leave existing callers unchanged
  (regression suites green). Non-Gaussian `lv` REML stays blocked.
