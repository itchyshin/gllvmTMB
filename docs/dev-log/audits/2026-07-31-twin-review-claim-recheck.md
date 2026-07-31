# Audit: re-checking the five remaining "CONFIRMED twin divergences" (2026-07-03 review)

**Role:** skeptical code auditor, read-only. **Trigger:** the 2026-07-03 twin
code review (`docs/dev-log/handover/2026-07-03-claude-handover.md:63-70`) listed
six "CONFIRMED twin divergences" between `gllvmTMB` (R/TMB, this repo) and
`GLLVM.jl` (Julia, sister repo). One of the six — the `psi`/residual-semantics
claim — has already been shown false at the code level. This document
independently re-derives the other five directly from source, with no
presumption that "CONFIRMED" in the original document means anything.

## Summary

Of the five claims, **three are CONFIRMED** today with live file:line evidence
on both sides (ordinal link, dispersion granularity, W-tier cross-trait
covariance), **one is REFUTED** as a cross-language divergence (the
log-determinant sign issue is real but is an R-internal inconsistency between
R's own four phylogenetic-precision code paths, already fixed 2026-07-05, and
was never actually a Julia comparison), and **one is CONFIRMED** via direct
reading of the tree-precision-construction code even though no matching GitHub
issue could be located (phylo variance normalization by tree height). The
dispersion-granularity claim needs a temporal caveat: it was already true for
NB2 and Beta at review time and remains true today (unfixed on the Julia
side), but for ordinary Gamma the claim was **not accurate in this form** at
review time — R's Gamma dispersion wasn't a vector at all then, it was
aliased to an unrelated shared scalar (`sigma_eps`) — and only became a
genuine vector-vs-scalar divergence as a side effect of an unrelated bug fix
two days after the review (commit `dff9b363`, 2026-07-05).

---

## Claim 1: "sign of the phylo log-determinant (sparse Ainv path)"

**Verdict: REFUTED** (as a cross-language twin divergence). A real,
now-fixed, same-repo (R-internal) sign bug underlies this claim; it was never
actually a comparison against Julia, and Julia's own phylo log-determinant
handling was correct throughout.

### Evidence

The traceable source is gllvmTMB issue **#611**, "[correctness] Wrong sign on
log-determinant for the phylo_tree (sparse Ainv) path" (CLOSED). Its own body
states the comparison explicitly: *"The other three paths supply the correct
sign: dense (line 2421) gives `+logdet(Aphy)`, sparse-Ainv (line 2405) gives
`-logdet(Ainv) = +log|A|`, and kernel (line 2301) gives `+logdet(K)`. **Only
the tree path is negated.**"* — i.e. the finding compares gllvmTMB's own four
internal phylo-precision-construction routes (dense `phylo_vcv`, direct sparse
`Ainv`, `phylo_tree`, kernel) against **each other**, not against `GLLVM.jl`.
No corresponding `GLLVM.jl` issue exists (checked both title and body text
across all open+closed issues for "sign"/"logdet"/"determinant"/"phylo").

