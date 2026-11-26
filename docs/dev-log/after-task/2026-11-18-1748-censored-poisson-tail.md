# After Task: Keep a right-censored Poisson row finite in the left tail

**Branch**: `cursor/fix-1748-censored-poisson-tail-7b3a`
**Date**: 2026-11-18
**Roles (engaged)**: Gauss, Noether, Curie

## 1. Goal

Right-censored `censored_poisson` rows (family id 21) added `log(pgamma(mu, C, 1))`. Once `C * eta` was very negative that underflowed, and `fn()` and `gr()` were NaN. Uncensored rows had already been moved onto `y * eta - mu - lgamma(y + 1)`.

## 2. Implemented

`gll_log_pois_survival()` evaluates the same Poisson-gamma probability in log space. Where the lower tail is not pressed against 1 it uses `log(1 - F)`. Where that complement would underflow it accumulates the upper tail from the `C * eta` term. Both `CondExp` inputs stay finite. The uncensored branch is unchanged. Eta remains the log mean. No parameter, default, or convergence rule moved.

## 3. Files Changed

- `src/gllvmTMB.cpp`
- `NEWS.md`
- `tests/testthat/test-1748-censored-poisson-tail.R`
- `docs/dev-log/check-log.d/2026-11-18-1748-censored-poisson-tail.md`
- `docs/dev-log/after-task/2026-11-18-1748-censored-poisson-tail.md`

No README, roxygen, vignette, or design-doc change. `docs/design/03-likelihoods.md` does not mention this density.

## 4. Checks Run

Pre-fix installed package: 17 failures on `test-1748-censored-poisson-tail.R` (NaN objective and gradient).

After `R CMD INSTALL`: that file FAIL 0 / ERROR 0 / 62 expectations. `test-censored-poisson.R` FAIL 0 / ERROR 0 / 15 tests, including the `1e-10` density match, the finite-difference gradient, and the known-DGP recovery. The #1603 uncensored left-tail comparison FAIL 0 / ERROR 0 / 72 expectations.

Not run: `devtools::check()` and the full suite.

## 5. Review

- Gauss: the tape no longer calls `pgamma` in the underflow region, and both conditional branches stay finite.
- Noether: on the ordinary grid the log survival matches `log(pgamma(mu, C, 1))` well inside `1e-10`.
- Curie: the new test drives C = 1, 2, 3 through the eta values in the issue, and the existing density test still passes.
