# Augmented phylogenetic random-slope release smoke

`run-slope-smoke.R` executes the frozen 12-cell operational smoke specified by
`slope-smoke-manifest.csv`: the 11 admitted augmented-slope family IDs, with
binomial logit and probit as distinct cells. It fits three traits under
`phylo_indep(1 + x | species, tree = tree)`. This is single-seed smoke/recovery
evidence, not an admission, coverage, or inference-certification campaign.

| Symbol in the DGP | Keyword / fit term | DGP draw | Recorded recovery field | Frozen truth |
|---|---|---|---|---|
| `beta_t` | `0 + trait` | three trait intercepts in `eta` | `fixed_estimate`, `fixed_max_abs_error` | `(-0.35, 0, 0.35)` |
| `a_{st}` | `phylo_indep(1 + x | species)` intercept | independently per trait, `a_t ~ N(0, sigma^2_{a,t} A)` | `sd_estimate` odd elements | `(0.45, 0.55, 0.40)` |
| `b_{st}` | same keyword slope | independently per trait, correlated with `a_{st}`, and phylogenetically structured by `A` | `sd_estimate` even elements | `(0.35, 0.45, 0.30)` |
| `rho_t` | within-trait augmented covariance block | `Cov(a_t,b_t)=rho_t sigma_{a,t} sigma_{b,t}` | `cor_estimate`, `cor_max_abs_error` | `(0.20, -0.15, 0.10)` |
| `y_{ist}` | selected family/link | `g^{-1}(eta_{ist})` plus family-specific draw | manifest family/link and fit health | one frozen seed per cell |

The CSV records convergence, positive-definite Hessian, maximum gradient,
fixed-effect truth recovery, random-effect SD/covariance truth recovery, warnings,
errors, and elapsed time. A fit has a 90-second elapsed-time ceiling; the driver
will not start a new cell after 20 minutes. Failures are written, not discarded.

Run from the worktree root:

```sh
Rscript dev/release-evidence/run-slope-smoke.R
```

For a construction check only (not the release smoke), set
`GLLVMTMB_SLOPE_SMOKE_MAX_CELLS=1`.

The optional `GLLVMTMB_SLOPE_SMOKE_FIRST_CELL`,
`GLLVMTMB_SLOPE_SMOKE_MAX_CELLS`, and `GLLVMTMB_SLOPE_SMOKE_OUTPUT` controls
exist solely for interrupted-run recovery; normal release evidence uses the
single command above.

## 2026-08-20 stop receipt

The retained `slope-smoke-results.csv` and `slope-smoke-results-summary.csv`
record 12 attempts (98.01 seconds total; 15.45-second p90).  The earlier
runner recorded Git revision `379a54472bef95f1e4c3b66c552a6b0acddbc714` but
did not prove that it loaded that checkout rather than an installed package.
That code provenance is therefore **unverified**; this receipt is fit-health
evidence only and is not a release claim.  The revised runner now loads the
source checkout explicitly and records both the checkout and loaded namespace
path for any future, separately approved smoke.  Seven cells were healthy:
Gaussian, lognormal, Gamma, Beta, beta-binomial, Student-t, and negative
binomial 1.  Five were not: binomial-logit had a non-positive-definite Hessian;
binomial-probit had convergence, Hessian, and gradient failures; Poisson had a
non-positive-definite Hessian and large gradient; negative binomial 2 had
convergence and gradient failures; and ordinal-probit had convergence, Hessian,
and gradient failures.

The pre-registered local-smoke gate requires every cell to be healthy.  This
smoke therefore **does not pass**.  It is retained as fit-health evidence, not
as family-recovery certification.  No Totoro or DRAC campaign was requested or
launched, no allowlist or validation-debt status was promoted, and no claim
about interval coverage, structured-route recovery, or new family admission is
made from these data.  The 0.7 decision is to keep MSPL point-only and
experimental, and to park MSPL expansion for a separate, approved methods arc.
