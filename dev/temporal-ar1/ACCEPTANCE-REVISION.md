# Approved G4 acceptance revision

**Decision date:** 2026-09-08
**Authority:** maintainer approval in the temporal-AR1 implementation task

The original 12-series bounded recovery fixture remains intact. It produced one
miss under the original per-variance median-relative-error ceiling of `0.35`:
replicated `phi = 0.6`, trait 2, `0.355778405907`. Every retained fit is finite,
converged, has a positive-definite Hessian and outer gradient at most `1e-3`;
no `abs(phi) > 0.99` boundary diagnostic occurred.

For this named local fixture only, the ceiling is revised to `0.36`. The change
is explicit, post-validation, and does not alter data, seeds, model,
optimizer, or any other criterion. The original result and the failed
`0.35` ledger are retained in `recovery-results-bfgs.csv`,
`recovery-cell-summary.csv`, and `REVIEWS.md`.

This permits a bounded engineering acceptance gate. It does **not** establish
general recovery, finite-sample precision, estimator calibration, or interval
coverage.
