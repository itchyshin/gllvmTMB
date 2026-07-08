# Audit — skip-on-flag test guards (Sweep 1)

**Date:** 2026-07-08 · **Author:** Claude (Ada) · **Type:** read-only audit, no code changed
**Trigger:** the `test-phylo-q-decomposition.R` locale/status-code fix ([PR #735](https://github.com/itchyshin/gllvmTMB/pull/735))
raised the question of how many tests decide pass/fail on a **second-order optimiser flag**
(`fit$opt$convergence`, `fit$sd_report$pdHess`, `fit$fit_health$pd_hessian`) rather than on the
estimand they exist to check.

---

## The question

Do the test-suite's `skip()`-on-flag guards silently lose coverage — i.e. report **green** for a
regression that should be **red**?

## Method

1. Static inventory: every `if (<fit flag>) skip(...)` guard (excluding `skip_if_not_*` gates),
   matched with a window that ignores comments and `test_that()` titles.
2. Dynamic measurement: ran the 47 guard-bearing files under `GLLVMTMB_HEAVY_TESTS=1`, captured the
   actual `expectation_skip` **reason strings** (not my grep's guess).
3. For a sample of the skipping cells, drove the fit directly and read `convergence`, `pd_hessian`,
   the gradient inf-norm, and the Hessian's flat-direction composition — to separate *genuine
   non-convergence* from a *nuisance ridge* (the PR #733 signature).

## Inventory

```
skip-guards of the form  if (<fit flag>) skip(...)   :  123   across 47 files
  gated on `convergence != 0 || !pd_hessian` (an OR) : 113
  gated on convergence only                          :   9
  gated on pd_hessian only                           :   1
```

**114 of 123 can fire on `pd_hessian` alone** — the flag PR #733 proved goes `FALSE` for benign
structural reasons.

## What actually skips (measured, pristine `main`)

**18 skips across 8 files; 0 failures.** Every skip is documented and self-explains, e.g.
`"nbinom2 spatial_latent + spatial_unique did not converge with PD Hessian; SPA-02(nbinom2) stays
partial pending bigger n / different seed"`. The corresponding register rows are already `partial`.

**So the answer to the headline question is: NO silent coverage loss.** The skips are honest and the
register does not over-claim. My earlier "active hole" framing was wrong.

**17 of the 18 are spatial × non-Gaussian**, all with the same message string. That homogeneity is
misleading — the *mechanism* is not homogeneous.

## The real finding: one skip message, two mechanisms

The guard is `!isTRUE(convergence == 0L) || !isTRUE(pd_hessian)` — an **OR** — so the message cannot
tell you which limb fired. Driving the fits directly splits the cells:

| cell group | npar | convergence | \|grad\|∞ | min Hessian eig | flat direction | verdict |
|---|---|---|---|---|---|---|
| `spatial_indep(1+x\|site)` binomial-logit | 6 | **0** | **6.0e-08** | −7.9e-11 | `log_sd_spde_b`, `log_kappa_spde` | **FALSE NEGATIVE** |
| `spatial_dep(1+x\|site)` gaussian *(control)* | 26 | 1 | 7.2e-01 | −6.2e+02 | `theta_spde_dep_chol` | genuine non-convergence |
| `spatial_dep(1+x\|site)` binomial-probit | 25 | 1 | 2.1e+02 | −8.1e+05 | `theta_spde_dep_chol` | genuine non-convergence |

Two genuinely different situations wearing the same skip string:

- **`spatial_indep` / `spatial_unique`** (2×2 augmented, ~6 params) **converge to machine precision**
  (`|grad| ≈ 1e-8`) and are parked *only* because one Hessian eigenvalue lands at `−7.9e-11` instead
  of `+7.9e-11`. The flat direction is the **SPDE variance–range ridge** (`log_sd_spde_b` /
  `log_kappa_spde`) — a well-known structural near-confounding of the Matérn/SPDE parameterisation,
  **not** a small-sample artifact. `"pending bigger n / different seed"` cannot fix a structural
  ridge; that note points these cells at a chase that never terminates.
- **`spatial_dep`** (full unstructured 2T×2T field covariance, ~26 params) **genuinely does not
  converge** at the fixture's `n_sites`: gradient `0.7`–`210`, Hessian wildly indefinite (min eig
  down to `−8e5`), and **even the Gaussian control fails**. The flat direction is the whole
  `theta_spde_dep_chol` block — the unstructured covariance is over-parameterised at this `n`.
  `"pending bigger n"` is the **correct** diagnosis here.

So the same skip is a false negative for the diagonal/augmented modes and an honest partial for the
unstructured mode. The `pd_hessian` limb is doing real work in the second case and doing harm in the
first.

## Two incidental defects found

1. **Stale comment.** `test-matrix-slope-spatial-dep.R` (`run_slope_spatial_dep_cell`) says the
   non-Gaussian dep slope is *"RESERVED gaussian-only … the use_spde_dep_slope family-id allowlist is
   c(0L)."* The source allowlist is now `c(0L, 1L, 2L, 4L, 5L, 7L, 14L, 15L)` (all seven families,
   the SPA-10 relaxation, `R/fit-multi.R:811`). The families **are** admitted; they construct and
   then fail the convergence gate. The comment predates SPA-10 and misdescribes the skip.
2. **CI counts `failed + errored`, not `skipped`.** 8 of 9 `*-recovery.yaml` workflows compute
   `n_fail <- sum(df$failed) + sum(df$error)` and exit 0 while printing skipped cells. Only
   `phylo-q-decomposition-recovery.yaml` (added in PR #735) fails on skip. So
   `spatial-dep-slope-nongaussian-recovery.yaml` currently reports **green** while all 7 of its cells
   skip — the gate is vacuous.

## Recommendations (for maintainer decision — none applied here)

1. **Do NOT blanket-convert `skip → fail`.** It would turn ~7 honestly-partial `spatial_dep` cells red
   for something that is not a defect. Rejected.
2. **Split the convergence and PD limbs, and stop gating recovery on `pd_hessian` when the null space
   is a nuisance ridge orthogonal to the estimand.** This is D-12's own doctrine (route uncertainty
   through profile/bootstrap when `pdHess = FALSE` is benign) applied to tests. The `spatial_indep` /
   `spatial_unique` augmented cells are the candidates: they converge; only the eigenvalue *sign*
   parks them.
3. **Make CI count unexpected skips** — against a declared allowlist of known-partial cells, so a
   genuinely-partial `spatial_dep` cell is allowed to skip but a regression that newly skips
   `spatial_indep` turns red. Mirror the `phylo-q-decomposition-recovery.yaml` fail-on-skip pattern.
4. **Re-examine `SPA-02`, `SPA-04`, and the `SLOPE-spatial-indep(*)` rows for promotability now.**
   At least `spatial_indep(1+x|site)` binomial-logit recovers at `|grad| = 6e-08`; its `partial`
   status may rest entirely on the eigenvalue-sign artifact. Per-cell work: run the recovery-band
   assertion past the `pd_hessian` gate and see if it passes. This needs the criterion fix (rec. 2)
   first, and is the maintainer's promotion call.

## Negative space — what this audit does NOT cover

- **Only the two poles were driven to ground:** `spatial_indep` binomial-logit (false negative) and
  `spatial_dep` gaussian+probit (genuine). The remaining parked cells —
  `spatial_latent + spatial_unique` paired (nbinom2, poisson), `spatial-pair-binary`, and the one
  non-spatial `m2-2a` ordinal — are **unclassified**; each needs its own fit to place it in the
  false-negative vs genuine split. Do not assume.
- **No register row was promoted or demoted.** No test guard was changed. No CI workflow was changed.
  This is diagnosis only.
- **The 418 `expect_equal(fit$opt$convergence, 0L)` assertions** (the *fragility* class, distinct from
  the *skip* class audited here) are out of scope; they are blocked on deriving a scale-free
  convergence criterion and a `fit_health$converged` source fix, per the earlier discussion.

## One-line conclusion

The skip guards are **honest, not silent** — but a single skip string hides two mechanisms, and for
the diagonal/augmented spatial modes the `pd_hessian` limb manufactures **false negatives** on fits
that have converged to machine precision. The fix is to change the *criterion* (rec. 2) and make CI
*count skips* (rec. 3), not to flip skips to failures.
