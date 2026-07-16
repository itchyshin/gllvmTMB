# After-Task — `Sigma_unit_diag` total-variance profile + delta-Wald build (Phase 1)

**Date:** 2026-07-16 · **Lane:** A (coverage certificate) · **Branch:** `claude/release-0.5.0`
**Status:** BUILD complete + validated; re-score (pilot/Totoro) in progress; certificate **NOT-DONE (D-43)**.

## 1. Goal

Build a genuine per-trait interval for the loadings-inclusive total unit variance
`V_t = Sigma_unit[t,t] = (ΛΛ')_{tt} + ψ_t`, so its coverage can be re-scored on the
doctrine-preferred routes (profile = star; log-SD Wald = diagnostic) instead of the
percentile bootstrap that under-covers it (grid2000 → HOLD, gaussian ~0.913 / binomial
~0.922, all misses "truth-above-upper" = right-skew of a bounded VC).

**Why a build, not a re-route:** the "profile/Wald already in the package" framing held only
for ψ and the pure-diag tier. For the loadings tier (all core m3 cells), `.confint_sigma_wald`
returns NA by design (2026-07-04) and `.confint_sigma_profile` falls back to bootstrap
(`test-profile-ci.R:254`). So the total `V_t` had **no genuine interval**. Confirmed by an
adversarial 3-lens design-review panel (Fisher / Curie / Rose+Noether) before implementation.

## 2. What was built

- **`.total_variance_spec(fit, tier)`** (`R/profile-derived.R`) — single source of truth for
  `V_t`, its `V_of_par(par, t)` and the **exact analytic gradient** `dV_dpar(par, t)`. ψ is
  reconstructed via `.expand_mapped_diag` (handles mapped-off single-trial-binary ψ, #717 —
  NOT positional indexing). The θ_rr→Λ packing is **linear**, so `d vec(Λ)/dθ_rr` is a constant
  0/1 map obtained once via `build_Lambda` on basis vectors (no hand-derived packing indices).
- **Route A — `.profile_ci_total_variance()`** (certificate candidate). Genuine profile on
  `log(V_t)` via `.profile_ci_via_refit` (bypasses the bootstrap fallback). Log scale is
  transformation-invariant (identical interval to profiling `V_t`) and makes the fixed
  `.fix_and_refit_nll` tolerance relative + the `V_t→0` boundary clean. `crit = χ²₁` (NOT the
  `.qt_threshold` sensitivity cutoff). Analytic `target_grad = dV/dpar / V` (mandatory for the
  fix-and-refit speedup — the compute budget driver).
- **Route B — `.wald_ci_total_variance_logsd()`** (DIAGNOSTIC only, never certifies). Delta
  method on `g = 0.5·log V_t`: `SE(V) = sqrt(Jᵀ cov.fixed J)` with the same analytic Jacobian
  (identical estimand), `SE(g)=SE(V)/(2V)`, interval `g ± z·SE(g)` back-transformed. **z, not t**
  (df = n_unit−1 ⇒ t≈z, cosmetic). Gates on `pdHess`; NA-guards `V_t→0` and the barely-identified
  case (`se_g > 2.5` → `wide_na`, since the log-SD delta breaks down there).
- **Scorer wiring** (`dev/m3-grid.R`) — gated `sigma_extra_methods` param on `m3_run_cell` /
  `m3_run_grid` (default `character(0)` = unchanged bootstrap grid, zero overhead). When set,
  emits `profile_total` / `wald_t_logsd` rows from the SAME fit as the bootstrap. `m3_summarise`
  already splits by `(cell,target,ci_method)` — no summariser change. New `coverage_certificate`
  gate column keyed on `profile_total`, kept **separate** from the bootstrap `coverage_primary`.
- **Tests** (`tests/testthat/test-profile-ci.R`, section 9) — estimand identity, exact gradient,
  bracketing, Route B status tokens, and the χ²₁ deviance-crossing check. Did NOT touch `:254`.

## 3. Panel corrections applied (all grounded in code reads)

- The θ_rr→Λ map is **linear** (identity packing, `cpp:776–782`) — the "nonlinear packing" premise
  was backwards; the real trap is packing-index arithmetic + mapped-off ψ. Avoided both.
- Do NOT reuse `.confint_sigma_wald` (NA by design) or `.lambda_ci_asym` (Fisher-z *correlation*
  transform — doctrine violation for a location VC).
- Use χ²₁ / z, not t-df (cosmetic at these g).
- Phase 1 dev-only: public `confint`, the 2026-07-04 NA guard, `:254`, NEWS, widget untouched.

## 4. Checks run (all green)

- **Gate-0 smoke** (gaussian + binomial, d=1): estimand identity Route A == Route B ==
  `diag(extract_Sigma)` to **0 / 2e-16**; analytic gradient vs central FD **7.4e-11**; intervals
  bracket + right-skew-asymmetric; Route B `wide_na` guard fires on a collapsed binomial loading.
- **S3 wiring smoke** (tiny grid): all four ci_methods rbind cleanly; `m3_summarise` splits by
  method; `coverage_certificate` populates only for `profile_total`. Directional signal: bootstrap
  ~0.92, profile wider (catches truth). Runtime **~30 s/rep** (profile-dominated) → n_sim=2000 ≈
  33 h single-core ≈ ~20 min on Totoro 96 cores; analytic gradient essential.
