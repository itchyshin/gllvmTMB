# TMB side of the stan-oracle fixed-parameter check -- PHYLOGENETIC arc

Target model, long-format ordinary Gaussian, ONE grouping level (`species`),
a rank-1 REDUCED-RANK PHYLOGENETIC latent term, loadings-only (`unique =
FALSE`, the default):

```
value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A)
family = gaussian()
```

`n_traits = 3`, `n_species = 8` (tips), `d_phy = 1` (rank), 2 replicates per
`(species, trait)` cell (`N = 48` rows). `A` is the dense tip-level
phylogenetic CORRELATION matrix from `ape::vcv(tree, corr = TRUE)`, passed
via `vcv =` inside the `phylo_latent()` keyword.

Script: `dev/stan-oracle-phylo/tmb-side-phylo.R`. Fixture:
`tmb-fixture-phylo.rds` / `.json`, written by that script.

## What is evaluated

Same move as Arc 0 (`dev/stan-oracle/tmb-side.R`): `fit <- gllvmTMB(...)` is
fit once (Laplace) purely to obtain a valid `fit$tmb_data` /
`fit$tmb_params` / `fit$tmb_map` triple, then a second TMB object is built
from that SAME triple with `random = NULL`:

```r
joint_obj <- TMB::MakeADFun(
  data = fit$tmb_data, parameters = fit$tmb_params, map = fit$tmb_map,
  random = NULL, DLL = "gllvmTMB", silent = TRUE
)
```

`joint_obj$fn(theta)` is then the JOINT negative log-density of data +
`g_phy` (the phylogenetic species scores), evaluated pointwise:

```
joint_obj$fn(theta) = -log p(y, g_phy | b_fix, log_sigma_eps, theta_rr_phy)
```

`length(theta) = 15` for this fixture: `3 (b_fix) + 1 (log_sigma_eps) + 3
(theta_rr_phy) + 8 (g_phy)`. Confirmed live (not mapped off): both
`theta_rr_phy` and `g_phy` appear in `names(joint_obj$par)`.

**Joint log-density at the published fixture `theta`:
`joint_obj$fn(theta) = 142.6333948738` (TMB sign convention -- this is
`nll`, an objective to MINIMISE; negate it, as in Arc 0, to compare against
a Stan `log_prob`).**

## (a) Does the engine use A or A^{-1}? Which object, how built?

**The density is evaluated through `A^{-1}` (`Ainv_phy_rr`), a quadratic
form `g' A^{-1} g`, never through `A` directly in the likelihood
computation** (`src/gllvmTMB.cpp:1172`, `Type quad = (g_k.matrix().transpose()
* Ainv_phy_rr * g_k.matrix())(0,0);`). `A` itself is used only to supply
`log det(A)` (see (e)).

There are **three different routes** the R side can build `Ainv_phy_rr`
(`R/fit-multi.R:3157-3229`), selected by which argument is supplied to
`phylo_latent()`:

1. **`tree =`** (canonical): a genuinely SPARSE augmented `A^{-1}` over
   TIPS + INTERNAL NODES, built by `.gllvm_phylo_tree_precision()`
   (`R/phylo-tree-precision.R`, a ported Hadfield-Nakagawa deterministic
   construction; no MCMCglmm dependency). `n_aug_phy = 2*n_tips - 2` (root
   excluded, internal nodes + tips included). Each observation reads its
   TIP's score via `species_aug_id`, but the density is over the full
   augmented vector, so internal-node scores are latent random effects too.
2. **`vcv = <sparseMatrix>`**: treated as a pre-built (possibly augmented)
   `A^{-1}` directly, via `.resolve_sparse_phylo_precision()`.
