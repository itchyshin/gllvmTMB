# Likelihoods

**Maintained by:** Gauss (TMB likelihoods + numerical stability)
and Noether (math-vs-implementation alignment).
**Reviewers:** Fisher (statistical inference semantics), Boole
(family API consistency).

Likelihoods are implemented in the TMB template at
`src/gllvmTMB.cpp` and called from R wrappers in `R/fit-multi.R`.
This document is the per-family likelihood contract: what the
density looks like on the link scale, what the numerical scales
are, what boundary cases are tested, and what comparator alignment
holds.

**Status discipline**: this doc uses the 4-state vocabulary from
`docs/design/01-formula-grammar.md` (`covered / claimed / reserved
/ planned`). Most per-family rows are currently `claimed`; Phase
0B verification walks them to `covered` with test-file evidence.
This doc grows as families validate — early sections will be terse,
mature sections will be thorough (drmTMB's `03-likelihoods.md` is
the structural reference; ours follows the same pattern at a
younger stage of development).

## Parameter Scales

- Positive parameters use log links.
- Unit-interval parameters use logit links.
- Bounded shape parameters (e.g. Tweedie $p \in (1, 2)$) use
  guarded transforms (e.g. logit on $(p - 1)$).
- Residual correlations use a Fisher-z-like linear predictor and
  a guarded `0.99999999 * tanh()` response transform.
- Phylogenetic / spatial loading matrices use the
  `glmmTMB::rr()`-style triangular-with-positive-diagonal
  reparameterisation (McGillycuddy et al. 2025).

## Variability Orientation

The public scale slot is `sigma` when the parameter controls
modelled variability. The user-facing orientation is:

```text
larger sigma -> larger variability, dispersion, or heterogeneity
```

This is a user-interface contract, not a claim that every
likelihood is written with a standard deviation parameter
internally. Some likelihoods are naturally expressed with
precision or size parameters; in those cases the TMB objective
uses a transformed internal quantity, but extractors and tutorials
report the public `sigma` direction unless a comparator check
explicitly needs the original parameterisation. Matches the
drmTMB convention.

| Family | Public scale | Internal scale | Direction |
|--------|--------------|----------------|-----------|
| `gaussian()` | `sigma` | residual SD | larger `sigma` ⇒ larger residual variance |
| `Gamma(link = "log")` | `sigma` | shape $1/\sigma^2$ | larger `sigma` ⇒ larger coefficient of variation |
| `Beta()` | `sigma` | precision $\phi = 1/\sigma^2$ | larger `sigma` ⇒ lower precision, larger variance |
| `betabinomial()` | `sigma` | precision $\phi = 1/\sigma^2$ | larger `sigma` ⇒ more extra-binomial variation |
| `nbinom1()` | `sigma` | size $\theta$ scaled by $\mu$ | larger `sigma` ⇒ more linear-mean overdispersion |
| `nbinom2()` | `sigma` | size $\theta = 1/\sigma^2$ | larger `sigma` ⇒ more quadratic-mean overdispersion |
| `student()` | `sigma`, `nu` | scale + d.o.f. | larger `sigma` ⇒ wider core; larger `nu` ⇒ lighter tails |
| `lognormal()` | `sigma` | SD of $\log y$ | larger `sigma` ⇒ wider distribution of $y$ |

## Notation

In mathematical prose, $\mathcal{N}(a, b)$ uses variance as the
second argument. The corresponding R density call uses standard
deviation: `dnorm(y, mean = a, sd = sqrt(b), log = TRUE)`. Matches
the drmTMB convention.

## Multi-trait stacking (gllvmTMB-specific)

`gllvmTMB`'s engine evaluates the likelihood **per row** of the
long-format data. Each row carries a `(unit, trait)` index plus
optional `(cluster, unit_obs)` indices and a per-row `family_var`
factor when the fit is mixed-family.

The joint log-likelihood is

$$
\log L(\theta) = \log \int \left( \prod_{i=1}^{N} f_{i}(y_i \mid \mu_i, \phi_i; \theta_y) \right) \, p(u \mid \theta_u) \, du
$$

where:

- $i$ indexes long-format rows; $N$ is the total number of
  observations across all `(unit, trait)` cells.
- $f_i$ is the density for row $i$, dispatched by the family
  assigned to that row (single family per fit → all rows; mixed
  family → per-row via `family_var`).
- $\mu_i = g^{-1}(\eta_i)$ is the link-scale mean for row $i$;
  $\phi_i$ is the family's dispersion / shape parameter (if any).
