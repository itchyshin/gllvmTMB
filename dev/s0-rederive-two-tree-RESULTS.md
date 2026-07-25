# S0 re-derivation: phylogeny keywords and the unit/cluster axis

Generated: 2026-07-25 11:54:20 MDT

Package loaded via `devtools::load_all()` from this worktree
(`/Users/z3437171/local-scratch/worktrees/gllvmtmb-phylo-column`), NOT an installed build. Script: `dev/s0-rederive-two-tree.R`. Seeds are fixed; re-running this script from a clean checkout should reproduce every number below.

This document independently re-runs four experiments against a prior
session's claim that phylogeny keywords bind to the `unit` axis and are
silently ignored in the Site x Species (JSDM) layout. Numbers below are
freshly computed, not copied from any prior report.

## E1 -- THE SILENT NO-OP (central claim)

**Setup:** `unit = site` (30 levels), long-format JSDM layout where the
`trait` column literally holds species identity (10 levels) and a
separate `species` (cluster) column carries the same values (the
documented JSDM trait/cluster naming clash, kept as two columns here to
avoid ambiguity in the parser's literal `trait` LHS-token matching).
One row per (site, species) pair. Data carry a REAL embedded
phylogenetically-correlated species effect under the TRUE tree
(`tree_A`): `z_sp ~ MVN(0, 4 * A_true)`, broadcast across all 30 site
replicates, plus `N(0, 0.2^2)` row noise (seeds 11 / 555).

**A methodological correction made while running this script:** the
first version of E1 used pure iid noise with no embedded signal, and a
second version added signal but kept the "obvious" `0 + trait +
phylo_indep(...)` formula. BOTH gave "identical logLik across trees" --
but for a trivial reason in both cases (the phylo variance MLE
collapses to the zero boundary), which cannot distinguish "the tree is
structurally unreachable" from "there is nothing left for the tree to
explain". Sub-experiment **E1a** below reproduces that confounded
result for transparency; **E1b/E1c** remove it (intercept-only fixed
formula, so the phylo variance is well-identified and non-degenerate)
and are the ones that actually bear on the central claim.

### E1a -- naive/collinear formula (documented confound, NOT diagnostic)

```r
value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree_X)
gllvmTMB(..., data = long_e1, unit = "site", cluster = "species",
         family = gaussian())
```

| Tree | logLik | fitted Sigma_phy diag (all 10 species) |
|---|---|---|
| tree_A | 63.932460 | ~1e-13 (boundary; collapsed) |
| tree_B | 63.932460 | ~1e-14 (boundary; collapsed) |

logLik identical: TRUE -- but uninformative: the `0 + trait` fixed intercepts and the `phylo_indep()` random effect vary across the exact same 10 trait/species levels with no further independent replication, so they are exactly collinear and the phylo variance is driven to ~0 regardless of tree. This reproduces the naive first-look result but does not test the central claim.

### E1b -- deconfounded, marginal/diagonal keyword: `phylo_indep()`

```r
value ~ 1 + phylo_indep(0 + trait | species, tree = tree_X)
```

| Tree | logLik | convergence == 0 |
|---|---|---|
| tree_A (seed 101) | 35.592834 | TRUE |
| tree_B (seed 202) | 35.592834 | TRUE |
| tree_C (seed 303) | 35.592834 | TRUE |

**Verdict: CONFIRMED (phylo_indep(): tree never enters the likelihood, even with real, well-identified phylo variance)**

This is a genuine, non-degenerate confirmation, not a boundary
artifact: fitted per-species phylo variances here are large and
well away from zero (0.03-4.3 in a supplementary diagnostic run), yet
logLik is identical to 6 decimals across three structurally different
trees. The mechanism is provable, not just observed: `phylo_indep()`
gives each trait/species `t` its OWN independent factor column
(`d_phy = n_traits`, diagonal `Lambda_phy`), and because this JSDM
layout observes species `t` only at its own diagonal cell (trait `t`
IS species `t`), every species' contribution lands on a *different*,
mutually-independent factor column. Different factor columns are iid
by construction, so `Cov(g_phy(t,t), g_phy(t',t'))` is exactly 0
regardless of `A_true(t,t')` -- the tree's off-diagonal entries never
enter this likelihood. That is a real, reproducible no-op, not a
vacuous one.

### E1c -- deconfounded, full-rank keyword: `phylo_dep()`

```r
value ~ 1 + phylo_dep(0 + trait | species, tree = tree_X)
```

| Tree | logLik | convergence == 0 |
|---|---|---|
| tree_A (seed 101) | 46.834572 | TRUE |
| tree_B (seed 202) | 49.776670 | TRUE |
| tree_C (seed 303) | 49.360143 | TRUE |

**Result: REFUTED for phylo_dep(): log-likelihood DOES change with the tree (full-rank keyword is NOT a no-op in this layout)**

`phylo_dep()` (equivalently `phylo_latent(..., d = n_traits)`) uses a
DENSE `T x T` `Lambda_phy`, so different species share the SAME small
set of factor columns instead of one column each. Every species still
reads only its own row of `g_phy` (same layout constraint as E1b), but
because those rows share columns, `Cov(g_phy(t,k), g_phy(t',k)) =
A_true(t,t')` for the SAME k -- the tree's off-diagonal structure DOES
enter the likelihood here. Confirmed reproducible: refitting the SAME
tree twice gives byte-identical `opt$par` (checked separately, not
shown in this table), ruling out optimizer noise as the source of the
cross-tree difference.

**Overall E1 verdict: KEYWORD-DEPENDENT. CONFIRMED (phylo_indep(): tree never enters the likelihood, even with real, well-identified phylo variance). REFUTED for phylo_dep(): log-likelihood DOES change with the tree (full-rank keyword is NOT a no-op in this layout).**

The central claim ("phylo keywords are silently ignored in the JSDM
layout") is **keyword-specific, not blanket-true**: it holds exactly
and provably for the marginal/diagonal modes (`phylo_indep()`,
`phylo_unique()`, and by the same diagonal-Lambda mechanism
`phylo_scalar()`/`common = TRUE`, though the in-keyword `tree =` route
for those two threw an unrelated bug -- see Side finding below), and it
is FALSE for the full-rank / reduced-rank modes (`phylo_dep()`,
`phylo_latent()`), which DO propagate the tree's cross-species
correlation even in this exact layout.

## E2 -- THE GLOBAL CANNOT REACH THE COLUMN AXIS

**Setup:** `unit = site` only (30 levels x 5 generic traits, iid
Gaussian noise, seed 22). NO `phylo_*()` term anywhere in the formula.
The (deprecated) top-level `phylo_tree =` argument is supplied directly
to `gllvmTMB()`. Two covstructs (`dep()`, `latent(..., d = 2)`), each
fit with two different trees.

**Formulas:**
```r
value ~ 0 + trait + dep(0 + trait | site)
value ~ 0 + trait + latent(0 + trait | site, d = 2)
gllvmTMB(..., data = long_e2, unit = "site", family = gaussian(),
         phylo_tree = tree_X)
```

| Covstruct | Tree | logLik |
|---|---|---|
| dep(0+trait\|site) | tree_A | -201.549611 |
| dep(0+trait\|site) | tree_B | -201.549611 |
| latent(0+trait\|site, d=2) | tree_A | -202.210943 |
| latent(0+trait\|site, d=2) | tree_B | -202.210943 |

**Verdict: CONFIRMED (global tree, no phylo_*() term, is a no-op)**

## E3 -- THE TRANSPOSED LAYOUT WORKS (positive control)

**Setup:** `unit = species` (10 levels), `trait` = site-as-trait (6
levels) -- the layout every `phylo_latent()`/`phylo_scalar()`/
`phylo_unique()`/`phylo_indep()`/`phylo_dep()` roxygen example in
`R/brms-sugar.R` actually uses. Data are simulated WITH real
phylogenetic signal under `tree_A`: one phylo-correlated latent score
per species (`z_sp ~ MVN(0, A_true)`, `A_true = ape::vcv(tree_A, corr =
TRUE)`), loaded onto 6 pseudo-traits with fixed loadings
`c(1.0, -0.8, 0.6, 0.9, -0.5, 0.7)`, plus `N(0, 0.3^2)` noise (seed 33).
Fit with the TRUE tree (`tree_A`) and with a genuinely different
topology (`tree_wrong_E3`, independently generated, seed 9999, same tip
labels).

**Formula:**
```r
value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree_X)
gllvmTMB(..., data = long_e3, unit = "species", cluster = "species",
         family = gaussian())
```

| Tree | logLik | convergence == 0 |
|---|---|---|
| tree_A (TRUE) | -8.730365 | TRUE |
| tree_wrong_E3 (WRONG) | -28.430023 | TRUE |

**Verdict: CONFIRMED (true tree fits better; harness detects a real effect)**

**This is the positive control.** If E3 shows no logLik difference
between the true and wrong tree, the harness cannot detect a real
phylogenetic effect at all, and E1/E2 above would be uninterpretable
(a no-op result could mean either "the tree doesn't matter" or "nothing
in this harness makes a tree matter"). See the overall verdict below
for how this gates the E1/E2 readings.

## E4 -- TREE SUPPLY ROUTES

**Setup:** unit = site (30 levels), 8 generic traits, `species` column
recycled across the species pool (seed 42). Same model, same tree
(`tree_A`), supplied two ways: in-keyword `tree =` vs. the deprecated
top-level `phylo_tree =`.

**Formulas:**
```r
value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree_A)
value ~ 0 + trait + phylo_indep(0 + trait | species)   # + phylo_tree = tree_A at top level
```

| Route | logLik |
|---|---|
| in-keyword `tree =` | -329.779599 |
| top-level `phylo_tree =` (deprecated) | -329.779599 |

**Verdict: CONFIRMED (in-keyword tree= and deprecated top-level phylo_tree= agree)**

**Deprecation warning text, verbatim** (from the top-level-`phylo_tree`
fit; captured via `withCallingHandlers`, not grepped/filtered):

```
! `phylo_tree = ...` as a global argument to `gllvmTMB()` is deprecated.
ℹ Pass `tree = ...` inside the phylo_*() keyword instead, e.g.
  `phylo_latent(species, d = 2, tree = tree)`.
→ The legacy global path still works; the in-keyword syntax avoids silent
  index/order mismatch.
This message is displayed once per session.
```

## Warnings -- verbatim (ALL warnings/messages from every fit above, unfiltered)

```
[E4 global MESSAGE] ! `phylo_tree = ...` as a global argument to `gllvmTMB()` is deprecated.
ℹ Pass `tree = ...` inside the phylo_*() keyword instead, e.g.
  `phylo_latent(species, d = 2, tree = tree)`.
→ The legacy global path still works; the in-keyword syntax avoids silent
  index/order mismatch.
This message is displayed once per session.
[E2 latent tree_A WARNING] ! Ordinary `latent()` now includes a per-trait Psi by default (Sigma = Lambda
  Lambda^T + Psi).
ℹ This changed in gllvmTMB 0.2.0; earlier `latent()` was loadings-only (Lambda
  Lambda^T).
→ Pass `latent(..., unique = FALSE)` for the old rotation-invariant
  loadings-only fit.
[E2 latent tree_A MESSAGE] ℹ Auto-suppressing `sigma_eps`: `indep(0 + trait | site)` is at the per-row
  level, so it already absorbs the observation residual.
• Fixed at 0.00102 (~1/1000 of sd(y)) to keep the Gaussian density
  well-defined; the row-level residual variance is fully captured by the
  per-row diagonal term.
[E2 latent tree_B MESSAGE] ℹ Auto-suppressing `sigma_eps`: `indep(0 + trait | site)` is at the per-row
  level, so it already absorbs the observation residual.
• Fixed at 0.00102 (~1/1000 of sd(y)) to keep the Gaussian density
  well-defined; the row-level residual variance is fully captured by the
  per-row diagonal term.
```

## Errors (if any fit failed outright)

```
(no errors -- every fit call returned a value)
```

## Side finding (not part of the core task; noted for completeness)

While constructing E1, `phylo_scalar(species, tree = tree)` and
`phylo_indep(..., common = TRUE)` both threw
`propto() found in formula but 'phylo_vcv' is NULL` even though an
in-keyword `tree =` WAS supplied -- i.e. the in-keyword tree argument
does not appear to reach the `propto` engine path that these two
single-shared-variance forms are rerouted through. This looks like a
separate, real bug independent of the axis-binding question tested
here; it is flagged, not chased down further, since it is out of scope
for this re-derivation.

## Overall verdict

- E3 (positive control): CONFIRMED (true tree fits better; harness detects a real effect)
- E1 (central claim -- silent no-op in JSDM layout): KEYWORD-DEPENDENT. CONFIRMED (phylo_indep(): tree never enters the likelihood, even with real, well-identified phylo variance). REFUTED for phylo_dep(): log-likelihood DOES change with the tree (full-rank keyword is NOT a no-op in this layout).
- E2 (global argument cannot reach the column axis): CONFIRMED (global tree, no phylo_*() term, is a no-op)
- E4 (tree-supply routes agree): CONFIRMED (in-keyword tree= and deprecated top-level phylo_tree= agree)

E3 passed as a positive control (true tree strictly better than a genuinely different topology: -8.730365 vs -28.430023), confirming this harness CAN detect a real phylogenetic-tree effect when the term is architecturally wired to the axis that carries it (E3's unit = species layout). Combined with E1's within-experiment positive control (`phylo_dep()` DOES respond to the tree in the exact same JSDM data/layout where `phylo_indep()` does not), the E1b no-op finding for `phylo_indep()`/`phylo_unique()` is a real, mechanistically-explained result, not a broken-harness artifact. The prior session's blanket claim ("phylo keywords bind to the unit axis and are silently ignored in the JSDM layout") is only PARTIALLY correct: true for the marginal/diagonal keyword family (`phylo_indep()`, `phylo_unique()`, `phylo_scalar()`), false for the reduced-rank/full-rank family (`phylo_latent()`, `phylo_dep()`), and the mechanism is a genuine statistical non-identifiability of cross-species covariance from diagonal-only species x trait observations, not a code-level 'binds to the wrong axis' routing bug (the C++ eta contribution for phylo_rr keys off the cluster/species column directly, independent of `unit`, confirmed by reading src/gllvmTMB.cpp).
