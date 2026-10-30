# VA template: cancelling lgamma sums (#1482)

Scope: `inst/tmb/gllvmTMB_va_r3.cpp` only (no `src/`, no `R/`).
Outcome: NB2 (fid 5), beta-binomial (fid 8) and beta (fid 7) rows now use
`va_r3_lgamma_shift` / `va_r3_lgamma_beta_const`, copies of the #1479 Laplace
helpers, so the VA row log-likelihood no longer carries ~1e-3 rounding error at
phi ~ 1e12.
Checks: new `test-va-lgamma-cancellation.R` (red on main, 6 failures; green on
branch, 16 passes); existing `test-va-*.R` and `test-cpp-numeric-edges.R` unchanged
(the errors in `test-va-all-family-{compiled,light-fits,oracles}.R` are identical on main).
Follow-up: #1488 (cut points) is a separate lane; the beta-binomial and NB2 rows
keep the existing 1e-12 latent-variance floor.
