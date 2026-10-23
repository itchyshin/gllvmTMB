# Symbolic alignment: ordinal_logit() (Arc O4)

Per `symbolic-alignment` discipline: this table is the contract the C++/R
code below must match term-by-term. This is a **link swap** on the already-
shipped `ordinal_probit()` (family_id 14) cumulative-threshold apparatus,
not a new architecture -- every piece of cutpoint metadata, packing, and
identifiability logic is reused verbatim; only the CDF changes.

## Reference

- Hadfield, J. D. (2015). *Methods Ecol. Evol.* 6:706-714, eqn 9 (the
  cumulative-threshold response model gllvmTMB implements for both links).
- `ordinal_probit()`'s own roxygen (`R/families.R`) documents the identical
  probit convention this table generalises.

## Symbol table

| Symbol | Meaning | R name | TMB name | Where it enters |
|---|---|---|---|---|
| $K_t$ | number of observed categories, trait $t$ | `Kt` (local, `R/fit-multi.R`) | implicit (`K_minus_2 + 2`) | cutpoint count |
| $\tau_{t,1}, \ldots, \tau_{t,K_t-1}$ | free-ish cutpoints, trait $t$ ($\tau_{t,1}=0$ fixed) | `extract_cutpoints()$tau_estimate` / `report$ordinal_cutpoints` | `cuts` (local `vector<Type>`, reconstructed in the likelihood) | cell-probability bounds |
| $\delta_{t,j}$ | log-spacing between $\tau_{t,j}$ and $\tau_{t,j+1}$ | (internal only) | `ordinal_log_increments` (`PARAMETER_VECTOR`, flat, packed across ALL ordinal traits -- probit and logit share one vector) | cutpoint reconstruction: $\tau_{t,1}=0,\ \tau_{t,j+1}=\tau_{t,j}+e^{\delta_{t,j}}$ |
| $K_t-2$ | free cutpoint count, trait $t$ | `n_ordinal_cuts_per_trait[t]` | `n_ordinal_cuts_per_trait(t)` (`DATA_IVECTOR`, SHARED with fid 14) | index into `ordinal_log_increments` |
| offset | cumulative free-cutpoint count before trait $t$ | `ordinal_offset_per_trait[t]` | `ordinal_offset_per_trait(t)` (`DATA_IVECTOR`, SHARED with fid 14) | index into `ordinal_log_increments` |
| $\eta_{it}$ | linear predictor, row $i$, trait $t$ | (unchanged) | `eta_o` | latent-score location |
| $y_{it}^*$ | latent score | (not materialised) | (not materialised) | $y^*=\eta+\varepsilon,\ \varepsilon\sim\mathrm{Logistic}(0,1)$ |
| $F(\cdot)$ | standard LOGISTIC cdf (the only change from fid 14's $\Phi$) | `stats::plogis` (R side: residuals, simulate, predict_missing) | `gll_log_inv_logit` / `gll_log_inv_logit_diff` (already defined, `src/gllvmTMB.cpp:69-79,515-532`, built for `cumulative_logit()`'s missing-predictor family -- REUSED here for a different family; see naming note below) | cell probability |
| $\sigma_d^2$ | link-residual (liability) variance | `extract_sigma()` / `link_residual_per_trait()` | (fixed constant, not a parameter) | $\pi^2/3$ for `ordinal_logit()`, vs. $1$ for `ordinal_probit()` |

**Naming trap (task brief):** `cumulative_logit()` (`R/missing-predictor.R`)
is the **missing-PREDICTOR** imputation family consumed by
`impute_model(family = cumulative_logit())` -- it declares no response
family and never appears in `gllvmTMB()`'s `family = ` argument.
`ordinal_logit()` (`R/families.R`, this arc) is the **RESPONSE** family for
`gllvmTMB()`'s `family = ` argument, family_id 20. Both happen to be
cumulative-logit cell probabilities and both reuse the same
`gll_log_inv_logit_diff()` TMB helper for the identical algebra, but they
model different things (a covariate's marginal distribution vs. the
observed multivariate response) and share no calling code path. Both
constructors' roxygen cross-reference this distinction explicitly.

## Log-likelihood

For observation $i$ of trait $t$ with observed category $y_{it}=k\in\{1,\ldots,K_t\}$:

$$
P(y_{it}=k\mid\eta_{it}) = F(\tau_{t,k}-\eta_{it}) - F(\tau_{t,k-1}-\eta_{it}),
\qquad \tau_{t,0}=-\infty,\ \tau_{t,1}=0,\ \tau_{t,K_t}=+\infty
$$

