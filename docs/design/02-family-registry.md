# Family Registry

**Maintained by:** Gauss (TMB likelihoods + numerical stability)
and Boole (R API + family constructors).
**Reviewers:** Fisher (statistical inference semantics), Emmy
(R package architecture + S3 dispatch), Noether (math-vs-
implementation alignment).

This document is the family registry contract for `gllvmTMB`. Per
**AGENTS.md Design Rule #1**, no new family ships without
simulation tests; per **Rule #4**, no likelihood parameterisation
change without applying the `tmb-likelihood-review` skill. Together
those rules + this registry are the family-API contract.

**Status discipline**: every per-family row uses the 4-state
vocabulary defined in `docs/design/01-formula-grammar.md`'s status
map (`covered` / `claimed` / `reserved` / `planned`). Most current
rows are `claimed` because Phase 0B verification has not yet
walked them to `covered`. **Treat `claimed` rows as parser-
accepted promissory notes, not features**, until the validation-
debt register in `docs/design/35-validation-debt-register.md`
(forthcoming, Phase 0A step 7) cross-references a passing smoke
test for each.

## Required fields per family

Each family constructor returns a small structured object with
the following slots:

- `name` — canonical family name (e.g. `"nbinom2"`, `"gaussian"`)
- `n_response` — 1 for univariate families; multi-trait fits
  stack the univariate density per row
- `dpars` — distributional parameters as a named character
  vector (e.g. `c("mu", "sigma")`)
- `links` — link function per parameter (identity / log / logit /
  probit / cloglog / inverse / atanh / logm2)
- `inverse_links` — closed-form inverse
- `bounds` — valid response support
- `density_id` — integer code passed to the TMB template
  (`src/gllvmTMB.cpp`)
- `simulate` — simulate-from-fitted closure for
  `simulate.gllvmTMB_multi()` (M2 family-aware rewrite work)
- `starting_values` — closure mapping data summary to initial
  parameter values
- `check_data` — closure validating that the response vector
  matches the family's bounds and dimensions
- `native_parameter_meaning` — the meaning of each `dpar` on the
  link scale (e.g. `mu` = log-mean for Poisson; not arithmetic
  mean of `y`)
- `fitted_response_rule` — what `fitted()` returns (mean of `y`,
  expected category score, hurdle conditional mean, etc.)
- `variance_rule` — formula for `Var(y)` given the parameters
  (or "no finite variance" if applicable)
- **`link_residual_rule`** — gllvmTMB-specific. The latent-scale
  residual variance used for mixed-family correlation reporting
  on the implied trait covariance. See "Link Residual Contract"
  below.

## Link Residual Contract (gllvmTMB-specific)

The package's headline feature is **latent-scale correlations on
mixed-family fits**: with `family = list(gaussian, binomial,
poisson, ...)`, `extract_correlations()` reports trait
correlations on the latent liability scale, after the per-family
link residual is added to the diagonal.

For a one-trait observation $y_t$ with family $f_t$, link $g_t$,
and link-scale linear predictor $\eta_t = g_t(\mu_t)$, the
latent-scale residual variance is

$$
\sigma^2_{d,t} = \text{Var}[\eta_t \mid \text{family-specific structural noise}]
$$

**Decomposition principle (maintainer, restated 2026-07-05).** At the lowest
level (the observation residual), the per-trait diagonal is
`Psi = unique_variance + link_specific_variance`, and for almost every family
exactly one term is non-zero:

- **Gaussian** — *unique only* (the estimated `sigma^2_eps`); link-specific $= 0$
  (identity link).
- **Non-Gaussian** (binomial, ordinal_probit, plain Poisson, gamma, beta,
  nbinom, delta) — *link-specific only* (the $\sigma^2_d$ below); the estimated
  unique term is $0$ (the link's implicit scale IS the residual — this is why the
  default auto-`Psi` is dropped for a pure-binary/ordinal/delta fit).