**R/C++ — the bug, pre-fix** (commit `eb10221d`'s parent, i.e. the code as it
stood at the review commit `76249a47`; verified via `git show eb10221d^:R/fit-multi.R`,
line 2510 at that historical revision — this exact block no longer exists in
today's file, see the refactor noted below):
```r
log_det_A_phy_rr <- -sum(log(inv$dii)) # log det A = -sum(log(dii))
```
`inv$dii` are `MCMCglmm::inverseA()`'s diagonal `D` factors of `A` itself, so
`sum(log(inv$dii)) = log|A|` and the pre-fix line stored `-log|A| = log|A^{-1}|`
— the wrong sign relative to what the TMB likelihood needs.

**R/C++ — the fix**, same line 2510 post-commit `eb10221d`
("Fix phylo tree logdet sign", 2026-07-05 02:41:23 -0600, closing #611;
verified via `git show eb10221d:R/fit-multi.R`):
```r
log_det_A_phy_rr <- sum(log(inv$dii)) # log det A = sum(log(dii))
```
This was independently re-verified fixed on `main` by the 2026-07-09 Arc-E
ground-truth triage (issue #611 comment), and the sign convention was
preserved through the later MCMCglmm-free refactor (commit `30e3b6ec`,
2026-07-06): current `R/fit-multi.R:2870-2872` calls
`.gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)` and sets
`log_det_A_phy_rr <- -phy_prec$log_det_precision`, where
`R/phylo-tree-precision.R:179` documents the returned `log_det_precision`
field as `\eqn{\log\det A^{-1}}` and line 240 computes it as
`n_aug * log(scale) - sum(log(edge_length))` — so the negation at the call
site is correct (`-log|A^{-1}| = log|A|`), matching the other three R-side
paths.

The TMB likelihood consumes this as `+log_det_A_phy_rr` inside the standard
`N(0, A)` negative-log-density, e.g. `src/gllvmTMB.cpp:1046` (comment) and
`src/gllvmTMB.cpp:1051-1053`:
```cpp
Type quad = (g_k.matrix().transpose() * Ainv_phy_rr * g_k.matrix())(0, 0);
nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
              + log_det_A_phy_rr + quad);
```

**Julia** — independently checked both of Julia's phylo marginal-likelihood
paths and found the sign convention was correct throughout, with no fix
needed or found:
- `src/fit_phylo.jl:66-69` (dense/Woodbury path):
  `logdetΣ = p * log(st.σ²_eps) + logdet(st.cΛ̃) - logdet(st.chol_Qcond)` then
  `return 0.5 * (p * log(2π) + logdetΣ + quad)` — the negative log-likelihood
  uses `log|Σ|` (covariance domain), the correct sign.
- `src/likelihood_sparse_phy.jl:319-322` (sparse augmented-precision path):
  `logdet_Σ_full = logdet_AnB + (n - 1) * logdet_A` then
  `return -0.5 * (n * p * log(2π) + logdet_Σ_full + quad)` — again `log|Σ|`
  with the correct sign, this time returning the (positive) log-likelihood
  directly.

### What it means

There is no live R-vs-Julia divergence in the sign of the phylo
log-determinant: today both sides use the same convention (`+log|covariance|`
in the negative log-density) everywhere I could find it. What was real is a
narrower, single-repo bug — one of R/C++'s four ways of building the phylo
precision matrix (the ape-tree/`MCMCglmm::inverseA` route) briefly disagreed
with its own other three routes, affecting reported objective/logLik/AIC/BIC
(not MLEs) for `phylo_tree=`-based fits between introduction and 2026-07-05.
That bug is closed and re-verified.

---

## Claim 2: "phylo variance normalized on different scales (R/C++ vs Julia)"

**Verdict: CONFIRMED.** I could not find a GitHub issue whose title/body
matches this specific finding (searched both trackers for "ultrametric",
"height", "scale", "normalize", "branch length" combined with "phylo"), so
this verdict rests on direct code reading rather than a paper trail — flagged
explicitly per the audit instructions. Two independent, current divergences
support it.

### Evidence

**R/C++ — tree-based phylo covariance is height-normalized by default.**
`R/fit-multi.R:2870` (the fitting-time call, hardcoded, not a user option at
this call site):
```r
phy_prec <- .gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)
```
`R/phylo-tree-precision.R:223,225-227`:
```r
scale <- if (isTRUE(correlation)) info$height else 1
...
precision <- Matrix::drop0(Matrix::sparseMatrix(
  i = rows, j = cols, x = scale * values,
  dims = c(n_aug, n_aug), dimnames = list(node_labels, node_labels)
))
```
`info$height` is the tree's root-to-tip distance (ultrametricity of the tree
is required whenever `correlation = TRUE`, enforced in
`.gllvm_validate_phylo_tree(..., require_ultrametric = correlation)`). The
inline design comment at `R/fit-multi.R:2863-2864` states the intent directly:
*"correlation = TRUE matches MCMCglmm::inverseA's default unit-root-to-tip
scaling (the phylo variance parameter absorbs the scale)."* Net effect: with
`σ²_phy = 1`, every tip's marginal Brownian variance is exactly 1 — a true
correlation matrix — regardless of the tree's native branch-length units.

**Julia — the tree-based phylo precision is built from raw branch lengths,
with no height/ultrametric rescaling anywhere.** `src/sparse_phy.jl:271-286`
(inside `augmented_phy(newick)`):
```julia
b = node_length[old_child]
b > 0 || error("branch length must be > 0; node $old_child has length $b")
push!(branch_lengths, b)
...
inv_b = 1.0 / b
# 2 × 2 block (1/b) · [[1, -1], [-1, 1]]
push!(I, new_parent); push!(J, new_parent); push!(V,  inv_b)
```
No `height`, `ultrametric`, or rescaling step appears anywhere in
`src/sparse_phy.jl`, `src/fit_phylo.jl`, or `src/phylo_contrasts.jl` (checked
by grep across all three; the only "unit-variance" language, e.g.
`src/fit_phylo.jl:7,90`, describes `Σ_phy_unit` as the σ²_phy = 1 baseline,
not a tree-height-normalized correlation matrix — its raw diagonal equals the
tree's actual root-to-tip branch-length sum, not 1, unless the input tree
happens to already have unit height). `src/sparse_phy.jl:388-389`'s own
docstring for its test-fixture tree generator underscores the point: *"Branch
lengths stay uniform — the goal is a representative sparse-tree topology,
not an ultrametric one."*

**Corroborating, independently-filed, still-open divergence at a different
pipeline stage** — GLLVM.jl issue **#128** ("[bug] Julia phylo_signal H2
divides by non-phylo variance, not total variance", OPEN, CONFIRMED
votes×2): R's `profile_ci_phylo_signal()` computes
`H2 = σ²_phy / (σ²_phy + σ²_non)` (bounded in (0,1)); Julia's
`phylo_signal()` (`src/confint_derived.jl:300-316`, spot-checked directly:
`Σ = sigma_y_site(fit)` then `return [ΛΛt[t, t] * diag_Σphy[t] / Σ[t, t] ...]`)
divides by a `Σ_y_site` that **excludes** the phylo block, yielding
`phy/(1-non) = H2_R/(1-H2_R)`, unbounded above 1. This is a distinct
mechanism (a derived-statistic denominator bug, not the tree-precision
construction above) but is independent evidence that "what fraction/scale a
phylogenetic variance number represents" genuinely diverges between the two
packages today.

