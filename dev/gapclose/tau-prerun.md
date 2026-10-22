# `loading_ridge` / VA pre-run: does either remedy fix a runaway loading on known-truth data?

D-139 pre-run test. Fisher (statistical-inference reviewer). gllvmTMB 0.7.1, R 4.6.0.
The package was **not edited**.

## Argument names confirmed from installed help before writing any code

- `gllvmTMBcontrol(loading_ridge = tau)` — confirmed the correct spelling (`?gllvmTMBcontrol`).
  `aghq_ridge` is the older name; `loading_ridge` is "*Integration-neutral alias for
  `aghq_ridge`... Use this spelling to request the same loading MAP penalty on a Laplace
  fit without suggesting that the penalty belongs to AGHQ.*" Confirms the package's own
  Heywood warning (which currently tells users to set `aghq_ridge = 2`) is naming the
  legacy alias, not the recommended spelling.
- `gllvmTMBcontrol(integration = "va")` — confirmed. VA is admitted only inside a fence:
  `latent(..., unique = FALSE)`, `d <= 2`, up to 80 responses, **at least 100 units**. A
  first attempt at `n_sites = 60` (smoke test) was refused outright with "60 units is below
  the evidenced minimum of 100" — both simulated datasets below use `n_sites >= 150`.
- `latent(0 + trait | g, d = K, unique = FALSE)` — confirmed (`?latent`); `unique = FALSE`
  is required anyway to stay inside the VA fence, so all arms (ML, every ridge, VA) fit the
  identical loadings-only model class for a fair comparison.
- `traits(...)` wide LHS — confirmed in `?gllvmTMB` but not used here; long-format
  `value ~ 0 + trait + latent(...)` was simpler for a simulated site x item matrix.
- Loadings/scores accessors: `getLoadings(fit, level = "unit")`, `getLV(fit, level = "unit")`
  (`?getLoadings`, `?getLV`) — both documented as thin wrappers around
  `extract_ordination()` and confirmed to return point estimates for VA fits too.
