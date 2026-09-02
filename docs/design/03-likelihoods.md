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
  `glmmTMB::rr()`-style reduced-rank reparameterisation
  (McGillycuddy et al. 2025): the strict upper triangle is zero,
  which fixes rotation. The **diagonal is unconstrained** -- a
  plain value, no `exp()` and no bound
  (`src/gllvmTMB.cpp:902,909`) -- so the column sign is free.
  Corrected 2026-08-03; this bullet previously said
  "triangular-with-positive-diagonal", which the engine does not
  implement. See `04-random-effects.md` for the consequences.

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
| `Gamma(link = "log")` | `sigma` | per-trait shape $\phi_{\gamma,t} = 1/\sigma_t^2$ | larger `sigma` ⇒ larger coefficient of variation |
| `Beta()` | `sigma` | precision $\phi = 1/\sigma^2$ | larger `sigma` ⇒ lower precision, larger variance |
| `betabinomial()` | `sigma` | precision $\phi = 1/\sigma^2$ | larger `sigma` ⇒ more extra-binomial variation |
| `nbinom1()` | `sigma` | size $\theta$ scaled by $\mu$ | larger `sigma` ⇒ more linear-mean overdispersion |
| `nbinom2()` | `sigma` | size $\theta = 1/\sigma^2$ | larger `sigma` ⇒ more quadratic-mean overdispersion |
| `student()` | `sigma`, `nu` | scale + d.o.f. | larger `sigma` ⇒ wider core; larger `nu` ⇒ lighter tails |
| `lognormal()` | `sigma` | SD of $\log y$ | larger `sigma` ⇒ wider distribution of $y$ |

Gaussian and lognormal scales do not share numerical units. Pure fits retain
the historical length-one `log_sigma_eps` parameter. When the two families
coexist, the native TMB route allocates exactly two slots in fixed order:
Gaussian raw-scale residual SD, then lognormal log-scale residual SD. Each slot
is shared among traits of its own family; this change does not create a
per-trait residual-variance model. The likelihood, simulation, residual-CDF,
prediction, and variance-partition consumers select the slot by family.

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
5. Routes the standard delta families through the same per-row dispatch. Their
   native likelihood uses one shared `eta` for occurrence and positive-part
   log mean. Automatic delta link-residual correlation is not implied by fit
   admission; the bounded predictor-informed LV cells use
   `link_residual = "none"`.

## Random-effects integration

The latent-variable block $u$ is integrated out via Laplace. The
default control is `gllvmTMBcontrol(integration = "laplace")`;
no other integrator is supported in 0.2.0 (the audit-2 "stay
Laplacian" decision; see
`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`).

The random-effects block decomposes as:

### Gaussian restricted likelihood

For the eligible Gaussian linear model, the current REML path integrates the
ordinary fixed-effect block `b_fix` in TMB. With response vector \(y\),
full-rank observed design \(X\), and marginal covariance \(V(\theta)\), the
test oracle is the Patterson--Thompson restricted log likelihood

\[
\ell_R(\theta) = -\tfrac12\{(n-p)\log(2\pi) + \log|V| +
\log|X^\top V^{-1}X| + (y-X\hat\beta)^\top V^{-1}(y-X\hat\beta)\}.
\]

This is exact for the Gaussian path, not a non-Gaussian Laplace analogue.
The engine-admitted contract is all-Gaussian, unweighted data with dropped
responses, a full-rank \(X\) and \(n>p\), and no `mi()`, `Xcoef_fixed`, or
predictor-informed `latent(..., lv = ~ x)` block. The oracle-certified
representatives are an ordinary random intercept and ordinary unit-tier
`indep()`, `dep()`, and rank-1/rank-2 `latent() + Psi`; other covariance tiers
need their own named recovery evidence before a certificate claim.

- **Reduced-rank** factor scores from `latent(0 + trait | g, d = K)`:
  $\Lambda \in \mathbb{R}^{T \times K}$ on the loadings,
  $\mathbf{u} \in \mathbb{R}^{n_g \times K}$ on the scores, with
  $\mathbf{u}_\ell \sim \mathcal{N}(0, I_K)$ per group level
  $\ell$. The trait-by-row contribution is $\eta_{it} = \mu_{it}
  + \boldsymbol\lambda_t^\top \mathbf{u}_{g(i)}$ on the link scale.

