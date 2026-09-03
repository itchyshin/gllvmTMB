# Symbolic alignment: `censored_poisson()` (Arc E, issue #1244)

Per `symbolic-alignment` discipline: this table is the contract the C++/R
code below must match term-by-term, written BEFORE any code. Scope is
right-censoring only (v1), following `GLLVM.jl`'s
`src/families/censored_poisson.jl` (read at `origin/main`,
2026-09-02/03) and design doc `docs/design/105-va-family-densities.md`
section 7's Laplace-scale row.

## Symbol table

| Symbol | Meaning | R name | TMB name | Link |
|---|---|---|---|---|
| $\mu_{it}$ | Poisson mean, row $i$, trait $t$ | (unchanged) | `eta_o -> exp(eta_o)` | log only (Identity lock, see below) |
| $C_i$ | right-censoring limit, row $i$ (only meaningful when the row is censored) | `tmb_data$cens_limit` (new `DATA_VECTOR`, length `n_obs`) | `cens_limit(o)` | n/a (data, not a parameter) |
| — | no dispersion, no extra `PARAMETER_VECTOR` | — | — | — |

`cens_limit(o) == 0` marks an ordinary (uncensored) observation; `y(o)`
holds the observed count. `cens_limit(o) == C >= 1` marks a row censored
at $Y \ge C$; `y(o)` is IGNORED on that branch (by R-side convention it is
set equal to `C`, matching the Julia oracle's `Y[t,s] = N[t,s] = C`
encoding, but the TMB likelihood never reads `y(o)` when
`cens_limit(o) > 0`).

This mirrors the existing `n_trials` DATA_VECTOR pattern exactly (a
per-row auxiliary data vector, default value that is a harmless no-op for
every other family, described at `src/gllvmTMB.cpp:549`).

## Density

For an uncensored row ($C_i = 0$, count $y$ observed exactly):

$$
\log f(y \mid \mu_{it}) = y \log \mu_{it} - \mu_{it} - \log \Gamma(y+1)
$$

— exactly the plain Poisson (`family_id` 2) log-density; no change.

For a right-censored row ($C_i \ge 1$, only $Y \ge C_i$ known):

$$
\log P(Y \ge C_i \mid \mu_{it}) = \log S(\mu_{it}, C_i)
$$

**Stable evaluation via the Poisson-Gamma duality** (the identity the
Julia oracle's own comment names, and the identity independently
re-derived here): for integer $C \ge 1$,

$$
P(Y < C \mid \mu) = P\!\left(\mathrm{Gamma}(\text{shape}=C, \text{rate}=1) > \mu\right)
\;\Longrightarrow\;
P(Y \ge C \mid \mu) = F_{\mathrm{Gamma}}(\mu;\, \text{shape}=C,\, \text{rate}=1)
$$

i.e. $S(\mu, C) = \texttt{pgamma}(\mu,\, \text{shape}=C,\, \text{scale}=1)$
in R/TMB's `(q, shape, scale)` parameterisation (`scale = 1/\text{rate}`).
This is the **lower**-tail regularized incomplete gamma function
$P(C, \mu)$, evaluated by TMB's built-in AD-differentiable
`pgamma(q, shape, scale)` (`TMB/include/distributions_R.hpp:36-44`,
confirmed present in the installed TMB headers by direct inspection
2026-09-03 — implemented via the `D_incpl_gamma_shape` atomic, so it is
differentiable w.r.t. `q = mu` through CppAD without any hand-coded
gradient).

$$
\log P(Y \ge C_i \mid \mu_{it}) = \log\big(\texttt{pgamma}(\mu_{it},\, C_i,\, 1.0)\big)
$$

TMB's `pgamma` has no `log = TRUE` argument (unlike `dpois`), so the log
is taken directly, `log(pgamma(...))`. This is a **known, disclosed
numerical-robustness boundary**: for extreme tail combinations of
$(\mu, C)$ where `pgamma(...)` itself underflows to exactly `0` in double
precision, `log(0) = -Inf` rather than a large-but-finite log-survival
(the Julia oracle's `logcdf(Gamma(C,1), mu)` computes the log directly and
does not have this failure mode). No clamp is added, matching this
file's existing convention of not adding defensive floors that other
families (`fid` 2, 5, 10, 11, ...) do not carry either — the test fixtures
below stay at magnitudes far from that boundary, and this is recorded
here rather than silently relied upon. **Do not read this docstring as
"TMB's pgamma is unstable in general"** — the atomic implementation is a
first-class differentiable special function; the boundary is specific to
composing it with an outer `log()` at extreme arguments.

## Gradient (why no hand-coded score/weight is needed here)

