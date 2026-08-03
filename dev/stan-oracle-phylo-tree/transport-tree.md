# Declared transport — TMB `tree =` augmented-sparse path → Stan oracle

Role: Gauss (numerical reviewer), orchestrated. Date: 2026-08-03.
Worktree: `/Users/z3437171/local-scratch/worktrees/stan-phylo-tree` @ `dbd0b2d5`.
Toolchain: R 4.6.0 · TMB 1.9.21 · rstan 2.32.7 · ape 5.8.1 · Matrix 1.7.5.

Model: `value ~ 0 + trait + phylo_latent(species, d = K, tree = tree)`, Gaussian identity,
loadings-only (`unique = FALSE`), **canonical `tree =` augmented-sparse route**.

Predecessor: `dev/stan-oracle-phylo/reconciliation-phylo.md` (Arc 1), which covered the
**dense/legacy `vcv =`** route only. Its §10 eight-rule transport is the starting point; this
document records which rules carry over, which are **void**, and which are **replaced**.

> **Chronology.** This file and `gllvm_phylo_tree.stan` are committed **before** any
> TMB-vs-Stan comparison is run. Arc 1 §11.3 found that arc's transport was *claimed* derived
> a priori while the file timestamps showed otherwise. Here the git commit order is the
> evidence, not a prose claim. The Stan model was additionally written by a **separate agent
> forbidden to read `src/` or `R/fit-multi.R`**, so the fence is structural rather than a
> matter of one author's self-restraint.

---

## 1. What changes from Arc 1, at a glance

| Arc 1 rule (dense `vcv =`) | status here | why |
|---|---|---|
| 1. `mu = b_fix`, trait-level order | **carries over** | fixed-effect block is unchanged by the phylo route |
| 2. `sigma_eps = exp(log_sigma_eps)`, an **SD** | **carries over** | residual block unchanged |
| 3. `Lambda = theta_rr_phy`, identity (no `exp`), diag-first then strict lower triangle, upper triangle exactly 0 | **carries over** | loadings packing is route-independent |
| 4. `G[s,k] = g_phy[s,k]`, column-major, **level-fastest** | **carries over in form** | but the row index is now an **augmented node**, not a species |
| 5. `A` is the **covariance**; engine stores its inverse | **replaced** | the engine never forms or inverts `A` here; it assembles the precision analytically from branch lengths |
| 6. **`A → A + 1e-8·I` ridge** | **VOID** | this route applies **no ridge at all** (`R/fit-multi.R:3172-3175`; contrast `:3224`) |
| 7. `log\|A\|` = `+log det(A + 1e-8 I)` | **replaced** | `log_det_A_phy_rr = −log_det_precision` (`R/fit-multi.R:3174`) |
| 8. species index = factor-level order, identity map | **replaced** | a genuine two-step map: factor level → tip label → augmented position |

**Void rule 6 is the headline difference.** Because the dense route perturbs `A` and this route
does not, the two routes do **not** agree with each other to better than the ridge's effect —
measured at 3.4e-07 on `rcoal(30)` (§5). Arc 1 §8 bounded that effect at ~6.6e-07 (`rcoal(8)`)
to ~2.4e-05 (`rcoal(200)`). Negligible for inference; material for verification.

---

## 2. The augmented node set — MEASURED

All values below are measured on the fixture tree (`set.seed(20260803L); ape::rcoal(8)`,
tips relabelled `sp1..sp8`), and cross-checked on `rcoal(6)`, `rcoal(12)`, `rcoal(25)`,
a star tree, and a polytomy.

```
n_tip 8   Nnode 7   edges 14   n_aug 14
root (ape id) 9        tree height 1.1957974869687171
rownames(Ainv): node10,node11,node12,node13,node14,node15,sp1,sp2,sp3,sp4,sp5,sp6,sp7,sp8
tip_node_index: sp1=7 sp2=8 sp3=9 sp4=10 sp5=11 sp6=12 sp7=13 sp8=14   (1-indexed)
sparsity: 38 nonzeros of 196  (19.4%)
```