- $u$ collects all latent variables (between-unit `latent()` and
  `unique()` random effects; within-unit `latent()` /
  `unique()`; phylogenetic, spatial, and `meta_V()` blocks).
- $\theta_u$ collects the variance / loading / precision
  parameters governing $p(u)$.
- The integral is evaluated by the Laplace approximation
  (TMB's `MakeADFun(random = ...)`).

The per-row structure is what makes mixed-family + multi-trait
work: TMB iterates over rows, dispatches to the family-specific
density, accumulates the log-likelihood, and then Laplace-
approximates the integral over the random-effects block.

## Mixed-family per-row routing

When `family = list(f_1, f_2, ..., f_T)` is passed, `R/fit-multi.R`:

1. Verifies the list length matches the number of trait levels.
2. Builds a per-row `family_var` factor that maps each row to its
   family (the trait factor + the list position).
3. Verifies within-trait family coherence: every row sharing the
   same `trait` level uses the same family. `check_auto_residual()`
   errors with `class = "gllvmTMB_auto_residual_incoherent"` if not.
4. Passes the per-row family code to `src/gllvmTMB.cpp` as an
   integer column in the data block. The TMB template
   dispatches at the row level via a `switch` on this code.
5. Rejects configurations that include a delta/hurdle family in
   a mixed-family fit (see `docs/design/02-family-registry.md`
   "Hurdle / delta families — DEFERRED to post-CRAN").

## Random-effects integration

The latent-variable block $u$ is integrated out via Laplace. The
default control is `gllvmTMBcontrol(integration = "laplace")`;
no other integrator is supported in 0.2.0 (the audit-2 "stay
Laplacian" decision; see
`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`).

The random-effects block decomposes as:

- **Reduced-rank** factor scores from `latent(0 + trait | g, d = K)`:
  $\Lambda \in \mathbb{R}^{T \times K}$ on the loadings,
  $\mathbf{u} \in \mathbb{R}^{n_g \times K}$ on the scores, with
  $\mathbf{u}_\ell \sim \mathcal{N}(0, I_K)$ per group level
  $\ell$. The trait-by-row contribution is $\eta_{it} = \mu_{it}
  + \boldsymbol\lambda_t^\top \mathbf{u}_{g(i)}$ on the link scale.

- **Trait-unique diagonal** from `unique(0 + trait | g)`:
  $\boldsymbol\Psi = \text{diag}(\psi_1^2, \ldots, \psi_T^2)$
  per-trait variance terms; trait-specific per-level deviations
  $\mathbf{v}_t \sim \mathcal{N}(0, \psi_t^2)$.

- **Compound-symmetric `indep(0 + trait | g)`** and unstructured
  **`dep(0 + trait | g)`** terms parameterise the trait
  covariance directly (no rank reduction). Internal scales: log
  on diagonals, atanh on the (single) off-diagonal correlation
  for `indep`; full Cholesky on `dep`.

- **Scalar `(omit) ↔ no trait-specific term`** contributes the
  correlation-source structure to the linear predictor but no
  trait-specific component.

The phylogenetic and spatial keywords plug into the same
random-effects machinery via the correlation-source rows of the
3 × 5 grid (see `docs/design/01-formula-grammar.md`).

### Laplace accuracy caveat

The Laplace approximation can be inaccurate on **hyper-sparse
binary** data (rare-species detections, very few items per
person at extreme difficulty). `gllvmTMB_check_consistency()`
(PR #121) tests whether the marginal score is centred at zero;
non-centred score flags Laplace unreliability. See
`docs/design/05-testing-strategy.md` (forthcoming) for the
Phase 0B per-family Laplace-accuracy verification plan.

## Phylogenetic A⁻¹ sparse integration

When `phylo_*(species, vcv = Cphy)` or `phylo_*(species, tree = ape::phylo)`
is in the formula, the species-level random effects use the
sparse-precision representation of Hadfield & Nakagawa (2010):

$$
p(\mathbf{a} \mid \sigma^2_\text{phy}, A) = \mathcal{N}(\mathbf{a}; \mathbf{0}, \sigma^2_\text{phy} \, A)
$$

where $A$ is the phylogenetic correlation matrix derived from the
tree. The sparse $A^{-1}$ is computed once on the R side and
passed to TMB as a sparse precision matrix. TMB uses sparse
Cholesky for the marginal-likelihood Hessian. Status: `claimed`;
Phase 0B verifies via a phylo-trait simulation-recovery test.

## SPDE / GMRF spatial integration

When `spatial_*(0 + trait | sites, mesh = mesh)` is in the
formula, the spatial random field is approximated by the
Lindgren-Rue-Lindström (2011) SPDE construction inherited from
`sdmTMB` (Anderson et al. 2025). The precision matrix is built on
the mesh nodes:

$$
Q = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2
$$

where $M_0$, $M_1$, $M_2$ are the finite-element mass / stiffness
matrices, and $\kappa = \sqrt{8}/\text{range}$ is the inverse-
range parameter. Mesh nodes' field values are linearly
interpolated to observation locations via a sparse projection
matrix $A_{n \times n_\text{mesh}}$. Status: `claimed`; Phase 0B
verifies via a single-trait sdmTMB cross-comparison.

## `meta_V()` additive sampling-covariance contribution

When `meta_V(value, V = V)` is in the formula, the likelihood
adds a known-covariance residual term:

$$
\mathbf{y} = X\boldsymbol\beta + Z\mathbf{u} + \boldsymbol\varepsilon, \quad
\boldsymbol\varepsilon \sim \mathcal{N}(\mathbf{0}, V + \sigma^2 I)
$$

where $V$ is supplied as the `known_V = V` argument to
`gllvmTMB()`. The desugaring is documented in
`docs/design/01-formula-grammar.md`. Internally: TMB evaluates the
multivariate normal density with covariance $V + \sigma^2 I$ via
a sparse or dense Cholesky depending on $V$'s structure (block-
diagonal via `block_V()` → sparse; full → dense). Status:
`claimed`; Phase 0B verifies via comparison to `glmmTMB::equalto()`
on a shared fixture (the `tests/testthat/test-stage3-propto-equalto.R`
agreement contract).

## Link-residual computation for mixed-family correlations

The package's headline differentiator (vision item 5) is that
`extract_correlations(fit, link_residual = "auto")` reports
trait correlations on the **latent liability scale** for mixed-
family fits. The computation is:

```r
# Pseudocode -- actual implementation in
# R/extract-sigma.R `link_residual_per_trait()` lines 99-280
Sigma_total <- Sigma_shared + diag(link_residual_per_trait(fit))
R_total     <- cov2cor(Sigma_total)
```

The per-family link-residual values are tabulated in
`docs/design/02-family-registry.md` "Link Residual Contract".
The math: for each row $i$ with family $f_i$, the latent-scale
residual variance $\sigma^2_{d, i}$ is added to the diagonal of
the implied trait covariance before correlation conversion.

**Boundary case** (`check_auto_residual()` safeguards):

- **Within-trait family mixing**: rejected; each trait must
  have a single family across all rows.
- **Ordinal-probit traits in `link_residual = "auto"` path**:
  warned; the probit latent residual is already $1$ by
  construction, so the auto path over-counts. Users should set
  `link_residual = "none"` for clarity. See PR #104.
- **Delta/hurdle families in mixed-family fits**: rejected; the
  two-scales problem (see `02-family-registry.md`). Planned
  safeguard `class = "gllvmTMB_auto_residual_delta_undefined"`.

## Per-family likelihood subsections

Each subsection follows this template (drmTMB's per-family pattern,
adapted for multi-trait):

1. **Status**: `covered / claimed / reserved / planned`
2. **Native parameters and links**
3. **TMB template path**: `src/gllvmTMB.cpp` line range
4. **R constructor**: `R/families.R` reference
5. **Density**: the mathematical form
6. **Numerical-stability notes**: what's on log/logit/atanh; what
   floors / ceilings are applied
7. **Boundary cases tested** (or **planned**)
8. **Comparator-test alignment**: which independent calculation
   the likelihood matches (e.g. `stats::dpois`,
   `glmmTMB::glmmTMB`, `MASS::glm.nb`)
9. **Test file path** (when present)

Subsections currently abbreviated (Phase 0B will fill them in as
verification runs):

### Gaussian

- Status: `claimed`
- Parameters: `mu` (identity), `sigma` (log).
- TMB template: `src/gllvmTMB.cpp` (verify in Phase 0B).
- Density: $y_i \sim \mathcal{N}(\mu_i, \sigma^2)$.
- Boundary cases planned: small `sigma`, large random-effects
  variance, unbalanced groups.
- Comparator: `glmmTMB::glmmTMB(..., dispformula = ~ 1, family =
  gaussian())` for the homoscedastic case. Reduced-rank
  comparator: `glmmTMB::glmmTMB(..., y ~ rr(0 + trait | g, d = K)
  + diag(0 + trait | g))` (the McGillycuddy 2025 path).
- Test file: `tests/testthat/test-stage2-rr-diag.R` (verify
  scope in Phase 0B).

### Binomial

- Status: `claimed`.
- Parameters: `mu` (logit, probit, or cloglog).
- Multi-trial via `cbind(succ, fail)` response or `weights` /
  `binomial_size` column (Phase 0B verifies which).
- Density: $y_i \sim \text{Binomial}(n_i, \mu_i)$.
- Numerical: logit on $\mu$ is the default; probit available for
  ordinal-probit cross-family fits; cloglog for asymmetric
  occurrence patterns.
- Comparator: `stats::glm(family = binomial())`; analytic match
  for the link-scale linear-predictor calculation.

### Beta-binomial

- Status: `claimed`.
- Parameters: `mu` (logit), `sigma` (log; internal $\phi = 1/\sigma^2$).
- Density: beta-binomial via beta-mixture-of-binomials closed form.
- Numerical: clamp $\mu$ at $[10^{-6}, 1 - 10^{-6}]$ before
  forming trigamma arguments (the Gauss correctness flag from
  the 2026-05-15 audit).

### Poisson

- Status: `claimed`.
- Parameters: `mu` (log).
- Density: $y_i \sim \text{Poisson}(\mu_i)$.
- Comparator: `stats::dpois`; `stats::glm(family = poisson(link = "log"))`.

### Negative binomial 2

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log; internal $\theta = 1/\sigma^2$).
- Density: NB2 with quadratic-mean variance
  $\text{Var}(y) = \mu + \mu^2 \sigma^2$.
