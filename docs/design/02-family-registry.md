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
| Zero-inflated Poisson | `zi_poisson()` | `mu`, `zi` | log, logit | $\{0, 1, 2, \ldots\}$ | partial (FAM-21) |
| Zero-inflated NB2 | `zi_nbinom2()` | `mu`, `sigma`, `zi` | log, log, logit | $\{0, 1, 2, \ldots\}$ | partial (FAM-22) |
| Zero-inflated binomial | `zi_binomial()` | `mu`, `zi` | logit, logit | $\{0, 1, \ldots, n_\text{trials}\}$, $n_\text{trials} \ge 2$ for at least one row per trait | partial (FAM-23) |

**Zero-inflated families (FAM-21/22/23, Arc D).** `zi_poisson()`,
`zi_nbinom2()`, and `zi_binomial()` are TRUE zero-inflation mixtures
(Design 62 reserves `zi_*` for exactly this): the count process is active
at every observation, including $y = 0$, unlike the hurdle/delta families
below whose positive-part likelihood is simply absent there. The
structural-zero probability `zi` is per-trait and intercept-only --
$\text{logit}(\text{zi}_t)$, no covariates and no random effects on the
zero part -- while the count part (`mu`, and `sigma` for `zi_nbinom2`)
carries the full grammar: fixed effects, `latent()`, and every covariance
tier, with correlations reported on the count-process scale conditional on
the non-structural component. `zi_nbinom2` reuses the ordinary per-trait
`nbinom2()` dispersion convention rather than a shared scalar across
traits. Laplace estimation only: `integration = "va"` and
`estimator = "mspl"` both refuse these three family ids with a named
reason; `aghq` DECLINES to a plain Laplace fit with a warning instead of
erroring (AGHQ's whole eligibility chain declines rather than refuses for
every ineligible model -- e.g. `multinomial()` rows get the identical
treatment -- so this is consistent with AGHQ's existing architecture, not
a zi-specific gap; corrected 2026-09-02, review R3). `zi_binomial()` refuses single-trial (0/1) response data (the
mixture is not identified there) and names plain `binomial()` as the
working alternative. Evidence: exact TMB-vs-hand-density identity (1e-8),
a finite-difference gradient check, and a known-DGP recovery test per
family -- see `dev/gapclose/arcD/D1-report.md` and
`docs/design/35-validation-debt-register.md` FAM-21/22/23.

### Ordinal families

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Ordinal probit | `ordinal_probit()` | latent `mu`, `cutpoints` (vector) | probit (latent), identity (cutpoints on log-difference scale) | $\{1, 2, \ldots, K\}$ ordered categories | claimed |

### Unordered categorical (multinomial) families

**Current status (2026-08-16; supersedes the 2026-07-21 wording below and the
historical Tier-1-only wording in Design 83).** Fixed-effect recovery for one
unordered categorical trait is **covered** (FAM-20). The Design 123 arc
(Slices 1-4, 2026-08-16) admitted a bounded structured-term surface on top of
that -- MOST cells gated on a signed recovery campaign rather than
construction alone, with one explicit exception noted below: the among-category phylogenetic/relatedness surface in all three
modes (`phylo_latent()`/`animal_latent()`/single-name `kernel_latent()`
loadings-only; `phylo_dep()`/`animal_dep()`/`kernel_dep()` full unstructured
$V$; `phylo_indep()`/`animal_indep()`/`kernel_indep()` diagonal $V$), the
spatial (SPDE) mode axis (`spatial_latent()`/`spatial_indep()`/
`spatial_dep()`), a generic `(1 | group)` random intercept, and the
non-phylogenetic `cluster`/`cluster2` diagonal tier. **The honest evidence:**
the one-categorical-draw-per-species recovery gate FAILED for the entire
phylogenetic/relatedness surface (rail rates 8/20 against a 6/20 threshold);
a pre-registered replication rescue (five draws per species) PASSED for the
loadings-only and full-$V$ cells but is untested for the diagonal-$V$ cell,
whose corrected rerun independently FAILED (small-variance collapse --
7/20 seeds collapse to numerical zero despite convergence = 0 and a PD
Hessian, undetected by any current diagnostic -- and a
failed planted-zero check). The spatial surface and the `(1 | group)`
route both PASSED their signed gates outright, no replication needed --
**but the cluster/cluster2 diagonal tier is admitted with
CONSTRUCTION-level evidence only** (the fit constructs, `extract_Sigma()`
returns a well-formed diagonal); it was NOT part of the `(1 | group)`
campaign and its recovery axis remains open (`partial`). `phylo_scalar()`/`animal_scalar()`/`kernel_scalar()`/`spatial_scalar()` and
`common = TRUE` at the cluster/cluster2 tier are REFUSED, not merely
deferred -- a shared-level collapse across the $K-1$ contrasts has no
interpretable null. See `docs/design/123-multinomial-structured-surface.md`
for the complete per-cell table and every number, and
`docs/design/35-validation-debt-register.md`'s FAM-20A-F rows for the
register statements.

