# Reconciliation — TMB joint log-density vs. an independent Stan oracle, `tree =` AUGMENTED-SPARSE path

Role: Gauss (numerical reviewer), orchestrated. Date: 2026-08-03.
Worktree: `/Users/z3437171/local-scratch/worktrees/stan-phylo-tree` @ `cd0c58cf`.
Toolchain: R 4.6.0 · TMB 1.9.21 · rstan 2.32.7 · ape 5.8.1 · Matrix 1.7.5 ·
gllvmTMB 0.6.0 (`src/gllvmTMB.so` built 2026-08-03 10:16).

Model: `value ~ 0 + trait + phylo_latent(species, d = K, tree = tree)`, Gaussian identity,
loadings-only (`unique = FALSE`), **canonical `tree =` augmented-sparse route**.

Predecessors: `dev/stan-oracle/reconciliation.md` (Arc 0, ordinary) and
`dev/stan-oracle-phylo/reconciliation-phylo.md` (Arc 1, dense `vcv =`). Arc 1 §10.2 named this
arc's target as *"the largest gap"*.

---

## VERDICT

> **AGREE AFTER STATED ADJUSTMENTS.**
>
> The adjustments are (i) a **sign flip**, (ii) **suppression of Stan's constraint Jacobian**
> (`adjust_transform = FALSE`), and (iii) a **transport** whose phylogenetic half is entirely
> new: Arc 1's ridge rule is **void**, and its `A`-role, log-determinant and species-index rules
> are **replaced** by a node permutation, a parent map, and a branch-length rescaling.
> **No normalising-constant correction was needed** (`k = 0`). **Neither density was altered.**
>
> At the published fixture point, `|difference| = 2.84 × 10⁻¹⁴`, relative `1.30 × 10⁻¹⁶`.
>
> Agreement holds at **seven parameter points across two trees** — including a **rank-2** model
> on a second, larger tree with **permuted tip order** and a **ragged design with two empty
> cells** — to a maximum absolute difference of **5.46 × 10⁻¹²** (on a value of magnitude
> `1.05 × 10⁴`) and a maximum relative difference of **5.17 × 10⁻¹⁶**, i.e. 1–8 ulp.
> Every dataset B point agreed on the **first run**; no tuning was performed.
>
> **The two implementations encode the same model on the augmented sample space.**

The two sides reach that number by **genuinely different routes**. TMB evaluates
`−½(n_aug·log2π + log_det_A_phy_rr + g′ A⁻¹ g)` against an assembled sparse precision. Stan
sums `normal_lpdf(a_v | a_parent(v), √b_v)` over branches, from a parent map and branch
lengths; **it never receives `A`, `A⁻¹`, or any Cholesky factor**. This is a stronger
instrument than Arc 1, where both sides consumed the same matrix.

Two findings sit outside the density comparison, both in the **implemented-vs-documented**
model:

1. **The augmented node count is misdocumented in five places**, and the error is exactly one
   `−½log(2π)` per latent axis. §7.
2. **`src/gllvmTMB.cpp:380` still credits `MCMCglmm::inverseA(tree)`**, which the native builder
   replaced. §8.

---

## 1. The two raw numbers

Dataset A: `set.seed(20260803)`, `ape::rcoal(8)`, tips `sp1..sp8`, `T = 3`, `K = 1`,
2 replicates, `N = 48`, `n_aug = 14`, 21 parameters.

| side | call | raw value |
|---|---|---|
| **TMB** | `joint_obj$fn(theta)` | **`+219.35321036952374`** |
| **Stan** | `log_prob(fit0, upars, adjust_transform = FALSE)` | **`−219.35321036952377`** |

```
|difference|        = 2.8421709430404007e-14
relative difference = 1.2957051954026395e-16
```

---

## 2. Failure mode 1 — SIGN

**Confirmed; definitional.** `TMB::MakeADFun()` returns an objective to **minimise**; Stan's
`log_prob` returns a log-density to **maximise**. **Adjustment 1 — negate the TMB value.**

## 3. Failure mode 2 — CONSTANT TERMS

**Excluded: `k = 0`.** No constant was applied, and the agreement is *pointwise*, not merely
up to an offset. The difference-of-differences across points is zero to machine precision:

```
(P2−P1)  0                       (P3−P1)  1.79e-12        (P4−P1) −1.42e-13
```

The `n_aug·log(2π)` term is the one that would have been easy to get wrong here, because
`n_aug` is **not** what the documentation says it is. Control C4 (§6) isolates exactly that.

