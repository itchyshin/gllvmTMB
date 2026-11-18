# Augmented phylogenetic random-slope release smoke

`run-slope-smoke.R` executes the frozen 12-cell operational smoke specified by
`slope-smoke-manifest.csv`: the 11 admitted augmented-slope family IDs, with
binomial logit and probit as distinct cells. It fits per-trait phylogenetic
intercept--slope blocks under `phylo_indep(1 + x | species, tree = tree)`.
This is single-seed fit-health evidence, not an admission, coverage, or
inference-certification campaign.

| Symbol in the DGP | Keyword / fit term | DGP draw | Recorded recovery field | Frozen truth |
|---|---|---|---|---|
| `beta_t` | `0 + trait` | family-matched trait intercepts in `eta` | `fixed_estimate`, `fixed_max_abs_error` | recorded per cell |
| `a_{st}` | `phylo_indep(1 + x | species)` intercept | independently per trait, `a_t ~ N(0, sigma^2_{a,t} A)` | `sd_estimate` odd elements | recorded per cell |
| `b_{st}` | same keyword slope | independently per trait, correlated with `a_{st}`, and phylogenetically structured by `A` | `sd_estimate` even elements | recorded per cell |
| `rho_t` | within-trait augmented covariance block | `Cov(a_t,b_t)=rho_t sigma_{a,t} sigma_{b,t}` | `cor_estimate`, `cor_max_abs_error` | recorded per cell |
| `y_{ist}` | selected family/link | `g^{-1}(eta_{ist})` plus family-specific draw | manifest family/link and fit health | one frozen seed per cell |

The CSV records convergence, positive-definite Hessian, maximum gradient,
fixed-effect truth recovery, random-effect SD/covariance truth recovery, warnings,
errors, and elapsed time. A fit has a 90-second elapsed-time ceiling; the driver
will not start a new cell after 20 minutes. Failures are written, not discarded.

Run from the worktree root:

```sh
Rscript dev/release-evidence/run-slope-smoke.R
```

The default `family_matched` scenario uses the existing route-specific fixture
information regimes: ten-trial binomial responses, a viable Poisson count
mean, the widened NB2 fixture (`n = 80`, six repeats, `phi = 4`), and the
four-category ordinal fixture. These choices are not tuned after the fact:
they are the fixed regimes already used by the corresponding route tests.
The results CSV records the actual `n_species`, `n_rep`, truths, and scenario.
The retained source-controlled 12-cell fit-health receipt is
`2026-08-23-family-matched-smoke-receipt.md`.

The original three-trait common-DGP run remains available as a deliberately
harsh stress check, but it is not a release gate because one Bernoulli trial
and low count information are not commensurate across the supported families:

```sh
GLLVMTMB_SLOPE_SMOKE_SCENARIO=generic_stress \
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

The old common-DGP stress result did not pass. It remains retained as
fit-health evidence, not as family-recovery certification. It must not block or
promote a family-matched smoke, and it makes no claim about interval coverage,
structured-route recovery, or new family admission. No Totoro or DRAC campaign
was requested or launched, no allowlist or validation-debt status was promoted,
and the 0.7 decision remains to keep MSPL point-only and experimental.