- Numerical: count-kernel hardening (the Phase 6d count-kernel
  fix; see if it's needed here too — Phase 0B verifies).
- Comparator: `stats::dnbinom`; `MASS::glm.nb` for the constant-
  dispersion case.

### Negative binomial 1

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log).
- Density: NB1 with linear-mean variance
  $\text{Var}(y) = \mu(1 + \sigma)$.
- Comparator: `stats::dnbinom`; `glmmTMB::glmmTMB(family = nbinom1())`.

### Truncated Poisson / NB1 / NB2

- Status: `claimed`.
- Parameters: same as the untruncated counterparts.
- Density: zero-truncated; positive-count normalising constant
  $-\log(1 - \Pr(0))$ added per row.

### Censored Poisson

- Status: `claimed`.
- Interval-censored Poisson observations; supports right-/left-
  /interval-censoring.

### Gamma

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log; internal shape
  $\alpha = 1/\sigma^2$, rate $\beta = \alpha / \mu$).
- Density: Gamma with mean-CV parameterisation.
- Comparator: `stats::dgamma`; `stats::glm(family = Gamma(link
  = "log"))` for the mean coefficients (note: base GLM and
  gllvmTMB estimate the Gamma dispersion differently; the test
  checks coefficients, not residual scale).

### Generalised Gamma

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log), `nu` (log; tail shape).
- Density: three-parameter generalised Gamma; reduces to Gamma
  when $\nu = 1$, lognormal as $\sigma \to 0$, Weibull as
  $\nu = \sigma$.