3. **`vcv = <dense matrix>`** -- **the path this fixture uses** (`A` is a
   plain `matrix`, not a `sparseMatrix`, since `ape::vcv()` returns dense):
   the **legacy dense path** (`R/fit-multi.R:3213-3229`):
   ```r
   Aphy <- phylo_vcv[levs, levs, drop = FALSE]
   Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))   # numerical ridge
   Ainv_phy_rr      <- Matrix::Matrix(solve(Aphy), sparse = TRUE)
   log_det_A_phy_rr <- as.numeric(determinant(Aphy, logarithm = TRUE)$modulus)
   n_aug_phy        <- n_species
   species_aug_id   <- species_id    # identity -- no augmented internal nodes
   ```
   `n_aug_phy == n_species = 8` here (no augmentation), `species_aug_id ==
   species_id` (confirmed programmatically in `tmb-side-phylo.R`, both
   `stopifnot`s pass). **This is the route the fixture is built on** because
   the task asked for a dense `A` and a tiny tree, and `phylo_latent()`
   dispatches on the R class of the `vcv =` argument (dense `matrix` ->
   legacy path; `sparseMatrix` -> sparse-Ainv-direct path; `tree =` ->
   augmented sparse path).

**Consequence for the Stan side: no internal-node augmentation to worry
about.** `g_phy` is exactly an 8-vector, one entry per tip species, in
`tip_order` (the tree's own `tip.label` order, since `A`'s rownames were
never reordered). The Stan model can use the **plain dense** `A` (or its
inverse) at tip level with no extra latent nodes.

