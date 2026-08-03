# TMB side of the stan-oracle fixed-parameter check -- PHYLOGENETIC arc, `tree =` route (Arc 2)

Target model, long-format ordinary Gaussian, ONE grouping level (`species`), a
rank-1 REDUCED-RANK PHYLOGENETIC latent term, loadings-only (`unique =
FALSE`, the default), on the CANONICAL augmented-sparse `tree =` route:

```
value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree)
family = gaussian()
```

`n_traits = 3`, `n_species = 8` (tips), `d_phy = 1` (rank), 2 replicates per
`(species, trait)` cell (`N = 48` rows) -- identical fixture and seed
(`20260803L`) to Arc 1 (`dev/stan-oracle-phylo/tmb-side-phylo.R`), so the tree
and the simulated dataset are bit-identical across the two arcs. Only the fit
call differs: `tree = tree` instead of `vcv = A`.

Script: `dev/stan-oracle-phylo-tree/tmb-side-tree.R`. Fixture:
`tmb-fixture-tree.rds` / `.json`. Full console log of the run reproduced
inline below where it carries a measured number.

**All measurements below are read off a live run of the script (this session),
not assumed.** Every claim cites the file:line of the code that produces it.

## Joint objective at the chosen theta

`joint_obj$fn(theta) = 173.37932199712063` (TMB sign convention: this is
`nll`, minimise it; negate to compare against a Stan `log_prob`, same
convention as Arc 0 / Arc 1). `length(theta) = 21`: `3 (b_fix) + 1
(log_sigma_eps) + 3 (theta_rr_phy) + 14 (g_phy)` -- 14, not 8, because
`n_aug_phy = 14` on this route (see (a)).