## 4. Failure mode 3 — JACOBIANS

**Confirmed disabled.** `sigma_eps` is the only constrained declaration
(`real<lower=0>`), so Stan's default would add `log σ_ε`. Measured at the fixture point:

```
log_prob(TRUE) − log_prob(FALSE) = −1.2039728043259288
log(sigma_eps)                   = −1.2039728043259361     |diff| = 7.33e-15
```

**Adjustment 2 — `adjust_transform = FALSE`.** A run left at the default would be off by 1.20.

## 5. Failure mode 4 — PARAMETER ORDER / SCALE

The full transport is declared in `transport-tree.md`, **committed in `cd0c58cf` before this
comparison ran**. Summary of what changed from Arc 1:

| # | rule | status | authority |
|---|---|---|---|
| 1 | `mu = b_fix`, trait-level order | carries over | Arc 1 §10 |
| 2 | `sigma_eps = exp(log_sigma_eps)`, an **SD** | carries over | Arc 1 §10 |
| 3 | `Lambda = theta_rr_phy`, identity, no `exp()` on the diagonal | carries over | Arc 1 §10, PR #919 |
| 4 | latent block column-major, level-fastest | carries over **in form** | rows are now nodes, not species |
| 5 | `A` is a covariance; engine stores its inverse | **replaced** | engine never forms or inverts `A` here |
| 6 | **`A → A + 1e-8·I` ridge** | **VOID** | `R/fit-multi.R:3172-3175`; measured `ridge_added_to_A = 0` |
| 7 | `log\|A\|` sign | **replaced** | `log_det_A_phy_rr = −log_det_precision` = `+log\|A_aug\|` = `−25.229441850133327` |
| 8 | species index | **replaced** | two-step map, level → tip label → augmented position |
| **9** | **node permutation** | **NEW** | engine is internal-first/tips-last; the Stan model is tips-first |
| **10** | **branch-length rescaling** | **NEW** | `b_v = edge.length / height` (`correlation = TRUE`) |

**Rule 9 is evidence about the fence, not just a mapping.** The Stan model was written by an
agent forbidden to read `src/`, `R/fit-multi.R`, or any Arc 1 driver. It chose **tips-first**
node indexing. The engine uses **internal-first**. An author who had peeked would have matched.

### Out-of-sample points — transport frozen

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| A/P1 (published fixture θ) | `219.35321036952374` | `−219.35321036952377` | `2.84e−14` | `1.30e−16` |
| A/P2 (fresh) | `154.46894678233485` | `−154.46894678233488` | `2.84e−14` | `1.84e−16` |
| A/P3 (fresh, `σ_ε = 0.05`) | `14710.23884943166` | `−14710.238849431662` | `1.82e−12` | `1.24e−16` |
| A/P4 (fresh, large `μ`, tiny `Λ`) | `221.14796463834116` | `−221.14796463834105` | `1.14e−13` | `5.14e−16` |

---

### Dataset B — a second tree, rank 2, permuted tips, ragged design

`ape::rcoal(10)`, `T = 4`, **`K = 2`**, `N = 104`, tip labels permuted relative to the factor
levels, two `(species, trait)` cells deleted entirely and several thinned to one replicate.
`n_aug = 18` (`n_tip 10 + Nnode 9 − 1`; `2S−2 = 18`, `2S−1 = 19` ✗) — the node-count finding
reconfirmed on a topologically unrelated tree. The transport was **frozen** before this ran.

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| B/P1 | `1777.5489537384951` | `−1777.5489537384947` | `4.55e−13` | `2.56e−16` |
| B/P2 | `1081.5698727007041` | `−1081.5698727007045` | `4.55e−13` | `4.20e−16` |
| B/P3 | `10549.861028879999` | `−10549.861028879994` | `5.46e−12` | `5.17e−16` |

Difference-of-differences: `9.09e−13`, `−5.00e−12`. Jacobian audit holds at every point.
**All three agreed on the first run; no tuning was performed.**

Three controls that are **degenerate at `K = 1`** and only become live at rank 2:

| control | shift |
|---|---|
| `g_phy` read axis-fastest instead of node-fastest (Kronecker order) | `+219.4338` |
| `theta_rr_phy` packed row-major instead of column-major | `+24.2731` |
| forced-zero `Λ[1,2]` set to `0.85` (the packing forces 0) | `−43.5092` |

### A latent defect in the dataset A driver, exposed by dataset B