### Beta

- Status: `claimed`.
- Parameters: `mu` (logit), `sigma` (log; internal $\phi = 1/\sigma^2$).
- Density: $y_i \sim \text{Beta}(a_i, b_i)$ with
  $a_i = \mu_i \phi$, $b_i = (1 - \mu_i) \phi$.
- Numerical: clamp $\mu$ at $[10^{-6}, 1 - 10^{-6}]$ before
  forming trigamma arguments (the Gauss correctness flag).
- Comparator: `stats::dbeta` with $\phi = 1/\sigma^2$.

### Student-t

- Status: `claimed`.
- Parameters: `mu` (identity), `sigma` (log), `nu` (logm2;
  $\nu = 2 + \exp(\eta_\nu)$).
- Density: scale-location Student-$t$ with $\nu > 2$ for finite
  variance.

### Lognormal

- Status: `claimed`.
- Parameters: `mu` (identity, on the log-$y$ scale), `sigma`
  (log; SD of $\log y$).
- Density: $y_i \sim \text{Lognormal}(\mu_i, \sigma^2)$;
  equivalently $\log y_i \sim \mathcal{N}(\mu_i, \sigma^2)$.

### Lognormal mixture / Gamma mixture / NB2 mixture

- Status: `claimed`.
- Two-component mixture: $\mu_1, \sigma_1$ and $\mu_2, \sigma_2$
  with mixture weight $w \in (0, 1)$ via logit.

### Ordinal probit

- Status: `claimed`.
- Parameters: latent `mu` (identity; the underlying continuous
  liability), `cutpoints` (vector; ordered).