- **Predictor-informed latent-score means** from the
  `latent(..., lv = ~ x)` surface (Design 73): for ordinary unit-tier
  fits, the score is split as
  $\mathbf{z}_i = M_i\alpha + \mathbf{e}_i$ with
  $\mathbf{e}_i \sim \mathcal{N}(0, I_K)$. The TMB change is a mean
  shift inside the existing reduced-rank contribution,
  $\eta_{it} = \mu_{it} + \boldsymbol\lambda_t^\top
  (M_i\alpha + \mathbf{e}_i) + q_{it}$. The innovation prior remains
  centred at zero. The default ordinary `latent()` model retains its diagonal
  $\Psi$ companion, but the family-wide named programme cells are explicitly
  rank one and loadings-only (`unique = FALSE`). Current support remains
  partial: R
  validates the `lv` formula, builds unit-level `X_lv_B`, estimates
  `alpha_lv_B`, reports `B_lv_unit`, and tests focused native Gaussian
  recovery plus pure-binomial standard-link trait-scale `B_lv`
  recovery/algebra fits. A retained 19-cell mixed/sentinel r200 campaign adds
  point-recovery evidence for the frozen native ML, rank-1, loadings-only,
  complete-response allow-list: all 3,800 attempts are retained, and the
  cross-fit targets are rotation-invariant `B_lv` and shared
  $\Lambda\Lambda^\top$, not raw axes. That campaign used `se = FALSE`, so it
  supports no interval conclusion. The separate pure r200 passes 17/19 cells;
  pure Beta and ordinal-probit retain HOLDs. Eight preregistered mixed
  Gaussian-anchor cells pass target-wise `B_lv` Wald calibration, without a
  simultaneous-coverage or arbitrary-mixture claim. `REML = TRUE`, unlisted family
  combinations, unsupported tiers, and fixed/LV predictor overlap remain
  rejected until the corresponding validation rows move.