Dataset A's driver builds its tip block from `prec$tip_node_index` — **tree-tip order**. The
Stan model's contract (`gllvm_phylo_tree.stan:62-68`) requires the first `S` rows of `a_node` to
be in **factor-level order**, the order that produced `ss[i]`. On dataset A those two orders
**coincide by construction** (`tip.label` was set to `sp1..sp8` and the factor levels take the
same order), so dataset A agrees either way and the distinction stays invisible.

On dataset B's genuinely permuted tree it does not coincide, and the dataset B driver
correctly uses `match(levs, rownames(Ainv_phy_rr))` instead, cross-checked against
`species_aug_id`. **This is Arc 1's finding recurring on the `tree =` path**: species are indexed
by factor-level order, not tree tip order. Arc 1 measured a 79-unit density error from confusing
them on the dense route; here the same confusion would have silently routed every species'
score into the wrong Stan row.

It is recorded rather than patched, for the same reason as §12's cosmetic defects: the dataset A
driver is the pre-registered artifact. Its *result* is unaffected — the two orders are equal
there — but a reader copying it onto a permuted tree would be wrong. **That is exactly the
user-facing hazard the documentation fix in the companion commit addresses.**

## 6. The controls — the comparison CAN fail, so it is a check

Each breaks exactly one rule. All shifts are 11–14 orders above the `≤1.8e−12` floor.

| # | control | shift in the Stan log-density |
|---|---|---|
| C1 | **internal-node score perturbed by +1** (η never reads it) | `−0.2688` |
| C2 | engine node order fed directly, permutation skipped | `−4.8245` |
| C3 | branch lengths left unscaled (no `/height`) | `+7.6139` |
| C4 | **root added as a 15th node** (the documented `2S−1`) | `−0.9189385332` |
| C5 | tip block permuted (wrong species map) | `+31.9878` |
| C6 | `branch_len` read as an SD instead of a variance | `−496.9393` |

**C1 is the vacuity control and it is the one that matters.** Arc 2's specific way to be
meaningless would be for the internal-node scores to be inert — they never enter `η`, so if the
density did not move, this arc would be testing nothing Arc 1 had not already tested. It moves.
The internal nodes are live, and they are live *only* through the prior.

**C4 is exact.** The measured shift is `−0.91893853320468111`; `−½log(2π)` is
`−0.91893853320467267`. They agree to `8.66e−15`. Adding the root as an extra node — i.e.
believing the documented `2S−1` — costs **exactly one Gaussian normalising constant per latent
axis**, because the root sits at its own mean with unit variance so only the `−½log(2π)`
survives. This is the documentation error of §7, quantified.

### The star-phylogeny control

A star tree has no internal nodes, so the augmented representation must collapse:

```
star n_aug_phy: 8        real tree: 14        (2S-2 would be 14)
TMB (star)  :  174.61647155550565
Stan (star) : -174.61647155550571        |diff| 5.68e-14
star vs real-tree TMB objective differs by -44.7367
```

Both sides agree to the same floor on a degenerate tree, **and** the density moves by 44.74
when the real phylogeny is swapped for a star. So both sides track a real change in tree
structure and still agree — the agreement is not an artefact of the phylogeny cancelling out.
This is Arc 1 §11.1's control, adapted, and it doubles as a dimension check: a harness that
reported `n_aug = 2S−2 = 14` on a star tree would not be reading the engine.

---

## 7. Finding 1 — the augmented node count is misdocumented, in five places

The engine computes `n_aug = n_tip + Nnode − 1` (`R/phylo-tree-precision.R:203-207`), the root
excluded. Equivalently, and more naturally: **`n_aug` is the number of EDGES in the tree** —
one latent score per branch, which is the Brownian increment view.

Measured (`verify-algebra.R`, and a live fit for the polytomy):

| tree | n_tip | Nnode | `n_aug` measured | `2S−2` | `2S−1` |
|---|---|---|---|---|---|
| `rcoal(8)` | 8 | 7 | **14** | 14 ✓ | 15 ✗ |
| `rcoal(25)` | 25 | 24 | **48** | 48 ✓ | 49 ✗ |
| star(7) | 7 | 1 | **7** | 12 ✗ | 13 ✗ |
| polytomy `((a,b),c,d)` | 4 | 2 | **5** | 6 ✗ | 7 ✗ |

- **`2·n_tips − 1` is wrong for every tree.** Stated flatly at `src/gllvmTMB.cpp:1168` and
  `docs/design/69-missing-predictor-phase3-phylo.md:193`; hedged at `src/gllvmTMB.cpp:381`
  ("or close to it depending on tree topology") and in `docs/design/106:505,770` and
  `docs/design/108:207`. The hedge is itself misleading: the count is an exact deterministic
  function of the tree, not an approximation.