The Julia oracle hand-codes `_glm_score`/`_glm_weight` (the $\eta$-score
$G$ and observed-information $W$) because `GLLVM.jl`'s Laplace core is a
**custom Newton inner loop** that consumes analytic per-observation
score/weight pairs, and `logcdf` does not survive its `ForwardDiff` path
(stated explicitly in the oracle's file header: *"η-derivatives (hand-
coded; AD through logcdf fails)"*). `gllvmTMB`'s TMB engine is different
in exactly the relevant way: **CppAD differentiates through TMB's
`pgamma` directly** (it is built from a differentiable atomic, not
opaque C library code), so the inner Laplace Newton step and the outer
marginal gradient are both obtained automatically from
`log(pgamma(mu, C, 1))` with no hand-derived score/weight needed — this
is the same reason every other family in `src/gllvmTMB.cpp` (Poisson,
NB2, Beta, ...) writes the log-density directly and never hand-codes a
score. The finite-difference gradient check in
`tests/testthat/test-censored-poisson.R` is therefore a check that CppAD's
automatic differentiation of `pgamma` is correct at this call site, not a
re-derivation of the Julia oracle's hand-coded $G$/$W$ formulas (recorded
so a reviewer does not expect the two to match algebraically term-for-
term — they are different differentiation strategies for the same
density).

## Link restriction (Identity lock, matching the oracle)

Log link only. `fitted()`/`predict(type="response")` and the R-side
`.dlinkinv_per_row()` derivative use `exp(eta)` unconditionally for
`censored_poisson` (falling through to the existing log-link default
branch — no new branch needed, see "R-side slots" below): this reports
the mean of the **underlying uncensored Poisson process**, not a
censoring-adjusted expectation, matching how a detection limit is
understood to be a property of the *observation mechanism*, not the
*population mean* being estimated (same convention `glmmTMB`'s
`truncated_*` families and this package's own `truncated_poisson`
(`fid` 10) already use for their own `fitted()` rule — the truncated mean
is NOT reported, the untruncated `exp(eta)` is).

## Scope boundaries (stated, not silently narrowed)

1. **Right-censoring only.** Left-censoring and interval-censoring
   (`docs/design/105-va-family-densities.md` §7's fuller table) are
   **NOT built** here — out of scope for this arc, matching the Julia
   oracle's v1 scope exactly (its own `censored_bounds_to_YN()` throws on
   any non-right-censored `(L,U)` pair). A future extension would need a
   `cens_type` DATA_IVECTOR (0 = exact, 1 = right, 2 = left, 3 = interval)
   rather than the single `cens_limit` scalar-per-row encoding used here.
2. **No dispersion, no zero-inflation.** This is plain censored Poisson,
   not a censored-and-zero-inflated hybrid.
3. **Laplace only.** AGHQ is refused (new `family_id_vec == 21L` clause
   in `R/fit-multi.R`'s AGHQ-eligibility chain, mirroring the existing
   `multinomial`/`zi_*` refusal one line above it) because the
   quadrature-vs-Laplace tiering in `docs/design/105-va-family-densities.md`
   §7 explicitly marks censored rows as needing GH (not exact), which is
   unbuilt; VA is refused by omission (`R/va-routing.R`'s `0:15L`
   allow-list already excludes every `family_id` from 16 up, no code
   change needed, same as fid 17-19); MSPL's registry
   (`R/mspl-registry.R`) is a fixed enumerated table with no
   `censored_poisson` row, so it refuses by omission too (verified, no
   code change needed).
4. **`fitted()`/residuals report the underlying-process quantity, not a
   censoring-corrected one**, per the Link restriction section above and
   the `link_residual_rule` slot below.