- **Ordinary augmented Gaussian random regression** from
  `latent(0 + trait + (0 + trait):x | unit, d = K)` or the equivalent
  `traits(...)` shorthand `latent(1 + x | unit, d = K)` (RE-12):
  the coefficient vector has
  $C = 2T$ rows ordered as `(intercept, slope) x trait`. The
  shared component uses
  $\Lambda_{\text{aug}} \in \mathbb{R}^{C \times K}$ and unit
  scores $\mathbf{z}_i \sim \mathcal{N}(0, I_K)$. The default
  diagonal Psi companion uses independent unit-level coefficients
  $\mathbf{q}_i \sim \mathcal{N}(0, \Psi_{B,\text{aug}})$, where
  $\Psi_{B,\text{aug}}$ is diagonal with entries
  $\psi_{B,\text{aug},c}^2$. Row-level designs `Z_B_lat` and
  `Z_B_diag` select the trait intercept row with coefficient 1 and
  the matching trait slope row with coefficient $x_i$. The TMB
  template reports `Sigma_B_slope = Lambda_aug Lambda_aug^T`,
  `sd_B_slope`, and `Sigma_B_unique_slope`; the extractor composes
  `part = "total"` as
  $\Lambda_{\text{aug}}\Lambda_{\text{aug}}^\top +
  \Psi_{B,\text{aug}}`. Explicit augmented `unique()` remains
  Gaussian-only compatibility syntax; non-Gaussian augmented diagonal
  Psi remains guarded in this slice.

- **Trait-unique diagonal** from `unique(0 + trait | g)`:
  $\boldsymbol\Psi = \text{diag}(\psi_1^2, \ldots, \psi_T^2)$
  per-trait variance terms; trait-specific per-level deviations
  $\mathbf{v}_t \sim \mathcal{N}(0, \psi_t^2)$.

- **Marginal-only `indep(0 + trait | g)`** and unstructured
  **`dep(0 + trait | g)`** terms parameterise the trait
  covariance directly (no rank reduction). `indep` is the diagonal
  model (same covariance as standalone `unique()`); `dep` uses a
  full Cholesky factor.

- **Shared-variance `indep(..., common = TRUE)`** ties the diagonal
  trait variances to one value while retaining the correlation-source
  structure in the linear predictor.

The phylogenetic and spatial keywords plug into the same
random-effects machinery via the correlation-source rows of the
4 × 3 grid plus its `common` and `unique` modifiers (see
`docs/design/01-formula-grammar.md`).

### Laplace accuracy caveat

The Laplace approximation can be inaccurate on **hyper-sparse
binary** data (rare-species detections, very few items per
person at extreme difficulty). `gllvmTMB_check_consistency()`
(PR #121) tests whether the marginal score is centred at zero;
non-centred score flags Laplace unreliability. See
`docs/design/05-testing-strategy.md` for the
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

### Phylogenetic random-regression blocks

`phylo_slope(x | species)` remains a legacy structured random-slope
path retained for compatibility:

$$
\mathbf{b} \sim \mathcal{N}\left(\mathbf{0}, \sigma_\beta^2 A\right),
\qquad \eta_i \leftarrow \eta_i + b_{\text{species}(i)} x_i
$$

with $\sigma_\beta = \exp(\texttt{log_sigma_slope})$ and sparse
$A^{-1}$ shared with the phylogenetic blocks above.

The augmented-LHS engine is live. For a random-regression matrix
$B \in \mathbb{R}^{n_\text{aug phy} \times C}$,

$$
\mathrm{vec}(B) \sim
\mathcal{N}\left(\mathbf{0}, \Sigma_b \otimes A\right).
$$

The fitted covariance channel depends on the keyword:

- Soft-deprecated `phylo_unique(1 + x | species)` retains the
  legacy/shared compatibility path with one block-local $2\times2$
  covariance $D R D$, assembled from `log_sd_b` and
  `atanh_cor_b`, shared across traits.
- Current Design 79/80 `phylo_indep(1 + x | species)` sets
  $C=2T$ and uses `theta_dep_chol` to form
  $\Sigma_b=L_bL_b^\top$. Cross-trait Cholesky entries are fixed so
  $\Sigma_b=\operatorname{blockdiag}(\Sigma_{b,1},\ldots,\Sigma_{b,T})$.
  With `|`, each trait-specific intercept-slope block is free; with
  `||`, its off-diagonal is also fixed to zero.
- `phylo_dep(1 + x | species)` uses the same interleaved $2T$
  channel without the cross-trait pins, giving a full unstructured
  $\Sigma_b$. More than one slope expands the dimension to
  $(1+s)T$ on the admitted Gaussian path.
- `phylo_latent(1 + x | species, d = K)` uses a separate
  block-diagonal reduced-rank covariance per augmented LHS column;
  cross-column covariance is structural zero.

The wrapper maps the inactive parameterisations off for each route;
it does not estimate both covariance channels simultaneously.
`extract_Sigma(level = "phy")` exposes the current indep and dep
channels as `phy_indep_slope` and `phy_dep`, respectively, while the
legacy/shared path returns `phy_unique_slope`. Validation is
family-by-route specific (PHY-11--PHY-18 and RE-14), not a universal
family or interval-calibration claim.

### Stable coefficient-prior evaluation

The full coefficient channel above, also used by `column_coef()` and
`phylo_coef()`, evaluates its Gaussian quadratic through the parameterized
lower-triangular factor. With $\Sigma_b=L_bL_b^\top$, define
$W=B L_b^{-\top}$ by forward substitution. Then

$$
\operatorname{tr}(\Sigma_b^{-1}B^\top A^{-1}B)
=\operatorname{tr}(W^\top A^{-1}W).
$$

For estimated `rho`, the same column whitening precedes the existing source
transform $U^\top D^{-1}W$. If $K=D U\operatorname{diag}(\lambda)U^\top D$,
the quadratic is the sum of squared transformed entries divided by
$1-\rho+\rho\lambda_r$. This preserves
$K_\rho=\rho K+(1-\rho)\operatorname{diag}\{\operatorname{diag}(K)\}$,
all normalization constants, and the reported $\Sigma_b$.

Forming and inverting $L_bL_b^\top$ is avoided in this prior because it squares
the factor's condition number. An ill-conditioned retained article attempt
produced a negative quadratic under that arithmetic; the same point provides
a regression check, not a biological result or a convergence guarantee.
The helper is private implementation, with compiled tests in
`tests/testthat/test-column-coef-triangular-density.R`. The separate spatial
coefficient implementation is outside this bounded repair and requires its own
numerical review.


### Gaussian response-column coefficient coordinates

For eligible nonspatial Gaussian identity ML compositions, the internal
coefficient random variables are standardized before constructing the Laplace
objective. The statistical model remains

$$
B=U L_b^\top,\qquad U\sim\operatorname{MN}(0,K_\rho,I),\qquad
\Sigma_b=L_bL_b^\top.
$$

Here $U$ denotes coefficient random variables, not the source eigenvector
matrix used above. Its negative log prior is

$$
\tfrac12\{nC\log(2\pi)+C\log|K_\rho|
 +\operatorname{tr}(U^\top K_\rho^{-1}U)\}.
$$

The coefficient determinant is absent because the density is now with respect
to $U$; the change of variables cancels the corresponding determinant in the
centred density. The linear predictor uses physical $B$. Thus the marginal
Gaussian likelihood is unchanged, while the random-effect prior no longer
contains the inverse of a nearly singular $L_b$. The prior on the source axis,
including estimated-rho diagonal scaling, is unchanged.

| Quantity | Internal operation | Preserved contract |
|---|---|---|
| $\Sigma_b=L_bL_b^\top$ | Same packed Cholesky parameters | Same covariance and rho reports |
| $B=U L_b^\top$ | Reconstruct before predictor/report | Same fitted coefficient effects |
| Physical start $B_0$ | $U_0=B_0L_{b,0}^{-\top}$ | Same physical initial coefficients |
| Fixed/tied physical $B$ maps | Keep centred path when incompatible | Never reinterpret constraints as maps on $U$ |
| Uncertainty of $B$ | Differentiate reconstructed $B$ through retained random and outer parameters | First-order physical-effect uncertainty |

Unlike the analytically eliminated singleton cell effect, $U$ remains a random
effect. Its transformed uncertainty therefore needs no added conditional
variance. Raw standardized-effect precision must not be presented as physical
coefficient precision. Warm starts must recover physical coefficients before
conversion to the target coordinates.

The intended admission is complete, unit-weight Gaussian identity ML for the
existing nonspatial response-column sources and their supported aliases.
Spatial coefficients, non-Gaussian models, other augmented-slope channels and
unsupported compositions retain the centred path. This is a numerical repair,
not a new estimator or a claim of interval coverage. Implementation and
validation status are tracked in the tree-axis after-task report; approval
alone does not establish that the new checks pass.

## SPDE / GMRF spatial integration

When `spatial_*(0 + trait | sites, mesh = mesh)` is in the
formula, the spatial random field is approximated by the
Lindgren-Rue-Lindström (2011) SPDE construction implemented in
gllvmTMB. The precision matrix is built on
the mesh nodes:

$$
Q = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2
$$

where $M_0$, $M_1$, $M_2$ are the finite-element mass / stiffness
matrices, and $\kappa = \sqrt{8}/\text{range}$ is the inverse-
range parameter. Mesh nodes' field values are linearly
interpolated to observation locations via a sparse projection
matrix $A_{n \times n_\text{mesh}}$. Status: `claimed`; external
comparisons are verification aids, not implementation provenance.

For `spatial_latent(0 + trait | sites, d = K)`, the shared fields
use the unscaled base SPDE prior and the scale is absorbed into the
trait loadings $\Lambda_\text{spde}$ for identifiability. The
optional `unique = TRUE` fold keeps a second per-trait SPDE block
alive:

$$
\mathbf{u}_t \sim \mathcal{N}\left(
  \mathbf{0}, \tau_t^{-2} Q^{-1}
\right),
\qquad
\Sigma_\text{spde}
  = \Lambda_\text{spde}\Lambda_\text{spde}^\top
    + \operatorname{diag}(\tau_t^{-2}).
$$

This is the spatial analogue of the ordinary / phylogenetic
`latent + Psi` decomposition, but note the SPDE scale: the unique
diagonal on the trait covariance scale is `exp(-2 * log_tau_spde)`,
not `exp(2 * log_tau_spde)`. Direct profile targets can still
profile `tau_spde`. The former derived spatial-correlation penalty-profile
prototype used the same total covariance as
`extract_Sigma(level = "spatial", part = "total")`, but that nonlinear public
route is withdrawn pending an exact constraint solver, optimizer-status
ledger, and target-specific calibration.

### Augmented spatial random-regression blocks

Augmented spatial slopes use the same observation projection and base SPDE
precision as the intercept-only field, but their coefficient covariance has
two distinct contracts:

- Soft-deprecated `spatial_unique(1 + x | coords)` retains the
  legacy/shared $2\times2$ intercept-slope field covariance assembled from
  `sd_spde_b` and `cor_spde_b`.
- Current Design 79/80 `spatial_indep(1 + x | coords)` uses an interleaved
  $2T\times2T$ `theta_spde_dep_chol` covariance with all cross-trait field
  blocks fixed to zero. `|` leaves one free within-trait intercept-slope
  correlation per trait; `||` also fixes those entries to zero.
- `spatial_dep(1 + x | coords)` uses the same $2T$ channel without the
  cross-trait pins and therefore fits a full unstructured field covariance.
- `spatial_latent(1 + x | coords, d = K)` uses separate low-rank
  cross-trait field covariance for each augmented LHS column.

The reported `Sigma_field` is on the fitted SPDE field-covariance scale; a
field variance is divided by $4\pi\kappa^2$ for the corresponding marginal
scale. `extract_Sigma(level = "spatial")` returns distinct
`spde_base_slope`, `spde_indep_slope`, and `spde_dep` labels so the shared
$2\times2$, block-diagonal $2T$, and full $2T$ channels cannot be conflated.
SPA-08--SPA-10 record the route-specific evidence; RE-14 remains C1 partial.

## `meta_V()` additive sampling-covariance contribution

When `meta_V(V = V)` is in the formula, the likelihood
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
`partial`; current tests cover parser desugaring, dimension guards,
wide `traits(...)` preservation, and smoke fits. A direct
`glmmTMB::equalto()` log-likelihood agreement fixture is still a
validation-debt item for MET-01.

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
- **Delta/hurdle families in mixed-family fits**: the compiled standard delta
  likelihoods use one shared `eta` for occurrence log-odds and positive-part
  log mean; they do not implement the historical positive-part-only design.
  The bounded predictor-informed LV programme targets only the shared loading
  covariance with `link_residual = "none"`. Automatic delta link-residual
  correlation remains a separate, uncalibrated surface. The earlier planned
  `gllvmTMB_auto_residual_delta_undefined` class was never built.

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
  occurrence patterns.  The cloglog branch evaluates its binomial density on
  the log scale, with a dedicated AD-safe left-tail series and bounded
  temporary branch inputs; it does not apply the generic binomial probability
  clip to cloglog rows.  At link predictor values above 700, where
  `exp(eta)` approaches floating-point overflow, the failure log-probability
  is held at `-exp(700)` with zero derivative; this is a representability guard
  rather than ordinary-range inference and is tested explicitly.
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
- Parameters: `mu` (log), per-trait `phi_gamma` shape (log;
  public CV / sigma is $1/\sqrt{\phi_{\gamma,t}}$; rate
  $\beta_t = \phi_{\gamma,t} / \mu$).
- Density: Gamma with mean-shape parameterisation and per-trait CV.
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
- **AD-safety of the interior-category CDF difference (fixed 2026-08-03).**
  The interior term is computed by `gll_log_pnorm_diff`
  (`src/gllvmTMB.cpp`), which selects between two algebraically
  equivalent forms with `CppAD::CondExp`. CondExp **evaluates both
  branches**, so both must be finite even when only one is selected.
  They were not. `gll_log_pnorm`'s direct branch is `log(pnorm(x))`,
  and `pnorm(x)` rounds to **exactly** $1.0$ for $x > 8.2924$, so when
  both category boundaries sit more than $\approx 8.3$ from $\eta$ on
  the same side, the two log-probabilities become bit-identical, their
  difference is exactly $0$, and `gll_log1mexp(0)` returns $-\infty$ on
  the unselected branch. The reachable condition is $|\eta| \gtrsim 8.3$
  — a rare extreme category under a large linear predictor — **not** a
  large cutpoint, which widens one boundary while leaving the other
  near zero.
  The consequence is specific and easy to miss: `fn()` and `gr()` stay
  finite **and correct**, and only `he()` returns `NaN`. No gradient
  check can see it (measured and documented at
  `inst/tmb/gllvmTMB_va_r3.cpp:154-180`).
  Fixed by a ceiling on the **input** of `gll_log1mexp` at the double
  unit roundoff, $-1.2\times10^{-16}$. The magnitude is load bearing: a
  $-10^{-300}$ or $-10^{-20}$ floor rescues the series branch but leaves
  the direct branch computing $\log(1 - e^{-\epsilon}) = \log 0$, because
  $e^{-\epsilon}$ rounds back to exactly $1$. Where the clamp binds,
  CondExp returns a constant so the propagated partial is exactly $0$;
  where it does not bind — every ordinary argument — the value is
  bit-identical to before. The same fix covers
  `gll_log_inv_logit_diff` (cumulative logit), whose exposure is the
  whole interval $(-1.1\times10^{-16}, 0]$ rather than exactly $0$,
  reachable when two adjacent cutpoints fall within $\sim10^{-16}$.
  Guard: `tests/testthat/test-log1mexp-adsafety.R`, which asserts
  `he()` (never `gr()` alone) and is demonstrated to **fail against the
  unfixed engine** — an earlier version that pushed cutpoints instead of
  $\eta$ passed against the defect and guarded nothing.

### Tweedie

- Status: `claimed`.
- Parameters: `mu` (log), `sigma` (log; dispersion $\phi$),
  `p` (logitp; $1 < p < 2$).
- Density: compound Poisson-Gamma with $\Pr(y = 0) > 0$ and
  continuous-positive for $y > 0$.

### Zero-inflated families (zi_poisson / zi_nbinom2 / zi_binomial)

- Status: `partial` (FAM-21/22/23, Arc D). Point recovery evidence only; no
  interval on `zi`.
- Parameters: `mu` (log for zi_poisson/zi_nbinom2, logit for zi_binomial),
  `sigma` for zi_nbinom2 (log; reuses the ordinary `nbinom2()` per-trait
  dispersion convention, not a new vector), `zi` (logit; per-trait,
  intercept-only -- no covariates, no random effects).
- TMB template: `src/gllvmTMB.cpp`, `obs_loglik` fid 17/18/19 blocks (the
  same per-row lambda the plain Laplace loop and the AGHQ per-node loop both
  call -- though AGHQ itself refuses these three family ids, see below).
  `PARAMETER_VECTOR(logit_zi)`.
- R constructor: `R/families.R` (`zi_poisson()`, `zi_nbinom2()`,
  `zi_binomial()`).
- Density: a TRUE mixture (Design 62 -- not the delta/hurdle shared-`eta`
  architecture below; the count process is active at every row, including
  $y = 0$):
  $$
  P(Y=0) = \pi_t + (1-\pi_t) f_c(0 \mid \mu, \ldots), \qquad
  P(Y=k>0) = (1-\pi_t) f_c(k \mid \mu, \ldots)
  $$
  with $f_c$ the ordinary Poisson / NB2 / Binomial($N_i$, $p$) pmf and
  $\pi_t = \text{invlogit}(\text{logit\_zi}_t)$. Consequently the mixture
  CDF has the closed form $F_{\text{mix}}(y) = \pi_t + (1-\pi_t) F_c(y)$,
  used by the randomized-quantile residual.
- Numerical: `logspace_add`/the log-sigmoid identity
  ($\log \pi = -\text{logspace\_add}(0, -\text{logit\_zi})$), matching
  drmTMB's `zi_poisson`/`zi_nbinom2` idiom (its `model_type == 6` branch)
  exactly; `zi_nbinom2` reuses the plain `nbinom2()` `dnbinom_robust` call;
  `zi_binomial` reuses `dbinom_robust` (logit-parameterised), the same
  numerically-stable primitive the delta-family presence term uses.
- Identifiability: `zi_binomial` is refused at parse time
  (`R/fit-multi.R`) for single-trial (0/1) response data -- with $N=1$,
  $P(y=1) = (1-\pi)p$ collapses $\pi$ and $p$ into one free product, with
  no curvature to separate them. At least one row per trait must carry
  $N \ge 2$.
- Boundary cases tested: exact TMB-vs-hand-density identity (1e-8) and a
  finite-difference gradient check at the starting values, both on a tiny
  fixed-effects-only fixture (`tests/testthat/test-zi-families.R`); a
  known-DGP rank-1-latent recovery test per family
  (`tests/testthat/test-zi-recovery.R`) -- see
  `dev/gapclose/arcD/D1-report.md` for the exact numbers, including a
  documented small-sample limit on `zi_nbinom2`'s per-trait dispersion
  recovery at n = 150 (not zero-inflation-specific; the same limit
  reproduces on plain `nbinom2()` under the identical DGP).
- Comparator-test alignment: `dev/gapclose/arcD/alignment-zi.md`'s
  symbolic derivation, checked against `stats::dpois`/`dnbinom`/`dbinom`
  directly in the exactness test; drmTMB's `model_type == 6` zi_poisson
  branch (`src/drmTMB.cpp`) and GLLVM.jl's `src/families/twopart.jl` are
  the two independent oracle derivations the density form was checked
  against (recon, `dev/gapclose/arcD/recon-zi.md`).
- Not established: `integration = "va"`, `aghq`, and `estimator = "mspl"`
  all refuse the three family ids (`R/va-routing.R`'s `0:15` allow-list;
  `R/fit-multi.R`'s AGHQ eligibility chain; the MSPL registry has no
  matching rows) -- no evidence exists for any of those routes here.
- Test file: `tests/testthat/test-zi-families.R`,
  `tests/testthat/test-zi-recovery.R`.

### Delta / hurdle families

**Status: `covered` for the standard fixed-effect family routes; `partial` for
the bounded predictor-informed LV cells.** The engine wires
`delta_lognormal()` and `delta_gamma()` with one shared `eta` controlling
occurrence log-odds and positive-part log mean. Point-recovery evidence covers
the named mixed/sentinel delta cells and the pure delta-lognormal and
delta-Gamma cells in the native rank-1, loadings-only, complete-response
programme; their targets are `B_lv` and `Lambda %*% t(Lambda)` with
`link_residual = "none"`. The Gaussian + delta-Gamma archetype also passes its
target-wise Wald calibration gate. This evidence does not
establish an unconditional response-mean effect, an automatic delta
link-residual correlation, default `+ Psi`, or the constructor-only delta
families. See Design 02 for the exact contract.

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

### Opt-in LA-MSPL GLM-outer weights (Poisson REPLACE)

`estimator = "mspl"` builds a GLM-outer Jeffreys atom from
`gll_mspl_log_weight_glm` (not Laplace-marginal \(I(\beta)\)).

- **Bernoulli** (`family_id == 1`): link-specific \(W\) via
  `gll_mspl_log_weight(eta, link_id)`.
- **Poisson** (`family_id == 2`, G0 SIGNED REPLACE 2026-08-17 / #1102):
  live weight is working logistic \(W_*=\mu_*(1-\mu_*)\),
  \(\mu_*=\operatorname{logit}^{-1}(\eta)\), via
  `return gll_mspl_log_weight(eta, /*logit*/ 0)` (Tweedie
  `family_id == 6` precedent; existence device, not true-model
  Jeffreys). True Poisson \(W=\operatorname{diag}(\mu)\) /
  `return eta` is one-sided (\(0/+\infty\)) and remains the
  historical contrast only (#1064 W1/W2). Experimental point;
  **no** public `se` / `vcov` / `confint`; **not** NEWS `covered`.
- **Tweedie** (`family_id == 6`, planned): same working-logistic device;
  true \(W=\mu^{2-p}/\phi\) rewards \(\phi\to 0\).

### Opt-in binary LA-MSPL objective

`estimator = "mspl"` changes the outer objective, not the response family or
the default estimator. On the admitted complete-Bernoulli Laplace surface, the
template evaluates stable unclipped logit/probit/cloglog log-pmfs and adds the
fixed-design Jeffreys, radial loading, and structure-specific covariance
penalties defined in `docs/design/88-binary-mspl-estimator.md`. The ordinary ML
branch remains on its historical arithmetic and never calls the guarded
information atom. The template reports penalised and unpenalised components
separately; R verifies them against a second penalty-off Laplace tape at the
selected MSPL point.

This is point estimation only. The penalty-off value is not `logLik()`, and no
AIC/BIC/LRT or interval route is licensed by a finite penalised Hessian.

- `docs/design/00-vision.md` — package vision; item 5 names
  latent-scale correlations across non-delta families.
- `docs/design/01-formula-grammar.md` — formula contract +
  family argument forms.
- `docs/design/02-family-registry.md` — per-family registry
  with link-residual contract.
- `docs/design/04-random-effects.md` — Laplace
  integration + reduced-rank reparameterisation details.
- `docs/design/05-testing-strategy.md` — two-tier
  validation (comparator + simulation recovery); per-family
  required edge cases.
- `docs/design/06-extractors-contract.md` — what
  `extract_*()` returns per family.
- `docs/design/35-validation-debt-register.md` — evidence ledger;
  every `claimed` row in this doc gets a register row.
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

### Gaussian singleton-cell integration (2026-08-30; bounded validation)

The ordinary unit-level diagonal effect can be integrated analytically when
each cell has one observed Gaussian response. Write its variance as
`psi = exp(2 * theta_diag_B)` and keep the observation variance
`e = sigma_eps^2` separate. The identity is

\[
 s_i\sim N(0,\psi_t),\quad y_i\mid s_i\sim N(\eta_{0i}+s_i,e)
 \quad\Longrightarrow\quad y_i\sim N(\eta_{0i},\psi_t+e).
\]

This changes integration arithmetic, not the marginal model. In particular,
the documented fixed stabilizer is retained; it is not set to zero or absorbed
into the reported Psi. Ordinary shared latent variation, phylogenetic shared
and diagonal variation, and response-column coefficient variation remain
separate components with unchanged parameters.

| Quantity | Native implementation | Output meaning |
|---|---|---|
| Cell variance `psi` | `exp(2 * theta_diag_B)` | Ordinary unique covariance |
| Observation variance `e` | Fixed `exp(2 * log_sigma_eps)` | Same stabilizer as before |
| Integrated density | Gaussian variance `psi + e` | Same marginal likelihood |
| Conditional cell mean `m` | `psi/(psi+e) * (y-eta0)` | Reconstructed ordinary cell effect |
| Conditional cell variance `v` | `psi*e/(psi+e)` | Remaining uncertainty conditional on other parameters/effects |

The reconstructed predictor is `eta0 + m`. Prediction for existing units uses
the saved reconstructed cell effects. Unconditional simulation continues to
draw the original separate components. `extract_ordination(level="unit")`
continues to read the retained ordinary latent scores.

For uncertainty, ADREPORT of `m` propagates uncertainty from the remaining
random effects and fixed/covariance parameters. `getREsd(block="diag_unit")`
adds `v` to that propagated variance before taking square roots. Adding only
the variance of `m` would omit conditional uncertainty. No additional variance
of the estimated `v` is added: the original TMB first-order convention uses
conditional variance evaluated at fitted covariance parameters. Removed cell
coordinates are not fabricated in the reduced tape's raw joint precision.

The initial implementation is restricted to complete, unit-weight Gaussian ML
models with singleton ordinary cells and the supported ordinary/phylogenetic
latent or response-column coefficient composition. Other families, repeated
cells, missingness, incompatible maps, and other excluded model paths retain
the existing integration route. This restriction is computational eligibility,
not a new model keyword or public engine. Compiled likelihood/gradient/output
checks and all twelve approved frozen fits pass. Evidence is recorded in
`dev/tree-axis-latent/evidence/2026-08-30-cell-integration.json` and
`tests/testthat/test-gaussian-cell-collapse.R`. This validates the named
Gaussian compositions and first-order conditional uncertainty calculation;
it does not establish parameter recovery or interval coverage. FG-20 remains
partial for response-column coefficients. Package, publication and landing
receipts remain separate gates.

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

## Structured source attenuation (development arc, 2026-08-31)

The approved contract is `dev/structured-rho/spatial-recovery/PLAN.md`. Fixed
attenuation and the admitted Gaussian estimator are implemented with scoped
workflow checks. Spatial recovery evidence remains limited: 14 cells are
partial, 2 are blocked, and none passes the predeclared joint range--rho gate.
For the legacy-resolved source covariance K,
define D = diag(diag(K)) and K_rho = rho K + (1-rho)D. The entire trait
covariance S = Lambda Lambda' + Psi receives the same source strength.
Ordinary variance components and Gaussian observation noise stay separate.

Dense sources are mixed after existing scaling and diagonal conditioning,
before inversion/determinant calculation. Sparse augmented sources retain Q
and their ancestor map: at modeled source level j, the effective score is
sqrt(rho) g_aug[j] + sqrt(1-rho) sqrt(D[j]) e[j]. Independent e lives at
source levels, not observations. Separate factor and Psi scores share rho.
At rho=0 augmented scores and their priors are inactive; their loading/SD
parameters remain active. Omitted/explicit rho=1 follows the old engine branch.
The common-variance propto route retains its own legacy marginal resolution.

Source diagonals are selected entries of the inverse FULL precision, obtained
with a reusable sparse factorization. Neither reciprocal precision diagonals
nor the inverse of a tip-only precision submatrix gives the required marginal
variance when ancestors are retained. Existing phylo(Ainv=) sugar resolves
densely; animal(Ainv=) retains sparse precision. Do not silently equate them.

`test-structured-rho-fixed-oracle.R` independently constructs the Gaussian
observation covariance, including replication and residual noise, to check
fixed-point likelihoods. No recovery claim follows from this check. Estimated
rho uses a separate outer logit parameter initialized at zero (rho=.5). The
dense prior uses an eigendecomposition of D^-1/2 K D^-1/2, with eigenvalues
(1-rho)+rho*lambda and log determinant sum(log(D))+sum(log(eigenvalues)).
Sparse estimated strength uses stable square-root logistic weights on both
fields. Observation-level admission requires at least two traits and complete repeated vectors on
unit_obs, every modeled group observed, positive diagonals and observed source
contrast. Competing ordinary covariance and other unproved configurations are
rejected. Rank-one latent admission with four traits is generic: weak/zero
loading configurations still need diagnostics and do not prove Psi separation.
Downstream methods and full fixed-family equivalence now have passing scoped
checks. The retained spatial study completed with 14 partial and 2 blocked
cells, so it makes no broad joint range--rho recovery claim. The separate
coefficient-rho parameter and defaults are unchanged.

### Spatial extension (maintainer addendum, 2026-08-31)

The approved spatial contract is retained in
`dev/structured-rho/spatial-recovery/PLAN.md`. With one
projection row per modeled location, K(kappa) = A_g Q(kappa)^(-1) A_g', where
Q(kappa) = kappa^4 M0 + 2 kappa^2 M1 + M2 uses the existing mesh scale.
The same K_rho formula applies, with its diagonal recomputed as kappa changes.
For latent scores, use sqrt(rho) A_g omega + sqrt(1-rho) sqrt(D) e before
the loading map. For independent/Psi effects, the mesh field already includes
1/tau; the IID companion receives exactly one 1/tau. Replication happens last.

Sparse projections stay sparse, and one differentiated sparse factorization
computes selected projected diagonals by location-wise solves. Neither dense
Q inverse nor full location covariance is needed by the likelihood. Omitted
and explicit rho one retain the literal old path. At fixed zero the mesh fields
are mapped off, but kappa stays active because D(kappa) still depends on it.
Proportional diagonal changes can confound range with trait scale at this endpoint.

Estimated spatial strength retains Gaussian replicated-vector admission and
adds a local source-shape check. H=K_rho/trace(K) removes amplitude; finite
differences in log(kappa) and the analytic rho derivative must have numerically
independent normalized columns (relative singular value >1e-8). Reference
kappa values are .5,1,2 and rho=.5, independent of data-generation truth.
Geometry uses at most 64 deterministically spaced modeled rows to bound memory.
Failure at all three points rejects this admission test, not a claimed theorem
of global nonidentification. Fitted diagnostics report the selected indices,
conditioning, and the fixed-rho range-shape derivative norm. Ancillary failures
return an unavailable reason rather than discard the fit.

Independent spatial tests vary both kappa and rho and construct the full
Gaussian observation covariance separately. Fixed-family comparison must
preserve spatial Psi even when the phylogenetic reference family maps its own
Psi companion off: encode that whole trait covariance through dense `dep()`.
The frozen nonspatial recovery study supplies no spatial recovery claim.