### What it means

Fitting the identical tree (same topology, same branch lengths) through R's
`phylo_tree=` route and Julia's `augmented_phy(newick)` route does not yield
comparable `σ_phy`/`σ²_phy` estimates unless the tree happens to already have
root-to-tip height exactly 1: R's parameter is on a height-normalized
(correlation) scale, Julia's is on the tree's raw branch-length scale, and a
second, separately-filed bug (#128) shows a further scale mismatch in the
derived phylogenetic-signal (H²) statistic computed from these variances.

---

## Claim 3: "ordinal link: probit (R/C++) vs cumulative-logit (Julia)"

**Verdict: CONFIRMED.**

### Evidence

**R/C++** — family id 14 is explicitly named `ordinal_probit` and uses
`pnorm` throughout. `src/gllvmTMB.cpp:2148-2154,2174,2179`:
```cpp
} else if (fid == 14) {
  // ordinal_probit (Wright/Falconer/Hadfield threshold model).
  //   y* = eta + e,  e ~ N(0, 1)   (link-residual variance = 1)
  //   y = k iff tau_{k-1} < y* <= tau_k
  // P(y = k | eta) = pnorm(tau_k - eta) - pnorm(tau_{k-1} - eta)
  ...
  upper_p = pnorm(cuts(yk - 1) - eta_o);
  ...
  lower_p = pnorm(cuts(yk - 2) - eta_o);
```
This is the only response-family ordinal path in the C++ template; there is
no logit alternative wired to `fid == 14`. (A textually similar
"cumulative-logit" phrase does appear at `src/gllvmTMB.cpp:2219`, but that is
the unrelated missing-**predictor** FIML machinery's discrete-covariate
prior, not the response-side ordinal family — confirmed by reading the
surrounding `mi_family` block, which marginalizes a missing covariate's
finite states, not the observed ordinal response.)

**Julia** — `src/families/ordinal.jl:1-6,20,27,29`:
```julia
# Ordinal (ordered categorical, C levels) — proportional-odds cumulative-logit
# GLLVM. ... common ordered cutpoints ... Cumulative model (McCullagh 1980):
#   P(y ≤ c | z) = logistic(τ_c − η),
struct Ordinal end
default_link(::Ordinal) = LogitLink()
_ord_F(x) = inv(one(x) + exp(-_clamp_eta(x)))            # logistic CDF (η-clamped)
```
Every probability/likelihood/gradient routine (`_ord_prob`,
`_ord_score_weight`, `_ordinal_laplace_mode`, `ordinal_loglik_site`) calls
`_ord_F`/`_ord_f` unconditionally — the `link::Link` field carried by
`OrdinalFit` and accepted as a keyword by `fit_ordinal_gllvm` is never
actually dispatched on inside the math (verified by grep: `link` appears only
in struct fields, `Base.show`, and keyword pass-through). So Julia's ordinal
family is hard-wired to cumulative-logit regardless of what `link=` a caller
passes; there is no live probit option on the Julia side either.

Neither `src/families/ordinal.jl` (last touched 2026-05-31) nor the C++
`fid==14` block's link choice (the one later touch, commit `8a824a64`,
2026-07-05, only replaced branching clamps with `CondExp` for AD-safety —
`pnorm` is untouched) has changed since the review.