5. **Rootogram (`predictive-diagnostics.R`'s `type = "rootogram"`) is
   NOT extended** to `family_id` 21 — left excluded, matching how plain
   `binomial` (fid 1) and `zi_binomial` (fid 19) are deliberately excluded
   already; a rootogram compares observed vs. simulated *count* histograms
   and censored rows do not carry an observed count (the design doc
   itself does not resolve this), so this is left as a stated gap rather
   than built speculatively.
6. **`diagnose.R`'s `check_gllvmTMB()` gains no new degeneracy row** for
   `censored_poisson` — unlike `zi_*` (which added a `boundary_zi_<trait>`
   row for its estimated `logit_zi` parameter), `censored_poisson`
   introduces no new estimated parameter at all, so there is no boundary
   quantity to flag.

## R-side response encoding (new, not in the Julia oracle's R analogue —
## gllvmTMB has no Julia twin R API to mirror here, so this is designed
## fresh against this package's own `cbind()` LHS convention)

Users supply `cbind(y, censored) ~ ...` for a `censored_poisson()` trait,
matching the existing `cbind(successes, failures) ~ ...` binomial LHS
grammar shape (both are "2-column response matrix" idioms, dispatched by
`family_id_vec` per row, exactly as `n_trials` is already computed
dataset-wide but only consumed by binomial-family rows):

- column 1 (`y`): the observed count if `censored == 0`, or the censoring
  limit $C$ if `censored == 1`.
- column 2 (`censored`): a strict `{0, 1}` indicator.

A plain single-column response (`y ~ ...`) is also accepted — every row
is treated as uncensored (`cens_limit = 0` throughout), which reproduces
plain `poisson()` exactly (the "all-uncensored convenience path" the
Julia oracle also documents explicitly, "(must match Poisson)").

Validation (new `cli_abort()`s, `R/fit-multi.R`, each with a `>` next-step
bullet per the gapclose discipline):
- `censored` column values other than exactly `{0, 1}` are refused.
- `censored == 1` rows with `y <= 0` are refused (limit `C = 0` is
  uninformative: $P(Y \ge 0) = 1$; matches the Julia oracle's own
  `C < 1` guard).
- `censored == 0` rows with a non-negative-integer `y` are validated the
  same way plain `poisson()` rows already are.

## 14-slot registry coverage (this arc's checklist, mirroring Arc D's)

| Slot | Location | Status |
|---|---|---|
| TMB density | `src/gllvmTMB.cpp`, `obs_loglik` lambda, new `fid == 21` branch | Built |
| `family_to_id()` | `R/fit-multi.R` | Built (`censored_poisson = 21L`) |
| Link check | `R/fit-multi.R` | Built (log only) |
| `y`/`censored` validation | `R/fit-multi.R` | Built |
| `cens_limit` DATA_VECTOR wiring | `R/fit-multi.R` `tmb_data` list + `src/gllvmTMB.cpp` `DATA_VECTOR` | Built |
| Mask/map registry | n/a | No new parameter to mask (stated, not omitted) |
| VA routing | `R/va-routing.R` | Refuses by omission (verified, no change) |
| AGHQ eligibility | `R/fit-multi.R` | Built (new refusal clause) |
| MSPL registry | `R/mspl-registry.R` | Refuses by omission (verified, no change) |
| `fitted()` / `predict(type="response")` rule | `R/methods-gllvmTMB.R` `.apply_linkinv_per_row()` | Falls through to existing log-link default (no change needed, documented) |
| `se.fit` derivative | `R/methods-gllvmTMB.R` `.dlinkinv_per_row()` | Falls through to existing log-link default (no change needed, documented) |
| `simulate()` | `R/methods-gllvmTMB.R` `.draw_y_per_family()` | Built (draws latent Poisson, re-applies the row's own censoring design) |
| Exact/randomized-quantile residuals | `R/predictive-diagnostics.R` | Built (new `fid == 21` branch: exact Poisson CDF on uncensored rows, `Uniform(F(C-1), 1)` on censored rows) |
| `link_residual_rule` | `R/extract-sigma.R` | Built (reuses `fid == 2` Poisson rule, `log1p(1/mu_t)`) |
| Family label | `R/predictive-diagnostics.R` `.gllvmTMB_family_label_from_id()` | Built |
| `.valid_family` enum mirror | `R/enum.R` | Built |
| Rootogram | `R/predictive-diagnostics.R` | Deliberately NOT extended (scope boundary 5 above) |
| Degeneracy check | `R/diagnose.R` | Deliberately NOT extended (scope boundary 6 above) |

## Runtime family id

**`family_id = 21`.** Originally built at `family_id = 20` (the next free
id above every id used on `main` at the time this arc started, `0`-`19`;
`17`-`19` are the `zi_*` families landed two days prior), then
**RENUMBERED to 21 on 2026-09-03**: a sibling unmerged branch
(`o4-ordinal-logit`) independently claimed the same id `20` for
`ordinal_logit()`, and its PR (#1250) was maintainer-approved and merges
first, so `censored_poisson` loses the tie and moves to the next free id.
This is the resolution of the collision this file itself flagged before
it reached merge time; the site was found and fixed here rather than at
a merge conflict. Every code site, test, and doc that named `20` for
`censored_poisson` was updated to `21` in the same commit that made this
edit (`src/gllvmTMB.cpp`, `R/enum.R`, `R/fit-multi.R`,
`R/extract-sigma.R`, `R/predictive-diagnostics.R`,
`R/methods-gllvmTMB.R`, `tests/testthat/test-enum-runtime-ids.R`,
`tests/testthat/test-censored-poisson.R`); density identity, the FD
gradient, the all-uncensored-equals-`poisson()` check, and the recovery
seeds were all re-measured after the renumber (see this arc's final
report for the re-measured numbers, not merely a claim that renumbering
is cosmetic).