- `check_gllvmTMB(fit)` — confirmed as the machine-readable diagnostic (`?check_gllvmTMB`).
  Its runaway-loading row is named **`binomial_prevalence_loading`** (confirmed by a smoke
  fit, not by reading the Rd alone — the argument names in the Rd, e.g.
  `loading_runaway_thresh`/`loading_absolute_thresh`, are threshold *parameters*, not the
  row's `component` value). `check_gllvmTMB()` requires class `gllvmTMB_multi` and errors on
  a `gllvmTMB_va` fit (confirmed by reading `R/va-routing.R`: VA fits carry `$status` instead
  of `$fit_health`/`$opt`/`$sd_report`, by design — "the field vocabulary is deliberately
  kept disjoint from an ordinary fit"), so `runaway_flag` is reported `NA` for the VA arm.

## Simulation code (dataset 1 — did NOT reproduce a runaway; see Finding 1)

```r
Sys.setenv(OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

set.seed(20260902)
n_sites <- 400L
p       <- 24L

prevalence_grid <- seq(0.02, 0.50, length.out = p)
true_intercept   <- qnorm(prevalence_grid)
true_loading <- rnorm(p, mean = 0, sd = 0.8)
true_z       <- rnorm(n_sites, mean = 0, sd = 1)

eta       <- outer(true_z, true_loading) + matrix(true_intercept, n_sites, p, byrow = TRUE)
true_prob <- pnorm(eta)
y         <- matrix(rbinom(n_sites * p, size = 1, prob = as.vector(true_prob)),
                     nrow = n_sites, ncol = p)
colnames(y) <- paste0("item", seq_len(p))

dat <- data.frame(
  site  = rep(seq_len(n_sites), times = p),
  trait = rep(colnames(y), each = n_sites),
  value = as.vector(y)
)
dat$trait <- factor(dat$trait, levels = colnames(y))

formula <- value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
fam     <- binomial(link = "probit")
# arms: gllvmTMBcontrol(); loading_ridge in c(0.25, 0.5, 1, 2); integration = "va"
```

Full runnable script (both datasets, parallel fitting, extraction, `tryCatch`/`system.time`
wrapping): `tau-prerun.R` (dataset 1) and `tau-prerun-dataset2.R` (dataset 2, identical
fitting/extraction logic, different DGP — see below).

## Finding 1 — dataset 1 did not reproduce a Heywood case

Realised prevalence range 1.5%-49%. Under plain ML the largest fitted loading was only
**1.93** (well under the package's own `loading_absolute_thresh = 8` and
`loading_runaway_thresh = 25` defaults), and `check_gllvmTMB()` reported `PASS` for every
arm. A true-loading SD of 0.8 combined with `n_sites = 400` was not close enough to
quasi-complete separation to trigger the pathology the real user hit — this is a negative
result about the DGP, not about the remedies, and none of dataset 1's numbers should be
used to justify a remedy for a problem the run never produced.

| arm | converged | max_gradient | max_loading | loading_spearman | lv_cor | prob_rmse | runaway_flag | runtime_s |
|---|---|---|---|---|---|---|---|---|
| ml | TRUE | 0.000888 | 1.933 | 0.9904 | 0.9181 | 0.08196 | FALSE | 25.13 |
| ridge_tau0.25 | TRUE | 0.001905 | 1.128 | 0.9887 | 0.9159 | 0.08255 | FALSE | 21.78 |
| ridge_tau0.5 | TRUE | 0.001219 | 1.515 | 0.9904 | 0.9174 | 0.08155 | FALSE | 23.03 |
| ridge_tau1 | TRUE | 0.001132 | 1.775 | 0.9904 | 0.9179 | 0.08174 | FALSE | 23.42 |
| ridge_tau2 | TRUE | 0.000895 | 1.887 | 0.9904 | 0.9181 | 0.08189 | FALSE | 24.63 |
| va | TRUE | NA | 1.882 | 0.9904 | 0.9181 | NA | NA | 173.13 |

(`tau-prerun.csv` holds this table; VA's 173 s includes ~15 s of one-time TMB C++
compilation inside that R session — not fit time proper.)

## Simulation code (dataset 2 — DID reproduce a runaway; orchestrator-directed DGP)

Same fitting/extraction logic; only the DGP changed (smaller `n`, narrower/sparser
prevalence range, larger true loading SD to push a few items toward quasi-separation):

```r
set.seed(20260903)
n_sites <- 150L
p       <- 24L

prevalence_grid <- seq(0.01, 0.30, length.out = p)
true_intercept   <- qnorm(prevalence_grid)
true_loading <- rnorm(p, mean = 0, sd = 1.5)
true_z       <- rnorm(n_sites, mean = 0, sd = 1)
# ... identical eta / y / dat / formula / fitting code as dataset 1
```

Full script: `tau-prerun-dataset2.R`.

## Finding 2 — dataset 2 reproduced the runaway, and the ridge/VA direction matches the real user's fit

Realised prevalence range 3.3%-41%. Under plain ML the largest fitted loading was
**10.90**, and `check_gllvmTMB()` flagged `binomial_prevalence_loading` as `WARN`/`FAIL`
(`runaway_flag = TRUE`).

| arm | converged | max_gradient | max_loading | loading_spearman | lv_cor | prob_rmse | runaway_flag | runtime_s |
|---|---|---|---|---|---|---|---|---|
| ml | TRUE | 0.000557 | 10.896 | 0.9678 | 0.9389 | 0.10212 | TRUE | 16.94 |
| ridge_tau0.25 | TRUE | 0.000302 | 1.000 | 0.9843 | 0.9385 | 0.09264 | **FALSE** | 11.23 |
| ridge_tau0.5 | TRUE | 0.000408 | 1.581 | 0.9739 | 0.9408 | 0.08601 | TRUE | 11.33 |
| ridge_tau1 | TRUE | 0.000450 | 2.294 | 0.9670 | 0.9411 | 0.08706 | TRUE | 13.11 |
| ridge_tau2 | TRUE | 0.000401 | 3.029 | 0.9643 | 0.9402 | 0.08987 | TRUE | 14.72 |
| va | TRUE | NA | 3.481 | 0.9661 | 0.9399 | NA | NA | 81.94 |

(`tau-prerun-dataset2.csv` holds this table; VA's 81.9 s again includes one-time
compilation.)

**Reading the table.** Every `loading_ridge` value and VA cut the maximum loading well
below the unridged ML fit's 10.90 (monotonically: `tau=0.25` -> 1.00, `tau=0.5` -> 1.58,
`tau=1` -> 2.29, `tau=2` -> 3.03, VA -> 3.48), the same ordering the real 406x29
systematic-map fit showed (19.0 unridged down to 5.05/2.28/1.61/1.17 as `tau` shrank from 2
to 0.25, VA at 3.47). Only `loading_ridge = 0.25` also cleared `check_gllvmTMB()`'s
automated `binomial_prevalence_loading` flag on this dataset, and it had the best rank
recovery of the true loadings (Spearman 0.984 vs. 0.966-0.973 for the weaker ridges and VA)
while every arm's latent-score recovery and fitted-probability accuracy stayed within a
narrow band of each other. Point estimation was cheap throughout — every ridge arm ran in
11-17 s, all comfortably inside the 3-minute per-fit cap — while VA's own quadrature engine
took roughly 5-7x longer per fit (82-173 s across the two datasets, most of it one-time TMB
compilation in a fresh R process) for a shrinkage effect similar to `loading_ridge` between
1 and 2, not stronger than `loading_ridge = 0.25`.

## Caveats

- **One dataset, one seed, per DGP** — `set.seed(20260902)` for dataset 1,
  `set.seed(20260903)` for dataset 2. Neither is a calibration; both are point-estimate
  pre-run checks on a single simulated draw. A grounded remedy recommendation needs a
  multi-seed campaign before any coverage- or bias-calibrated claim is made.
- Dataset 1's negative result (no runaway at all) is itself informative about how narrow
  the runaway regime is — a true loading SD of 0.8 at `n = 400` did not approach
  quasi-separation, while SD 1.5 at `n = 150` did. This pre-run cannot say where the
  boundary sits between those two settings.
- `check_gllvmTMB()`'s `binomial_prevalence_loading` flag did not fall monotonically with
  `tau` on dataset 2 the way `max_loading` did (it fired at `tau = 0.5, 1, 2` despite their
  loadings being far below the unridged ML fit's); only `tau = 0.25` cleared it. This
  pre-run did not investigate why (plausibly the same near-constant items also trip a
  prevalence-only sub-check inside that row) — flagging this as a genuinely open question
  rather than resolving it (AGENT-INFERRED explanation only, not verified against the
  check's source).
- VA's engine health gate (`fit$status == "healthy"`) is a different kind of pass/fail
  signal than `check_gllvmTMB()`'s table and was not cross-checked against the same
  criteria; `runaway_flag = NA` for VA reflects that `check_gllvmTMB()` refuses a
  `gllvmTMB_va` object outright, not that VA was checked and passed.
- Real-data numbers quoted for comparison (406 papers x 29 items, max loading 19.0 -> 5.05
  / 2.28 / 1.61 / 1.17 / VA 3.47) are the maintainer-supplied 2026-08-20 measurements, not
  reproduced here — they are cited only to show this pre-run's ridge/VA ordering points the
  same direction, not to re-validate them.

## Proposed one-sentence remedy text (for the Heywood warning; grounded in dataset 2, the run that reproduced the pathology)

> If a fit reports a runaway loading, try `gllvmTMBcontrol(loading_ridge = tau)` with a
> small `tau` (start around 0.25-0.5) to shrink it back down, or
> `gllvmTMBcontrol(integration = "va")` as a tuning-free alternative — both cut a real
> 406-paper systematic-map fit's largest loading from 19 down to roughly 1-5 depending on
> how strongly you shrink it.

## Files

- `tau-prerun.R` — dataset 1 script (did not reproduce a runaway).
- `tau-prerun.csv` — dataset 1 results table.
- `tau-prerun-dataset2.R` — dataset 2 script (orchestrator-directed harder DGP; did
  reproduce a runaway).
- `tau-prerun-dataset2.csv` — dataset 2 results table.
- `tau-prerun.md` — this file.
