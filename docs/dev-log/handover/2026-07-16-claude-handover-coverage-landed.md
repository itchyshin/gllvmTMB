# Handover → next Claude: coverage arc LANDED + Ayumi #18 fixed

**Meta:** 2026-07-16 · Claude (Lane A) → next Claude · branch `claude/release-0.5.0`
(pushed to origin, in sync). Two parallel lanes ran this session: **Lane B** (X_lv) and
**Lane C** (categorical/multinomial) — do not touch their files (see the 2026-07-16 lane-split
notes in `docs/dev-log/check-log.md`).

## TL;DR — what landed
1. **`Sigma_unit_diag` coverage certificate arc: COMPLETE (dev-only).** Built the genuine
   PROFILE on the loadings-inclusive total `V_t = ΛΛ'[t,t] + ψ[t]` (previously it had NO real
   interval — Wald=NA, profile→bootstrap fallback). Totoro n_sim=1000 grid + D-43 panel →
   **scoped GAUSSIAN n≥150 certificate DEFENSIBLE; BINOMIAL + nbinom2 + ordinal FENCED.**
2. **Ayumi issue #18 (bootstrap_Sigma): TWO bugs fixed + committed + pushed + replied.**

## Coverage arc — detail
- **Code (committed `829c34cd`, dev-only):** `R/profile-derived.R` — `.total_variance_spec()`
  (single estimand builder: `V_of_par` + exact analytic gradient; ψ via `.expand_mapped_diag`
  for mapped-off binomial ψ #717), `.profile_ci_total_variance()` (χ²₁ profile on `log(V_t)` via
  `.profile_ci_via_refit` — the certificate route), `.wald_ci_total_variance_logsd()` (log-SD
  delta-Wald DIAGNOSTIC, never certifies). Wired into `dev/m3-grid.R` (gated `sigma_extra_methods`;
  `coverage_certificate` gate). Tests in `tests/testthat/test-profile-ci.R` §9. Harness:
  `dev/profile-rescore-run.R` + `dev/totoro-profile-rescore.sh`.
- **Result (Totoro n_sim=1000, 8 core-2 cells, MCSE ~0.007), profile_total by (family,d,n):**
  gaussian d1 0.939/**0.950**, d2 0.939/**0.948** (n50/n150); binomial d1 0.765/0.890, d2 0.770/0.916.
  Coverage IMPROVES with n (correct direction = small-sample, not a bug). Gaussian misses repaired
  to ~two-sided vs bootstrap's ~10:1-above.
- **D-43 panel (Rose/Curie/Fisher):** gaussian n≥150 = 2/3 certify (Rose+Fisher); Curie holds out
  for an **n_sim≥5000 confirmation** (n_sim=1000 lower-CI dips below 0.94). Binomial = 3/3 WITHHELD.
- **NOT DONE (deliberately):** no public flip. `confint()`/widget/NEWS untouched. The flip + the
  Phase-2 wiring (genuine profile into public `confint(fit,'Sigma_unit')`, retire the 2026-07-04
  NA guard) are a **with-Shinichi doc-honesty decision**, gated on the n_sim≥5000 confirm.

## Ayumi #18 — bootstrap_Sigma (committed + pushed + 3 replies posted)
- **`1dd7fcde`** — forward ALL grouping tiers (unit/unit_obs/cluster/cluster2, canonical names);
  was dropping `unit_obs` → 100% silent refit failure. + fail-loud warning on any refit failure.
- **`198ca67d`** — STOP (error, class `gllvmTMB_bootstrap_conditional_sim`) when a requested RE
  tier can't be unconditionally redrawn (phylo_diag/spatial): `simulate()` silently falls back to
  conditional sim (frozen REs) → collapsed intervals (false precision). Points users to profile/Fisher-z.
- **Correlation-CI steer (VERIFIED works):** `confint(fit, parm="rho:TIER:i,j", method="fisher-z")`
  gives distinct, point-bracketing intervals on real correlations. (The profile-for-correlations is
  withheld; `extract_correlations(method=...)` errors — use the `confint` route.)
- **`weights` round-trip** for multi-trial models: flagged as a SEPARATE gap (the fit doesn't persist
  weights) — not yet fixed.

## Methods backlog (0.6 → 1.0) — in Mission Control `status/gllvmTMB.json`
1. **n_sim≥5000 confirm** of gaussian-n≥150 [0.6, near-term — do this before any flip].
2. **REML profile** — small-n gaussian [0.6-1.0; our probe: REML barely moves Σ̂ at n=150, payoff is n=50].
3. **AGHQ** integration — binomial/ψ=0-boundary coverage [1.0; Laplace is least accurate for binary;
   too-narrow profile is the Laplace signature; PARTIAL fix].
4. **BCa/studentized bootstrap** — quantities without a profile [0.6].
5. **Unconditional RE redraw** (phylo/spatial) — makes the parametric bootstrap VALID for structured Σ [0.6].
6. **Restore correlation profile** (withdrawn penalty-profile) [0.6].
7. **nbinom2 φ-bias** correction [1.0].
- **POLICY (Shinichi 2026-07-16):** Wald CI *calibration* for VCs/correlations is a **NON-GOAL** —
  profile + Fisher-z own it, bootstrap has a roadmap. Keep Wald for FIXED EFFECTS + keep the
  sdreport/SE machinery sound. No "make Wald cover" arc.

## Next moves (ordered)
1. **Launch the n_sim≥5000 gaussian-n≥150 confirmation** on Totoro (gaussian is cheap ~15s/rep).
2. **Shinichi:** flip decision + doc-honesty review → if confirmed, flip ONLY the gaussian-n≥150
   coverage cell (widget/NEWS); binomial/nbinom2/ordinal stay fenced. Then Phase-2 public confint wiring.
3. The **3 held sign-offs** (disp_group / family-breadth / tweedie worktrees) — untouched this session.

## Gotchas / lessons
- **Totoro = passwordless `ssh totoro`, NO Duo** (Duo is DRAC-only). Socket at `~/.ssh/cm/cm-...`. 384 cores.
- **The Totoro re-score results live at a mangled path** from an OUTDIR-quoting bug:
  `~/gllvm_work/gllvmTMB/$HOME/gllvm_work/profile_rescore/` (literal `$HOME` dir). `rescore-collected.rds`
  + `rescore-summary.rds` are there. Fix the launcher's OUTDIR quoting before re-running.
- **Verify your own output before advising publicly** — I once called three IDENTICAL degenerate CIs
  "sensible"; they were a zero-correlation (diagonal-tier) artifact. Give non-degenerate examples.
- The pilot (n_sim=40) over-promised binomial (0.94) vs the real grid (0.77-0.92) — trust MCSE ~0.007, not ~0.03.