**Prior status (2026-07-21), still accurate as far as it goes.** Two
deliberately narrow Tier-2 routes were **partial**:
`phylo_latent()` reports the $(K-1)\times(K-1)$ among-category phylogenetic
covariance $V$, and an ordinary shared `latent()` block may connect one
multinomial trait to other families through its $K-1$ contrast pseudo-traits.
Neither route turns the nominal response into one scalar correlation: reporting
keeps the contrast block explicit. The phylogenetic V route is data-hungry (now
quantified above: one draw per species does not identify $V$, five does); the
ordinary cross-family route permits one multinomial trait per fit and rejects
unsupported tiers before TMB construction.

The softmax link residual is the fixed matrix $(\pi^2/6)(I+J)$ on each contrast
block and is applied at extraction time by
`extract_Sigma(..., link_residual = "auto")`; it is not a fitted phylogenetic
diagonal. For the ordinary FAM-20B route, `latent()` may retain its default
`Psi` for identified partner traits, but the current engine maps off the
multinomial contrast diagonal. That term is not identified with one categorical
draw per unit; replication can identify it in principle, but the current
conservative implementation still suppresses it. An explicit multinomial
`unique()` or `indep()` term remains fenced. Point extraction and
target-specific Wald/bootstrap plumbing belong to FAM-20B only; their interval
calibration is not covered and nonlinear profile requests are withdrawn with a
typed refusal.

| Family | R constructor | `dpars` | Links | Bounds | Status |
|--------|---------------|---------|-------|--------|--------|
| Multinomial | `multinomial()` | `mu` ($K-1$ baseline-category linear predictors) | baseline-category logit (softmax) | $\{1, \ldots, K\}$ unordered categories | covered fixed-effect route; partial, campaign-gated phylogenetic/relatedness, spatial, and group-intercept structured routes (Designs 83, 84, 122) |

**Historical scope note (Design 83, superseded 2026-07-21).** This originally
admitted fixed-effect recovery only. The current allow-list is the one stated
above: fixed effects, a narrow `phylo_latent()` V route, and a narrow ordinary
shared-`latent()` cross-family route. Name: `multinomial()` (not
`categorical()`, which is the unordered missing-**predictor** imputation family,
Design 68). Julia parity is a separate later arc.

**Admission is enforced by a two-stage fence (Slice 0, Design 108/123,
2026-08-16).** `dep()`, explicit multinomial `unique()`/`indep()`, slopes,
spatial/animal/kernel tiers, the `cluster`/`cluster2`/`unit_obs` grouping
tiers, generic `(1 | group)` random intercepts, and `mi()` predictor terms
were all deferred at Slice 0 and genuinely fail loud when combined with a
`multinomial()` trait unless separately admitted below. Historically this was **not** true: several of these
keywords desugar (`R/brms-sugar.R`) onto the same engine flag as an admitted
keyword -- `dep()` at the unit tier, `phylo_dep()`, `phylo_indep()` /
`phylo_unique()` (standalone), and `animal_latent()` all folded onto the
same `use_*` flag as an admitted term, single-name `kernel_*()` folded onto
`phylo_latent()`'s flag, and `phylo_scalar()` / `animal_scalar()` were
explicitly exempted from the old allow-list scan -- so those specific
combinations silently reached an untested categorical path instead of
erroring. `R/multinomial-fence.R` closes this: an early covstruct-keyed
classifier reads the raw parser markers before that flag-level folding
happens (so keywords sharing a flag with an admitted term are still told
apart), and the late `use_*` re-scan is kept as belt-and-braces, moved past
every `use_*` flag in `gllvmTMB_multi_fit()` (including the `mi()`
predictor flags, which were previously defined after the old scan and so
were invisible to it), with the `use_propto` exemption removed.

**Adversarial-review repair (2026-08-16, same day).** An Opus review of the
fence above found it was not yet load-bearing everywhere. `phylo_latent()`
is admitted intercept-only with its default `unique = FALSE` (no Psi
companion emitted at all); `phylo_latent(..., unique = TRUE)` (a free
phylogenetic Psi) is explicitly **not** admitted, and the fence's first
pass had wrongly classified it as admitted (the late re-scan already
caught it via a different flag, so this was a documentation/classifier
contradiction rather than a live leak). Augmented (intercept + slope)
`latent(1 + x | unit)` and `phylo_latent(1 + x | species)` random
regressions reuse the same covstruct kind as their intercept-only admitted
forms with no `.dep`/`.phylo_unique` marker set, so the early classifier's
first pass fell through to admitted for both; the ordinary-`latent()` case
was still caught by the untyped late re-scan, but the `phylo_latent()` case
was caught by neither fence pass -- an unrelated per-family
augmented-slope-support gate happened to abort first. Both are now
classified blocked directly. `meta_V()` / `equalto()` (known
sampling-covariance) was blanket-exempted in both passes alongside
`propto()`; it is now fail-closed by default, since no route is
established for it on a categorical-contrast pseudo-trait. Both fence
passes now share one classed condition,
`gllvmTMB_multinomial_structured_not_admitted`.

