# S10: phylo_dep() tree-discrimination replication

Generated: 2026-07-25 14:20:18 MDT

Package loaded via `devtools::load_all()` from this worktree (`/Users/z3437171/local-scratch/worktrees/gllvmtmb-phylodep-seeds`), NOT an installed build. Script: `dev/s10-phylodep-seed-replication.R`. Seeds are fixed and deterministic per replicate; re-running this script from a clean checkout with the same `S10_NREPS` reproduces every number below.

## Question replicated

A single S0 realization (`dev/s0-rederive-two-tree.R`, experiment E1c) found
`phylo_dep(0 + trait | species, tree = tree_X)` scored the TRUE tree (tree_A)
WORSE (logLik 46.834572) than two WRONG trees (tree_B: 49.776670, tree_C:
49.360143), in the JSDM Site x Species layout. This script replicates that
single draw across independent data realizations under the SAME fixed tree_A
(true) / tree_B / tree_C (wrong) trio, to determine whether the true tree
loses SYSTEMATICALLY or that was noise.

## Design

- `n_reps` = 20, each with its own fixed seed (main-arm z: 5000+i, main-arm noise: 6000+i, positive-control z: 7000+i, positive-control noise: 8000+i).
- Trees are FIXED across replicates (identical construction to S0: `ape::rcoal(10)`
  under seeds 101/202/303 for tree_A (TRUE) / tree_B (wrong) / tree_C (wrong)).
  Only the data draws vary by replicate.
- **Main + control arm** (JSDM layout, E1-style): `unit = site` (30 levels),
  `trait` = species identity (10 levels), intercept-only fixed formula so the
  phylo variance is well-identified (matches S0's deconfounded E1b/E1c design,
  not the collinear E1a naive formula). Per replicate: one shared draw
  `z_sp ~ MVN(0, 4*A_true(tree_A))` broadcast across sites, plus
  `N(0, 0.2^2)` row noise. The SAME generated dataset is fit under
  `phylo_dep(0 + trait | species, tree = tree_X)` (main) and
  `phylo_indep(0 + trait | species, tree = tree_X)` (control), for each of
  the 3 trees.
- **Positive control** (transposed layout, E3-style): `unit = species` (10
  levels), 6 pseudo-traits, fixed loadings `c(1.0, -0.8, 0.6, 0.9, -0.5, 0.7)`,
  `z_sp ~ MVN(0, A_true(tree_A))`, `N(0, 0.3^2)` noise, fit with
  `phylo_latent(species, d = 1, tree = tree_X)` for each of the 3 trees.