### What it means

The two packages implement genuinely different ordinal-response models —
Wright/Falconer/Hadfield probit-threshold (R/C++) vs proportional-odds
cumulative-logit (Julia) — which are not interchangeable reparameterizations;
cutpoints and loadings fitted on one side have no exact correspondence on the
other. This is a real, current, unfixed divergence.

---

## Claim 4: "Gamma/NB2/Beta dispersion granularity (per-trait vector vs single scalar)"

**Verdict: CONFIRMED today for all three families** — but Gamma needs an
explicit "was NOT true in this form at review time" caveat; NB2 and Beta were
already true then and remain true now, unfixed.

### Evidence

**Julia — uniformly single global scalar for all three families**, unchanged
since 2026-05-31 (checked `git log` on each file; none touched since):
- `src/families/gamma.jl:40-43`: `struct GammaFit ... α::Float64 ...` — one
  shape for the whole `p×n` response matrix.
- `src/families/negbin.jl:38-41`: `struct NBFit ... r::Float64 ...` — one
  dispersion for the whole matrix.
- `src/families/beta.jl:52-55`: `struct BetaFit ... φ::Float64 ...` — one
  precision for the whole matrix.

**R/C++ today** — all three are `PARAMETER_VECTOR` of length `n_traits`,
`src/gllvmTMB.cpp:615,617,628`:
```cpp
PARAMETER_VECTOR(log_phi_nbinom2);             // length n_traits (or 1 if unused)
PARAMETER_VECTOR(log_phi_gamma);               // length n_traits (or 1 if unused), fid 4
...
PARAMETER_VECTOR(log_phi_beta);                // length n_traits (or 1 if unused)
```

**NB2 and Beta: true both then and now.** Checked out `src/gllvmTMB.cpp` at
the exact review commit (`76249a47`, 2026-07-03 18:07:18): `log_phi_nbinom2`
(line 586) and `log_phi_beta` (line 598) were **already** `PARAMETER_VECTOR`
at review time — unchanged since. Matching, still-**OPEN** issues exist on
the Julia side: GLLVM.jl **#132** ("NB2 dispersion granularity differs:
per-trait phi vector (R) vs single global r (Julia)", CONFIRMED×2) and
GLLVM.jl **#148** ("Beta precision granularity differs: per-trait phi vector
(R) vs single global phi (Julia)"). Neither has been remediated.