### Hurdle / delta families

**Status:** the standard `delta_lognormal()` and `delta_gamma()` routes are
admitted for fixed-effect recovery tests. Other exported delta
constructors remain compatibility constructors only and must fail loudly until
likelihood wiring, recovery tests, and the mixed-family latent-scale correlation
contract are all defined.

These two-stage families combine a binary occurrence component
(`hu` = hurdle probability) with a positive-continuous component.
The `delta_*` prefix matches the `sdmTMB` convention.

**Source correction (2026-08-25; supersedes the positive-part-only wording
recorded on 2026-07-05).** The native likelihood does not have a separate
occurrence predictor. It sends the same linear predictor `eta` to both delta
components. For the currently implemented families,

\[
\Pr(Y_{it}>0\mid u_i)=\operatorname{logit}^{-1}(\eta_{it}),
\qquad
\eta_{it}=\beta_t+\lambda_tu_i,
\]

and the positive-part log mean uses that same `eta`. Thus an ordinary
predictor-informed latent effect
\(B_{lv,t}=\lambda_t\alpha\) is one constrained coefficient that acts
simultaneously on occurrence log-odds and positive-part log mean. It is not a
positive-part-only effect and it is not an unconditional response-mean effect.
The compiled family-ID 12/13 likelihoods and the public family help are the
source of truth for this contract.

The bounded family-wide LV evidence covers this shared-`eta` model only for
native ML, rank one, ordinary unit tier, `unique = FALSE`, complete responses,
one numeric LV predictor, and `link_residual = "none"`. In that scope the
rotation-invariant covariance target is the shared loading covariance
`Lambda %*% t(Lambda)`; no diagonal Psi or occurrence/positive-part residual
correlation is added. The positive-part scale/dispersion remains an observation
parameter, not a second shared LV covariance. Response-scale marginal effects,
automatic delta link residuals, separate occurrence and positive-part
predictors, masks, higher ranks, and structured tiers require separate
derivation and evidence.

Earlier notes also said cross-family correlation on a delta mixed-family fit
was rejected by `check_auto_residual()`. That was inaccurate:
`check_auto_residual()` is an exported manual diagnostic, is not invoked by
`gllvmTMB()` or the extractors, and only aborts within-trait family mixing
(class `gllvmTMB_auto_residual_incoherent`). There is no
`gllvmTMB_auto_residual_delta_undefined` class.

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

- **Broader mixed-family delta fits and automatic link residuals.** The bounded
  predictor-informed LV programme admits only its named complete-response,
  rank-1, loadings-only Gaussian + delta-lognormal and Gaussian + delta-Gamma
  cells, with `link_residual = "none"` and the shared-`eta` interpretation
  above. It does not establish arbitrary delta mixtures, default `+ Psi`,
  response masks, response-scale marginal effects, or an automatic per-row
  delta link residual.
- **Zero-inflated count families are now in the engine** (`zi_poisson()`,
  `zi_nbinom2()`, `zi_binomial()`; FAM-21/22/23, Arc D) -- see the Count
  families table above. This supersedes the earlier "planned; post-CRAN"
  note here, which described a different, since-abandoned idea (routing
  zero-inflation through the delta/hurdle path); Design 62 clarified that
  the delta/hurdle families have no second zero source and are not
  zero-inflation at all, and the families actually built are a TRUE
  mixture with a single count-process scale, so they do not carry the
  delta families' two-scales latent-structure restriction (Decision 2
  above): `latent()` and the full covariance grid apply to the count part
  directly. What remains `partial`, not `covered`: no calibrated interval
  on `zi`; VA and MSPL refuse (Laplace only); AGHQ declines to Laplace with a warning rather than refusing.
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
  softmax response family; historical Tier-1 decision record and the current,
  bounded Tier-2 allow-list.
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
- **Rose** audits the public scope statements (for example: nbinom2 is
  `claimed`; truncated_nbinom1 / mixture / gengamma constructors are blocked
  constructor-only; multinomial fixed-effect recovery is FAM-20 `covered`,
  while FAM-20A/FAM-20B are narrow `partial` routes and every unlisted
  categorical covariance surface remains blocked) for honesty.
- **Ada** ratifies the per-family status when Phase 0B verifies
  evidence.
