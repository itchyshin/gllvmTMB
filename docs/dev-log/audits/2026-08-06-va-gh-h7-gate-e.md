# VA(GH) H = 7 Gate E — independent 18-cell verdict

**Date:** 2026-08-06
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families`
**Branch:** `codex/va-gh-all-families`
**Verdict:** **PASS — 18/18 scalar family/link cells**
**Boundary:** arithmetic, AD, parameter routing, and known-DGP light health only.
This is not recovery-depth, Wald-coverage, latent-SD calibration, or Arc-2 evidence.

## Gate contract

Each cell had to match an independent scalar oracle, retain finite compiled
derivatives, pass its light known-DGP fit, and preserve explicit alternative
evaluators where present. No pooled score could hide a failing cell. Multinomial
`family_id = 16` remained excluded as a coupled-softmax architecture.

## Per-cell verdict

| family_id | Family/link | Route | Arithmetic/compiled evidence | Light fit | Verdict |
|---:|---|---|---|---|---|
| 0 | Gaussian / identity | exact | exact normal expectation and compiled bridge | healthy | PASS |
| 1 | binomial / logit | GH; JJ explicit | independent H7 oracle and prior JJ regression | healthy | PASS |
| 1 | binomial / probit | GH; AC/AC2 explicit | independent H7 oracle and AD-safety regression | healthy | PASS |
| 1 | binomial / cloglog | GH | independent H7 tail-safe oracle | healthy | PASS |
| 2 | Poisson / log | exact | exact log-Poisson expectation and compiled bridge | healthy | PASS |
| 3 | lognormal / log | exact | exact transformed-normal expectation | healthy | PASS |
| 4 | Gamma / log | exact | exact Gamma expectation | healthy | PASS |
| 5 | NB2 / log | GH | independent H7 oracle; L-BFGS-B light route | healthy | PASS |
| 6 | Tweedie / log | GH | fixed `p=1.7`, eta 40: `-679973.1806340611` vs `-679973.1806340618` | healthy | PASS |
| 7 | Beta / logit | GH | eta 40: `-43.557568031411328` vs `-43.557568031411336` | healthy | PASS |
| 8 | beta-binomial / logit | GH | eta 40: `-42.952395960067030` vs `-42.952395960067022` | healthy | PASS |
| 9 | Student / identity | GH | fixed `df=7`: `-1.2132490536505878` vs `-1.2132490536505862` | healthy | PASS |
| 10 | truncated Poisson / log | GH | eta -40: `-40.693147180559954` vs `-40.693147180559961`; finite Hessian | healthy | PASS |
| 11 | truncated NB2 / log | GH | eta -40: `-40.344840486291730` vs `-40.344840486291737`; finite Hessian | healthy | PASS |
| 12 | delta lognormal / log | hybrid | GH occurrence plus exact positive-part oracle | healthy | PASS |
| 13 | delta Gamma / log | hybrid | GH occurrence plus exact positive-part oracle | healthy | PASS |
| 14 | ordinal / probit | GH | stable independent CDF-difference oracle | healthy | PASS |
| 15 | NB1 / log | GH | eta 40: `-1.8386558124908122e17` vs `-1.8386558124908160e17`, relative error `2.09e-15` | healthy | PASS |

The seven formerly blocked cells were re-reviewed with `statmod` standard-normal
H7 quadrature rather than the package GH helper and separately coded densities.
The Tweedie reference used a compound-Poisson/Gamma log series; NB1 used a stable
gamma recurrence. Non-negligible variances (`0.06` or `0.08`) kept all relevant
nodes inside the formerly clamped tails. Every reviewed objective had finite
gradients. The two far-left truncated objectives also had finite Hessians.

## Defects found and repaired before PASS

1. Eta/probability clamps changed the Tweedie, Beta, beta-binomial, truncated
   Poisson, truncated NB2, and NB1 densities.
2. Fixed Tweedie power and Student degrees of freedom were dropped by the VA
   adapter. The router now preserves them per trait and the TMB map pins them.
3. The shared `log(1-exp(a))` helper floored `a` at unit roundoff, making both
   truncated families wrong by 3.3409600688892 log units at eta -40. Branch-local
   safe surrogates now preserve the selected small-probability limit while keeping
   unselected AD paths finite.
4. Public VA-Wald conditioned on fitted family nuisance parameters. Its Schur
   block now profiles every fitted global model coordinate and is checked against
   a full inverse-Hessian beta block.
5. `student(df=...)` now validates one finite value greater than one; malformed
   metadata cannot silently become a free parameter.

## Commands and outcomes

```sh
Rscript --vanilla -e 'devtools::test(filter = "(va-all-family-compiled|approximation-engine|student-recovery)", reporter = "summary")'
# DONE; new adapter, map, tail, gradient, Hessian, and constructor tests green.

Rscript --vanilla -e 'devtools::test(filter = "(va-(routing-oracle|r3-prototype|intervals)|va-all-family-(oracles|compiled|light-fits))", reporter = "summary")'
# DONE; all 18 light cells healthy; compiled, oracle, intervals, prototype,
# and public-routing targets green.

git diff --check
# PASS before this receipt was written.
```

Independent review found no remaining likelihood blocker. Earlier checkpoint
evidence also retained 180/180 ordination/routing/probit checks, 160/160 original
all-family oracle/compiled checks, and 174/174 original all-family light checks.

## Permission and negative space

Gate E now authorises making H = 7 the automatic GH order, routing public `auto`
to GH, and admitting the 18 scalar family/link cells individually. The package
default remains Laplace. Explicit JJ remains available for binomial-logit; AC and
AC2 remain internal explicit research alternatives.

This receipt does **not** authorise multinomial, `unique = TRUE`, wider ranks,
smaller `n`, structured providers, random slopes, missing predictors, calibrated
coverage claims, or pooled family verdicts. Arc 2 must test recovery and uncertainty
independently by family on Totoro/DRAC.
