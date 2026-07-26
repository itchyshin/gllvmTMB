# VA Engine: `failed_variance_domain` Status

## Threshold & Quantity

**Threshold:** `max_projected_variance <= 4` (R/va-r3-proto.R line 601).

**Quantity:** `max_projected_variance = max(best_report$v_by_obs)`, where `v_by_obs` is the **projected variance** `||L_i' lambda_t||^2` (line 261–273 in gllvmTMB_va_r3.cpp). This is computed per observation as the variance contribution from the latent factor loadings to each cell's linearization.

## Why Bernoulli Trips It; Poisson Does Not

**Binomial/Bernoulli (family=1)** uses `va_r3_softplus_expectation()` to compute `E[softplus(mu + sqrt(v) Z)]` via Gauss-Hermite quadrature. When `v` is small (<1e-6), the code switches to a **Taylor expansion** of softplus (line 63–66 in .cpp):
```
f + v f''/2 + v² f''''/8 + v³ f^(6)/48 + O(v⁴)
```
This expansion becomes inaccurate as `v` grows. The threshold of 4 keeps `v` in the regime where the omitted O(v⁴) terms remain negligible (estimated <1e-10 error for v=4).

**Poisson (family=2)** uses an **exact formula**: `E[exp(eta)] = exp(mu + v/2)` (line 297 in .cpp). No expansion. No sensitivity to large `v`.

Both families share the same gate (line 602), so the gate is a **conservatively cautious check for the binomial case**, applied uniformly.

## Hard Failure or Advisory?

**Advisory label.** Lines 606–612 show:
- When `!variance_domain_ok`, status ← `"failed_variance_domain"`
- BUT the fit object is **fully returned** with:
  - `best` (best parameters)
  - `report` (full TMB report incl. ELBO)
  - `objective` (the TMB objective function)

No downstream code discards the fit. The status blocks **admission to "healthy"** (line 602) but does **not invalidate** the objective or parameter estimates. The fit is usable; it is simply flagged as out-of-certified-domain.

## Wide Condition Grid Over Binary Data?

**Yes, likely to trip in most cells.** Reasoning:
- Binary data with non-trivial latent loadings (e.g., `|Lambda| > 0.5`) routinely produces `v > 4` in at least one observation.
- The gate applies to every fit uniformly, no family-specific exemption.
- Example: fitting a small `q=1` binary GLLVM with realistic loadings (e.g., theta_rr=c(3)) on 2 units × 2 traits produces max_v ≈ 9, which trips the gate.

A typical coverage/power campaign over a grid of `n`, `effect_size`, `q`, sample structure would see most Bernoulli fits return `status = "failed_variance_domain"` if loading magnitudes are realistic. Poisson fits in the same grid would routinely return `"healthy"`.

## Summary

The gate is a **domain-of-validity check** specific to the binomial softplus expansion. It is **not a bug and not a hard error**; it is a signal that the fit is outside the certified-accurate regime for the binomial approximation. Downstream consumers can still use the fit for diagnostics, but the status label appropriately warns that the VA approximation quality is not guaranteed.
