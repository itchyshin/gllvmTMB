# VA intervals: the campaign tested the wrong route — and the speed backlog

**Status:** design note, carried forward to the next lane. Nothing here is promoted.
**Written:** 2026-08-04, closing the VA speed/blocker lane.
**Supersedes nothing.** Read with `docs/design/va-interval-coverage-campaign.md` (the campaign
design) and `dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before citing anything**).

---

## 1. The correction that motivates this note

**Shinichi, 2026-08-04:** *"I thought VA is not Wald but MCMC posterior like trick?? — and can
use sandwich like trick??"*

Both halves are right, and together they say the Step-0 pilot aimed at the wrong instrument.

**VA's uncertainty is a variational POSTERIOR, not a sampling distribution.** The fit returns
`q(z_i) = N(m_i, A_i)` — an approximate posterior over latent variables, Bayesian in flavour,
obtained at no extra cost because it *is* the fit. A Wald interval, by contrast, is a statement
about the sampling distribution of an estimator. Reading a variational covariance as a Wald
standard error silently swaps one for the other.

**And the direction of the error is known in advance.** Mean-field variational approximations
systematically **under-state** posterior variance (the classic VA critique). So a naive Wald
interval built from the variational Hessian should **under-cover** — which is exactly what the
pilot measured:

| route | n=150 | n=400 | nominal |
|---|---:|---:|---:|
| **VA-Wald** | **0.897** | **0.935** | 0.95 |
| LA-Wald (Σ_jj) | 0.929 | 0.942 | 0.95 |
| LA-Profile (V_j) | 0.925 | 0.929 | 0.95 |

⚠ **These are 30-seed descriptive numbers, MCSE ≈ 0.055.** They are feasibility triage, not
coverage estimates — 0.897 is 0.897 ± 0.11. They cannot rank routes; they can only say the
machinery runs. **The full campaign (Tiers 1+2) has never been run.**

But the *direction* matches theory, and that is the point: **VA-Wald was predicted to
under-cover, and the one route the pilot scored was VA-Wald.**

## 2. The sandwich is the right tool, and it is already built

A sandwich (Huber–White) estimator is the standard correction when the working likelihood is
misspecified — and a variational bound **is** a misspecified likelihood. That makes it the
natural instrument here, not an exotic one.

It exists: `.va_sandwich_beta_ci()` (`R/va-intervals.R:1409`) and
`.va_sandwich_loadings_ci()` (`:1496`), with the per-unit score machinery in
`.va_r3_profiled_score_by_unit()` (`:1162`).

**Its precondition is stationarity, and this is load-bearing.** The envelope-theorem
simplification that makes the per-unit profiled score valid holds *only at a converged
optimum*. The code states the falsifiable check: summing the per-unit profiled score over units
must reproduce `objective$gr(par)[fixed_idx]`, which is ~0 at a converged fit. If it is not
small, the fit was not stationary and the whole construction is void.
`.va_r3_sandwich_information()` reports `max_abs_gradient` for exactly this reason — and an
adversarial review already caught a version returning **plausible-looking SEs from a `par` 4–6
orders of magnitude off-optimum**. A sandwich that does not gate on stationarity is a machine
for producing confident nonsense.

Note the interaction with the health-gate recalibration this lane landed (`f15ad1b7`, the bar
moved 1e-4 → 5e-3): a looser *health* bar must **not** be read as a looser *stationarity* bar
for the sandwich. They serve different purposes and the sandwich needs the stricter one.

## 3. The four routes, all built as instruments, none promoted

| route | entry points | status |
|---|---|---|
| Wald-Schur | `.va_wald_beta_ci` `:418`, `.va_wald_loadings_ci` `:524` | built; **the only route Step-0 scored**; theory predicts under-coverage |
| **sandwich** | `.va_sandwich_beta_ci` `:1409`, `.va_sandwich_loadings_ci` `:1496` | built; **the theoretically indicated route**; UNSCORED |
| bootstrap | `.va_bootstrap_beta_ci` `:955`, `.va_bootstrap_loadings_ci` `:1005` | built; deferred (55% of campaign compute, no oracle floor, weakest power) |
| profile | `.va_profile_ci` `:174` | built; UNSCORED |

`confint.gllvmTMB_va()` and `vcov.gllvmTMB_va()` still **hard-refuse**
(`R/va-methods.R:184-201`, *"the inverse variational Hessian is not calibrated frequentist
uncertainty"*, Design 85 §10). That fence is correct and should stay until a route earns removal.

## 4. A hard constraint on what VA-AC intervals can ever mean

Under Albert–Chib with the A_i collapse, the variational covariance is **structurally
data-independent** — one shared matrix for every unit, by construction. So **per-unit
variational SDs carry no per-unit information at all.**

This is not a defect to fix; it follows from `∂E/∂v ≡ −n/2`. But it means any per-unit
uncertainty claim under AC is far weaker than the same claim under GH, and
`getLV(se = TRUE)`-style output must say so wherever AC produced it. **Constancy requires
complete data, constant `n_trials`, pure-probit traits, and the unstructured single-tier KL; it
is UNVERIFIED for structured tiers.**

Consequence for route selection: a route scored under GH does not transfer to AC unexamined.

## 5. What the next lane should run

**Not a coverage certificate — a ROUTE SELECTION.** D-112 fences coverage campaigns as a
release blocker and directs post-0.6 effort at capabilities. This is a capability question:
*can VA ship intervals at all, and by which route?* Framed that way it is inside D-112, not
against it. **Confirm that framing with Shinichi before spending the compute.**

1. **Score the sandwich route** at the two primary cells, alongside Wald as the control. This is
   the single highest-value measurement and it has never been made.
2. **Gate every replicate on stationarity** (`max_abs_gradient` from
   `.va_r3_sandwich_information()`), and report the rejection count — a route that only works on
   90% of fits is a different product from one that works on all of them.
3. **Enough seeds to rank routes.** 30 seeds cannot: MCSE 0.055. Ranking two routes ~0.03 apart
   needs several hundred. Budget accordingly, on Totoro, results LOCAL (D-50).
4. **Score under BOTH `eval_method`s.** §4 means an AC result and a GH result are different
   claims.
5. Only then consider profile, and only then revisit bootstrap.

**Both former blockers are closed** (`f15ad1b7` health gate; `2a174fb9` + `86049310` estimand),
verified end-to-end at n=150 and n=400. Nothing blocks this run technically.

## 6. Speed backlog carried forward

Shipped this lane: `se = FALSE` on the two refit paths that discard SEs (`e729a5be`,
`7f47717a`), both **bit-exact**, 1.26× and 1.21×.

**Closed by measurement — do not re-attempt without new information:** TMBad (1.76× *slower*);
supernodal (requires TMBad, then fails to link CHOLMOD); custom sparse Cholesky (lives in TMB
core, unreachable at package level — confirmed by two independent scouts); galamm's AD
(forward-mode, behind TMB's reverse mode); profiling as an exponent fix (~7× penalty, constant
in N — see `9c659d07`).

**Untested, in recommended order:**

| # | lever | expected | risk |
|---|---|---|---|
| 1 | **lazy `sdreport()`** — fit fast, SEs on demand | **1.49–1.57× on the core LA fit**, measured | needs a small public API addition — **Shinichi's call** |
| 2 | sdmTMB `multiphase` (`sdmTMB/R/fit.R:1539-1571`) | unknown | free by construction (a starting value only) |
| 3 | `optimHess` polish (`sdmTMB/R/extra-optimization.R:63-95`) | unknown | free by construction |
| 4 | `nlminb(scale=)` — never passed by any engine | unknown | should be free; cousin of the conditioning gap |
| 5 | gllvm's `inner.control` (`gllvm/R/gllvm.TMB.R:2125,2215`) | unknown | ⚠ `tol10` loosens inner-Newton convergence — **may move estimates**, so not free until proven |
| 6 | `sdreport` knobs (`skip.delta.method`, `ignore.parm.uncertainty`) | unknown | varies |

Full inventory: `dev/va-speed/53-ENGINE-KNOB-AUDIT.md`. Reference reads:
`50-GALAMM-REFERENCE-READ.md`, `52-SDMTMB-GLMMTMB-REFERENCE-READ.md`.

## 7. Speed facts this lane established, with regimes attached

| comparison | N=250 | N=1000 | N=2500 | N=5000 |
|---|---:|---:|---:|---:|
| VA(AC+collapse) vs LA **with** SEs | 6.72× | 4.02× | 1.67× | **0.97–1.17×** |
| VA(AC+collapse) vs LA **without** SEs (algorithm only) | 4.59× | 2.51× | **1.11×** | — |

**Crossovers are MEASURED, not extrapolated:** algorithm-vs-algorithm parity at **N ≈ 2500**;
including LA's standard errors, parity at **N ≈ 5000**. VA scales ~N^1.58, Laplace ~N^0.97.

**Never quote a VA speed multiplier without its N and without stating whether SEs are on both
sides.** A third of the apparent advantage at N=250 is LA computing standard errors that VA
cannot currently produce at all.