- **Overdispersed Poisson — BOTH, and it is the ONLY distribution that carries
  both**: a *separate estimated OLRE* (unique variance) on top of the Poisson
  link residual `log1p(1/mu)`. The other overdispersed families **bake** the
  overdispersion into a single analytic $\sigma^2_d$ (`nbinom2` $= \psi'(\phi)$,
  the trigamma of the NB2 dispersion, matching the shipped
  `link_residual_per_trait()`; tweedie $= \log(1 + \phi\,\mu^{p-2})$), so they
  have no separate unique term.

(Caution: this is the *observation-level* residual. The *between-unit* `Psi`
`theta_diag_B` in a `latent()`/`indep()` term is a distinct, genuinely
identifiable random-effect variance — do not conflate the two.)

This `link_residual_rule` is family-specific. The well-known
cases:

| Family | Link | Link-residual $\sigma^2_d$ |
|--------|------|----------------------------|
| `gaussian` | identity | $0$ (the family's variance is the residual; no latent-scale extra term) |
| `binomial` | logit | $\pi^2 / 3 \approx 3.29$ |
| `binomial` | probit | $1$ (by construction; the probit latent residual is unit-Gaussian) |
| `binomial` | cloglog | $\pi^2 / 6 \approx 1.64$ |
| `poisson` | log | depends on $\mu$; the trigamma-approximation $\sigma^2_d \approx \log(1 + 1/\mu)$ is the standard latent-Gaussian linearisation |
| `nbinom2` | log | $\sigma^2_d = \psi'(\hat\phi)$ (trigamma of the per-trait NB2 dispersion $\phi$), matching the shipped `link_residual_per_trait()` |
| `Gamma` | log | $\sigma^2_d = \psi'(\phi_{\gamma,t})$ where $\phi_{\gamma,t}$ is the per-trait shape and $\psi'$ is the trigamma function |
| `Beta` | logit | $\sigma^2_d = \psi'(a) + \psi'(b)$ where $a, b$ are the beta shape parameters |
| `lognormal` | identity (of log-y) | $0$ (since the linear predictor is on the log-y scale, this is just Gaussian on log-y) |
| `ordinal_probit` | probit (latent) | $1$ (by construction; probit latent residual is unit-Gaussian) |

These values are computed by `link_residual_per_trait()` in
`R/extract-sigma.R:99–280`. Phase 0B verifies each formula in
that function against a per-family simulation; mismatches get
filed against the validation-debt register.

**Mixed-family fits use a per-ROW link residual** (since the
family can vary by row, not just by trait). `check_auto_residual()`
guards against incoherent configurations (e.g. multiple families
within the same trait, or ordinal-probit traits where the latent
residual is already standardised by construction; see PR #104).

## Distributional parameter naming

Follow the GAMLSS convention (Rigby and Stasinopoulos 2005) as
the canonical vocabulary:

- `mu` — location or mean-like parameter
- `sigma` — residual scale, dispersion, or standard-deviation-
  like parameter
- `nu` — first shape parameter (family-specific meaning)
- `tau` — second shape parameter (family-specific meaning)
- `zi` — zero-inflation probability (when present)
- `cutpoints` — ordered category thresholds (ordinal families)

`tau` is allowed in ordinal-probit families and is NOT confused
with the meta-analytic `tau` (residual heterogeneity SD) — that
one lives in `meta_V()`-context discussions only.

## Family registry — per-family table

The table below lists every family constructor currently exported from
`gllvmTMB`. The **Status** column distinguishes fit-admitted families
from constructor-only compatibility surface. A constructor being exported
does not by itself mean `gllvmTMB()` currently admits that family in the
multivariate TMB engine. The validation-debt register is the source of
truth for whether a family is `covered`, `partial`, or `blocked`.

### Continuous families

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Gaussian | `gaussian()` (base R) | `mu`, `sigma` | identity, log | $\mathbb{R}$ | claimed |
| Student-t | `student()` | `mu`, `sigma`, `nu` | identity, log, logm2 | $\mathbb{R}$ | claimed |
| Lognormal | `lognormal()` | `mu`, `sigma` | identity (of $\log y$), log | $(0, \infty)$ | claimed |
| Lognormal mixture | `lognormal_mix()` | `mu`, `sigma`, mixture weights | identity, log, logit | $(0, \infty)$ | blocked constructor-only |
| Gamma | `Gamma()` (base R) | `mu`, `sigma` (reported from per-trait `phi_gamma`) | log, log | $(0, \infty)$ | claimed |
| Gamma mixture | `gamma_mix()` | `mu`, `sigma`, mixture weights | log, log, logit | $(0, \infty)$ | blocked constructor-only |
| Generalised Gamma | `gengamma()` | `mu`, `sigma`, `nu` | log, log, log | $(0, \infty)$ | blocked constructor-only |
| Tweedie | `tweedie()` | `mu`, `sigma`, `p` | log, log, logitp (constrained $1 < p < 2$) | $[0, \infty)$ with point mass at 0 | claimed |

### Bounded continuous families

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Beta | `Beta()` | `mu`, `sigma` | logit, log (internal: $\phi = 1/\sigma^2$) | $(0, 1)$ | claimed |
| Beta-binomial | `betabinomial()` | `mu`, `sigma` | logit, log (internal: $\phi = 1/\sigma^2$) | $\{0, 1, \ldots, n_\text{trials}\}$ | claimed |

### Count families

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Binomial | `binomial()` (base R) | `mu` | logit / probit / cloglog | $\{0, 1, \ldots, n_\text{trials}\}$ | claimed |
| Poisson | `poisson()` (base R) | `mu` | log | $\{0, 1, 2, \ldots\}$ | claimed |
| Negative binomial 1 | `nbinom1()` | `mu`, `sigma` | log, log | $\{0, 1, 2, \ldots\}$ | claimed |
| Negative binomial 2 | `nbinom2()` | `mu`, `sigma` (overdispersion) | log, log | $\{0, 1, 2, \ldots\}$ | claimed |
| Negative binomial 2 mixture | `nbinom2_mix()` | `mu`, `sigma`, mixture weights | log, log, logit | $\{0, 1, 2, \ldots\}$ | blocked constructor-only |
| Truncated Poisson | `truncated_poisson()` | `mu` | log | $\{1, 2, 3, \ldots\}$ (no zeros) | partial |
| Truncated nbinom1 | `truncated_nbinom1()` | `mu`, `sigma` | log, log | $\{1, 2, 3, \ldots\}$ | blocked constructor-only |
| Truncated nbinom2 | `truncated_nbinom2()` | `mu`, `sigma` | log, log | $\{1, 2, 3, \ldots\}$ | partial |
| Censored Poisson | `censored_poisson()` | `mu` | log | $\{0, 1, 2, \ldots\}$ with interval censoring | blocked constructor-only |

### Ordinal families

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Ordinal probit | `ordinal_probit()` | latent `mu`, `cutpoints` (vector) | probit (latent), identity (cutpoints on log-difference scale) | $\{1, 2, \ldots, K\}$ ordered categories | claimed |

### Unordered categorical (multinomial) families

**Status:** in progress, **fixed-effects-only** (Design 83). Admitted for
fixed-effect recovery of a single unordered categorical trait via
baseline-category logit / softmax (runtime id 16). Latent / random structure is
**N/A by design** — a multinomial trait maps to $K-1$ non-comparable
baseline-category linear predictors, so it contributes $K-1$ latent liabilities,
not one; the GLLVM latent machinery induces **one** interpretable residual
covariance $\Sigma$ per trait, so there is no single latent-residual scale on
which a trait×trait correlation is defined for a nominal response. This is the
same single-latent-scale boundary Design 62 records for delta/hurdle, generalised
from 2 scales to $K-1$.

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Multinomial | `multinomial()` | `mu` ($K-1$ baseline-category linear predictors) | baseline-category logit (softmax) | $\{1, \ldots, K\}$ unordered categories | in-progress, fixed-effects-only (Design 83) |

**Scope note (maintainer, Design 83).** Tier 1 admits fixed-effect recovery only;
`latent()` / `unique()` / `indep()` / `dep()` / `phylo_*` / `spatial_*` / slope /
cluster terms on a multinomial trait fail loud. The $K-1$-dimensional latent-scale
correlation surface is **Tier 2, deferred** (open derivation, not a validation
task) — reversible only by first defining a principled per-category or
stacked-liability reporting convention. Name: `multinomial()` (not
`categorical()`, which is the unordered missing-**predictor** imputation family,
Design 68). Julia parity is a separate later arc.

### Hurdle / delta families

**Status:** the standard `delta_lognormal()` and `delta_gamma()` routes are
admitted for fixed-effect recovery tests. Other exported delta
constructors remain compatibility constructors only and must fail loudly until
likelihood wiring, recovery tests, and the mixed-family latent-scale correlation
contract are all defined.

These two-stage families combine a binary occurrence component
(`hu` = hurdle probability) with a positive-continuous component.
The `delta_*` prefix matches the `sdmTMB` convention.

**Resolution** (maintainer, 2026-07-05 — supersedes the 2026-05-16 deferral):

The two-scale obstruction is removed by a modelling **constraint**: the latent
(random-effect) structure attaches **only to the main / positive-continuous
submodel**; the binary **occurrence (hurdle) submodel is fixed-effects only** and
carries no random effects. A delta trait therefore contributes **one** latent
scale — the positive part's — so cross-family latent correlations are
well-defined, and the "defensible single latent-residual value" the deferral
waited on is simply the **positive-part residual** (`sigma^2` on the log scale
for `delta_lognormal`; `trigamma(shape)` for `delta_gamma`). The occurrence
`pi^2/3` baseline lives on a scale with no shared latent and does **not** enter
the correlation diagonal.

Note the resulting correlation is on the positive-continuous latent scale, i.e.
**conditional on occurrence** — label it as such; it is not an unconditional
response correlation.

Two residuals must therefore be distinguished for a delta trait:

- **correlation / latent-scale context:** positive-part residual only (above);
- **total-variance / repeatability context:** the two-component
  `sigma^2_positive + pi^2/3` (law of total variance) currently in
  `extract-sigma.R` stays correct for its own purpose.

**Scope (0.2.0 arc, maintainer 2026-07-05).** Latent-on-main + the
fixed-effects-only-occurrence constraint is buildable in this arc (live wiring is
Codex lane): admit `latent()` random *intercepts* on a delta trait's positive
part, **guard** against random effects on the occurrence submodel (random
*slopes* are already blocked at `fit-multi.R:1495`), and use the positive-part
residual in `extract_correlations()`. The resulting correlations carry
`interval_status = "route-only"` (coverage unestablished, CI-08 / CI-10) until
calibrated. **Post-CRAN:** allowing random effects on the *occurrence* part too
(the genuine two-latent-scale case) needs a separate derivation — a
2-dimensional latent contribution per delta trait, or a principled per-scale
reporting scheme — and stays deferred.

**Correction (2026-07-05).** Earlier notes said cross-family correlation on a
delta mixed-family fit is "rejected by `check_auto_residual()`." That is
inaccurate: `check_auto_residual()` is an `@export`ed **manual** diagnostic, is
never auto-invoked by `gllvmTMB()` / `extract_*()`, and only aborts *within-trait*
family mixing (class `gllvmTMB_auto_residual_incoherent`). There is **no**
`gllvmTMB_auto_residual_delta_undefined` class and no automatic delta rejection.
Under the resolution above, delta is **handled** (route-only), not rejected.

| Family | R constructor (engine has it) | Components | Public status |
|--------|------------------------------|------------|---------------|
| Delta-lognormal | `delta_lognormal()` | hurdle (binomial) + lognormal (positive) | covered for fixed-effect standard parameterisation |
| Delta-lognormal mixture | `delta_lognormal_mix()` | hurdle + lognormal mixture | blocked constructor-only |
| Delta-Gamma | `delta_gamma()` | hurdle + Gamma | covered for fixed-effect standard parameterisation |
| Delta-Gamma mixture | `delta_gamma_mix()` | hurdle + Gamma mixture | blocked constructor-only |
| Delta-Beta | `delta_beta()` | hurdle + Beta (on $(0, 1)$ proportions with point mass at 0) | blocked constructor-only |
| Delta-gengamma | `delta_gengamma()` | hurdle + generalised Gamma | blocked constructor-only |
| Delta-truncated nbinom1 | `delta_truncated_nbinom1()` | hurdle + truncated nbinom1 (positive counts) | blocked constructor-only |
| Delta-truncated nbinom2 | `delta_truncated_nbinom2()` | hurdle + truncated nbinom2 | blocked constructor-only |
| Delta Poisson-link Gamma | `delta_poisson_link_gamma()` | Thorson-style Poisson-link decomposition | blocked deprecated constructor |
| Delta Poisson-link lognormal | `delta_poisson_link_lognormal()` | Thorson-style Poisson-link decomposition | blocked deprecated constructor |

## Mixed-family support

`gllvmTMB` accepts `family = list(...)` to fit different families
per trait or per row. This is the unparalleled-capability feature
named in `00-vision.md`.

### Long format

```r
gllvmTMB(
  value ~ 0 + trait + (0 + trait):env +
    latent(0 + trait | site, d = 2),
  data = df_long,
  family = list(gaussian(), binomial(), poisson()),
  trait = "trait",
  unit  = "site"
)
```

The list length must match the number of trait levels in the
data. Internally each trait gets its own per-row family slot via
the `family_var` column logic in `R/fit-multi.R`.

### Rules

- **Within-trait family mixing is REJECTED.** Each trait must
  use a single family across all its rows. `check_auto_residual()`
  errors with `class = "gllvmTMB_auto_residual_incoherent"` on
  configurations that violate this.
- **Mixed-family with `link_residual = "auto"`** uses the
  per-family link-residual rule on the latent diagonal. The
  default since the 2026-05-15 PR #101 change.
- **Ordinal-probit traits in mixed-family fits** trigger a warning
  (`class = "gllvmTMB_auto_residual_ordinal_probit_overcount"`)
  because the probit latent residual is already 1 by construction;
  the auto path over-counts. Users should set `link_residual =
  "none"` for clarity.

### Status

The mixed-family API surface is `claimed` end-to-end. Phase 0B
slice M1.x and M2.x verify per-family extractor behaviour on
mixed-family fits. Until then, `extract_correlations(fit,
link_residual = "auto")` on a `family = list(...)` fit is a
**promissory note**, not a guarantee.

## Design principles

1. **No family without simulation tests.** AGENTS.md Design Rule
   #1. Adding a family means simulating from known parameters,
   fitting the new family, and confirming recovery.
2. **No likelihood parameterisation change without the
   `tmb-likelihood-review` skill.** AGENTS.md Design Rule #4.
3. **`mu` is always the location parameter.** Other parameter
   names are family-specific.
4. **Link residual is the gllvmTMB-specific slot.** Every family
   declares its `link_residual_rule`. The 15 well-known cases
   above are formal; novel families need a derivation.
5. **Mixed-family is per-trait or per-row, not per-cell.** A
   single observation $(unit, trait)$ has exactly one family.
6. **No family is shipped just because it exists elsewhere.**
   Families should serve a clear multivariate-GLLVM use case in
   ecology, evolution, or environmental sciences.

## What this registry does NOT include (yet)

These are family-related directions captured for the roadmap but
NOT in the registry today:

- **Mixed-family fits combining a delta/hurdle family with another
  family** — e.g. `family = list(gaussian, delta_lognormal)` is
  **not a supported configuration in 0.2.0**. `check_auto_residual()`
  rejects these with `class = "gllvmTMB_auto_residual_delta_undefined"`
  (planned safeguard; Phase 0B writes the test). Reason: the
  latent-scale correlation contract is undefined for two-stage
  families (see "Hurdle / delta families" section above).
- **Latent-scale correlations on single-family delta fits** —
  even a fit with `family = list(delta_lognormal, delta_lognormal)`
  has no defined per-row link residual. Deferred to post-CRAN.
- **Zero-inflated count families on multi-trait fits** (planned;
  post-CRAN). Single-trait zero-inflated count via the delta-*
  hurdle path is in the engine but its multi-trait correlation
  surface is `planned (post-CRAN)` for the same two-scales reason
  as the delta families.
- **Skew-normal / skew-t** for skewed continuous-response
  modelling (planned; post-CRAN).
- **Compound Poisson-Gamma direct parameterisation** (the Tweedie
  `1 < p < 2` case is the existing path; a direct `cp_gamma`
  family is planned).
- **Custom user-supplied likelihood** via a `family_custom()`
  hook (reserved; would require a careful TMB-side density
  contract).

## Cross-references

- `docs/design/00-vision.md` — "What makes gllvmTMB different"
  item 5: latent-scale correlations on mixed-family fits.
- `docs/design/01-formula-grammar.md` — formula-grammar contract;
  `family = ...` argument; `family = list(...)` for mixed-family.
- `docs/design/03-likelihoods.md` (forthcoming, Phase 0A step 3b)
  — per-family TMB likelihood code; numerical scales; parameter
  constraints; stability notes.
- `docs/design/06-extractors-contract.md` (forthcoming, Phase 0A
  step 6) — what each `extract_*()` returns per family.
- `docs/design/35-validation-debt-register.md` (forthcoming,
  Phase 0A step 7) — every `claimed` family row above gets a
  corresponding register row with evidence column.
- `R/extract-sigma.R:99–280` — `link_residual_per_trait()`
  function that computes the per-row link residual.
- `R/fit-multi.R` — `family_var` column logic for mixed-family
  fits.
- `R/families.R` (or per-family `R/family-*.R`) — the constructor
  functions named in the tables above.
- `docs/design/83-multinomial-response-family.md` — baseline-category logit /
  softmax response family; Tier 1 fixed-effects-only scope and the Tier 2
  latent-correlation deferral.
- AGENTS.md Design Rules #1 and #4 — bind family-addition and
  likelihood-parameterisation changes to this registry.

## Persona-active engagement on this registry

- **Gauss** owns the link-residual contract (the trigamma / variance
  formulas per family) and the TMB-side density-id integer mapping.
- **Boole** owns the family constructors' R signatures + `dpars`
  declarations.
- **Fisher** reviews the family-specific inference semantics
  (what does `confint()` return per family; per-family profile-CI
  validity).
- **Emmy** reviews the S3 dispatch surface (`predict()`,
  `simulate()`, `fitted()`, `residuals()` per family).
- **Noether** audits the math-vs-implementation alignment for
  every new family before merge.
- **Curie** writes the simulation-recovery tests per family
  (AGENTS.md Rule #1).
- **Jason** scouts new families against the published literature
  (is this family novel or replicating existing software?).
- **Rose** audits the public scope statements ("nbinom2 is
  `claimed`; truncated_nbinom1 / mixture / gengamma constructors are
  blocked constructor-only; multinomial is in progress, fixed-effects-only per
  Design 83 — its $K-1$-dimensional latent-scale correlation surface is Tier 2,
  deferred and must never be advertised") for honesty.
- **Ada** ratifies the per-family status when Phase 0B verifies
  evidence.