**Gamma: NOT true in this form at review time; became true afterward.** At
the review commit (`76249a47`), there was **no** `log_phi_gamma` parameter at
all. Ordinary Gamma (fid 4) instead did:
```cpp
Type shape_g = Type(1.0) / (sigma_eps * sigma_eps);   // review-time code, line 1919
```
`sigma_eps` is `PARAMETER(log_sigma_eps)` — a single scalar for the *entire
model*, also used as the Gaussian and lognormal residual SD. So at review
time, R's Gamma dispersion was not a vector at all — if anything it was
*less* granular than Julia's already-scalar `GammaFit.α`. This matches
gllvmTMB issue **#622** ("[correctness] Gamma dispersion aliased to the
shared scalar sigma_eps (R), independent shape in Julia", CLOSED,
CONFIRMED×2), whose own diagnosis is aliasing, not vector-vs-scalar
granularity: *"GLLVM.jl gives the Gamma its own independent shape alpha
... decoupled from any other family... the R side additionally COUPLES the
Gamma dispersion to the Gaussian/lognormal residual SD."*

Commit `dff9b363` ("fix: decouple gamma dispersion from sigma eps",
2026-07-05 05:23:25 -0600, two days after the review) closed #622 by
introducing a genuine per-trait vector:
```cpp
// src/gllvmTMB.cpp diff, dff9b363
+  PARAMETER_VECTOR(log_phi_gamma);               // length n_traits (or 1 if unused), fid 4
...
-      Type shape_g = Type(1.0) / (sigma_eps * sigma_eps);
+      int t = trait_id(o);
+      Type shape_g = exp(log_phi_gamma(t));
```
This is what created today's Gamma vector-vs-scalar divergence against
Julia's still-scalar `GammaFit.α` — as a side effect of fixing an unrelated
(aliasing) bug, not as a direct response to a granularity finding.

### What it means

Reading the claim as "true, unchanged, since the review" is correct for NB2
and Beta (both still open, both still real) but wrong for Gamma: at review
time the accurate description of the Gamma problem was parameter *aliasing*
to an unrelated family's shared scalar, not a vector/scalar granularity gap
— that specific gap opened up two days later as a side effect of the
aliasing fix, and remains open today because Julia's Gamma shape was never
changed.

---

## Claim 5: "W-tier reduced-rank term drops cross-trait covariance in Julia but not C++"

**Verdict: CONFIRMED.** Directly matches still-**OPEN** GLLVM.jl issue
**#135** ("[correctness] W-tier reduced-rank term drops cross-trait
covariance in Julia but not in C++", CONFIRMED×2), and independently
re-derived from source below.

### Evidence

**R/C++ — z_W is one shared vector per site_species, loaded differently per
trait, producing a full off-diagonal cross-trait covariance.**
`src/gllvmTMB.cpp:499` (`PARAMETER_MATRIX(z_W)`, `d_W × n_site_species`),
`src/gllvmTMB.cpp:929-935`:
```cpp
for (int ss = 0; ss < n_site_species; ss++) {
  vector<Type> col_ss = z_W.col(ss);
  nll -= dnorm(col_ss, Type(0), Type(1), true).sum();
}
REPORT(Lambda_W);
matrix<Type> Sigma_W = Lambda_W * Lambda_W.transpose();
REPORT(Sigma_W);
```
and `src/gllvmTMB.cpp:1866-1869` (inside the per-observation `eta` builder,
`t = trait_id(o)`, `ss = site_species_id(o)`):
```cpp
if (use_rr_W == 1) {
  Type u_W_sst = 0;
  for (int k = 0; k < d_W; k++) u_W_sst += Lambda_W(t, k) * z_W(k, ss);
  eta(o) += u_W_sst;
}
```
Every trait `t` observed at the same `site_species` `ss` reads the **same**
`z_W(:, ss)` draw, so integrating it out induces genuine off-diagonal
covariance `Cov(trait t, trait t') = (Lambda_W Lambda_W')[t,t']` — an
explicit `n_traits × n_traits` matrix, reported in full.