**Rule A — the node count.** `n_aug = n_tip + Nnode − 1`, equivalently **the number of edges
in the tree**: one latent score per branch. The root is **excluded**
(`R/phylo-tree-precision.R:203`, `setdiff(..., info$root)`).

This contradicts the package's own documentation. Measured across tree shapes:

| tree | n_tip | Nnode | `n_aug` measured | `2S−2` | `2S−1` |
|---|---|---|---|---|---|
| `rcoal(8)` | 8 | 7 | **14** | 14 ✓ | 15 ✗ |
| `rcoal(25)` | 25 | 24 | **48** | 48 ✓ | 49 ✗ |
| star(7) | 7 | 1 | **7** | 12 ✗ | 13 ✗ |
| polytomy `((a,b),c,d)` | 4 | 2 | **5** | 6 ✗ | 7 ✗ |

- `2·n_tips − 1` is wrong for **every** tree. Stated flatly at `src/gllvmTMB.cpp:1168` and
  `docs/design/69-missing-predictor-phase3-phylo.md:193`; hedged at `src/gllvmTMB.cpp:381`
  ("or close to it") and in `docs/design/106:505,770` and `docs/design/108:207`.
- `2·n_tips − 2` is right **only for a fully bifurcating rooted tree**.
  `dev/stan-oracle-phylo/model-spec-phylo.md` §8.5 says `2S−2` but correctly scopes it to
  "a rooted bifurcating tree" — the fence-clean spec is conditioned, not wrong.
- The only unconditionally correct in-repo statement is `R/va-r3-proto.R:423`.

A polytomous tree is **fitted successfully** through the public API (`n_aug_phy = 5` on the
4-tip example), so this is a live user-facing discrepancy, not a rejected corner case.

**Rule B — node ordering.** Internal nodes first (root excluded), then tips, both in ape id
order (`R/phylo-tree-precision.R:204`). Tips therefore occupy the **last** `n_tip` positions.
The comment at `:197-202` states this is deliberate, to remain a numerical drop-in for
`MCMCglmm::inverseA()`. Ordering is a **transport** fact only: the §8.5 density is a sum over
edges and is invariant to node numbering.

**Rule C — the species map.** `species_aug_id = tip_to_aug[species_id + 1] − 1`, where
`tip_to_aug = match(levels(data[[species]]), rownames(Ainv))` (`R/fit-multi.R:3179-3182`),
0-indexed for C++. This is a **two-step** map — factor level → tip label → augmented position —
and is **not** the identity, unlike the dense route. A user whose factor levels do not match
their tree's tip order is exposed here exactly as Arc 1 found for the dense route.

---

## 3. The prior — MEASURED

**Rule D — the scale.** `correlation = TRUE` multiplies the raw precision by
`scale = height` (`R/phylo-tree-precision.R:223,226`), equivalently dividing every branch
length by the root-to-tip height so that depth is 1. Verified: the scaled branch lengths sum
to exactly `1.0000` along every root-to-tip path (e.g. `sp1`:
`0.076622 + 0.122860 + 0.535948 + 0.264570 = 1.000000`).

**Rule E — the log-determinant and its sign.** The engine stores

```
log_det_A_phy_rr = −phy_prec$log_det_precision            (R/fit-multi.R:3174)
log_det_precision = n_aug·log(scale) − Σ log(edge_length) (R/phylo-tree-precision.R:240)
```

Measured on the fixture: `log_det_precision = 25.229441850133327`, so the engine stores
`log_det_A_phy_rr = −25.229441850133327`, i.e. **`+log|A_aug|`** (negative, since `A_aug` has
determinant < 1). The closed form agrees with a direct `determinant()` **exactly** (difference
`0.0`) and with `determinant()` on the assembled matrix to `4.4e-13`.