- **S4 unit tests**: 12 + 2 expectations pass, 0 failures.
- **Default-path regression**: empty `sigma_extra_methods` → only `bootstrap` + `psi` rows
  (production grid unchanged).

## 5. Files changed

- `R/profile-derived.R` — `.total_variance_spec`, `.profile_ci_total_variance`,
  `.wald_ci_total_variance_logsd` (internal, `@noRd` — no NAMESPACE change).
- `dev/m3-grid.R` — `sigma_extra_methods` param + emission block + `coverage_certificate` gate.
- `tests/testthat/test-profile-ci.R` — section 9 (total-variance routes).

## 6. Follow-up

- **S5 local pilot** (DONE, n_sim=40, n_units=50) — **GO**. `profile_total` coverage: gaussian d1
  0.950 / d2 0.942, binomial d1 0.942 / d2 0.949 (na_rate ≤ 0.017); bootstrap 0.850–0.925 (the known
  under-coverage). Critically the misses became **two-sided** (gaussian d2 miss_above 0.142→0.042;
  binomial d2 0.108→0.000) — the skew is repaired, not merely widened. `wald_t_logsd` erratic with
  heavy NA (18–77%) → diagnostic-only, confirmed. Runtime: gaussian ~13 s/rep, binomial ~44–78 s/rep
  (the ψ=0-boundary profile is the long pole). Certificate still HELD (D-43) pending the full grid.
- **S6 Totoro n_sim≈2000 re-score** — READY (Totoro is passwordless key-based ssh, NO Duo — that is
  DRAC-only; verified live, 384 cores). `dev/totoro-profile-rescore.sh smoke|grid|aggregate`. Compares
  profile_total / wald_t_logsd / bootstrap columns at MCSE ~0.006.
- **S7 Rose D-43 panel** — default NOT-DONE; flip ONLY earned gaussian+binomial cells; nbinom2 +
  ordinal stay fenced. Then after-task update + check-log bus + board.
- **Phase 2 (deferred, only if cells earned)** — wire the profile into public `confint(fit,'Sigma_unit')`,
  retire the 2026-07-04 NA guard, update `:254` + validation-debt register, then NEWS/widget.

## 7. Coordination

Lane A files only (`R/profile-derived.R`, `R/loading-uncertainty-helpers.R` [reverted, no net change],
`dev/m3-grid.R`, `tests/testthat/test-profile-ci.R`). No overlap with Lane B (X_lv) or Lane C
(categorical). No public-surface or estimand/fence changes. Certificate claim withheld pending the
re-score + Rose panel.

## 8. Outcome — Totoro n_sim=1000 grid + D-43 panel (2026-07-16)

Grid: 8 core-2 cells (gaussian+binomial x d in {1,2} x n_units in {50,150}), n_sim=1000, n_boot=100,
Totoro 64 shards, MCSE ~0.007. profile_total na_rate ~0 everywhere. Coverage by (family,d,n_units):

| profile_total | d1 n50 | d1 n150 | d2 n50 | d2 n150 |
|---|---|---|---|---|
| gaussian | 0.939 | **0.950** | 0.939 | **0.948** |
| binomial | 0.765 | 0.890 | 0.770 | 0.916 |

Coverage IMPROVES with n for both families (correct direction = small-sample/information, NOT a
pipeline bug). Gaussian misses repaired to ~two-sided (n150: 74/168, 103/155) vs bootstrap's ~10:1
above (43/459). Binomial too-narrow at the psi=0 boundary (n50 both-sided ~591/568).

**D-43 panel (Rose / Curie / Fisher):**
- **Gaussian n>=150: certificate DEFENSIBLE (scoped).** Rose + Fisher certify (nominal, two-sided,
  correct direction, na~0). Curie holds out pending an **n_sim>=5000 confirmation** (at n_sim=1000 the
  lower CI dips just below 0.94). So the honest claim is a scoped gaussian-n>=150 certificate, to be
  firmed by one confirmatory run before any public flip.
- **Gaussian n=50:** not certified (0.939, benign small-sample shortfall).
- **Binomial (every d,n):** all three lenses WITHHELD (best 0.916, ~5 SE below nominal). FENCED with
  nbinom2 + ordinal.

**Verdict:** the genuine profile earns a **scoped gaussian-n>=150** coverage certificate; binomial is
not close and stays fenced. wald_t_logsd confirmed diagnostic-only (erratic, up to 49% NA).

## 9. Next (not done here)

- n_sim>=5000 gaussian-n>=150 confirmation run (Curie's ask) before any widget/NEWS flip.
- The public flip + Phase-2 wiring (genuine profile into public `confint(fit,'Sigma_unit')`, retire the
  2026-07-04 NA guard) is a with-Shinichi doc-honesty decision.
- 0.6->1.0 methods backlog (Mission Control): BCa; unconditional RE redraw (phylo/spatial); restore the
  correlation profile; REML profile (small-n gaussian); AGHQ (binomial/psi=0 boundary); nbinom2 phi-bias.
- Policy: Wald CI *calibration* for VCs/correlations is a non-goal (profile + Fisher-z own it); keep
  Wald for fixed effects + the sdreport machinery sound.