with $F(x) = \mathrm{plogis}(x) = 1/(1+e^{-x})$. Three cases, matching fid
14's structure exactly (only the CDF differs):

**Bottom category ($k=1$):** $\tau_{t,0}=-\infty$, so $F(\tau_{t,0}-\eta)=0$:

$$
\log P(y=1\mid\eta) = \log F(\tau_{t,1}-\eta) = \texttt{gll\_log\_inv\_logit}(\tau_{t,1}-\eta)
$$

(implemented as `cuts(yk-1) - eta_o` with `yk=1`, i.e. `cuts(0) - eta_o = -eta_o`
since $\tau_{t,1}=0$).

**Top category ($k=K_t$):** $\tau_{t,K_t}=+\infty$, so $F(\tau_{t,K_t}-\eta)=1$,
and by logistic symmetry $1-F(x)=F(-x)$:

$$
\log P(y=K_t\mid\eta) = \log\big(1-F(\tau_{t,K_t-1}-\eta)\big) = \log F(\eta-\tau_{t,K_t-1}) = \texttt{gll\_log\_inv\_logit}(\eta-\tau_{t,K_t-1})
$$

**Middle category ($1<k<K_t$):**

$$
\log P(y=k\mid\eta) = \log\big(F(\tau_{t,k}-\eta)-F(\tau_{t,k-1}-\eta)\big) = \texttt{gll\_log\_inv\_logit\_diff}(\tau_{t,k}-\eta,\ \tau_{t,k-1}-\eta)
$$

