# AGHQ scope, slice 0a: family inventory and the attachment point

Scope: read-only survey of `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
main @ `dc10fa6a`. No code touched, no fits run beyond reading source. All
claims below cite `file:line`; anything I could not settle from the code is
marked UNVERIFIED.

## 1. How many families, and where the count comes from

**16 admitted families**, ids `0..15`. Two independent sources of truth,
verified to agree:

- `R/enum.R:5-22` — `.valid_family` named integer vector, explicitly commented
  as "internal diagnostic mirror" that must be kept in lockstep with the real
  authority.
- `R/fit-multi.R:265-288` — `family_to_id()`'s `switch(f$family, ...)`, the
  actual dispatch that runs at fit time and errors (`cli::cli_abort`, line
  284-287) on anything not in the list.
- `src/gllvmTMB.cpp:1994-2199` — the C++ `obs_loglik` lambda's `if (fid == N)`
  chain, one branch per id 0-15, `error("gllvmTMB_multi: unknown family_id")`
  (line 2198) as the fallback. This is the ground truth the R-side ids must
  match; I did not find a third, independent enum in the C++ file — it keys
  off the same 0-15 integers threaded through `DATA_IVECTOR(family_id_vec)`
  (`src/gllvmTMB.cpp:252`).

The two delta/hurdle families (`delta_lognormal` = 12, `delta_gamma` = 13)
are detected structurally in R by `isTRUE(f$delta)` (`R/fit-multi.R:241`)
rather than by name, so a future `delta_beta()`/`delta_gengamma()` etc. could
extend the same switch — but today only those two delta ids are wired
(`R/fit-multi.R:249-263`); `delta_beta`, `delta_gengamma`,
`delta_*_mix`, and `delta_truncated_nbinom{1,2}` are constructed by
`R/families.R` but are **not** in the delta_id switch and would hit the
"Unsupported delta family" abort (`R/fit-multi.R:253-257`).

**Reconciling the maintainer's `fit$report` name list** against the 16-id
table below: every name given (`sigma_lognormal_delta`, `phi_betabinom`,
`phi_tweedie`, `sigma_eps`, `df_student`, `p_tweedie`, `phi_nbinom1`,
`phi_nbinom2`, `phi_truncnb2`, `phi_beta`, `phi_gamma_delta`, `sigma_student`,
`ordinal_cutpoints`, `phi_gamma`) maps 1:1 onto a `PARAMETER_VECTOR`/
`PARAMETER` declared in `src/gllvmTMB.cpp:449-654` for one of the 16 ids
(see table, "aux param (C++)" column) — no extra family and no missing one.
So: **the count is really 16**, and the report-name list is a faithful
cross-check, not a hint at a larger surface.

**Exported but NOT admitted** (constructed in `R/families.R`, absent from
`family_to_id()`'s switch, so a fit attempt errors loudly): `gengamma()`
(`R/families.R:155`), `gamma_mix()`, `lognormal_mix()`, `nbinom2_mix()`
(`R/families.R:192,220,247`), `truncated_nbinom1()` (`R/families.R:384`),
`censored_poisson()` (`R/families.R:472`), `delta_gamma_mix()`,
`delta_gengamma()`, `delta_lognormal_mix()`, `delta_beta()`,
`delta_truncated_nbinom1()`, `delta_truncated_nbinom2()`
(`R/families.R:534,548,602,700,628,641`). `R/families.R:146-153`'s own
roxygen block says this explicitly: "exported for API continuity, but are
not admitted by the current multivariate `gllvmTMB()` engine ... Fits with
those families fail loudly as unsupported until likelihood wiring and
recovery tests land." So the exported R surface is larger than 16, but the
**engine** surface — the one AGHQ would sit on top of — is exactly 16.

One link-restriction discrepancy worth flagging while cross-checking: the
`betabinomial()` constructor accepts `link = "logit"` or `"cloglog"`
(`R/families.R:678`), but `family_to_id()` hard-requires `logit`
(`R/fit-multi.R:314-315`, fid 8) — so `betabinomial(link = "cloglog")`
constructs fine but errors at fit time. Not an AGHQ concern per se, just a
pre-existing family-surface inconsistency noticed in passing.

## 2. Per-family table

All branches live in one function, the `obs_loglik` lambda,
`src/gllvmTMB.cpp:1994-2201`. "Loop line" below is the line of the `if (fid
== N)` branch inside that lambda. Response type is discrete/continuous by
inspection of the density used.

| id | user spelling | link (R switch) | loop line | aux param(s) (C++, PARAMETER_VECTOR unless noted) | response | special structure |
|---|---|---|---|---|---|---|
| 0 | `gaussian()` | identity | 2000 | `log_sigma_eps` (scalar `PARAMETER`, `:450`) | continuous | none |
| 1 | `binomial()` | logit / probit / cloglog (`link_id_vec`, `:2009-2019`) | 2000-2023 | none | discrete (Bernoulli / k-of-n) | trial count `n_trials(o)`; 3-way link switch is the only per-row link choice in the engine |
| 2 | `poisson()` | log | 2024-2026 | none | discrete (count) | none |
| 3 | `lognormal()` | log | 2027-2030 | `log_sigma_eps` (shared with gaussian, `:450`) | continuous (y>0) | Jacobian `-log(y)` added for the log-y normal density |
| 4 | `Gamma()` | log | 2031-2039 | `log_phi_gamma` (per-trait, `:618`) | continuous (y>0) | mean-shape parameterisation |
| 5 | `nbinom2()` | log | 2040-2048 | `log_phi_nbinom2` (per-trait, `:615`) | discrete (count) | quadratic mean-variance; uses `dnbinom_robust` |
| 6 | `tweedie()` | log | 2049-2058 | `log_phi_tweedie`, `logit_p_tweedie` (per-trait, `:618-619`) | continuous-with-atom (y>=0, point mass at 0) | Tweedie power `p in (1,2)` estimated per-trait via `dtweedie` |
| 7 | `Beta()` | logit | 2059-2076 | `log_phi_beta` (per-trait, `:628`) | continuous (0,1) | mean-precision; manual clamp of y away from {0,1} |
| 8 | `betabinomial()` | logit only (engine-enforced) | 2077-2095 | `log_phi_betabinom` (per-trait, `:629`) | discrete (k-of-n) | trial count `n_trials(o)`; manual lgamma-based density (no TMB builtin dbetabinom used) |
| 9 | `student()` | identity | 2096-2103 | `log_sigma_student`, `log_df_student` (per-trait, `:636-637`) | continuous | df estimated (`df = 1+exp(.)`) or fixable at construction (`R/families.R:429-433`) |
| 10 | `truncated_poisson()` | log | 2104-2108 | none | discrete (count, y>=1) | zero-truncation via `logspace_sub` normaliser |
| 11 | `truncated_nbinom2()` | log | 2109-2118 | `log_phi_truncnb2` (per-trait, `:642`) | discrete (count, y>=1) | zero-truncated NB2 |
| 12 | `delta_lognormal()` | logit (presence) + log (positive) | 2119-2133 | `log_sigma_lognormal_delta` (per-trait, `:647`) | mixed: discrete presence + continuous positive | hurdle; **shared eta** drives both parts (no separate presence/abundance linear predictor) |
| 13 | `delta_gamma()` | logit (presence) + log (positive) | 2134-2147 | `log_phi_gamma_delta` (per-trait, `:648`) | mixed | hurdle; shared eta, same structure as 12 |
| 14 | `ordinal_probit()` | probit | 2148-2184 | `ordinal_log_increments` (packed per ordinal trait via `n_ordinal_cuts_per_trait`/`ordinal_offset_per_trait`, `:275-276,654`) | discrete (ordered, K>=3 categories) | cutpoints `tau_1=0` fixed, `tau_2..tau_{K-1}` free, reconstructed from log-increments; observed category read via `CppAD::Integer(y(o))` (data-dependent branch, not parameter-dependent) |
| 15 | `nbinom1()` | log | 2185-2196 | `log_phi_nbinom1` (per-trait, `:616`) | discrete (count) | linear mean-variance; `dnbinom_robust` |

`trait_id(o)` (used by every per-trait-aux family) and `family_id_vec`/
`link_id_vec` (`src/gllvmTMB.cpp:252,254`) are both `DATA_IVECTOR`s of length
`n_obs`, built row-wise in R from the per-row family/link assignment
(`R/fit-multi.R:328-372`) — this is also the plumbing behind the documented
mixed-family fit feature (`R/families.R:46-56`): different rows can carry
different family ids in one joint TMB objective.

Orthogonal to the family switch: a separate exact, non-Laplace marginalisation
lives beside it for **discrete missing predictors** (`src/gllvmTMB.cpp:2203-2337`,
design 68). It is a finite state-sum baked directly into `nll`, not part of
`obs_loglik`'s family dispatch and not something `random` covers — see §3/§4.

## 3. Where AGHQ would attach

**Entry chain**, file:line:

1. `gllvmTMB()` (`R/gllvmTMB.R:772`) calls `gllvmTMB_multi_fit()`
   (`R/fit-multi.R:182`) — the one function that builds the TMB object for
   every multivariate fit (also reachable directly, per the comment at
   `R/fit-multi.R:4967`).
2. Inside `gllvmTMB_multi_fit()`, the `random` character vector is built up
   incrementally starting from `random <- character(0)` (`R/fit-multi.R:4474`)
   through ~35 conditional `random <- c(random, "<param_name>")` pushes
   (`R/fit-multi.R:4475-4521`) depending on which covariance/RE/missing-data
   terms the parsed formula requested (e.g. `"g_phy"` for phylogenetic loadings,
   `"omega_spde"` for the SPDE spatial field, `"x_mis"`/`"u_mi_group"`/`"g_x"`
   for the three Gaussian-latent missing-predictor routes).
3. `obj <- TMB::MakeADFun(data = tmb_data, parameters = tmb_params, map =
   tmb_map, random = random, DLL = "gllvmTMB", silent = silent)`
   (`R/fit-multi.R:4541-4548`) is the single call site. **This is where the
   Laplace approximation is taken** — it happens entirely inside the `TMB`
   package's C++ internals (triggered by passing a non-empty `random=`), not
   in any code owned by this repository. I found no local re-implementation
   of the inner Laplace/Newton step (no `obj$env$spHess`, no custom
   `newtonOption` calls, no hand-rolled inner optimizer anywhere under `R/`);
   `gllvmTMB` only links `TMB`/`RcppEigen` (`DESCRIPTION:47-49`) and calls the
   stock `TMB::MakeADFun`/`TMB::sdreport`.
4. After optimisation, `invisible(obj$fn(opt$par))` then
   `obj$env$last.par.best <- obj$env$last.par` (`R/fit-multi.R:4693-4694`)
   re-populates TMB's internal state so that the **conditional mode of the
   full random-effect block, given the fixed-effect optimum**, is current;
   `obj$report()` (`:4696`) and `TMB::sdreport(obj, par.fixed = opt$par,
   getJointPrecision = FALSE)` (`:4703-4704`) are the only two places that
   read the fitted joint state afterward.

**What "a refinement layer over the Laplace objective" needs to wrap**: the
single `obj` returned by `MakeADFun` at step 3, specifically:

- the **conditional mode** of the random-effect vector at a given fixed-effect
  value — TMB already computes and caches this as part of `obj$fn()`/
  `obj$gr()` whenever `random` is non-empty (available via `obj$env$last.par`
  after a call to `obj$fn(par)`, exactly the idiom the fit code already uses
  at `:4693-4694`);
- the **Hessian (or its sparse Cholesky) of the negative log-density in the
  random-effect block only**, at that mode — TMB exposes this internally as
  `obj$env$spHess(random.only = TRUE)` (not currently called anywhere in this
  repo; this is new plumbing AGHQ would need to add, not existing plumbing to
  reuse);
- the **conditional log-density** `log p(y, u | theta)` at arbitrary points `u`
  near the mode, i.e. the ability to re-evaluate the same joint objective
  `obj$fn` at perturbed random-effect values without re-running the inner
  optimizer — this is exactly what quadrature-node evaluation needs, and it is
  the same `nll` accumulated by `obs_loglik` (§2) plus every random-effect
  prior term (the `dnorm`/`GMRF`/`SCALE(GMRF(...))` calls scattered through
  `src/gllvmTMB.cpp:691-1770`, all of which the family switch in §2 does NOT
  touch — they are unconditional on `fid`).

Because the family dispatch (§2) only decides how the **fixed, per-row**
`obs_loglik` term is computed given `eta_o`, and the refinement layer only
ever needs to re-evaluate the **whole objective** at new random-effect draws
(never needs to know which `fid` produced `eta_o`), the attachment point is
structurally **family-agnostic** at the R/TMB-object level — nothing in the
`MakeADFun` call or the `obj$fn`/`obj$gr`/`obj$env` interface differs by
family. Family-specific risk, if any, has to come from the *shape* of
`obs_loglik` as a function of `eta_o` (curvature, discreteness, atoms), not
from the wiring.

## 4. Which families make the attachment structurally awkward, and why

None of the 16 families break the **wiring** in §3 — the `MakeADFun`/
`obj$fn`/`obj$env` interface is identical regardless of `fid`. The risk is
entirely in **how well a Gauss-Hermite node grid approximates a
non-quadratic conditional log-density**, which is a property of individual
families' shape, not of the code path. Three candidates stand out, in order
of confidence:

1. **`tweedie()` (fid 6) — highest confidence risk, and already measured.**
   The maintainer's own numbers (q=2, cost 3.40x at n=2000/5 seeds; the
   `c_full = 1.064` vs a 1.02-1.04 predicted band) were measured on a
   Gaussian-response DGP, not Tweedie — so the existing evidence does not
   directly indict Tweedie. What the code does show: `dtweedie()`
   (`src/gllvmTMB.cpp:2058`) is TMB's own compound Poisson-Gamma density,
   internally a series/saddlepoint evaluation, already one of the more
   expensive built-in densities to differentiate. If AGHQ multiplies the
   number of `obj$fn` evaluations by `H^q` (stated as 81 at q=2, 2401 at q=4
   in the maintainer's brief), and each evaluation calls `dtweedie` once per
   Tweedie row, the per-node cost is not uniform across families — Tweedie
   rows will dominate whatever the cost multiplier turns out to be. This is
   an accuracy-orthogonal, pure-cost risk: UNVERIFIED whether it changes the
   q=1→q=2 sign flip already flagged as unexplained, but directly relevant to
   whether AGHQ stays inside a usable time budget for a Tweedie-heavy fit.

2. **Delta/hurdle families, `delta_lognormal()`/`delta_gamma()` (fid 12, 13)
   — moderate confidence.** These are the only families where a single
   `eta_o` drives a **mixture of a discrete and a continuous component** with
   NO separate presence/abundance predictor (`src/gllvmTMB.cpp:2119-2147`,
   comment at `:2120-2124` makes the shared-eta design explicit). The
   `if (y(o) > Type(0))` branch is a **data**-conditioned branch (fixed once
   `y` is known), so it does not break AD differentiability in the random
   effects — but the conditional log-density `log p(y|u)` as a function of
   the random effect `u` (which enters through `eta_o`) is a weighted sum of
   a logistic term and a lognormal/gamma term whose relative weight shifts
   sharply near `eta_o ~ 0` (the presence/absence boundary). That is exactly
   the kind of non-quadratic, boundary-sensitive shape that motivated AGHQ
   over Laplace in the first place (per the framing in this task's brief),
   so it's double-edged: potentially the biggest *accuracy* win, but also the
   case most likely to need more than the currently-fenced low `q` to
   converge, given the observed slow, unexplained q=1→q=2 sign flip on a
   *simpler* Gaussian DGP.

3. **`ordinal_probit()` (fid 14) — lower confidence, flagged for completeness.**
   The per-trait number of free cutpoints (`n_ordinal_cuts_per_trait`) and
   their offsets are fixed **parameters**, not random effects, so they do not
   add dimensions to the AGHQ node grid directly. The observed-category index
   `yk = CppAD::Integer(y(o))` (`:2168`) is a data-only integer cast (not
   differentiated), so it is not an AD hazard. The awkwardness, if any, is
   indirect: this is the one family combined most often in this codebase with
   `phylo_latent`/`animal_latent` structured random effects (per
   `CLAUDE.md`'s standing guard on `phylo_latent(unique=TRUE)`), and the
   liability-scale identity `H^2 = sigma^2_phy / (sigma^2_phy + 1)` used
   downstream (`R/families.R:709-730`, roxygen for `ordinal_probit`) depends
   on the random-effect variance recovered from exactly the same conditional
   mode/Hessian AGHQ would refine — so an inaccurate AGHQ node grid here
   propagates into a published heritability-style ratio, a higher-stakes
   failure mode than a plain point estimate. This is a **downstream-consumer**
   risk, not a wiring risk; I did not find anything in `src/gllvmTMB.cpp`
   that makes the ordinal branch itself harder to wrap than gaussian/poisson.

**Structurally orthogonal, not "awkward" but worth flagging**: the discrete
missing-predictor SUM (design 68, `src/gllvmTMB.cpp:2203-2337`) marginalises
some units' missing categorical/ordinal predictor **exactly**, inside `nll`,
for every family. It is not part of `random` and is not Laplace-approximated,
so AGHQ refining the `random`-block Laplace approximation does not touch it
directly — but every quadrature-node evaluation of `obj$fn` still re-runs this
exact finite sum, so it is a pure additional-cost multiplier on any fit that
combines a missing discrete predictor with AGHQ, independent of which of the
16 response families is in use. UNVERIFIED whether this cost is material
relative to the family-density cost in §4.1-2 — no timing evidence was
available in this read-only slice.

## Answer to the assignment's specific asks

- **Path**: `gllvmTMB()` (`R/gllvmTMB.R:772`) → `gllvmTMB_multi_fit()`
  (`R/fit-multi.R:182`) → `TMB::MakeADFun(..., random = random, ...)`
  (`R/fit-multi.R:4541`, the Laplace-taking call, entirely inside the `TMB`
  package) → `obj$fn`/`obj$gr`/`obj$env$last.par` (`R/fit-multi.R:4693-4694`)
  → `TMB::sdreport()` (`R/fit-multi.R:4703`).
- **Family count actually found**: **16**, ids 0-15, cross-checked in
  `R/enum.R:5-22`, `R/fit-multi.R:265-288`, and `src/gllvmTMB.cpp:1997-2196`,
  all three in agreement; the maintainer's `fit$report` name list matches
  1:1 against the 16 ids' auxiliary `PARAMETER`s with no leftover on either
  side.
- **Highest-risk families for the AGHQ layer**: (1) `tweedie()` — cost, given
  `dtweedie`'s own internal series cost multiplied by `H^q` node evaluations;
  (2) the delta/hurdle pair `delta_lognormal()`/`delta_gamma()` — accuracy
  tension, the shared-eta presence/absence boundary is the sharpest
  non-quadratic conditional shape in the family list, likely to need more
  nodes than the fenced low-`q` regime allows; (3) `ordinal_probit()` — not a
  wiring risk but a downstream-stakes risk, since its heritability-style
  ratio consumes exactly the random-effect variance AGHQ would refine.
