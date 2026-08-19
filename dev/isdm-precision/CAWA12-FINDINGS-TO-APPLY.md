# Findings to apply to the 12-species Warbler article

Measured outside the workflow's four measurement lanes, and each verified here
directly. These must reach the article.

## 1. Use `fit$report$Lambda_spde` — not the packed parameter vector

The article (and an earlier fix of mine) unpacked `theta_rr_spde_lv` and
reasoned about its length being `P*d - d(d-1)/2`. That is unnecessary and
error-prone: at `d = 2` with 12 species the packed vector has **23** entries
while the loadings are a **12 x 2** matrix, so naming it with the species
vector silently mislabels.

**Verified on a live 12-species fit** (`conv 0`, `iters 83`):

```
fit$report$Lambda_spde   ->  dim 12 x 2
per-column rms           ->  0.03519, 0.01960
sum(names(par) == "theta_rr_spde_lv")  ->  23
```

`Lambda_spde` gives the matrix directly. **Use it.** The length-guard I added
earlier is a workaround for a problem that has a clean accessor, and should be
replaced rather than kept.

*(Found by the lane that was superseded by the workflow; verified here.)*

## 2. CORRECTION to something I propagated — the loading tell fails, but not the way I said

I told the workflow, carrying a claim forward from a reviewer, that at true
rank 2 with 12 species **"the second column's rms exceeds the first"**, so a
reader watching for a near-zero column stops at `d = 1`.

**Two independent measurements do not reproduce that.**

| source | per-column rms | reading |
|---|---|---|
| superseded lane, `d = 2` | 0.0178 / 0.0166 | second is 93% of first |
| superseded lane, `d = 3` | 0.0273 / 0.0271 / **0.0132** | spurious third is still 48% of first |
| verified here, `d = 2` | 0.0352 / 0.0196 | second is 56% of first |

**The tell still fails, but by the opposite mechanism.** There is no near-zero
cliff to stop at — the *spurious* column is a substantial fraction of the real
ones — so a reader watching for one **over-fits** rather than under-fits.

The article must show its own measured numbers and describe the failure it
actually observes. Do not restate the "second exceeds first" figure: it was
carried from a review and has not been reproduced.

## 3. Dead code in the current article

`fit_env_only` (around line 356 of the pre-rewrite file) is fitted and never
used — an expensive wasted fit at 12 species. Remove it.

## 4. Feasibility numbers from the superseded lane, for cross-checking

12 species x 240 sites = 2,880 rows, 177 mesh nodes; max opportunistic count
20, well clear of the #1167 boundary:

| fit | time | convergence | iterations |
|---|---|---|---|
| `d = 1` | 19.6 s | 0 | 60 |
| `d = 2` | 47.9 s | 0 | 91 |
| `d = 3` | 67.6 s | 0 | 101 |

AIC on a true rank-2 field: **6095.5 (d=1) -> 5988.9 (d=2) -> 6007.9 (d=3)** —
picks 2 correctly. The workflow's AIC lane is measuring this independently at a
different design; **if the two disagree, report both rather than choosing.**

## 5. A note on the arm level names

`sim_cawa12()` produces `isdm_source` levels **`ebird` and `abmi`** — an
`isdm_sources()` family must name those exact levels or the fit aborts. The
error is loud and correct, but it costs a cycle if you guess `survey`.
