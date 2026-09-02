# GLLVM.jl capability status (twin of gllvmTMB)

Mission Control input for `/p/gllvmTMB/julia-surface`. **GLLVM.jl is a twin of
gllvmTMB**: public capability rows use the **same R vocabulary**
(sources × modes, families, intervals, slopes) so the board shows R↔Julia
alignment. The *code behind* a row may be Julia (closed-form / dense Laplace /
sparse phy / SPDE) rather than TMB — that is an engine difference, not a
different product taxonomy.

Status words (MC parser; counts derived at render time — never hand-typed into
`status/*.json`):

- `implemented` — Julia code under `src/` **and** a test (`test/` and/or gated
  `test/parity/`) for this capability row (or its clear twin analogue).
- `rejected` — deliberately refused, fail-loud, or not advertised.
- `planned` — tracked / designed; no promoted twin-complete implementation yet.
- `missing` — no Julia implementation found for this R-parallel row.

**Rose fence.** Intended API similarity ≠ full parity claim.

- Light gllvmTMB logLik: named-route **63/63** + shared site-X
  Gaussian/Binomial/Poisson **18/18** + NB2+X/Beta+X **16/16** (#177) +
  **Gamma+X** light cell (per-trait α, observed Laplace; Δ≈3e-8) +
  **Ordinal+X** light cell (per-trait cutpoints + shared γ, `ordinal_probit`;
  Δ≈5e-9) + **NB1+X** light cell (per-trait φ, observed Laplace; abs Δ≈1.53e-9,
  seed=48; #186) + **Poisson species-XB** light cell (`(0+trait):x` /
  `fit_gllvm_speciescov`; Δ≈4e-9) + **BetaBinomial+X** light cell (per-trait φ,
  trials `N`, finite-difference outer Laplace; abs Δ≈1.50e-8, seed=49). Engine
  Arc 1 lands per-trait NB2/Beta/Gamma/NB1/BetaBinomial+X and Ordinal+X. Not
  full family parity; ADEMP and coverage certificates remain fenced.
- R-bridge (`engine = "julia"`) rows that are live are still **partial** vs the
  public R-user surface even when Status = `implemented`.
- Phylo Model A / source-specific `lv` intervals: **rejected** for advertising.
- Prefer reading this beside R `/p/gllvmTMB/surface` — gaps should stay visible
  as `planned` / `missing` / `rejected`, not renamed away.

## Covariance structure grid (sources × modes)

R grammar: source ∈ {none, phylogenetic, animal, spatial, kernel} × mode ∈
{indep, dep, latent} (+ `common = TRUE` / `unique = TRUE` modifiers). Julia
exposes twin capabilities under native fitters; engine notes in parentheses are
implementation detail only.

| Capability | Status |
|---|---|
| none × indep (`indep()` / ordinary independent RE) | implemented |
| none × dep (`dep()` / unstructured trait covariance) | implemented (function API only — see caveat) |
| none × latent (`latent()` / ordinary LV GLLVM) | implemented |
| phylogenetic × indep (`phylo_indep()`) | implemented |
| phylogenetic × dep (`phylo_dep()`) | planned |
| phylogenetic × latent (`phylo_latent()`) | implemented |
| animal × indep (`animal_indep()`) | implemented |
| animal × dep (`animal_dep()`) | planned |
| animal × latent (`animal_latent()`) | planned |
| spatial × indep (`spatial_indep()`) | implemented |
| spatial × dep (`spatial_dep()`) | planned |
| spatial × latent (`spatial_latent()`) | implemented |
| kernel × indep (`kernel_indep()`) | planned |
| kernel × dep (`kernel_dep()`) | planned |
| kernel × latent (`kernel_latent()`) | planned |
| phylo_latent + `lv = ~ x` (Phylo Model A public intervals) | rejected |

Notes (not status rows): Julia phylo rows share three **equivalent** likelihood
representations (sparse CHOLMOD, contrasts, edge-incidence). Gaussian animal/spatial
today enter via `relatedness_cov` / `spatial_cov` (and SPDE latent for
**`none × dep` promotion (2026-08-28, maintainer decision gate 6).** Promoted
from `planned` on the evidence: `fit_dep_gllvm` is implemented
(`src/none_dep.jl`), exported (`src/GLLVM.jl:226`), included
(`src/GLLVM.jl:76`), and tested (`test/test_none_dep.jl`, 29 assertions, in
`runtests.jl`). It forces `K = p` (full-rank packed Λ, `p(p+1)/2` free
parameters, Σ = LLᵀ) — the same estimand as the twin's
`latent(0 + trait | g, d = T)`.

**Scope caveat, MEASURED not asserted:** the row is `implemented` for the
**function API only**. There is no `@formula` `dep()` sugar (v1 rejects
`FunctionTerm` / `(… | g)`), the wrapper is **Gaussian-only** (non-Normal
families fail loud), and no phylo/animal/spatial/kernel `dep` variant exists.
Critically, **at `K = p` the Σ / σ_eps split is not separately identified**:
the likelihood pins only the total `Σ_total = ΛΛᵀ + σ²I`. Verified 2026-08-28
(seed 4747, p=4, n=200): the fit reports `σ_eps = 0.9875`, yet the
alternative parameterisation `(Λ = chol(Σ_total).L, σ_eps = 0)` reproduces
`Σ_total` to `4.4e-16`. Read `σ_eps` from this path as one point on a flat
ridge, never as an estimated residual variance.

non-Gaussian `spatial_latent`). `none × indep` maps to random row effects /
per-trait diagonal paths; full unstructured `dep()` without LV is still a gap.

## Response families

Twin family names align with gllvmTMB / gllvm. Status = native Julia engine
(with tests). Bridge partiality is under **R bridge**, not hidden by renaming.

| Capability | Status |
|---|---|
| gaussian | implemented |
| poisson | implemented |
| nbinom2 | implemented |
| nbinom1 | implemented |
| binomial | implemented |
| betabinomial | implemented |
| beta | implemented |
| Gamma | implemented |
| tweedie | implemented |
| ordinal_probit / cumulative_logit | implemented |
| student | implemented (**parity Δ PAID 2026-08-28 at FIXED ν only** — see caveat) |
| lognormal | implemented |
| truncated_poisson | implemented |
| truncated_nbinom2 | implemented |
| censored_poisson | implemented |
| multinomial / categorical | missing |
<!-- Row stays `missing` deliberately: engine + parity cell is NOT a surface admit.
     **FE-only light RCall Δ PAID 2026-08-24** — live Δ abs ≈2.27e-12 @ rtol 1e-6
     (seed=57, ncat=4, n=400; gllvmTMB 0.7.0 / R 4.6.0;
     `test/parity/test_multinomial_parity.jl`). Exact concave softmax, no Laplace on
     either side, hence the picoscale Δ. Both engines additionally pinned to the
     closed-form intercept-only MLE `Σ n_c log(n_c/n)`. The 2026-08-18 Identity
     fenced a Δ as FORBIDDEN "until an engine exists" and sanctioned exactly this
     cell once it did (#257). Claim is limited to FE-only softmax logLik parity: it
     does NOT promote this row, does NOT cover the twin's latent/phylo/spatial
     multinomial surface (Design 123 — structurally absent in Julia), and is NOT
     itself a surface admit. ≠ full family parity.

     WORDING CORRECTED 2026-08-25. This clause previously read "does NOT admit
     multinomial to `fit_gllvm`/bridge dispatch", which reads as a statement of
     fact and is half wrong:
       * `fit_gllvm`: a live dispatch arm DOES exist — `fit_gllvm.jl:283-284`
         (`_fit_gllvm(::Multinomial, …) = fit_multinomial_gllvm(…)`), with a
         guarded branch at `:148`, and `test/test_multinomial.jl:136-138` asserts
         `fit_gllvm(Y; family = GLLVM.Multinomial())` returns a `MultinomialFit`
         agreeing with the named fitter to atol 1e-8.
       * bridge: correct — `grep -c multinomial src/bridge.jl` → 0.
     Bundling the two surfaces into one phrase is what made it misread. The row
     status is UNCHANGED (`missing`) and is separately defensible: it tracks the
     twin's latent/phylo/spatial multinomial surface, which is genuinely absent. -->
| delta_gamma | implemented (**parity Δ PAID 2026-08-28**) |
| delta_lognormal | implemented (**parity Δ PAID 2026-08-28**) |
| hurdle_poisson / hurdle_nbinom2 | implemented |
| zip / zinb / zib | implemented |
| ordered_beta / beta_hurdle | implemented |
| exponential (Gamma shape=1 path) | implemented |
| com_poisson | implemented |

Notes (not status rows): `zip` / `zinb` / `zib` are Julia-forward (ZIP+X via
`fit_zip_gllvm_cov`; ZINB+X via `fit_zinb_gllvm_cov`, shared scalar `r`);
twin gllvmTMB cut ZIP/ZINB — **no** invent twin light Δ. Status cells stay
bare MC tokens. `zib` also has a native Julia ZIB+X fitter (`fit_zib_gllvm_cov`)
with dual shared slopes (`γz`, `γc`), `Λ_z = 0`, and one shared scalar `N::Int`.
Since #218 / #220 the **no-X** ZIB is reachable through `fit_gllvm(Y;
family = ZIB(N))` and `@formula(y ~ 1)`, and since the bridge no-X arc through
`bridge_fit(; family = "zib", N = …)` with Wald/profile/bootstrap CI and one
**required shared scalar** trials count `N` (a uniform `p×n` `N` collapses; a
non-uniform one errors — ZIB is deliberately **out** of
`_BRIDGE_TRIALS_FAMILIES`, so `cbind_binomial` stays false). ZIB+X on any public
surface, bridge missing-response masks, `confint` under X, and any gllvmTMB
parity claim all remain OWED (the twin has no ZIB, so a light Δ would be
invented, not owed).
`student` / `com_poisson` promoted on native engine + package
**Student-t parity, PARTIAL (2026-08-28).** The live logLik Δ against
gllvmTMB 0.7.1 is PAID — but only in the **fixed-ν** configuration, and the
scope fence matters:

- **What is paid:** with ν pinned on BOTH sides (`gllvmTMB::student(df = 4)`
  vs Julia `nu = 4.0`) and Julia set to the twin's per-trait scale
  (`disp_group = :species`), Δ logLik = −9.66e-10 (builder, seed 71) and
  **3.34e-9, rel 3.6e-12 on an independent re-measurement at fresh seed 9203**
  — both far inside the 1e-6 light-cell gate. Julia's per-trait σ̂ matches the
  twin's to 4–5 significant figures. Test: `test/parity/test_studentt_parity.jl`.
- **What is NOT paid:** the twin's DEFAULT `student()` **estimates** ν
  (`R/families.R:362,367` — *"estimates degrees of freedom unless `df` is
  supplied"*), and `log_df_student` is itself per-trait
  (`gllvmTMB.cpp:1185`). GLLVM.jl fixes ν and does not estimate it. So the
  twin's default student model is still NOT comparable, and this cell must not
  be described as fully paid.
- Related: the twin's df profile CI is off by one (reports df−1 as df; see
  `docs/dev-log/decisions/2026-08-28-studentt-parameterisation.md`), so any
  future ν-interval comparison must account for that before attributing a
  mismatch to GLLVM.jl.
- Known limitation of `disp_group = :species` on this family: the postfit
  helpers in `link_residual.jl` / `simulate_fit.jl` assume a scalar σ and now
  raise a clean `MethodError` under per-trait σ — a fail-fast boundary, not
  silent misbehaviour, and not extended in this slice.

tests (`test_studentt.jl`, `test_com_poisson.jl`). Since the 2026-08-16 Student-t
surface admit the **no-X** `student` surface is reachable through `fit_gllvm(Y; family = StudentTFamily(ν))`
and `@formula(y ~ 1)`; the FIXED `ν` travels on the marker (a separate `nu`
keyword is rejected) and the marker's `σ` is an inert tag payload. Student-t +X,
`disp_group`, row effects, `bridge.jl` admission, and any gllvmTMB parity claim
remain OWED — the twin's `student` route is not benchmarked here, so **no**
light Δ is invented. Since the 2026-08-16 COM-Poisson no-X surface admit,
`com_poisson` is reachable through `fit_gllvm(Y; family = COMPoisson())` and
`@formula(y ~ 1)`; the marker's `ν` is an inert tag payload (always estimated —
the opposite of Student-t's structural `ν`). COM-Poisson +X, `disp_group`,
row effects, `bridge.jl`, and any twin light Δ remain OWED — the twin has no
CMP family, so a Δ would be invented. Since the 2026-08-16 Delta no-X surface admit,
`delta_lognormal` / `delta_gamma` are reachable through
`fit_gllvm(Y; family = DeltaLogNormal())` / `DeltaGamma()` and `@formula(y ~ 1)`;
marker `σ` / `α` are inert tag payloads (always estimated). Delta +X,
`disp_group`, row effects, `bridge.jl`, and any twin light Δ remain OWED — no
invented twin Δ. Since the 2026-08-16 Hurdle-Poisson no-X surface admit,
`hurdle_poisson` is reachable through `fit_gllvm(Y; family = HurdlePoisson())`
and `@formula(y ~ 1)`; the marker is empty (no payload). Since the 2026-08-17
Hurdle-NB no-X surface admit, `hurdle_nbinom2` is reachable through
`fit_gllvm(Y; family = HurdleNB())` and `@formula(y ~ 1)`; the marker's `r` is
an inert tag payload (always estimated; no `r_init`). Since the 2026-08-17 Beta-hurdle no-X surface admit, `beta_hurdle` is reachable
through `fit_gllvm(Y; family = BetaHurdle())` and `@formula(y ~ 1)`; the
marker's `φ` is an inert tag payload (always estimated; no `φ_init`).
Since the 2026-08-17 Ordered-beta no-X surface admit, `ordered_beta` is
reachable through `fit_gllvm(Y; family = OrderedBeta())` and `@formula(y ~ 1)`;
the marker's `c0`, `c1`, and `φ` are inert tag payloads (always estimated;
not used as inits; not Ordinal's `τ₁ = 0` pin).
Hurdle-Poisson / Hurdle-NB / Beta-hurdle / Ordered-beta +X, `disp_group`,
row effects, `bridge.jl`, and any twin light Δ remain OWED — the twin has no
hurdle / ordered-beta family, so a Δ would be invented. `truncated_poisson` =
zero-truncated Poisson (Identity 2026-08-15; twin fid 10; engine+admit; **bridge no-X paid** via `bridge_fit(; family = "truncated_poisson")`; **light RCall no-X Δ PAID 2026-08-24** — live Δ abs ≈2.71e-9 @ rtol 1e-6 (seed=53, p=5, K=2, n=60; Laplace both sides; gllvmTMB 0.7.0 / R 4.6.0; `test/parity/test_truncated_poisson_parity.jl`; ≠ full family parity)); `truncated_nbinom2`
= zero-truncated NB2 (Identity 2026-08-15; twin fid 11; **light RCall no-X Δ PAID 2026-08-24** — live Δ abs ≈1.58e-6 @ rtol 1e-6, relative ≈1.15e-9 (seed=58, p=5, K=1, n=120, per-trait `r`; gllvmTMB 0.7.0 / R 4.6.0; `test/parity/test_truncated_nbinom2_parity.jl`; pairs with `fit_truncated_nbinom2_gllvm_pertrait`, NEVER the shared-scalar route; requires `hessian=:observed`, the default since 2026-08-24 — the Fisher weight gives relative 1.06e-5 and FAILS; ≠ full family parity); Arc1 shared scalar `r`
≡ twin `φ`; Arc1b 2026-08-18 per-trait pack ≡ twin `log_phi_truncnb2`;
≠ bridge admit ≠ AGHQ). `lognormal` = one-part lognormal (Identity 2026-08-15; twin fid 3; engine+admit; **bridge no-X paid** via `bridge_fit(; family = "lognormal")`; **light RCall no-X Δ PAID 2026-08-24** — live Δ abs ≈2.24e-8 @ rtol 1e-6 (seed=52, p=5, K=2, n=60; exact-vs-exact; shared scalar σ; loglik includes `−Σ log y`, verified structurally **and** by a scale-shift test on `2·Y`; gllvmTMB 0.7.0 / R 4.6.0; `test/parity/test_lognormal_parity.jl`; ≠ full family parity)). `censored_poisson` = right-censored Poisson (Identity 2026-08-15; Julia-forward / twin constructor-only; light RCall Δ FORBIDDEN).

## Intervals and estimation evidence

| Capability | Status |
|---|---|
| Point extraction (coef / loadings / Σ_y / correlations) | implemented |
| Wald intervals | implemented |
| Profile-likelihood intervals | implemented |
| Parametric bootstrap intervals | implemented |
| Simulation-validated coverage certificate (broad grid) | missing |
| Light gllvmTMB logLik named routes (63/63) | implemented |
| Shared-X light logLik Gauss/Bin/Pois (18/18) | implemented |
| ML default (Gaussian closed-form / non-Gaussian Laplace) | implemented |
| REML (Gaussian pilot twin) | implemented |
| AGHQ estimator | missing |
| VA / ELBO alternative (selected families; not R-default) | implemented |

Notes (not status rows): Gaussian REML is promoted on `src/reml.jl`
(`gaussian_reml_loglik`, `fit_gaussian_reml`) + the bridge `reml=true` route +
`test/test_reml.jl` (dense-oracle criterion at rtol 1e-8, FD gradient ≤ 1e-6,
span-of-`X` invariance, recovery, bridge route). Twin admits a Gaussian-only
REML pilot and non-Gaussian REML stays `rejected`; the `fit_gaussian_gllvm(reml
= true)` profile engine and phylogenetic REML are **not** on `main` (feature
branch), so this row is the standalone + bridge path only — no twin light Δ, no
coverage certificate.

AGHQ (this row and "Broad AGHQ (Julia)" below) stays `missing`. Julia has no
`aghq` symbol under `src/` or `test/` (probed 2026-08-17 at `origin/main`
`51ffa320`). The VA path's `_gauss_hermite` is physicists' GH for VA `E_q`,
not AGHQ — do not rename it. Twin `gllvmTMB` @ `e3e813f4` ships opt-in
experimental AGHQ via `gllvmTMBcontrol(aghq = FALSE | k | "auto")`
(`R/aghq-control.R`, `aghq-gate.R`, `aghq-auto-ridge.R`, `aghq-report.R`);
default remains Laplace; eligibility is a single ordinary loadings-only
`latent()` unit-tier block; the twin itself makes no capability claim for
quadrature-fitted models. Identity:
`docs/dev-log/decisions/2026-08-17-aghq-identity.md`. No engine in that
slice. No twin light Δ.

## Random slopes and special capabilities

| Capability | Status |
|---|---|
| Fixed-effect covariates `X` (shared site design) | implemented |
| Species-specific environmental coefficients | implemented |
| Fourth-corner / trait–environment | implemented |
| Row effects fixed | implemented |
| Row effects random | implemented |
| Per-species / grouped dispersion (`disp.group`) | implemented |
| Keyworded random slopes (≥1) | planned |
| Uncorrelated slope (R double-bar / uncorrelated RE) | planned |
| Missing responses (NA / mask) | implemented |
| Missing predictor `mi()` | planned |
| Latent scores on covariates `latent(..., lv = ~ x)` ordinary | implemented |
| Concurrent / constrained / RRR ordination (`num.lv.c` / `num.RR`) | implemented |
| Quadratic response | implemented |
| Mixed-family response vector | planned |
| `@formula` / long+wide data (fixed effects) | implemented |

## R bridge (`engine = "julia"`)

Same twin surface, transport layer. Status = code + bridge/parity test exist;
**every live bridge family remains partial vs full R-user parity.**

| Capability | Status |
|---|---|
| Bridge capability ledger + drift probe (**probe is RED — see fence below**) | implemented |
| Bridge no-X point fit (core one-part families) | implemented |
| Bridge fixed-effect X (selected families) | implemented |
| Bridge missing-response mask (selected families) | implemented |
| Bridge CI transport Wald/profile/bootstrap (selected) | implemented |
| Bridge predictor-informed `lv` / `X_lv` (selected) | implemented |
| Bridge mixed-family vector | implemented |
| Bridge full family × full structure parity | rejected |
| Bridge phylo / animal / spatial / kernel source parity | planned |
| Bridge Phylo Model A / source-specific `lv` advertising | rejected |

## Bridge drift probe: `implemented` is misleading for this row (2026-08-26)

**This section exists because the row above is a compound of two halves with different
truth values.** The capability-ledger half is genuinely implemented and tested
(`bridge_capabilities()` at `src/bridge.jl:632`, exported `src/GLLVM.jl:251`, test wired
at `test/runtests.jl:206`). **The drift probe is RED**, and nothing in either repo's CI
reports it.

Measured against the twin at `origin/main`, re-derived from both constant sets:

| surface | R mirror | engine | engine-only |
|---|---|---|---|
| one-part families | 11 (`R/julia-bridge.R:18`) | 17 (`src/bridge.jl:164`) | `zip`, `zinb`, `zib`, `lognormal`, `betabinomial`, `truncated_poisson` |
| fixed-effect `X` | 6 (`:76`) | 12 (`src/bridge.jl:635`) | `zip`, `zinb`, `betabinomial`, `nb1`, `ordinal`, `ordinal_probit` |
| CI under `X` | inherits the stale 6 (`:106`) | all 12 (`_BRIDGE_NO_CI_X_FAMILIES` is empty) | same six |

There is no drift in the other direction: the R mirror never claims a family the engine
lacks.

**Count the X row from `bridge_capabilities()`, not from the constant.**
`_BRIDGE_X_FAMILIES` (`src/bridge.jl:198`) holds **11** and is documented as *"One-part
**NON-Gaussian** families"* — it excludes `gaussian` by design. The engine's actual
advertised surface is built at `src/bridge.jl:635` as
`Set(vcat(["gaussian"], _BRIDGE_X_FAMILIES))` = **12**, and the R mirror's list *includes*
`gaussian`. Citing the constant against the R list compares a gaussian-exclusive count with
a gaussian-inclusive one. The six-family delta is unaffected — `gaussian` is on both sides —
but the totals are 6 vs 12. (Corrected 2026-08-26 after a Rose audit; the first version of
this fence made exactly the error the fence exists to prevent.)

**Why nothing catches it.** `.gllvm_julia_expected_capability_drifts()`
(`R/julia-bridge.R:432`) returns a literal 0-row frame whose comment states as fact that
the two surfaces agree. The only engine-facing assertion
(`tests/testthat/test-julia-bridge.R:2848`) sits behind `skip_if_no_julia()`, so it does
not run in ordinary CI — and would fail if it did. The check that *does* pass compares the
R mirror against itself.

**User-visible consequence.** An R user on `engine = "julia"` cannot reach six families the
Julia engine ships — including the zero-inflated trio and lognormal, which are precisely
the families where GLLVM.jl is *ahead* of the twin. The bridge that would expose that lead
does not know they exist.

Reported upstream at `gllvmTMB#488`, the issue that predicted this bug class and asked for
the audit. The status word is left `implemented` because the ledger half is real; this
fence is what makes the row honest, in the same style as the Laplace-curvature section
below.

## Laplace curvature: which families match TMB's log-det (2026-08-25)

**This section exists because `implemented` alone is misleading for these rows.**
A row can be fully implemented and tested and still not reproduce `gllvmTMB` to
the precision a reader would assume, for a reason orthogonal to capability.

`gllvmTMB` is built on TMB, whose `MakeADFun(..., random = ...)` differentiates
the coded joint negative log-likelihood — so its Laplace log-determinant uses the
**observed** joint Hessian, structurally, without ever choosing. GLLVM.jl
hand-codes its Laplace kernels, and several used the **Fisher (expected)**
information in that role. The two coincide at canonical links (Poisson/log,
Binomial/logit) where the curvature is free of `y`, which is why the launch
families were unaffected and the discrepancy went unnoticed for so long.

**Status by family.** "observed" = matches TMB's log-det; "Fisher" = does not,
so a log-likelihood from that family will *not* match `gllvmTMB` to machine
precision even where the row reads `implemented`.

| family / link | log-det curvature | note |
|---|---|---|
| Poisson / log | observed ≡ Fisher | canonical; y-free, unaffected |
| Binomial / logit | observed ≡ Fisher | canonical; y-free, unaffected |
| TruncatedPoisson / log | observed ≡ Fisher | verified by expansion |
| CensoredPoisson / log | observed | hand-derived, already correct |
| Ordinal | observed | correct by construction |
| Gamma / log | **observed** | flipped 2026-08-25 — was the public default path |
| Exponential / log | **observed** | fixed |
| NB1 (grouped route) | **observed** | fixed |
| TruncatedNegBin2 | **observed** | fixed; both entry points agree since 2026-08-25 |
| DeltaGamma | **observed** | fixed |
| **NB2 (shared route)** | **observed** | flipped 2026-08-27 (PR #269) |
| **Beta** | **observed** | flipped 2026-08-28, decision A (PR #270) |
| **NB1 (generic core)** | **observed** | flipped 2026-08-28, decision A |
| **Student-t** | **observed** | flipped 2026-08-28, decision A |
| **Tweedie** | **observed** | flipped 2026-08-28, maintainer gate 1 |
| **Binomial / probit** | **observed** | flipped 2026-08-28, maintainer gate 2 |
| **GP-1** | Fisher | **retained BY DECISION** — evidence against, see below |
| **Binomial / cloglog** | Fisher | intrinsic Laplace saturation pathology, see below |

CORRECTED 2026-08-28: this table had drifted roughly four flips behind the
engine (it still described Beta, NB2, NB1 and Student-t as "not yet decided"
after decision A had already flipped all four). The census structural guard
`test/test_curvature_census.jl` is the machine-checked source of truth; this
table is prose and must be re-read against it whenever a default moves.

`Binomial` is worth calling out: it is clean at **logit** (canonical, the two
weights coincide), a flipped instance at **probit**, and a documented
exception at **cloglog**. These are properties of the *(family, link)* pair,
so any census organised by family alone will miss them.

**Census state:** `KNOWN_OPEN` is EMPTY as of 2026-08-28 — every one-part
family's curvature is adjudicated and declared. Two families are deliberate
exceptions rather than open items: GP-1 sits in `DEFERRED_BY_DECISION` with
its evidence recorded, and Binomial/cloglog's runaway is an intrinsic Laplace
saturation pathology (link FD-verified correct; diagnostic guard shipped in
PR #272), not a weight bug. **Still open: the TWO-PART families** — only
DeltaGamma has a specialised observed count-part weight, so the selector is
currently inert for the other nine (`TWOPART_KNOWN_OPEN`).

**This is a PARITY goal, not an accuracy improvement — and that distinction is
load-bearing.** Measured against high-resolution numerical quadrature over 12
seeds per family:

- **Gamma**: observed is closer **12/12**, with 20–60× smaller error.
- **Beta**: observed is closer only **2/12** — Fisher is usually nearer.
- **GP-1**: observed is measurably **worse** for dispersion recovery
  (α = 0.879 against a truth of 0.4, where Fisher lands inside the test's
  tolerance) — this is why GP-1 was retained on Fisher by decision.

So each family is decided on its own evidence, not on principle. Matching TMB is
the objective; "the numbers get better" would be an overstatement, and for two of
the three families measured it is simply false.

**How the remaining flips were decided (2026-08-28).** The 900-cell
adjudication campaign scored each cell on two metrics against an exact
quadrature oracle: objective error (|Laplace − exact|, which feeds AIC/BIC
honesty) and estimator preference (does the exact marginal prefer the
observed fit's θ̂ or the Fisher fit's?). Where the two metrics disagreed —
Beta, NB1, Student-t — the maintainer chose **estimator quality over
reported-loglik accuracy** (decision A), accepting a measurably more biased
reported loglik for estimates nearer the exact optimum, for TMB parity.
Tweedie was the strongest flip case in the entire table (observed preferred
in 98–100% of cells in every regime). Probit was decided on parity grounds
with a supporting derivation: its observed curvature is provably
non-negative (affine in `y`, endpoints positive under BigFloat; Pratt 1981
proves the probit binomial log-likelihood globally concave), so the flip
carries no indefiniteness risk.

**Where a curvature was corrected, the previous behaviour stays reachable** via
`hessian = :fisher` on the corresponding marginal.

**Not closed, but the AGHQ instance of this fault class is fixed (2026-08-28,
AGHQ unpark Slice 0/1).** A role-separation contract (Fisher-scored mode
search, selectable log-det) now covers 12 kernels; `src/families/aghq_grid.jl`
was the 13th and, until this fix, carried an unconditional Fisher weight at
`aghq_stage1a_loglik_site` for BOTH roles — silently diverging from the same
family's own default Laplace fitter for every family whose `_default_hessian`
is `:observed` (Beta, Gamma, NegativeBinomial, NB1, StudentT, Exponential,
TruncatedNegBin2, TweedieED, Binomial-probit). It now takes a
`hessian::Symbol = _default_hessian(family, link)` keyword mirroring
`laplace_loglik_site`/`covariates.jl` exactly: the Newton mode search stays
Fisher-scored; only the adaptation curvature (log-det AND the per-site
Cholesky reused across every quadrature node) is selectable. `hessian =
:fisher` pinned reproduces the pre-fix value bit-for-bit (verified against an
independent copy of the pre-change unconditional-Fisher formula, all 9
affected families plus Poisson at k=1 and k=3); the family-default k=1
template now equals that family's own default dense Laplace marginal to
1e-10, for all 9 affected families (`test/test_aghq_grid.jl`). **This closes
only the AGHQ instance.** The module remains internal — no `aghq=` public
surface, no capability-status ledger row changes from `missing`/`missing`
(§AGHQ above). The fault class generally (any future kernel that builds its
own `Λ'WΛ + I`) is still not guaranteed closed by this fix.

## gllvmTMB 0.7.1 delta (tracked 2026-08-27)

The twin moved while the Julia campaign ran: `gllvmTMB` origin/main is at
**0.7.1 (release candidate)** — 126 commits past the 0.7.0 snapshot this ledger
was written against. **The parity milestone stays pinned at 0.7.0** (do not
re-baseline mid-campaign); this section makes the new twin surface visible as
tracked debt instead of invisible. Sources: twin `NEWS.md` at origin/main plus
the merged feature PRs (#1192, #1196, #1216, #1217).

New twin capability with **no Julia ledger vocabulary until now**:

| Capability (twin 0.7.1 vocabulary) | Status |
|---|---|
| Response-column slope family (`slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, `spatial_slope()`; Gaussian long-format, predictor-only) | missing |
| Internal IID column coefficients (#1216) | missing |
| Per-source iSDM observation formulas (#1192) | missing |
| Column-slope covariance helpers incl. diagonal phylogenetic column slopes (#1196) | missing |

Deltas to rows that already exist elsewhere in this ledger (no duplicate rows —
the existing row keeps its status; the twin side moved):

- **Mixed-family response vector** (`planned` above): the twin's named
  mixed-family LV programme is now validated and closed on its main (#1217) —
  the R side of this row strengthened from partial to native-validated.
- **Predictor-informed latent scores** (`implemented` above, partial scope):
  0.7.1 ships an evaluated guide; the twin's interval evidence remains limited
  to named native Gaussian and rank-1 multi-trial binomial cells, so the
  Julia-side scope fence is unchanged.

Not capability (API hygiene in 0.7.1, nothing to mirror): unused grouping-slot
warnings (#1190), `extract_Sigma_*` soft-deprecation (#1194), VA remains opt-in
experimental (#1189).

## Withdrawn and deferred (twin fences)

| Capability | Status |
|---|---|
| Full family R↔Julia parity claim | rejected |
| Phylo Model A public interval promotion | rejected |
| Delta/hurdle latent-scale correlation advertising | rejected |
| Non-Gaussian REML | rejected |
| Broad AGHQ (Julia) | missing |

## Evidence pointers

- R surface (compare side-by-side): `/p/gllvmTMB/surface` ←
  `gllvmTMB/docs/dev-log/capability-surface.html`
- Light logLik 63/63: `docs/dev-log/handover/2026-08-01-cursor-handover.md`
- Shared-X 18/18: `docs/dev-log/after-task/2026-08-02-x-covariate-light-loglik.md`
- NB1+X engine (bridge/`@formula`/`fit_nb1_gllvm_grouped_cov`):
  `docs/dev-log/after-task/2026-08-05-nb1-x-engine-arc12.md` — light RCall
  cell live Δ abs ≈1.53e-9 @ rtol 1e-6 (seed=48; ≠ full family parity)
- NB1 no-X surface admit (`fit_gllvm` + `@formula` with no X; Identity
  `docs/dev-log/decisions/2026-08-16-nb1-betabinom-fit-gllvm-identity.md`):
  `docs/dev-log/after-task/2026-08-16-nb1-nox-surface.md` — exported `NB1` marker,
  per-trait φ via the API-B coerce. Julia-side surface + identity only; **no** new
  twin Δ (bridge behaviour unchanged, `src/bridge.jl` not opened)
- **NB1 no-X light RCall Δ PAID 2026-08-24** — live Δ abs ≈1.34e-8 @ rtol 1e-6
  (seed=55, p=5, K=1, n=120, per-trait φ; gllvmTMB 0.7.0 / R 4.6.0;
  `test/parity/test_nox_dispersion_parity.jl`; ≠ full family parity). **This cell
  first FAILED at Δ ≈ −0.115 and found a real engine defect**, since fixed:
  `fit_nb1_gllvm_grouped` declared no `hessian` keyword, so it silently inherited the
  `:fisher` default of `nb1_grouped_marginal_loglik_laplace` — the
  expected-information Laplace, a *different objective* from TMB's — while its NB2,
  Beta and `_cov` siblings all default to `:observed`. The optimiser was never
  failing; it was converging correctly to the wrong objective. Fix aligns the default;
  `hessian=:fisher` stays reachable explicitly. See `docs/dev-log/check-log.md`
  2026-08-24
- BetaBinomial+X engine (bridge/`@formula`/`fit_beta_binomial_gllvm_grouped_cov`):
  `docs/dev-log/after-task/2026-08-05-betabinomial-x-engine-arc12.md` — light
  RCall cell live Δ abs ≈1.50e-8 @ rtol 1e-6 (seed=49; ≠ full family parity)
- **Gamma + BetaBinomial no-X light RCall Δ PAID 2026-08-24** —
  `test/parity/test_nox_dispersion_parity.jl`, per-trait dispersion via the grouped
  fitters: Gamma (twin fid 4) live Δ abs ≈2.05e-8 @ rtol 1e-6 (seed=54, p=5, K=1,
  n=120); BetaBinomial (twin fid 8, N=8, trials via twin API-B `weights`) live Δ abs
  ≈6.15e-9 @ rtol 1e-6 (seed=56, p=5, K=1, n=120). gllvmTMB 0.7.0 / R 4.6.0.
  These are the **no-X** arms of families that previously had twin evidence only
  under +X; ≠ full family parity
- BetaBinom no-X surface admit (`fit_gllvm` + `@formula` with no X; same Identity
  as the NB1 row above): `docs/dev-log/after-task/2026-08-16-betabinom-nox-surface.md`
  — exported `BetaBinom` marker, per-trait φ via the API-B coerce, p×n trials `N`
  **required** at the entry point (φ unidentifiable at `N = 1`). Julia-side surface
  + identity only; **no** new twin Δ (bridge behaviour unchanged, `src/bridge.jl`
  not opened)
- ZIP+X engine (bridge/`@formula`/`fit_zip_gllvm_cov`; Identity 2026-08-09):
  `docs/dev-log/after-task/2026-08-09-zip-x-engine.md` — Julia identity/FD only;
  **no** twin light Δ (gllvmTMB ZIP cut)
- ZINB+X engine (bridge/`@formula`/`fit_zinb_gllvm_cov`; Identity 2026-08-13):
  `docs/dev-log/after-task/2026-08-14-zinb-x-engine.md` — Julia identity/FD only;
  shared scalar `r`; **no** twin light Δ (gllvmTMB ZINB cut)
- ZINB+X confint under X (`confint(ZINBCovFit)`; FD Hessian; `ci_x_*` true):
  Julia CI claim only ≠ twin Δ ≠ ADEMP
- truncated_poisson Identity + engine + **bridge no-X** (zero-truncated; twin fid 10):
  `docs/dev-log/decisions/2026-08-15-truncated-poisson-identity.md` ·
  `src/families/truncated_poisson.jl` · `src/bridge.jl` (`_BRIDGE_ONEPART_FAMILIES`
  after `zib` / `_bridge_family_key` / `_bridge_fit_onepart`) ·
  `test/test_truncated_poisson.jl` · `test/test_bridge_truncated_poisson.jl` —
  Julia identity/FD + bridge admit; light RCall Δ still OWED (not invented);
  CI / X / X_lv / masks remain follow-ups; y ≥ 1 fail-loud
- truncated_nbinom2 Identity + engine (zero-truncated NB2; twin fid 11; shared-`r` Arc1 + per-trait Arc1b):
  `docs/dev-log/decisions/2026-08-15-truncated-nbinom2-identity.md` ·
  `docs/dev-log/plans/2026-08-15-truncated-nbinom2-identity-engine.md` ·
  `docs/dev-log/after-task/2026-08-18-truncated-nbinom2-arc1b.md` ·
  `src/families/truncated_nbinom2.jl` · `test/test_truncated_nbinom2.jl`
  — Arc1b pack `[β; pack(Λ); log r_1…log r_p]` ≡ twin `log_phi_truncnb2`;
  ≠ bridge admit ≠ AGHQ
- lognormal Identity + engine + admit + **bridge no-X** (one-part lognormal; twin fid 3):
  `docs/dev-log/decisions/2026-08-15-lognormal-identity.md` ·
  `src/families/lognormal.jl` · `src/bridge.jl` (`_BRIDGE_ONEPART_FAMILIES` /
  `_bridge_family_key` / `_bridge_fit_onepart`) · `test/test_lognormal.jl` ·
  `test/test_bridge_lognormal.jl` ·
  `docs/dev-log/handover/2026-08-15-lognormal-ADMIT.md` — Julia identity/FD +
  bridge admit; light RCall Δ still OWED (not invented); CI / X / X_lv / masks
  remain follow-ups
- censored_poisson Identity + engine + admit (right-censored Poisson):
  `docs/dev-log/decisions/2026-08-15-censored-poisson-identity.md` ·
  `src/families/censored_poisson.jl` · `test/test_censored_poisson.jl` ·
  `docs/dev-log/after-task/2026-08-15-censored-poisson-engine.md` — Julia-forward;
  twin is constructor-only, so a light RCall Δ is **forbidden**, not owed
- Hurdle-Poisson no-X surface admit (`fit_gllvm` + `@formula` fall-through):
  `src/families/fit_gllvm.jl` · `test/test_hurdle_poisson.jl` — empty marker
  `HurdlePoisson()`; +X / bridge remain OWED; twin light Δ
  **forbidden** (no twin hurdle family)
- Hurdle-NB no-X surface admit (`fit_gllvm` + `@formula` fall-through):
  `src/families/fit_gllvm.jl` · `test/test_hurdle_nb.jl` — tag-payload marker
  `HurdleNB()` (`r` never read); +X / bridge remain OWED; twin light Δ
  **forbidden** (no twin hurdle family)
- Beta-hurdle no-X surface admit (`fit_gllvm` + `@formula` fall-through):
  `src/families/fit_gllvm.jl` · `test/test_beta_hurdle.jl` — tag-payload marker
  `BetaHurdle()` (`φ` never read); +X / bridge remain OWED; twin light Δ
  **forbidden** (no twin beta-hurdle family)
- Ordered-beta no-X surface admit (`fit_gllvm` + `@formula` fall-through):
  `src/families/fit_gllvm.jl` · `test/test_ordered_beta.jl` — three-field
  tag-payload marker `OrderedBeta()` (`c0`, `c1`, `φ` never read); +X /
  bridge remain OWED; twin light Δ **forbidden** (no twin ordered-beta
  family; `"ordered"` on the bridge already means ordinal)
- ZIB no-X surface admit (`fit_gllvm` #218, `@formula` #220):
  `src/families/fit_gllvm.jl` · `src/formula.jl` · `test/test_zero_inflated.jl` /
  `test/test_formula.jl` — X on those surfaces remains OWED
- ZIB no-X **bridge** admit (Identity
  `docs/dev-log/decisions/2026-08-16-zib-bridge-identity.md`):
  `src/bridge.jl` · `test/test_bridge_zib.jl` — `"zib"` is a one-part bridge
  family with Wald/profile/bootstrap no-X CI and a required shared scalar `N`;
  ZIB+X on the bridge, `_family_ci(::ZIBCovFit)`, and masks remain OWED; a twin
  light RCall Δ is **forbidden**, not owed (no twin ZIB)
- student / com_poisson ledger promote: `test/test_studentt.jl`,
  `test/test_com_poisson.jl` (code already present)
- REML promote: `src/reml.jl` + bridge `reml=true` + `test/test_reml.jl`
  (dense-oracle criterion rtol 1e-8; FD gradient ≤ 1e-6; span-of-`X` invariance;
  β/σ_eps recovery; bridge `gaussian_reml_rr` route vs the standalone fitter).
  Gaussian-only; `fit_gaussian_gllvm(reml = true)` and phylo REML are not on
  `main`
- AGHQ Identity (estimator absent; twin opt-in experimental; VA GH ≠ AGHQ):
  `docs/dev-log/decisions/2026-08-17-aghq-identity.md` — both AGHQ ledger
  rows stay `missing`; no engine, no stub knob, no twin Δ
- Public catch-up prose: `docs/src/gllvmtmb-parity.md` (Documenter legend ≠ this
  MC vocabulary)