- **`2·n_tips − 2` is right only for a fully bifurcating rooted tree.**
  `dev/stan-oracle-phylo/model-spec-phylo.md` §8.5 says `2S−2` but explicitly scopes it to "a
  rooted bifurcating tree" — **the fence-clean spec is correctly conditioned; it is the in-repo
  documentation that is not.**
- The only unconditionally correct in-repo statement is `R/va-r3-proto.R:423`, written
  2026-08-02.

**Why it is load-bearing.** `n_aug_phy` multiplies `log(2π)` in the normalising constant
(`cpp:1170-1171`) — control C4 measures the cost at exactly `−½log(2π)` per axis. It also sizes
`g_phy`, `g_phy_diag`, `b_phy_slope`, `b_phy_aug` and `g_phy_slope`, so it drives memory and the
VA cost estimates in `docs/design/106`/`108`, where the number is used to argue that the
phylogenetic tier "costs twice what the species count suggests".

**A polytomous tree is fitted successfully** through the public API (`n_aug_phy = 5` on the
4-tip example above), so this is a live user-facing discrepancy, not a rejected corner case.
Unresolved nodes are common in real phylogenies.

## 8. Finding 2 — a stale attribution in the C++ comments

`src/gllvmTMB.cpp:380` states the augmented precision "is built over tips + internal nodes via
`MCMCglmm::inverseA(tree)`". That has not been true since the native builder landed
(`R/phylo-tree-precision.R`, whose own header records that it "no longer needs MCMCglmm").
Cosmetic — it is a comment, and `n_aug_phy` arrives from R as data — but it misdirects anyone
tracing this path.

Related and **not** a defect: `docs/design/35:194` and `docs/design/69:191` give opposite-sign
formulas for `log_det_A_phy_rr`, both labelled `log|A|`. Issue #611
(`docs/dev-log/after-task/2026-07-05-phylo-tree-logdet-sign.md`) fixed a sign bug on this path;
the design docs still carry both the pre-fix and post-fix forms. **Measured, the current engine
stores `+log|A_aug| = −25.229441850133327`**, verified against `determinant()` to `3.6e−15` and
against the closed form `Σ log(b_v)` exactly.

## 9. Relationship to Arc 1 — the joints differ, the marginals do not

Measured on `rcoal(30)`, `T = 3`, `K = 1`, identical data through both routes:

```
n_aug_phy   tree= : 58        vcv= : 30
MARGINAL (Laplace) objective   tree=  226.51709156644554
                               vcv=   226.51709122836257
                               |diff| 3.38e-07     rel 1.49e-09
```

The **joint** densities live on sample spaces of different dimension and are not comparable —
which is precisely why Arc 1's Stan model could not be reused. The **marginals** agree to
3.4e-07, exactly as the marginalisation identity requires, with a residual of the right order
for the dense route's `1e-8` ridge (Arc 1 §8 bounds its effect at ~6.6e-07 for `rcoal(8)`).

That identity was verified independently, in pure R using neither TMB nor Stan
(`verify-algebra.R`): inverting the augmented precision and restricting to tips reproduces
`ape::vcv(tree, corr = TRUE)` to `2.2e−15` / `4.9e−13` / `0` on `rcoal(6)` / `rcoal(12)` /
star(7). No design doc derives this; the equivalence had been asserted and tested, never shown.

It also settles an apparent conflict between two existing tests. `test-phylo-hadfield.R:92`
compares the **`phylo_latent` block** across routes and asserts objective equality at
`tolerance = 1e-4` — correct, and about three orders looser than the real agreement. The
**607.74** offset documented at `test-matrix-slope-relmat.R:27-38` is between the **relmat and
phylo slope** routings — different keywords, a separate phenomenon, and not evidence against
the latent-block equivalence.

---

## 10. What this does NOT cover

1. **One family.** Gaussian identity only.
2. **`unique = FALSE` only.** The `phylo_latent(..., unique = TRUE)` tier (`+ Ψ_phy ⊗ A`,
   `log_sd_phy_diag`/`g_phy_diag`) would add a third density term and a genuine
   variance-transform question. `use_phylo_diag = 0` throughout.
3. **One route.** The `tree =` path only. The **sparse `vcv = <sparseMatrix>`** path
   (`.resolve_sparse_phylo_precision()`, the `animal_*(pedigree=)` / `Ainv=` entry) is
   structurally similar and remains **untested**. Arc 1 covered dense `vcv =`.
