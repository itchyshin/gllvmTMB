# S2 -- gllvm `colMat` reference implementation: results

Script: `dev/s2-gllvm-colmat-reference.R` (this worktree only; no gllvmTMB
package source touched). Run with `Rscript --vanilla
dev/s2-gllvm-colmat-reference.R` from the worktree root. gllvm 2.0.11,
ape 5.8.1, R 4.6.0.

## Setup (data + trees + seed)

- Simulated JSDM: `n = 30` sites, `m = 12` species, one covariate `env`.
- Seed `1` for data generation. Species slopes for `env` drawn jointly
  correlated under the true tree: `slopes_true ~ MVN(mean = 0.6, Sigma =
  1^2 * Ctrue)` where `Ctrue = cov2cor(ape::vcv(tree_true))`. Species
  intercepts `~ N(0.5, 0.3)` (uncorrelated). Response: `Y ~
  Poisson(exp(intercept_j + slope_j * env_i))`.
- `tree_true <- ape::rcoal(12, tip.label = paste0("sp", 1:12))` under
  seed 1. `tree_wrong <- ape::rcoal(12, tip.label = paste0("sp", 1:12))`
  under an independent seed (999) -- same tip-label set, unrelated
  topology/branch lengths.
- Confirmed non-trivial difference between the trees: `ape::dist.topo(tree_true,
  tree_wrong) = 18`; max abs entrywise difference between `Ctrue` and
  `Cwrong` = 0.9953.
- Data sanity: 0 zero-rows, 0 zero-columns in `Y`; range 0-366, mean
  13.4.
- Column names of `Y` and row/col names of `Ctrue`/`Cwrong` are the
  identical `sp1`...`sp12` vector, in the identical order -- required
  for `colMat` to align to `Y`'s columns.

## Two-tree test (the decisive test)

**Working recipe:** random column (species) effects are created via
**bar syntax inside the main `formula` argument** -- `formula = ~ (env |
1)` -- combined with `colMat = <correlation matrix>` and `num.lv = 0`,
`family = "poisson"`. This is *not* the literal `randomX = ~ env`
top-level argument named in the brief; see "gllvm model assumptions" §A
below for why, and the Negative control section for the empirical proof
that the literal top-level argument is inert in this gllvm version.

| | logLik | rho.sp (signal) | col.eff | dim(spdr) | time (s) | warnings |
|---|---|---|---|---|---|---|
| `tree_true`  | **-662.849670** | 0.962666 | random | 30 x 2 | 0.127 | none |
| `tree_wrong` | **-672.582973** | 0.000000 | random | 30 x 2 | 0.074 | "Phylogenetic signal parameter is on the boundary..." |

**Difference (true - wrong) = 9.733303.** The two log-likelihoods
differ, and `tree_true` scores better, as required. The correctly
specified tree also produces a non-degenerate signal estimate
(rho.sp = 0.963, well inside (0,1)), while the wrong tree's fit collapses
the signal parameter to the 0 boundary (correctly diagnosing "no
phylogenetic structure detectable" when the supplied tree does not
match the data-generating process) and emits a boundary warning.

## Negative control (required)

Two variants were run, both against the SAME two trees, to confirm
`colMat` is inert whenever there is no random column effect for it to
attach to.

**5a -- literal top-level `randomX = ~ env` argument (no bar syntax),
`formula = ~ env`, `colMat` still passed:**

| | logLik | col.eff | dim(spdr) |
|---|---|---|---|
| `tree_true`  | -613.512827 | FALSE | 1 x 1 |
| `tree_wrong` | -613.512827 | FALSE | 1 x 1 |

Difference = **0.0000000000** (bit-identical to 10 decimal places).
`col.eff` stayed `FALSE` and the column-random-effect design matrix
(`spdr`) stayed the degenerate `1 x 1` zero placeholder -- i.e. the
top-level `randomX` argument, passed alone without bar syntax in
`formula`, did not create any random column-effect structure, so
`colMat` had nothing to act on. This is the trap reproduced exactly as
warned in the brief.

**5b -- no `randomX` argument at all, plain `formula = ~ env`, `colMat`
still passed** (the literal reading of "without randomX"):

| | logLik | col.eff | dim(spdr) |
|---|---|---|---|
| `tree_true`  | -613.512827 | FALSE | 1 x 1 |
| `tree_wrong` | -613.512827 | FALSE | 1 x 1 |