**Julia — the within-tier latent draw is independent per (trait, site), so
only the diagonal ever enters the covariance; the off-diagonal is never
formed.** `src/likelihood.jl:6-13` (header spec, its own emphasis):
```julia
#   y[t,s] = (Λ_B η_s)[t] + sum_k Λ_W[t,k] η_W[k,t,s]
# where η_s ~ N(0, I_{K_B}), η_W[:,t,s] ~ N(0, I_{K_W}) (per (t, s)!),
...
#   Σ_y_site = Λ_B Λ_B' + diag(d_total)
#   d_total[t] = (Λ_W Λ_W')[t,t] + σ²_B[t] + σ²_W[t] + σ²_eps
```
and `src/likelihood.jl:159-171` (the actual `d_total` construction):
```julia
if Λ_W !== nothing
    K_W = size(Λ_W, 2)
    for k in 1:K_W
        v += Λ_W[t, k]^2
    end
end
...
d_total[t] = v
```
`Σ_y_site` is built as `Λ_B Λ_B' + diag(d_total)` per the header spec
(`likelihood.jl:12`) — a **diagonal** contribution from the W tier, full
stop; `Λ_W` never appears in an off-diagonal position anywhere in this file,
because `η_W[k,t,s]` is explicitly documented as independent across `t`. The
same diagonal-only pattern recurs in the J3 phylogenetic branch's analogous
`A` matrix later in the same file (`likelihood.jl:208,212-214`:
`# Build A = Λ_B Λ_B' + diag(d_total) ...`, `A = Λ_B * Λ_B'`,
`A[t, t] += d_total[t]`), and in the two mirror sparse-phylo paths:
`src/likelihood_sparse_phy.jl:9,156-168` and
`src/likelihood_edge_incidence.jl:7,93` (same `η_W[k,t,s]` formula, same
diagonal-only `d_total`).

### What it means

The two packages give the "W tier" the same name and the same-shaped
`Lambda_W`/`Λ_W` matrix, but they are not the same model: R/C++'s W tier is a
genuine within-unit shared latent factor that correlates traits at the same
site_species; Julia's W tier is, statistically, a per-trait variance
inflation term with zero cross-trait structure by construction. A fit with
non-trivial off-diagonal `Lambda_W Lambda_W'` in R/C++ has no representable
counterpart in Julia, and log-likelihoods will not match between the two
engines whenever this tier is active with `K_W ≥ 1` and more than one trait.

---

## Verdict table

| # | Claim | Verdict |
|---|---|---|
| 1 | Sign of the phylo log-determinant (sparse Ainv path) | REFUTED (real bug existed, but was R-internal, not a Julia comparison; fixed 2026-07-05, commit `eb10221d`) |
| 2 | Phylo variance normalized on different scales (R/C++ vs Julia) | CONFIRMED (no matching GitHub issue found; verified directly from `R/phylo-tree-precision.R` vs `src/sparse_phy.jl`; corroborated by separate open issue GLLVM.jl #128) |
| 3 | Ordinal link: probit (R/C++) vs cumulative-logit (Julia) | CONFIRMED |
| 4 | Gamma/NB2/Beta dispersion granularity (per-trait vector vs single scalar) | CONFIRMED today (NB2 #132, Beta #148 both open, unchanged since review; Gamma became true only after commit `dff9b363`, 2026-07-05 — NOT true in this form at review time) |
| 5 | W-tier reduced-rank term drops cross-trait covariance in Julia but not C++ | CONFIRMED (matches open issue GLLVM.jl #135) |

**Tally: 4 CONFIRMED, 1 REFUTED, 0 STALE, 0 CANNOT DETERMINE.**

(For context, the sixth original claim — `psi`/residual semantics — was
independently disproved before this audit began: `GLLVM.jl` uses a scalar
`σ_eps`, not a folded `diag(psi)`, verified at `GLLVM.jl/src/likelihood.jl:73`,
`src/likelihood_sparse_phy.jl:110`, and `src/em_squarem.jl:59-60`.)