4. **No other structure.** `phylo_slope`, `phylo_dep`, `phylo_scalar`, `animal_*`, kernel,
   spatial, `meta_V`, or an ordinary `latent()` alongside a phylo term — all mapped off.
5. **Joint density, not the marginal.** This compares the pre-Laplace joint at fixed `(θ, a)`.
   It says nothing about the Laplace approximation, the inner optimisation, gradients,
   `sdreport()`, or anything downstream. §9's marginal comparison is a separate, coarser check.
6. **No optimum involved.** All points are hand-chosen or seeded draws.
7. **Small, ultrametric, well-conditioned trees.** `S ≤ 10`. `correlation = TRUE` requires
   ultrametricity; the non-ultrametric case is **unresolved** — the Stan side's companion note
   (`stan-side-tree.md` §5) flags that §8.5's "scale that makes root-to-tip depth 1" phrasing
   presupposes it, and this arc did not test a non-ultrametric tree.
8. **No coverage, calibration, or recovery claim. No validation-debt register row moved.**

## 11. Honest boundary

**The mathematics is independent; the encoding is measured.** The density comes from
`model-spec-phylo.md` §8.5, written under a documented fence and committed in `dbd0b2d5`
**before this arc began**, and implemented by an agent that could not read the engine. The
transport — node ordering, the tip map, the log-determinant sign, the rescaling — was read off
`R/fit-multi.R` and `R/phylo-tree-precision.R` and is declared **as measured** in
`transport-tree.md`.

Arc 1 §11.3 criticised that arc for *claiming* an a-priori derivation the timestamps did not
support. This arc's answer is structural rather than rhetorical: the model, the transport and
the driver are committed in `cd0c58cf` with **no result of the comparison in existence at that
commit**, and the fence was enforced by *what the author was allowed to open*, not by
self-restraint. The tips-first/internal-first mismatch (rule 9) is independent evidence that
the fence held.

**The pre-registration claim is checkable, and was checked.** Anyone can run:

```sh
git grep -c "219\.35321" cd0c58cf -- dev/     # -> no match: the result exists nowhere
git grep -c "219\.35321" HEAD     -- dev/     # -> gauss-reconcile-tree.log, reconciliation-tree.md
git log --format="%h %s" --follow -- dev/stan-oracle-phylo-tree/gauss-reconcile-tree.log
```

The headline value appears **nowhere** in `cd0c58cf` and first exists at `58d98450`. A naive
grep for `log_prob(fit0` does hit the pre-registration commit five times — those are the
driver's *call sites*, not its output, and the distinction is the point: the code that would
produce the number was fixed before the number existed.

What remains true, and is not dissolved by any of the above: **a fixed-parameter oracle can be
independent about the density and cannot be fully independent about the encoding.**

---

## 12. Exact commands to reproduce

```sh
# TMB side (writes tmb-fixture-tree.rds / .json)
Rscript dev/stan-oracle-phylo-tree/tmb-side-tree.R

# the orchestrator's third implementation: pure R, no TMB, no Stan
Rscript dev/stan-oracle-phylo-tree/verify-algebra.R

# dataset A: 4 points, Jacobian audit, 6 controls, star-phylogeny control
Rscript dev/stan-oracle-phylo-tree/gauss-reconcile-tree.R

# dataset B: second tree, T=4, K=2, permuted tips, ragged, +3 rank-2 controls
Rscript dev/stan-oracle-phylo-tree/gauss-reconcile-tree-k2.R
```

Both drivers run TMB and Stan in a **single R session** with the data regenerated in-session,
so no value crosses a JSON boundary before comparison. Each asserts `gllvm_phylo_tree.stan`'s
mtime is unchanged on exit. All figures are quoted from `%.17g` driver output, never from the
`.json` artifacts — `jsonlite::write_json(digits = NA)` is not bitwise exact, reproduced
independently here (RDS `173.37932199712063` vs JSON `173.379321997121`).

### Known cosmetic defects in `gauss-reconcile-tree.R`

Recorded rather than silently patched, because the driver is the pre-registered artifact:

- the `root-to-tip depth (should be 1)` diagnostic prints a single branch length, not a path
  sum. The rescaling is nevertheless confirmed by control C3 and by a manual path sum
  (`sp1`: `0.076622 + 0.122860 + 0.535948 + 0.264570 = 1.000000`).
- the `ctrl()` helper leaks a bare `[1] …` echo of its return value between control lines.

Neither touches any compared quantity.