- Species count fixed at 10 throughout (matching S0's scale); the optional
  species-count sweep (6/10/20) in the task brief item 6 was SKIPPED to stay
  inside the local runtime budget -- see Runtime below.

## Runtime

Total wall time for 20 replicates x 3 trees x 3 fit-types (dep + indep + positive-control latent) = 180 fits: **50.9 sec (0.85 min)**.

## Control arm (phylo_indep) -- checked FIRST per task instructions

S0 proved `phylo_indep()` is a structural no-op in this exact JSDM layout (tree never enters the likelihood). If that does not replicate as an exact tie here, the harness is suspect and the phylo_dep numbers below are not trustworthy.

- Replicates: 20 total, 0 discarded for non-convergence/error, 20 usable.
- All usable replicates numerically tied across trees (max abs logLik diff < 1e-4): **TRUE** (20 / 20 tied).

**Control arm verdict: PASSED (tree is a confirmed no-op for phylo_indep on every usable replicate).**

#### Per-replicate detail -- phylo_indep (control)

| rep | usable | best tree | true is best | delta (true - best wrong) | max abs logLik diff |
|---|---|---|---|---|---|
| 1 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 2 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 3 | TRUE | tree_B | FALSE | -0.000000 | 0.000000 |
| 4 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 5 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 6 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 7 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 8 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 9 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 10 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 11 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 12 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 13 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 14 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 15 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 16 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 17 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 18 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 19 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |
| 20 | TRUE | tree_C | FALSE | -0.000000 | 0.000000 |

## Positive control (transposed layout, phylo_latent)

S0 showed the true tree wins decisively in this layout (true -8.730365 vs wrong -28.430023). If the true tree does NOT win at a high rate here, the harness cannot be shown to detect a real phylogenetic effect and nothing else in this report is interpretable.

- Replicates: 20 total, 0 discarded for non-convergence/error, 20 usable.
- TRUE tree best logLik in 18 / 20 usable replicates (proportion = 0.900).
- Mean (logLik_true - logLik_best_wrong) = 3.027532, SD = 2.286387.

**Positive control verdict: PASSED (true tree wins at a high rate).**

#### Per-replicate detail -- positive control (phylo_latent, transposed)

| rep | usable | best tree | true is best | delta (true - best wrong) | max abs logLik diff |
|---|---|---|---|---|---|
| 1 | TRUE | tree_A | TRUE | 6.740334 | 7.751417 |
| 2 | TRUE | tree_A | TRUE | 2.440374 | 6.463099 |
| 3 | TRUE | tree_A | TRUE | 2.301460 | 9.117053 |
| 4 | TRUE | tree_A | TRUE | 3.380302 | 7.286443 |
| 5 | TRUE | tree_A | TRUE | 5.333760 | 7.712352 |
| 6 | TRUE | tree_A | TRUE | 2.717001 | 3.361944 |
| 7 | TRUE | tree_A | TRUE | 1.588256 | 3.858262 |
| 8 | TRUE | tree_A | TRUE | 0.930464 | 3.917497 |
| 9 | TRUE | tree_A | TRUE | 1.420082 | 4.415141 |
| 10 | TRUE | tree_A | TRUE | 2.666657 | 3.008186 |
| 11 | TRUE | tree_A | TRUE | 4.941165 | 6.264617 |
| 12 | TRUE | tree_A | TRUE | 5.698548 | 6.121430 |
| 13 | TRUE | tree_A | TRUE | 1.448717 | 1.846565 |
| 14 | TRUE | tree_A | TRUE | 3.222141 | 3.542760 |
| 15 | TRUE | tree_B | FALSE | -0.743409 | 6.408902 |
| 16 | TRUE | tree_C | FALSE | -0.292803 | 6.102677 |
| 17 | TRUE | tree_A | TRUE | 1.938192 | 2.238410 |
| 18 | TRUE | tree_A | TRUE | 1.663205 | 5.194191 |
| 19 | TRUE | tree_A | TRUE | 5.330818 | 6.962120 |
| 20 | TRUE | tree_A | TRUE | 7.825380 | 8.454750 |

## Main result: phylo_dep(), JSDM layout

- Replicates: 20 total, 0 discarded for non-convergence/error (discard rate = 0.0%), 20 usable.
- **TRUE tree (tree_A) achieved the best logLik in 0 / 20 usable replicates (proportion = 0.000).** Chance level with 3 trees is ~0.333.
- Signed (logLik_true - logLik_best_wrong): mean = -2.671772, SD = 0.746477 (negative mean means the true tree systematically scores WORSE than the best wrong tree).
- No replicates discarded.

#### Per-replicate detail -- phylo_dep (main)

| rep | usable | best tree | true is best | delta (true - best wrong) | max abs logLik diff |
|---|---|---|---|---|---|
| 1 | TRUE | tree_C | FALSE | -3.268831 | 3.268831 |
| 2 | TRUE | tree_C | FALSE | -3.132534 | 3.132534 |
| 3 | TRUE | tree_C | FALSE | -1.940925 | 1.940925 |
| 4 | TRUE | tree_C | FALSE | -4.336111 | 4.336111 |
| 5 | TRUE | tree_B | FALSE | -1.867803 | 1.867803 |
| 6 | TRUE | tree_C | FALSE | -2.412012 | 2.412012 |
| 7 | TRUE | tree_C | FALSE | -1.907879 | 2.041599 |
| 8 | TRUE | tree_B | FALSE | -2.378660 | 2.378660 |
| 9 | TRUE | tree_C | FALSE | -2.513847 | 2.513847 |
| 10 | TRUE | tree_C | FALSE | -2.296718 | 2.296718 |
| 11 | TRUE | tree_C | FALSE | -2.169626 | 2.169626 |
| 12 | TRUE | tree_C | FALSE | -3.559101 | 3.559101 |
| 13 | TRUE | tree_C | FALSE | -1.228710 | 1.228710 |
| 14 | TRUE | tree_C | FALSE | -2.753412 | 2.753412 |
| 15 | TRUE | tree_C | FALSE | -2.954749 | 2.954749 |
| 16 | TRUE | tree_C | FALSE | -3.360434 | 3.742427 |
| 17 | TRUE | tree_C | FALSE | -3.602290 | 3.648240 |
| 18 | TRUE | tree_C | FALSE | -2.851962 | 2.851962 |
| 19 | TRUE | tree_C | FALSE | -2.942776 | 2.942776 |
| 20 | TRUE | tree_C | FALSE | -1.957069 | 1.957069 |

## Warnings and messages -- verbatim, unfiltered

Every warning/message from every one of the 180 fits was captured via `withCallingHandlers` (never suppressed at the point it fired). Identical repeated text is deduplicated below for readability with an explicit repeat count `[xN]` -- nothing is filtered by content or grepped away.

```
(no warnings or messages captured from any fit)
```

## Errors

```
(no errors -- every fit call returned a value)
```

## VERDICT

**SYSTEMATIC -- the true tree does not win more often than chance (~1/3 with 3 trees); the S0 single-draw result replicates as a repeatable pattern, not noise.**

Numbers: phylo_dep true-tree-wins proportion = 0.000 (0/20 usable reps); control arm all-tied = TRUE; positive-control true-tree-wins proportion = 0.900 (18/20 usable reps); mean signed delta (true - best wrong) for phylo_dep = -2.671772 (SD 0.746477).

---

## CORRECTION — D-43 adversarial re-execution panel, 2026-07-25

The 20-replicate result above reproduces **bit-for-bit** on re-run
(0/20, mean -2.671772, SD 0.746477; control 20/20 tied; positive control 18/20),
and the harness survived the legitimacy checks: all three tree-fits are
genuinely equal-parameter (df = 57, `length(opt$par)` = 57) and all three trees
are ultrametric with `vcv(corr = TRUE)` normalising height away.

**But the headline framing is overclaimed, on two counts.**

**1. A tree-identity confound inflates the effect.** Rotating WHICH tree
generates the data gives true-tree wins of 0/10, 1/10, 3/10 for truths A, B, C.
`tree_A` wins **0 of 30** fits under every truth, including when it is wrong.
Among the 16 replicates where the true tree lost under truths B and C, `tree_A`
won 0 where exchangeability predicts ~8 (p ~ 1.5e-5). `tree_A` carries a fitting
disadvantage tied to its identity, and `tree_A` is the designated true tree
throughout the main arm. The effect survives in weakened form -- aggregate
**4/30 = 0.133 vs chance 0.333, p ~ 0.004** -- but "0/20" and "mean delta -2.67"
describe the worst-case cell, not the effect. Truth = `tree_C` sits at exactly
chance, delta -0.94.

**2. The proposed mechanism is UNSUPPORTED.** The saturation hypothesis (a free
m(m+1)/2 Sigma absorbing what A should explain) predicts the effect scales with
species count. The m-sweep is non-monotone and REVERSES at m = 15 -- true-tree
wins 0/10, 0/10, **6/10**, 0/10 for m = 5/10/15/20 (mean delta -1.31, -2.61,
**+0.77**, verified twice). A star tree (A = I) also scores far worse
(29.95 vs 41-44), pointing opposite to the hypothesis. Reported as a lead only:
because `trait` == `species` in this layout the effective covariance is the
Hadamard `Sigma o A`, not `Sigma x A` -- equal parameter counts but unequal
family richness. The panel's direct richness test failed twice and it drew no
conclusion; neither do we.

**3. "No warnings or messages captured from any fit" is no longer true.** On the
integration branch 60 warnings fire, all on the `phylo_indep` control arm, from
the diagnostic shipped in `a1b9b23e` ("every level of `trait` is observed for at
most one level of `species`"). This corroborates the control-arm diagnosis, but
it means the main arm runs in a layout the package now flags as structurally
degenerate for the sibling keyword.

**Status: phenomenon real, mechanism unsupported, wording overclaimed.** Nothing
is promoted to the validation-debt register or any public surface.
