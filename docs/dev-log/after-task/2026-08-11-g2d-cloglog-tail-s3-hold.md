# After Task: G2d cloglog-tail repair and S3 incomplete-artifact HOLD

**Branch**: `codex/isdm-g2d-six-species`
**Engine commit**: `55be39babfa128e7c7691690fbdf05acbcdd56f7`
**Date**: `2026-08-11`
**Roles engaged**: Ada, Gauss, Noether, Curie, Rose

## 1. Goal

Replace the binomial-cloglog probability clip with an AD-safe likelihood, prove
its tail contract before fitting, then run exactly one private G2d six-species
S3 smoke and close it with retained provenance.

## 2. Mathematical contract

For binomial count \(y\) out of \(n\) and cloglog predictor \(\eta\), the
engine evaluates

\[
q(\eta)=\exp\{-\exp(\eta)\},\quad
\log p(\eta)=\log\{1-\exp[-\exp(\eta)]\},\quad
\ell=\log {n\choose y}+y\log p-(n-y)\exp(\eta).
\]

It does not construct then clip \(p\). For `eta < -20`, an equivalent series
preserves \(\log p\approx\eta\) and derivative 1. A `min(eta, 700)` guard
makes CppAD branches finite; its selected derivative above 700 is zero and is
explicitly tested. This is an internal numerical repair, not a new family,
DGP, estimand, grammar, public API, detection/spatial/zero-inflation model, or
Paper 2 claim.

| Quantity | Engine | Independent check |
| --- | --- | --- |
| \(\log p\) | `gll_log_cloglog_p()` | `log(-expm1(-exp(eta)))` |
| \(\ell\) | `gll_dbinom_cloglog()` | `dbinom(..., -expm1(-exp(eta)), log=TRUE)` |
| iJSDM event probability | unchanged likelihood branch | R oracle uses `-expm1(-exp(eta))` |

## 3. Decisions

- Dedicated direct log density, not a probability-only `expm1` patch or generic
  `gll_log1mexp()` helper.
- Representation guard 700, not the rejected cap 20 that changed the
  multi-trial right tail at `eta=40`.
- `G2D_SMOKE_HOLD_INCOMPLETE_ARTIFACTS`, not a guessed fit failure or PASS.
- No retry: approval allowed exactly one smoke.

## 4. Files touched

- Engine: `src/gllvmTMB.cpp`, new `src/gllvmTMB_cloglog.h`.
- Oracle/tests: `R/methods-gllvmTMB.R`,
  `tests/testthat/test-isdm-developer-fit.R`, new
  `tests/testthat/fixtures/gllvmTMB_cloglog_tail.cpp`.
- Internal design: `docs/design/03-likelihoods.md` and
  `docs/design/35-validation-debt-register.md`.
- Closeout: this report, paired reconciliation, and `check-log.md`.

Untouched: public API/Rd, README, NEWS, ROADMAP, vignettes, `_pkgdown.yml`,
empirical data, Totoro/DRAC, campaigns, detection, structural-zero, spatial,
survey-count, comparator/source-admission work, and Issue #953.

## 5. Checks run

```sh
Rscript --vanilla -e 'devtools::test(filter = "tmb-ad-safe-clamps|isdm-developer-fit", reporter = "summary", stop_on_failure = TRUE)'
# PASS: targeted C++/R tail and iJSDM oracle tests.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=validate --output=dev/isdm-package-recovery/results/g2d-tail-preflight-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species --campaign-sha=55be39babfa128e7c7691690fbdf05acbcdd56f7
# PASS: no-fit fixture/support/profile contract validation.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=preflight --output=dev/isdm-package-recovery/results/g2d-tail-preflight-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species --campaign-sha=55be39babfa128e7c7691690fbdf05acbcdd56f7
# PASS: G2D_PREFLIGHT_PASS (no fit).

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=smoke --scenario=ordinary --replicate=1 \
  --output=dev/isdm-package-recovery/results/g2d-tail-smoke-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species --campaign-sha=55be39babfa128e7c7691690fbdf05acbcdd56f7
# One attempt; no terminal output or final receipt; root-only HOLD.

Rscript --vanilla -e '<read root receipt and assert frozen commit>'
# PASS: G2D_TAIL_SMOKE_ROOT_READBACK_PASS.

git diff --check
# PASS.
```

Compiler/external-pointer cleanup warnings were non-fatal. Full test/check,
documentation, pkgdown, and article commands were deliberately not run: no
public API, roxygen, grammar, or reader documentation changed, and S3 is spent.

## 6. Tests of the tests

Boundary tests cover far tails, general `n_trials`, moderate `dbinom`
agreement, former saturation, and finite compiled function/gradient/Hessian
without optimisation. The fixture includes the production header. `eta=701`
tests the guard derivative; `eta=40,n=3,y=2` rejects the prior cap-20 defect.

## 7. Consistency audit

```sh
rg -n 'gll_dbinom_cloglog|gll_log_cloglog_p|1 - exp\(-exp\(|-expm1\(-exp\(' src/gllvmTMB.cpp src/gllvmTMB_cloglog.h R/methods-gllvmTMB.R tests/testthat/test-isdm-developer-fit.R docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md
rg -n 'G2D_SMOKE_(PASS|HOLD)|G2C_SMOKE_ADMISSION_HOLD|Totoro|Issue #953' dev/isdm-package-recovery docs/dev-log/after-task docs/dev-log/plan-actual
rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design
rg 'in prep|in preparation' docs vignettes
rg 'meta_known_V|gllvmTMB_wide' README.md NEWS.md docs vignettes
```

Verdict: direct probability construction remains only in comments, R inverse/
simulation code, and independent oracles; the C++ likelihood uses the direct
log-scale helper. G2c remains held; Totoro still needs `G2D_SMOKE_PASS`.

## 8. What did not go smoothly

The one authorised smoke wrote its root receipt but no downstream artifact or
terminal status. The root proves entry, not where or why it stopped. Cause is
unobserved. No retry was made.

## 9. Team learning

**Ada** preserved the one-smoke boundary. **Gauss** required a direct
general-binomial log density. **Noether** checked symbolic and engine/R tail
alignment. **Curie** caught the cap-20 and optimizer-backed-test errors.
**Rose** requires a complete terminal bundle before a smoke becomes evidence.

## 10. Design, documentation, roadmap, and issue ledger

Internal design records changed; no public documentation or pkgdown surface did.

**Roadmap tick**: N/A; private repair/HOLD changes no public row.

**GitHub issue ledger**: Issue #953 was inspected read-only (`OPEN`, “Paper 2:
trait-gradient hypotheses for insects and herpetiles”); no comment, update,
closure, or new issue. It was explicitly out of scope.

## 11. Known limitations and next action

This does not establish a completed smoke, valid fit, recovery, campaign,
detection separation, structural-zero identifiability, spatial performance,
public readiness, or Paper 2 claim. `G2C_SMOKE_ADMISSION_HOLD` is unchanged.

A separately approved task must diagnose the root-only termination with
controlled logging before deciding whether a fresh replacement S3 smoke is
justified. It must retain this root and cannot promote it retroactively.
