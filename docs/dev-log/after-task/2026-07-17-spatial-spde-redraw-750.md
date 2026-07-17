# After-task — Unconditional spatial (SPDE) RE redraw for structured-Σ bootstrap (#750)

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` · **Issue:** #750 · **Method:** ultra-plan
(S1 build → S2 Opus review ∥ S3 tests → S4 coverage → S5 consolidate)

## Scope
Extend the landed phylo unconditional RE-redraw (`be40d8ae`) to the **base per-trait spatial (SPDE)**
tier so `bootstrap_Sigma()` and the other simulate-based CIs (`coverage_study`, loading/phylo-signal/
proportions/lv-effects) return valid, non-collapsed intervals for a structured-Σ (spatial) fit.
`spatial_latent` (loadings, `spde_lv_k>0`), `spatial_dep`, and the `spde_*_slope` variants stay
**fail-closed** (out of scope, still abort). No public-surface change.

## What changed (`R/methods-gllvmTMB.R`)
- **`.simulate_eta_unconditional()`** — new `spde` branch (gated `isTRUE(fit$use$spde) &&
  spde_lv_k==0`) that reconstructs the sparse SPDE precision `Q_base = kappa^4·M0 + 2·kappa^2·M1 + M2`
  from `tmb_data$spde_M0/M1/M2` (never stored — built in C++), draws each trait's field via a
  **`perm=FALSE`** sparse-Cholesky precision solve (`solve(L, rnorm, system="Lt")/tau_t` ⇒ covariance
  `tau_t^-2 Q_base^-1`), and projects through `A_proj` to `eta`. Matches the C++ engine exactly.
- **`.check_simulate_unconditional()`** — added `"spde"` to `handled` and `"spatial_indep"`/
  `"spatial_scalar"` to `handled_labels` (they ride the base `spde` engine); left `spatial_latent`/
  `spatial_dep`/`spde_*_slope` OUT so they still fail loud.
- Tests: `test-spatial-redraw.R` (new — mock redraw-recovery + fail-closed unit tests);
  `test-bootstrap-Sigma.R` (the heavy spatial guard test flipped to a `spatial_indep` **success** test;
  the fail-closed coverage moved to the fast mock).

## The one real bug caught (before commit)
`Matrix::Cholesky(Qb, LDL=FALSE)` with the **default `perm=TRUE`** does NOT reproduce `Q_base^-1` — it
gives `P·Q_base^-1·Pᵀ` (relerr 0.61 vs the truth), which silently scrambles the correspondence with
`A_proj`'s columns. Fixed with explicit **`perm=FALSE`**. Caught by the build agent's empirical recovery
test AND independently re-confirmed by the review (perm=TRUE relerr 0.61; perm=FALSE relerr 0.018).

## Verification
- **S2 — adversarial Opus review (Noether): PASS.** Checkpoint-by-checkpoint the R redraw exactly
  reproduces the C++ SPDE field distribution (Q_base coefficients, the `tau_t^-2 Q_base^-1` draw with
  `perm=FALSE`, the `A_proj`/`trait(o)` projection + 1-indexing, `1/tau` scale, `spatial_scalar`
  tau-tying), and the fail-closed whitelist is airtight (verified against `fit-multi.R` that slope fits
  set `spde=FALSE` + distinct flags). No silent-misdraw path. Nothing blocks the commit.
- **S1 mock recovery:** empirical field covariance ≈ `tau_t^-2 A Q_base^-1 Aᵀ` (relerr ~0.01–0.03),
  cross-trait corr ≈ 0. **15/15 pass.**
- **S3 heavy suite:** `devtools::test(filter="bootstrap-Sigma|spatial-redraw")` → **73 pass, 0 fail**
  (6 benign "1 bootstrap replicate failed to refit → NA" warnings). Includes a real
  `spatial_indep + latent(B)` fit → `bootstrap_Sigma()` finite, non-collapsed.
- **S4 coverage DoD (`dev/spatial-coverage-750.R`):** `coverage_study()` now **runs on a spatial fit**
  (previously errored with `gllvmTMB_bootstrap_conditional_sim`); the spatial params (`kappa_spde`,
  `tau_spde`) vary across reps, confirming unconditional spatial redraw end-to-end.
  **n_reps=50 (0 failed refits), profile coverage:** kappa_spde 0.92, tau_spde 0.92/0.96, sd_B 0.94/0.92,
  sigma_eps 1.00, b_fix 0.90/0.88. Per-cell MCSE at n=50 is ~0.031, so the whole table is consistent
  with nominal 0.95 within ~1–2 MCSE — the "5/8 below 0.94" is Monte-Carlo noise at this n, NOT
  under-coverage. The spatial-specific params (kappa_spde, tau_spde) sit at 0.92–0.96. This is NOT a
  tight per-cell "≥0.94 certificate" (n=50 is too small to certify that, and we do not overclaim it);
  it confirms broadly-nominal downstream coverage. The redraw distribution itself is proven EXACT by the
  recovery test + review, so any residual softness (esp. variance/SD params near boundaries) is
  profile-CI/Laplace behavior, orthogonal to #750. A tighter estimate (n≥200 on Totoro) is available as
  follow-up if a formal per-cell number is wanted.

## Process note (wrong-base recovery)
The S1 build sub-agent's `isolation:worktree` was based on `8ec0ee99` (the `main` line, from the #754
merge), which diverged 35 commits ago and lacks `be40d8ae` (phylo redraw + `handled_labels` + the abort
contract). Its SPDE math + `perm=FALSE` fix + recovery test were branch-independent and sound, so they
were **ported onto `claude/release-0.5.0`** (whitelist re-placed into `handled_labels`; tests adapted to
the abort contract). Lesson: the Agent tool's worktree isolation bases off the default branch, not the
current one — verify the base for any worktree-isolated build on a non-default branch.

## Fences honored
Base per-trait spatial ONLY; `spatial_latent`/`spatial_dep`/`spde_*_slope` fail-closed. No `.cpp`
change. No public-surface (roxygen/NEWS/capability-surface) change. Coverage results kept LOCAL
(`dev/`), never GitHub artifacts (D-50). `newdata`→conditional path unchanged.

## Follow-up
- The auto-benefiting callers (`loading-ci-bootstrap`, `phylo-signal-ci`, `proportions-ci`,
  `bootstrap-lv-effects`, `coverage-study`) are now valid for base spatial fits too.
- Deferred: `spatial_latent` (the `phylo_rr` analogue — loadings-mapped redraw) and the spatial slope
  tiers, for a later slice. Also noted (out of scope): `phylo_unique` label-only sub-flag is not
  whitelisted even though `phylo_rr` is handled — same class of gap, different tier.