Two design docs disagree about this sign. `docs/design/35:194` gives
`log_det_A_phy_rr = sum(log(inverseA(tree)$dii))` with no negation;
`docs/design/69:191` gives `-sum(log(inv$dii))`. Both label the result `log|A|`. The
2026-07-05 after-task `phylo-tree-logdet-sign.md` (issue #611) fixed a sign bug on this path;
the design docs still carry both the pre-fix and post-fix forms. **Measured, the current
engine stores `+log|A_aug|`.**

**Rule F — no ridge.** The `tree =` branch (`R/fit-multi.R:3172-3175`) adds no jitter. Only
the dense branch does (`:3224`). Confirmed by reading both branches.

---

## 4. The density — the independent route

The Stan side does **not** receive `A`, `A⁻¹`, or any Cholesky factor. It receives the tree —
a parent index per augmented node (root encoded as 0) and a scaled branch length — and builds
the prior from the Brownian increment factorization of
`dev/stan-oracle-phylo/model-spec-phylo.md` §8.5:

```
a_vk | a_p(v),k ~ N(a_p(v),k , b_v),     a_root,k ≡ 0
log p(a_.k) = Σ_v [ −½log(2π) − ½log(b_v) − (a_vk − a_p(v),k)² / (2 b_v) ]
```

TMB instead evaluates `−½(n_aug·log2π + log_det_A_phy_rr + g' Ainv g)` from the assembled
sparse precision. **Two genuinely different numerical routes**: one sums independent
per-branch normals, the other forms a quadratic form against a matrix. Agreement is therefore
evidence about the precision assembly, the root handling, and the scaling — not merely about
floating-point arithmetic.

That the two are the same object was verified **by the orchestrator, in pure R, using neither
Stan nor TMB** (`verify-algebra.R`) — a third implementation, independent of both sides being
compared. It ran concurrently with the Stan authoring, not demonstrably before it; the claim
here is independence, not precedence.

| claim | rcoal(6) | rcoal(12) | star(7) |
|---|---|---|---|
| edge-recursion precision == engine's builder | 3.55e-15 | 8.88e-16 | 0 |
| marginalise internal nodes → `ape::vcv(corr=TRUE)` | 2.22e-15 | 4.94e-13 | 0 |
| Σ per-branch `dnorm` == `−½(n_aug log2π + log\|A\| + a'Λa)` | 1.42e-14 | 4.55e-13 | 0 |

The edge table supplied to Stan for the fixture tree (child position, parent position with
`0` = root, scaled branch length) is written into `tmb-fixture-tree.json` and reproduced in
`tmb-side-tree.md`.

---

## 5. Relationship to Arc 1 — joints differ, marginals do not

Measured on `rcoal(30)`, `T = 3`, `K = 1`, identical data through both routes:

```
n_aug_phy   tree= : 58        vcv= : 30
MARGINAL (Laplace) objective   tree= 226.51709156644554
                               vcv=  226.51709122836257
                               |diff| 3.38e-07   rel 1.49e-09
```

The **joint** densities are on sample spaces of different dimension and are not comparable —
which is precisely why Arc 1's Stan model cannot be reused and Arc 2 needs its own. The
**marginals** agree to 3.4e-07, as the marginalisation identity requires, with a residual of
the right order for the dense route's `1e-8` ridge. This also settles an apparent conflict
between two existing tests: `test-phylo-hadfield.R:92` (objectives agree, `tolerance = 1e-4`)
concerns the **`phylo_latent` block**, while the 607.74 offset documented at
`test-matrix-slope-relmat.R:27-38` is between the **relmat and phylo slope** routings —
different keywords, a separate phenomenon, and not evidence against the latent-block
equivalence.

---

## 6. Honest boundary

Unchanged from Arc 1 §9.2 and restated rather than quietly dropped:

**The mathematics is independent; the encoding is measured.** No published source states
another program's internal node ordering, its factor-level indexing, or which sign it stores a
log-determinant in. Rules A–F above were read off `R/fit-multi.R` and
`R/phylo-tree-precision.R` and are declared **as measured**. What is *not* measured — the
density itself — comes from §8.5, which was committed to `main` in `dbd0b2d5` before this arc
began and whose own header records the fence it was written under.