One numerical wrinkle: the engine adds a **`1e-8` ridge to `A` before
inverting** (not documented anywhere outside this code path). `tmb-fixture-phylo.rds$A` is the RAW `ape::vcv()` output (unridged); if the
Stan side wants bit-exact agreement with the engine's own `Ainv_phy_rr` /
`log_det_A_phy_rr`, it must add the same `1e-8 * I` before inverting /
taking the log-determinant. This was verified in `tmb-side-phylo.R`:
`fit$tmb_data$Ainv_phy_rr` matches `solve(A + 1e-8*I)` to `< 1e-6` max abs
difference (loose because `solve()` on a near-singular-ish small matrix is
not bitwise stable, but the ridge's presence is unambiguous).

## (b) Correlation or covariance? Scaled/normalised anywhere?

**`A` is a CORRELATION matrix**, unit diagonal by construction: `A <-
ape::vcv(tree, corr = TRUE)` gives `diag(A) == 1` for every tip (confirmed:
`stopifnot(all(diag(A) == 1))` passes in the script). No further scaling or
normalisation is applied to `A` inside the engine on this path -- the ONLY
modification is the `+ diag(1e-8)` ridge in (a), which is a numerical
regulariser, not a rescaling (it does not touch the diagonal's leading
order or the off-diagonal entries).

Because `A` is a correlation (not a free-scale covariance), the OVERALL
phylogenetic variance is carried entirely by `theta_rr_phy` (the loadings),
exactly parallel to how the ordinary `latent()` term's `z_B ~ N(0, I)` score
prior carries no scale of its own -- the scale lives in `Lambda_B`/`Lambda_phy`.
`Sigma_phy = Lambda_phy %*% t(Lambda_phy)` (T x T here, T=3) is reported via
`REPORT(Sigma_phy)` at `cpp:1178` and is the identifiable across-trait
phylogenetic covariance; the SPECIES-level structure contributed by `A` is
a pure correlation shape.

## (c) Where does the phylogeny enter -- z, u, or elsewhere? Exact density term.

The phylogeny enters through the PRIOR on the reduced-rank LATENT SCORE
`g_phy` (the direct analogue of Arc 0's `z_B`), **not** on any trait-level
effect and **not** as a separate marginal covariance on the data. Exactly
one density term per phylogenetic factor `k = 1..d_phy` (here `d_phy = 1`,
so one term, an 8-dimensional Gaussian):

```
-log p(g_phy[, k]) = 0.5 * ( n_aug_phy * log(2*pi)
                              + log_det_A_phy_rr
                              + g_phy[, k]' %*% Ainv_phy_rr %*% g_phy[, k] )
```

(`src/gllvmTMB.cpp:1166-1174`; `nll += ...`). This is a plain zero-mean
MVN(0, A) density on `g_phy[, k]`, evaluated via its precision `A^{-1}`
rather than by calling `dnorm` -- there is no `dnorm`/`dmvnorm` TMB helper
used here, it is a hand-written quadratic form.

`g_phy` then enters the LINEAR PREDICTOR `eta` additively, alongside the
fixed-effect trait intercepts, at the row's own `(species, trait)` cell
(`cpp:2040-2044`):

```
eta(o) += sum_{k=1}^{d_phy} Lambda_phy(trait(o), k) * g_phy(species_aug_id(o), k)
```

which for `d_phy = 1` collapses to a single term
`Lambda_phy(trait(o), 1) * g_phy(species(o), 1)`. `Lambda_phy` uses the SAME
reduced-rank packing convention as the ordinary `latent()` term's
`Lambda_B` (diagonal first, then strict-lower-triangle column-major, upper
triangle forced to exactly 0, UNCONSTRAINED diagonal -- no `exp()`, no sign
constraint; `cpp:1145-1165`, mirroring `theta_rr_B` at `cpp:902-913`). For
`d_phy = 1` (this fixture) the packing is trivial: `theta_rr_phy ==
Lambda_phy[, 1]` directly, all 3 entries free reals.

Then the DATA likelihood is the ordinary Gaussian term, one per row (48
here): `nll -= dnorm(y(o), eta(o), sigma_eps, log = TRUE)`,
`sigma_eps = exp(log_sigma_eps)`.

**Full sum, 3 kinds of term, exactly as in Arc 0's model-spec.md sec.0
form (b) — hierarchical, NOT marginal**:
1. Data likelihood: 48 `dnorm(y, eta, sigma_eps)` terms.
2. Phylogenetic score prior on `g_phy`: 1 term, an 8-dimensional
   `MVN(0, A)` quadratic form (not 8 independent univariate terms -- this
   is the one structural difference from Arc 0's `z_B ~ N(0, I)`, which
   WAS 15 independent univariate `dnorm` calls because its prior covariance
   is the identity).
3. No `unique()`/diagonal companion term is active here (`unique = FALSE`,
   the default) -- `use_phylo_diag = 0`, so `log_sd_phy_diag`/`g_phy_diag`
   are both mapped off and contribute nothing.

## (d) Kronecker structure? Which order?

**Implicit, never formed explicitly.** The full identifiable phylogenetic
covariance is `Sigma_phy_full = Lambda_phy %*% t(Lambda_phy) %x% A` (a
`(n_traits * n_species) x (n_traits * n_species)` object if you wrote it
out as one Kronecker-structured MVN over `vec(eta_phy)`), but the engine
**never builds or inverts that matrix**. It instead evaluates the
mathematically equivalent REDUCED-RANK factorisation: `d_phy` independent
`N(0, A)` densities on the columns of `g_phy` (species-indexed, `A`
appearing once per factor, at species dimension only), and lets the T x
`d_phy` loadings `Lambda_phy` carry the trait-covariance part when `g_phy`
is fed into `eta` at `cpp:2040-2044`. This is exactly the same trick Arc 0
used for the ORDINARY `latent()` term (`z_B ~ N(0, I)` i.i.d., with
`Lambda_B` carrying the trait covariance) -- the only change here is that
the species-axis prior covariance is `A` instead of `I`.

**Order**: at `d_phy = 1` (this fixture) there is only one factor column,
so the species-major-vs-axis-major question is DEGENERATE -- `g_phy` is
literally an 8-vector in tip order, no interleaving to get wrong. (Same
caveat Arc 0 flagged for `z_B` at `K = 1`: the packing/ordering questions
that matter at `d_phy >= 2` -- which axis is fastest when `g_phy`, a
`PARAMETER_MATRIX(g_phy)` of dimension `n_aug_phy x d_phy`, is flattened
column-major -- are UNTESTED by this fixture. `PARAMETER_MATRIX` flattening
is species-fastest-within-factor, i.e. `g_phy` column-major means all
species for factor 1, then all species for factor 2, etc. -- read from the
declaration comment and TMB's standard `PARAMETER_MATRIX` semantics, not
independently exercised here since `d_phy = 1` makes it moot.)

## (e) Log-determinant term -- present, constant w.r.t. theta?

**Present, and constant w.r.t. theta -- but NOT numerically zero.** It IS
constant with respect to `theta` (it depends only on the supplied `A`,
which is fixed DATA, not a parameter, so it never varies as `theta`
varies) -- in that sense it plays the same role as Arc 0's Failure-Mode-2
"normalising constants". But UNLIKE Arc 0's `z_B ~ N(0, I)` term, where
`log det(I) = 0` made the whole constant vanish, here
`log_det_A_phy_rr = log det(A + 1e-8*I) = -7.8611543987` (see
`fixture$checks$log_det_A_phy_rr` in the `.rds`) is genuinely nonzero, so
it is NOT free to omit or get wrong. If the Stan model computes its own
`log det(Sigma_phy)` via `multi_normal_prec` or an explicit Cholesky, it
MUST reproduce this exact `-7.8611543987` value (using the SAME ridged `A`,
per (a)) for the two densities to agree to machine precision; get the
ridge or the sign of the log-det wrong and this is exactly the kind of
miss Arc 0's Failure-Mode-2 check was built to catch.

**Sign convention, stated explicitly**: `log_det_A_phy_rr` in this dense
path is `+log det(A)` (`determinant(Aphy, logarithm=TRUE)$modulus`, the
covariance's own log-determinant, matching the standard MVN density
`-log p = 0.5*(n log 2pi + log det(Sigma) + quad)` with `Sigma = A`). This
is the SAME sign convention the `tree =` path produces too
(`log_det_A_phy_rr <- -phy_prec$log_det_precision`, i.e. `-log det(A^{-1}) =
+log det(A)`) -- both routes end up passing `log det(A)`, never `log
det(A^{-1})`, into the C++ density term. Confirmed by reading both branches
of `R/fit-multi.R:3172-3229`, not inferred.

## (f) Full parameter vector: names, dimensions, order, transforms

`length(theta) = 15`. Order and names from `names(joint_obj$par)` (the
order `TMB::MakeADFun` concatenates the `parameters` list, using only
entries NOT fully mapped off):

| block           | length | positions | scale / transform |
|-----------------|-------:|-----------|--------------------|
| `b_fix`         | 3      | 1-3       | natural scale (identity link); trait intercepts, order `traita, traitb, traitc` (matches `levels(df$trait)`) |
| `log_sigma_eps` | 1      | 4         | log-SD of the Gaussian observation residual; `sigma_eps = exp(log_sigma_eps)` |
| `theta_rr_phy`  | 3      | 5-7       | UNCONSTRAINED packed loadings of `Lambda_phy` (`n_traits x d_phy = 3 x 1`). For `d_phy = 1` this packing is trivial: `theta_rr_phy[i] = Lambda_phy[i, 1]` for `i = 1..3`, no sign/positivity constraint (identical convention to `theta_rr_B` in Arc 0 -- see `reconciliation.md` sec 6.1 for the doc/engine divergence this inherits: the diagonal is NOT `exp()`-constrained despite `docs/design/04-random-effects.md` claiming otherwise). |
| `g_phy`         | 8      | 8-15      | phylogenetic species scores, UNCONSTRAINED (marginal `N(0, A)` draws under the density in (c), NOT `N(0,1)` -- this is the one place this arc's prior differs qualitatively from Arc 0's `z_B ~ N(0, I)`). Stored as an `n_aug_phy x d_phy = 8 x 1` matrix (`PARAMETER_MATRIX(g_phy)`); with `d_phy = 1` the flattened order is exactly one score per species, in `tip_order` (`species_aug_id` 0..7, identity map to `species_id`, confirmed by `stopifnot`). |

Total: `3 + 1 + 3 + 8 = 15`.

No other parameter block is active for this formula/family: `use_phylo_rr =
1`, every other `use_*` flag (`use_phylo_diag`, `use_rr_B`, `use_diag_B`,
`use_lv_B`, `use_phylo_slope*`, `use_diag_species`, spatial/kernel/meta
flags, ...) is 0, confirmed by `stopifnot(!any(theta_names %in%
c("theta_rr_B", "z_B", "theta_diag_B", "s_B")))` in the script and by
`table(theta_names)` showing exactly the four blocks above.

## Jacobian

Same as Arc 0: TMB applies NO automatic Jacobian correction. `sigma_eps =
exp(log_sigma_eps)` is a plain substitution inside `dnorm(..., log = TRUE)`,
with no compensating term -- `log_sigma_eps` is an ordinary (non-random)
hyperparameter, not a random effect being integrated over. `theta_rr_phy`
and `g_phy` are both untransformed (identity unconstraining map), so no
Jacobian arises there either.

## Verification performed

`tmb-side-phylo.R`:
- Fits the model, rebuilds the joint (non-Laplace) objective, confirms
  `theta_rr_phy` and `g_phy` both appear in `names(joint_obj$par)` (i.e.
  neither is silently mapped off) -- **passed**.
- Confirms no ordinary (non-phylo) `latent()`/`unique()` blocks are present
  in `theta_names` -- **passed**.
- Confirms `fit$tmb_data$n_aug_phy == n_species` and
  `fit$tmb_data$species_aug_id` is the identity map onto `species_id`,
  i.e. the LEGACY DENSE path (no augmented internal nodes) is the one
  actually taken -- **passed**.
- Confirms `fit$tmb_data$Ainv_phy_rr` numerically matches `solve(A +
  1e-8*I)` in `tip_order` (max abs diff `< 1e-6`) -- **passed**, and is the
  evidence for the `1e-8` ridge claim in (a).
- Evaluates `joint_obj$fn(theta)` twice at the identical `theta` and
  asserts `identical()` (bitwise) -- **passed**
  (`nll = 142.6333948738` both times).
- Evaluates at a `theta` perturbed ONLY in `theta_rr_phy[1]` (+0.15, a
  phylo-specific parameter, not a shared block like `b_fix`) and asserts
  the value changes -- **passed**, differed by `+15.471518`.
- Evaluates at a `theta` perturbed ONLY in `g_phy[1]` (+0.5, a
  phylo-specific latent score) and asserts the value changes -- **passed**,
  differed by `+32.997427`. Together with the `theta_rr_phy` perturbation,
  this rules out the phylo term being a silently-dropped/no-op block: BOTH
  the loadings AND the species-score prior are live in the objective.

## Where I could not determine the transform / left an open question

- **The `1e-8` ridge added to `A` before inversion** (`R/fit-multi.R:3224`)
  is not documented anywhere I found outside the source line itself -- no
  roxygen comment, no design doc, no NEWS entry. It is small enough to be
  irrelevant to any point estimate, but it means a Stan model computing its
  own `Sigma^{-1}`/`log det Sigma` from the RAW `A` (unridged) will disagree
  from the TMB density by an amount on the order of `1e-8 / eigenvalue`,
  which is far above the ~1e-13 floor Arc 0 achieved. **The fixture stores
  BOTH the raw `A` and documents the ridge explicitly (`meta$ridge_added_to_A
  = 1e-8`) so the Stan side can replicate it exactly** -- add `1e-8` to
  the diagonal of `A` before any inversion/Cholesky/log-det, in the SAME
  `tip_order` used throughout (`fixture$meta$tip_order`, matching
  `rownames(fixture$A)`).
- I did NOT test the `tree =` (augmented sparse) or `vcv = <sparseMatrix>`
  paths in this arc -- only the dense/legacy path the task specified. Both
  are named and cited in (a) from reading the source, not from running them.
- `d_phy = 1` throughout, so the loadings-packing / axis-ordering questions
  that matter at `d_phy >= 2` (the direct phylogenetic analogue of Arc 0's
  dataset-C K=2 check) are UNTESTED here, same limitation Arc 0 states for
  its own K=1 fixtures.