Difference = **0.0000000000**. Identical in every digit to 5a, and also
identical to the no-`colMat`-at-all baseline (§E below, same
-613.512827) -- i.e. passing `colMat` when `col.eff != "random"` is
completely silently absorbed with zero effect on the fit, not just
approximately inert.

## Signal parameter

gllvm reports a phylogenetic signal parameter `rho.sp` in
`fit$params$rho.sp` whenever `col.eff == "random"` and `colMat` is
supplied (absent otherwise -- confirmed `NULL`/not-present in every
`col.eff == FALSE` fit above).

- Two-tree decisive test (`colMat.rho.struct = "single"`, default): one
  shared `rho.sp` per fit -- **0.962666** for `tree_true`, **0.000000**
  (boundary) for `tree_wrong`.
- §A1 (random intercept only): rho.sp = 0.000000 for both trees (both
  hit the boundary; a random-intercept-only model on Poisson count data
  generated with phylogenetically structured *slopes*, not intercepts,
  gives the signal parameter nothing real to detect for either tree).
- §A2 (random slope only): rho.sp = **1.000000** (upper boundary) for
  `tree_true`, 0.000000 (lower boundary) for `tree_wrong` -- consistent
  with the data being simulated with slopes at maximal phylogenetic
  signal (no independent-noise component was added to the true slopes).
- §C (`colMat.rho.struct = "term"`, per-covariate signal): two separate
  values were returned, `0.000000` and `0.000001` (both intercept and
  slope terms' signal collapsed toward the boundary in this
  particular, small-and-fast toy fit -- see caveat in §C below).

## gllvm model assumptions