using the existing `gll_log_inv_logit_diff(upper, lower)` helper
(`src/gllvmTMB.cpp:514-532`), which computes $\log(F(\mathrm{upper})-F(\mathrm{lower}))$
for $\mathrm{upper}>\mathrm{lower}$ in a form stable in both tails
(inherits `gll_log1mexp`'s input-ceiling guard).

**$K_t=2$ reduction.** With $K_t=2$ there are zero free cutpoints
($\tau_{t,1}=0$ only), and the two-category density collapses to
$P(y=2\mid\eta)=F(\eta)=\mathrm{plogis}(\eta)$, $P(y=1\mid\eta)=1-F(\eta)$ --
exactly `binomial(link = "logit")`, the logit analogue of Hadfield (2015)
eqn 10 (which shows the same reduction for the probit case). `R/fit-multi.R`
emits the same `cli_inform()` advisory as `ordinal_probit()` does, naming
the correct binomial link.

## Numerical guard behaviour: why the logit tail threshold is NOT ~8.3

`gll_log_pnorm` (probit) switches to a Mills-ratio asymptotic expansion at
$x<-20$ because `pnorm(x)` rounds to **exactly** 1.0 in double precision
once $x>8.2924$: the Gaussian tail $1-\Phi(x)$ decays like
$e^{-x^2/2}$ (double-exponential in $x$), so it drops below the double unit
roundoff ($\approx1.11\times10^{-16}$) by $x\approx8.3$. The logistic
complement $1-F(x)=1/(1+e^{x})$ decays only like $e^{-x}$ (a single
exponential), so it does not round to exactly 1.0 until
$x\approx-\log(1.1\times10^{-16})\approx36.7$ -- more than four times
further out. `logspace_add(0, x) = \log(1+e^x)`, which
`gll_log_inv_logit`/`gll_log_inv_logit_diff` are built on, is the standard
numerically-stable form and needs no separate asymptotic branch for this:
it stays finite and accurate across the full range TMB's `Type` can
represent, with no analogue of `gll_log_pnorm`'s explicit `-20` switch
point. **No new tail-threshold constant is introduced for fid 20.**

**Adjacent-cutpoint collision** (the failure mode `gll_log1mexp`'s comment
documents) is still reachable for `ordinal_logit()`, exactly as it is for
`ordinal_probit()`: two free cutpoints landing within $\sim10^{-16}$ of each
other on the $\eta$ scale makes `logp_k` underflow toward $\log(0)=-\infty$
before the shared `log(1e-300)` floor at the end of both branches catches
it. This is `gll_log1mexp`'s existing input-ceiling guard
(`src/gllvmTMB.cpp:83-131`) firing on `gll_log_inv_logit_diff`'s
`lower - upper` argument -- already documented at that function's own
definition (`src/gllvmTMB.cpp:521-527`) as reachable by BOTH ordinal
families. Nothing new is needed here; the SAME `log(1e-300)` residual floor
used by fid 14 is reused verbatim for fid 20.

## Identifiability (reused verbatim from fid 14)

- $\sigma_d^2=\pi^2/3$ is a FIXED constant (the standard logistic variance),
  not a free parameter -- so the between-unit auto-Psi and the per-row OLRE
  are unidentifiable for the same reason as `ordinal_probit()`'s
  $\sigma_d^2=1$: adding `sd_W`/`sd_B` on top introduces an extra scale
  factor the cutpoints absorb
  ($\tau_k \to \tau_k/\sqrt{\mathrm{sd}_W^2+\sigma_d^2}$). `R/fit-multi.R`'s
  `auto_unique_off_family` and the per-trait W-tier OLRE skip
  (`ordinal_only_per_trait`) both gate on `family_id_vec %in% c(14L, 20L)`.
- A trait must be owned ENTIRELY by one ordinal family (probit XOR logit) --
  mixing `ordinal_probit()` and `ordinal_logit()` rows within one trait is
  refused with the same "must own all rows of a trait" error fid 14 already
  raises for mixing with a non-ordinal family, because cutpoints are
  per-trait and the two link scales are not interchangeable.

## Where it enters the density (C++)

`src/gllvmTMB.cpp`, a fresh `else if (fid == 20)` block in the same per-row
`nll` accumulation loop as `fid == 14` (NOT a separate function) --
positioned immediately after the `fid == 14` block and before `fid == 15`.
Reuses `n_ordinal_cuts_per_trait`, `ordinal_offset_per_trait`, and
`ordinal_log_increments` byte-for-byte; only the three CDF calls
(`gll_log_pnorm` / `gll_log_pnorm_diff` -> `gll_log_inv_logit` /
`gll_log_inv_logit_diff`) differ.

## Fitted-response / dispersion rules

- No single-row response mean, matching `ordinal_probit()`: `fitted()` /
  `predict(type = "response")` fall back to the latent-scale
  `plogis(eta)` (not a category probability). `predict_missing(type =
  "response")` computes the genuine EXPECTED CATEGORY
  $E[k]=\sum_k k\cdot P(k\mid\eta,\tau)$ using `plogis` for fid 20 rows and
  `pnorm` for fid 14 rows, dispatched per-row from `family_id_vec`.
- `link_residual_per_trait()` (`R/extract-sigma.R`) reports
  $\sigma_d^2=\pi^2/3$ for fid 20, exactly analogous to fid 14's exact 1.

## Scope boundary (this arc)

**IN:** Laplace estimation (the package's default and only shipped
estimator), the full covariance grid on $\eta$ (the same grid every other
family gets), fixed-effect + random-effect recovery, cutpoint estimation
and reporting, residuals/simulate/predict/predict_missing/diagnostics
plumbing parity with `ordinal_probit()`.

**NOT (out of scope, unchanged from before this arc):**
- Calibrated intervals on the cutpoints themselves (Wald SEs are reported
  via `extract_cutpoints()`'s existing sdreport machinery, exactly as for
  `ordinal_probit()` -- no NEW interval work is added or claimed here).
- VA / AGHQ / MSPL. `ordinal_logit` is not added to
  `.gllvmTMB_integration_fence_limits()$families` (VA stays refused, by
  omission -- the fence's default is refuse, not admit), not added to the
  MSPL registry (`R/mspl-registry.R`), and `R/aghq-control.R` already
  matched the string `"ordinal_logit"` generically before this arc (dead
  code until now; AGHQ itself remains a separate opt-in route this arc does
  not touch).
- `diagnose.R`'s ordinal loading-degeneracy screen
  (`.gllvmTMB_ordinal_degeneracy_row()`, O1/O2) is DELIBERATELY left
  scoped to fid 14 only. Its own roxygen states the probit-liability
  argument for O2's scale-free claim ("the probit-liability residual
  variance is EXACTLY 1... so a loading IS the trait's latent SD in
  liability units") — false as written for logit ($\sigma_d^2=\pi^2/3\neq1$)
  — and its thresholds were calibrated by a dedicated 315-fit campaign
  specific to the probit family. Extending it to fid 20 without an
  analogous logit calibration would silently misstate that screen's own
  justification. Both thresholds already default to `Inf` (disarmed) for
  probit, so this exclusion changes no shipped behaviour; it is a
  validation-debt item for a future arc, not a regression.
- The augmented (intercept + slope) random-regression path
  (`.augmented_slope_family_contract()`, `R/fit-multi.R`) does not add fid
  20 -- that is a separate capability gate requiring its own C1-style
  evidence campaign, matching how it is not blanket-extended for any newly
  admitted family without dedicated evidence.