- Density: $\Pr(y_i = k) = \Phi(c_k - \eta_i) - \Phi(c_{k-1} - \eta_i)$.
- Numerical: latent residual variance fixed at $1$ by
  construction; cutpoints estimated on log-difference scale to
  preserve ordering. Mode-fixing convention via `extract_cutpoints()`.

### Tweedie

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log; dispersion $\phi$),
  `p` (logitp; $1 < p < 2$).
- Density: compound Poisson-Gamma with $\Pr(y = 0) > 0$ and
  continuous-positive for $y > 0$.

### Delta / hurdle families

**Status: `planned (post-CRAN)`** — see
`docs/design/02-family-registry.md` "Hurdle / delta families —
DEFERRED to post-CRAN" for the two-scales rationale. The engine
has the constructors and densities; the deferral is to the
public-API surface (latent-scale correlations across delta and
other families is not yet defined).

## Boundary conditions and edge cases

The Phase 0B verification campaign tests these per-family edge
cases (matches drmTMB's required-edge-case list, extended for
the multi-trait case):

- `sigma` small and large.
- `rho` (when present) near $0$, positive, negative, and near
  $\pm 1$.
- Boundary-pinned variance components (e.g. one trait's $\psi^2$
  near zero).
- Factor predictors with unbalanced cell counts.
- Missing data handling (rows with NA dropped; entire-trait
  missingness rejected).
- Shape parameters near weak-identification regions (Student-t
  `nu` near $2$; Tweedie `p` near $1$ or $2$).
- Multi-trait combinations: 2 traits, 5 traits, 20 traits; ranks
  $K = 1, 2, 3$.
- Mixed-family combinations: `list(gaussian, binomial)`;
  `list(gaussian, binomial, poisson, Gamma)`; per-trait
  family-list length mismatches rejected.

## Cross-references

- `docs/design/00-vision.md` — package vision; item 5 names
  latent-scale correlations across non-delta families.
- `docs/design/01-formula-grammar.md` — formula contract +
  family argument forms.
- `docs/design/02-family-registry.md` — per-family registry
  with link-residual contract.
- `docs/design/04-random-effects.md` (forthcoming) — Laplace
  integration + reduced-rank reparameterisation details.
- `docs/design/05-testing-strategy.md` (forthcoming) — two-tier
  validation (comparator + simulation recovery); per-family
  required edge cases.
- `docs/design/06-extractors-contract.md` (forthcoming) — what
  `extract_*()` returns per family.
- `docs/design/35-validation-debt-register.md` (forthcoming,
  Phase 0A step 7) — evidence ledger; every `claimed` row in
  this doc gets a register row.
- `src/gllvmTMB.cpp` — the actual TMB template.
- `R/fit-multi.R` — R wrapper; per-row family routing;
  `family_var` column logic.
- `R/extract-sigma.R` — `link_residual_per_trait()` at lines
  99-280.
- AGENTS.md Design Rule #1: no family without simulation tests.
- AGENTS.md Design Rule #4: no likelihood parameterisation
  change without `tmb-likelihood-review` skill.

## Persona-active engagement on this doc

- **Gauss** owns the per-family TMB density derivations and
  numerical-stability paragraphs. Validates every new density
  against the `tmb-likelihood-review` skill checklist.
- **Noether** audits the math-vs-implementation alignment for
  every density: does the symbolic equation match what
  `src/gllvmTMB.cpp` evaluates?
- **Fisher** reviews per-family inference semantics: do the CI
  methods work on each family? Per-family profile-CI accuracy?
- **Boole** reviews the family-API surface (constructor names,
  parameter naming, link conventions) for consistency with
  `02-family-registry.md`.
- **Curie** writes per-family simulation-recovery tests and
  comparator smoke tests.
- **Rose** audits the per-family status statements for honesty
  (`claimed` rows must NOT be advertised as features).
- **Ada** ratifies a per-family promotion `claimed → covered`
  when Phase 0B evidence arrives.

## How this doc grows

drmTMB's `03-likelihoods.md` is 1374 lines because they've
validated many families. gllvmTMB's lives at this thinner
stage today, but the **structure mirrors drmTMB exactly** so
that as Phase 0B verifies each family, the per-family
subsections grow with:

- specific TMB template line references,
- explicit numerical-stability annotations,
- comparator-test code paths,
- boundary-case test references,
- comparator results (independent-likelihood matches).

A mature `03-likelihoods.md` at v0.3.x will look much like
drmTMB's today. The path is: write the structure now; let
evidence accumulate; promote claims to covered as it lands.