Answers below are labeled **DOCUMENTED** (cites `?gllvm`,
`?getEnvironCov.gllvm`, `?getResidualCov.gllvm`, or a vignette),
**MEASURED** (this script's fitted-object numbers), or **UNRESOLVED**.

### A. Where exactly does `colMat` enter the model -- intercepts, slopes, or both?

**MEASURED, and DOCUMENTED via `?getEnvironCov.gllvm`.** `colMat` (`C`,
a species correlation matrix) enters through the covariance of
whichever term(s) are placed in the **column-effect ("col.eff") random
bar formula** -- it can be the intercept, a slope, or both, depending on
what you put in the bars. The documented formula (from
`?getEnvironCov.gllvm`, "Details"):

```
Sigma_e = kronecker(rho*C + (1-rho)*I_p, R)
```

where `C` is the species correlation matrix (colMat), `rho` the signal
parameter, `R` the covariance matrix of whatever random-effect terms
are in the bar formula (intercept, slope(s), or both jointly if
correlated), and the whole thing is further multiplied by
`kronecker(I_p, x)` for the covariate values `x`. This is a
Pagel's-lambda-style blend between the pure phylogenetic correlation and
independence, not a fixed additive structure -- so `colMat`
mathematically touches every random column-effect term present, jointly,
through one shared covariance block (or per-term blocks if
`colMat.rho.struct = "term"`; see §C).

Confirmed empirically that the tree also matters when `colMat` is
attached to intercept-only or slope-only random effects individually
(not just the combined intercept+slope model used for the main
decisive test):

| Model | `tree_true` logLik | `tree_wrong` logLik | diff |
|---|---|---|---|
| `~ env + (1\|1)` (random INTERCEPT only) | -625.554292 | -628.189687 | 2.635395 |
| `~ (0 + env\|1)` (random SLOPE only) | -654.435770 | -667.987774 | 13.552004 |

Both show a real, tree-sensitive difference, confirming `colMat` acts on
whichever column-random term(s) are present -- there is no restriction
to "intercepts only" or "slopes only"; it is determined entirely by
what the user puts inside the bar formula's random part.

### B. How many grouping levels does gllvm support for random column effects?

**MEASURED: exactly ONE.** The species/column axis is always and only
the columns of the response matrix `y` -- there is no analogue of
gllvmTMB's `unit` / `unit_obs` / `cluster` multi-level distinction. This
was tested directly: fitting `formula = ~ (env | fam)` where `fam` is an
arbitrary 3-level site covariate (not a taxonomic or species grouping)
did **not** error and did **not** create an alternative grouping axis for
the phylogenetic structure -- instead it just replicated the
species-level term block once per level of `fam`:

- `~ (env | 1)`: `dim(spdr) = 30 x 2`, `dim(Br) = 2 x 12` (2 terms
  [intercept, env] x 12 species).
- `~ (env | fam)`: `dim(spdr) = 30 x 6`, `dim(Br) = 6 x 12` (2 terms x 3
  `fam` levels = 6, still x 12 species).

In both cases `Br`'s second dimension is `12` -- the species count --
and `colMat` (dimension 12 x 12, keyed to `Y`'s column names) is the
only matrix that can ever attach to that axis. The `| <name>` syntax
resolves to a genuine crossed grouping factor for the *covariate design*
(more copies of the term), not to an alternative *species*-axis grouping
-- `mkReTrms1()` (the internal bar-formula parser) builds the design
purely from site-level covariates in `X`/`studyDesign`, and the code
path that would resolve the bar RHS to real data levels
(`grps <- unique(unlist(lapply(bar.f, all.vars)))`) is only invoked for
**row**-effect formulas, not column-effect formulas -- for column
effects the RHS is boilerplate (`bquote(1 | 1)` is even special-cased at
`gllvm.R` line ~392 as the canonical no-grouping case).

**This is a real finding, not a gap in investigation:** gllvm's API
gives no mechanism to disambiguate "put the tree on the species
random-intercept axis" vs. "on some other structured grouping of
species" -- there IS only the one axis (the columns of `y`), so the
question that would matter for gllvmTMB (which axis?) simply does not
arise in gllvm. `colMat`'s row/col names must match `colnames(y)`
exactly, and that is the entirety of the species-identity binding.

### C. What is assumed about the phylogenetic signal parameter?

**DOCUMENTED** (`?getEnvironCov.gllvm`, and mirrored in `?gllvm`'s
`colMat.rho.struct` entry): default `colMat.rho.struct = "single"` fits
**one shared** signal parameter `rho` for all column-random-effect terms
combined (equation in §A above). `colMat.rho.struct = "term"` instead
fits **one `rho` per covariate/term**, via a documented block-diagonal
Cholesky form:

```
Sigma_e = kronecker(x_i', I_m) %*% bdiag(L_k) %*% kronecker(Sigma_r, I_m) %*% bdiag(L_k') %*% kronecker(x_i, I_m)
```

where `bdiag(L_k)` is a block-diagonal matrix of per-covariate lower-
triangular Cholesky factors `L_k` (each `L_k` built from that
covariate's own `rho_k*C + (1-rho_k)*I` blend).

**MEASURED**, `colMat.rho.struct = "term"` on the two-term
(intercept+env) model returned two `rho.sp` values (0.000000 and
0.000001) rather than one -- confirming the per-term parameterization is
live, though in this particular toy fit both terms' estimates collapsed
near the boundary (this run used the small default `reltol` toy setup
and `nn.colMat = m` to force an exact rather than NNGP-approximated
inverse for only 12 species -- the near-zero pair should not be read as
a general property of the per-term mode, just this one fit's numbers;
a larger/better-powered fit was out of scope here).

### D. Is there a residual/observation-level species covariance in gllvm, and can `colMat` act on it?

**DOCUMENTED** (`?getResidualCov.gllvm`): the "residual covariance"
gllvm reports is `Theta %*% t(Theta) [+ Psi]`, i.e. it comes from the
`num.lv` (or `num.lv.c`/`num.RR`) latent-variable ordination loadings,
plus a diagonal dispersion-adjustment `Psi` for negative-binomial/
binomial/gaussian families. `colMat` is documented and coded as a
property of the **column-effect random slopes/intercepts only**
(`?getEnvironCov.gllvm`'s "Species covariance matrix due to the
environment" -- a distinct, separately-computed matrix from
`getResidualCov`) -- there is no code path connecting `colMat` to the
`Theta Theta'` ordination covariance.

**MEASURED** confirmation with `family = "gaussian"`, `num.lv = 0`, no
random column effect: `fit$params` contained only `beta0`, `Xcoef`,
`phi` -- `phi` is a length-12 (`= m`) vector of **per-species scalar**
standard deviations (0.358-0.544), with no off-diagonal covariance term
present anywhere in the returned object. For Poisson/binomial families
there is no free dispersion parameter at all when `num.lv = 0`, so there
is no residual covariance mechanism of any kind for `colMat` to attach
to -- confirming the premise in the brief: a tree cannot structure a
residual covariance that does not exist for these families absent
latent variables.

### E. Row/column effect structure -- fixed vs. random species intercepts by default

**MEASURED.** With no bar syntax, no `randomX`, and no `colMat`
(`formula = ~ env`, `X = data.frame(env=...)`), gllvm's returned
`params` were `beta0` (length 12, one **per species**) and `Xcoef`
(length 12, also one **per species**) -- both fixed, independent,
unpenalized per-species scalars, with no shared/community mean and no
covariance structure between species. The fitted `Xcoef` values (2.19,
1.83, 1.88, 1.81, 1.77, 1.62, 2.07, 1.70, 1.67, 1.88, 2.23, 0.17) closely
recover the true simulated slopes (2.17, 1.81, 1.73, 1.81, 1.73, 1.61,
2.15, 1.75, 1.61, 1.86, 2.31, 0.19) -- i.e. even the "no random effects
at all" baseline already fits fully species-specific slopes and
intercepts by default (gllvm's `X`/`formula` interface is inherently a
saturated fourth-corner-style per-species fit, not a single
community-common slope), it is simply not *correlated* across species
and has no home for `colMat` to attach to. Switching any term in the
formula into the bar/random part (`col.eff == "random"`) replaces that
term's fixed per-species parameter with a **community-mean + correlated
per-species deviation** decomposition (`B` + `Br`, with `Br`'s
across-species covariance structured by `colMat` per §A) -- and this
switch is the one and only thing that gives `colMat` something to act
on. This directly explains why §E's baseline logLik (-613.512827) is
bit-identical to both negative-control variants (5a, 5b) above: with
`col.eff == FALSE`, `colMat` is parsed and stored but never enters the
likelihood at all, regardless of whether it is even supplied.

## Warnings verbatim

All warnings across every fit in the script (none were grepped away or
suppressed; captured via `withCallingHandlers`/`invokeRestart`):

- Two-tree test, `tree_true`: (none)
- Two-tree test, `tree_wrong`: `"Phylogenetic signal parameter is on the
  boundary. Considering trying a different optimizer or increasing the
  convergence tolerance ('reltol')."`
- Negative control 5a (`tree_true`, `tree_wrong`): (none)
- Negative control 5b (`tree_true`, `tree_wrong`): (none)
- §A1 intercept-only, `tree_true`: `"Phylogenetic signal parameter is on
  the boundary...."` (same message)
- §A1 intercept-only, `tree_wrong`: same boundary warning
- §A2 slope-only, `tree_true`: same boundary warning
- §A2 slope-only, `tree_wrong`: same boundary warning
- §B `(env | fam)`: same boundary warning
- §C `colMat.rho.struct = "term"`: same boundary warning
- §D gaussian baseline: (none)
- §E fixed-only baseline: (none)
- (Outside the main fits, generating `tree_wrong`/`dist.topo` triggered
  a base-`ape` warning: `"Some trees were rooted: topological distances
  may be spurious."` -- informational only, both `rcoal()` trees are
  rooted coalescent trees by construction, this does not affect the
  `colMat`/`vcv()` correlation matrices used for fitting.)

No warnings were dropped, muffled without recording, or grepped away.

## Verdict

**REFERENCE WORKING.**

The decisive test (`formula = ~ (env | 1)` + `colMat`, `num.lv = 0`,
`family = "poisson"`) produces log-likelihoods that differ between
`tree_true` (-662.849670) and `tree_wrong` (-672.582973) by 9.733303,
with `tree_true` scoring better and yielding a well-identified signal
parameter (rho.sp = 0.963) versus `tree_wrong` collapsing to the
boundary (rho.sp = 0.000, with gllvm's own boundary warning) -- exactly
the qualitative signature expected of a working phylogenetic
column-effect fit.

The literal top-level `randomX = ~ env` argument named in the brief is
**not** the mechanism that creates this effect in gllvm 2.0.11: passed
alone (without bar syntax in `formula`), it leaves `col.eff == FALSE`
and produces bit-identical logLik (-613.512827, to 10 decimals) for both
trees -- reproducing the trap exactly. The working mechanism is bar
syntax inside the main `formula` argument (`~ (env | 1)`, matching the
package's own phylogenetic vignette, `vignette7.Rmd`/`vignette("gllvm ->
Phylogenetic random effects")`), which sets `col.eff <- "random"`
internally and builds a real (non-degenerate) design matrix for
`colMat` to attach to.