**IMPORTANT precision caveat (reproduces Arc 1's finding):** the RDS value
above and the console `%.17g` prints are authoritative. `jsonlite::write_json
(digits = NA)` is confirmed, again, NOT bitwise exact on this fixture:

```
RDS  joint_neg_log_density = 173.37932199712063
JSON joint_neg_log_density = 173.379321997121      (differs at the 13th sig. fig.)
RDS  log_det_A_phy_rr      = -25.229441850133327
JSON log_det_A_phy_rr      = -25.229441850133298    (differs at the 15th sig. fig.)
```
Do not round-trip through the `.json` fixture for bitwise comparison; read
the `.rds` or the script's own `%.17g` console output.

## (a) n_aug_phy -- the actual integer, and the arithmetic

**Measured: `n_aug_phy = 14`** (`fit$tmb_data$n_aug_phy`, built at
`R/fit-multi.R:3175`, `n_aug_phy <- nrow(Ainv_phy_rr)`).

Arithmetic, measured directly off the tree object:
```
n_tip           = 8
tree$Nnode      = 7      (ape internal-node count, ROOT INCLUDED, for a fully
                           bifurcating rooted tree: Nnode = n_tip - 1)
n_total         = n_tip + Nnode = 15
n_aug_phy       = n_total - 1   = 14   (root is the ONE excluded node)
2*n_tip - 2     = 14   <- MATCHES
2*n_tip - 1     = 15   <- does NOT match
```
Console: `n_tip=8  tree$Nnode=7  n_total=n_tip+Nnode=15  n_aug_phy(measured)=14  2S-2=14  2S-1=15`.

Source of the arithmetic (`R/phylo-tree-precision.R:203-207`):
```r
internal_nodes <- setdiff(seq.int(info$n_tip + 1L, n_total), info$root)
included_nodes <- c(internal_nodes, seq_len(info$n_tip))
...
n_aug <- length(included_nodes)
```
`internal_nodes` = all internal-node ape ids EXCLUDING the root, i.e.
`Nnode - 1` of them; `included_nodes` appends all `n_tip` tips. So
`n_aug = (Nnode - 1) + n_tip = (n_tip - 1 - 1) + n_tip = 2*n_tip - 2`, exactly,
for any fully bifurcating rooted tree -- not "close to it depending on tree
topology" (see the contradiction noted below).

**Contradiction with the code's own comments.** `src/gllvmTMB.cpp:381` and
`src/gllvmTMB.cpp:1168` both state:
> `"n_aug_phy = 2*n_tips - 1 (or close to it depending on tree topology)"` (cpp:381)
> `"In the Stage-40 sparse-$A^{-1}$ path n_aug_phy = 2*n_tips - 1 (tips + internal nodes)"` (cpp:1168)

The measured value is **`2*n_tips - 2 = 14`**, not `2*n_tips - 1 = 15`. This is
off by exactly one node -- the root -- and is not a topology-dependent
approximation; `R/phylo-tree-precision.R:203` deterministically excludes
`info$root` from `included_nodes` for every tree. The two C++ comments are
wrong (or describe a different, non-root-excluding convention that the
current R-side builder does not implement).

## (b) Node ordering of the augmented precision

**Internal-first, tips-last** -- measured `rownames(Ainv_phy_rr)` (from
`fit$tmb_data$Ainv_phy_rr`, the exact object the C++ side reads):

```
[1] "node10" "node11" "node12" "node13" "node14" "node15" "sp1" "sp2"
[9] "sp3"    "sp4"    "sp5"    "sp6"    "sp7"    "sp8"
```

6 internal nodes (ape ids 10-15; ape id 9 is the root, excluded), then the 8
tips in `tip_order` (`tree$tip.label`, unchanged from the order used to
simulate the data). Confirmed by two independent script assertions:
`is_internal_first` (all of the first 6 names match `^node[0-9]+$`) and
`is_tips_last` (the last 8 names are `identical()` to `tip_order`); both
`TRUE`.

Source: `R/phylo-tree-precision.R:197-204`, the comment states the intent
explicitly ("Order augmented nodes internal-first, tips-last -- matching the
convention `MCMCglmm::inverseA()` used") and the code
(`included_nodes <- c(internal_nodes, seq_len(info$n_tip))`) implements it.

## (c) species_aug_id -- the actual map

**Measured** (`fit$tmb_data$species_aug_id`, 0-indexed, built at
`R/fit-multi.R:3179` `tip_to_aug <- match(levs, rownames(Ainv_phy_rr))` and
`R/fit-multi.R:3182` `species_aug_id <- tip_to_aug[species_id + 1L] - 1L`):

```
sp1 sp2 sp3 sp4 sp5 sp6 sp7 sp8
  6   7   8   9  10  11  12  13     (0-indexed augmented positions)
```

i.e. species occupy augmented positions **6 through 13** (0-indexed) / **7
through 14** (1-indexed) of the 14-row precision -- exactly the tips-last
block identified in (b). Cross-checked two independent ways in the script:
(i) directly off `fit$tmb_data$species_aug_id`, and (ii)
`.gllvm_phylo_tree_precision(tree)$tip_node_index`, which agrees:
`sp1..sp8 -> 7..14` (1-indexed). **`species_aug_id` is emphatically NOT the
identity map** onto `species_id` (which runs `0..7`) -- confirmed
`identical(species_aug_id, species_id)` is `FALSE`, the opposite of Arc 1's
dense/legacy-path finding.

## (d) log_det_A_phy_rr -- measured value and sign convention

**Measured: `log_det_A_phy_rr = -25.229441850133327`**
(`fit$tmb_data$log_det_A_phy_rr`, built at `R/fit-multi.R:3174`:
`log_det_A_phy_rr <- -phy_prec$log_det_precision   # log det A = -log det A^-1`,
where `phy_prec$log_det_precision` comes from
`R/phylo-tree-precision.R:240`: `log_det_precision = n_aug * log(scale) -
sum(log(edge_length))`).

**Sign convention: `log_det_A_phy_rr` is `+log det(A)` (the covariance's own
log-determinant), i.e. `-log det(A^{-1})`.** Verified directly against
`determinant()` of the engine's own precision matrix, not merely read off the
source:
```
determinant(Ainv_phy_rr) [= log det A^-1]   =  25.229441850133323
-determinant(Ainv_phy_rr) [= +log det A]    = -25.229441850133323
engine log_det_A_phy_rr                     = -25.229441850133327
difference                                  = -3.553e-15   (floating-point noise)
```
This is the **same sign convention as Arc 1's dense/legacy path**
(`log_det_A_phy_rr` there was also `+log det(A)`, confirmed in
`tmb-side-phylo.md` (e)) -- both routes hand the C++ side `+log det(A)`, never
`log det(A^{-1})`. Consistent, no contradiction here.

## (e) Ridge/jitter -- present or absent?

**Absent, confirmed both by reading the code path and empirically.**

Reading `R/fit-multi.R:3157-3182` (the `if (!is.null(phylo_tree))` branch):
no `+ diag(...)` or any other additive term appears anywhere in this branch.
Contrast with the legacy dense branch a few lines later
(`R/fit-multi.R:3223-3224`):
```r
Aphy <- phylo_vcv[levs, levs, drop = FALSE]
Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))    # ridge -- NOT executed on the tree route
```

Empirical confirmation (stronger than Arc 1 could achieve, because there is
no ridge to average away): a fresh, independent call to
`.gllvm_phylo_tree_precision(tree, correlation = TRUE)$precision` -- the exact
function the engine itself calls at `R/fit-multi.R:3172` -- is **bit-for-bit
`identical()`** to `fit$tmb_data$Ainv_phy_rr` (`max|diff| = 0.000e+00`, not
merely "small"). Arc 1's analogous dense-path check could only reach `< 1e-6`
agreement (because of the ridge and `solve()`'s numerical instability); here
the match is exact, which is itself evidence of "no ridge, no jitter,
nothing else added."

## (f) Tree structure saved for the Stan side

Saved in `fixture$tree_struct` (RDS; also `A`, `A_chol_upper`,
`Ainv_phy_rr_dense`, `node_labels`, `species_aug_id_map` at the top level):

| field | value / shape | source |
|---|---|---|
| `edge` | `tree$edge`, 14 x 2 (parent, child), ape 1-indexed node ids | `tree$edge` (ape) |
| `edge_length` | length 14, one per edge | `tree$edge.length` (ape) |
| `root` | **9** (ape node id) | `.gllvm_phylo_tree_precision()$root`, `R/phylo-tree-precision.R:247` |
| `height` | **1.1957974869687171** (root-to-tip distance; the `scale` applied under `correlation = TRUE`) | `...$height`, `R/phylo-tree-precision.R:247`, used at `:223,226` |
| `node_labels` | length 14, augmented order (see (b)) | `...$node_labels`, `:224` |
| `node_index` | length 15 (`n_total`); ape node id -> 1-indexed augmented position, **0 for the root** | `...$node_index`, `:205-206,242` |
| `tip_node_index` | named by tip label -> 1-indexed augmented position (`sp1->7, ..., sp8->14`) | `...$tip_node_index`, `:229-230,243` |

`Ainv_phy_rr_dense` (14x14, dense for portability) and `node_labels` are also
duplicated at the fixture's top level for convenience. `Ainv_phy_rr` itself
(sparse, dimnamed) is preserved in the `.rds` inside `tmb_data` provenance but
not separately duplicated as a sparse object in the fixture list (JSON cannot
hold a sparse `dgCMatrix`; the dense copy is exact since `n_aug_phy = 14` is
tiny).

## (g) use_phylo_rr and all other use_* flags

**Measured directly off `fit$tmb_data` (every name matching `^use_`), not
enumerated from source.** `use_phylo_rr == 1`; the other **22** flags present
are all `0`:

```
use_rr_B use_lv_B use_diag_B use_rr_W use_diag_W use_rr_B_slope
use_diag_B_slope use_propto use_diag_species use_diag_cluster2 use_equalto
use_spde use_spde_slope use_spde_dep_slope use_spde_latent_slope
use_phylo_diag use_phylo_slope use_phylo_slope_correlated
use_phylo_latent_slope use_phylo_dep_slope use_re_int use_aghq   -> all 0
use_phylo_rr                                                      -> 1
```

Confirms: loadings-only (`use_phylo_rr = 1`), no phylo diagonal companion
(`use_phylo_diag = 0`, i.e. no `Psi_phy`), no phylo slope, no augmented
latent-slope, no spatial/kernel/meta terms active. Cross-checked at the
parameter-vector level too: `theta_names` (21 entries) contains only
`b_fix` (3), `log_sigma_eps` (1), `theta_rr_phy` (3), `g_phy` (14) -- none of
`theta_rr_B, z_B, theta_diag_B, s_B, g_x, log_sd_phy_diag, g_phy_diag,
b_phy_slope, log_sigma_slope, b_phy_aug, theta_rr_phy_slope, g_phy_slope`
appear.

Source: `use_phylo_rr = as.integer(use_phylo_rr)` at `R/fit-multi.R:3734`;
`use_phylo_diag` at `:3757`; `use_phylo_slope` at `:3759`;
`use_phylo_latent_slope` at `:3765`.

## Additional check beyond the task brief: internal-node scores are genuinely live

Because the whole point of the `tree =` route is that the joint density is
now over 14 latent scores, not 8, and only the 8 TIP scores ever appear in
`eta` (`species_aug_id`, `src/gllvmTMB.cpp:2043`:
`contrib += Lambda_phy(t, k) * g_phy(species_aug_id(o), k);` -- internal nodes
are never indexed here), it is worth isolating whether an INTERNAL node's
score is a structural no-op or genuinely enters the objective (only possible
through the `A^{-1}` quadratic-form prior, `cpp:1166-1174`). Measured:

```
nll(theta)                            = 173.37932199712063
nll(theta_rr_phy[1] + 0.15)           = 188.85083972596718   (diff = +15.47151772884655)
nll(g_phy[tip sp1] + 0.5)             = 208.02888114235506   (diff = +34.649559145234434)
nll(g_phy[internal node 1] + 0.5)     = 172.59294844681526   (diff =  -0.78637355030537037)
```

All three perturbations change the objective (all `!identical()` to the
baseline) -- internal-node scores are NOT dropped from the joint density.
Note the internal-node perturbation's effect is much smaller in magnitude
(`~0.79` vs `~34.6` for a tip) and of the OPPOSITE sign (the objective
*decreases*) -- expected, since that node only appears in the `A^{-1}`
quadratic-form prior term (no `eta`/likelihood contribution at all, since no
observation reads an internal node), whereas the tip perturbation hits both
the prior AND 6 `dnorm` likelihood terms (3 traits x 2 reps for `sp1`).

## Verification performed

`tmb-side-tree.R`, all `stopifnot()` assertions passed on this run
(`Rscript dev/stan-oracle-phylo-tree/tmb-side-tree.R`, exit code 0):

- `n_aug_phy == n_total - 1` (the measured arithmetic in (a)) -- **passed**.
- Node ordering: first 6 names match `^node[0-9]+$`, last 8 equal `tip_order`
  exactly -- **passed** (both `TRUE`).
- `species_aug_id` is finite, lands exactly on the tips-last block
  (`n_internal + 0..7`), and is **not** identical to `species_id` --
  **passed**.
- `log_det_A_phy_rr` matches `-determinant(Ainv_phy_rr)` to `< 1e-8` --
  **passed** (diff `-3.553e-15`).
- `Ainv_phy_rr` (engine) is `identical()` to a fresh
  `.gllvm_phylo_tree_precision(tree, correlation = TRUE)$precision` call --
  **passed** (`max|diff| = 0`).
- `use_phylo_rr == 1`, all other (22) `use_*` flags `== 0` -- **passed**.
- `theta_names` contains no ordinary-latent, phylo-diag, phylo-slope, or
  mi-covariate blocks -- **passed**.
- `joint_obj$fn(theta)` evaluated twice, `identical()` (bitwise) -- **passed**
  (`173.37932199712063` both times).
- Perturbing `theta_rr_phy[1]` (+0.15), `g_phy` at a tip position (+0.5), and
  `g_phy` at an internal-node position (+0.5) all change the value -- **all
  three passed** (see numbers above).
- `jsonlite::write_json(..., digits = NA)` round-trip is **not** bitwise exact
  (reproduces Arc 1's finding) -- confirmed by direct RDS-vs-JSON comparison,
  not assumed from the Arc 1 report.

## Where this arc could not determine something, or found something surprising

- **The two C++ comments (`src/gllvmTMB.cpp:381`, `:1168`) claiming
  `n_aug_phy = 2*n_tips - 1` are wrong** for this measured fixture
  (`n_aug_phy = 2*n_tips - 2 = 14`, not `15`). See (a) above for the full
  arithmetic and the quoted comment text. This is off by exactly one node
  (the excluded root) for every fully bifurcating rooted tree, not a
  topology-dependent approximation as the hedge "(or close to it depending on
  tree topology)" implies.
- **`src/gllvmTMB.cpp:380`** also says the augmented `A^{-1}` "is built over
  tips + internal nodes via `MCMCglmm::inverseA(tree)`" -- this is a STALE
  comment. The actual builder is `.gllvm_phylo_tree_precision()`
  (`R/phylo-tree-precision.R`), which its own header comment states explicitly
  replaces the `MCMCglmm::inverseA` call and has "no MCMCglmm dependency."
  `MCMCglmm` is not invoked anywhere in the measured code path
  (`R/fit-multi.R:3157-3182`).
- Only `d_phy = 1` is exercised here (same limitation Arc 1 states for
  itself), so the loadings-packing / axis-ordering questions at `d_phy >= 2`
  remain untested on the tree route as well.
- Did not test `phylo_slope()`, `phylo_unique()` alongside `phylo_latent()`
  augmentation interactions, or the `mi()` phylogenetic-covariate model on
  this route -- out of scope for this arc's brief.
