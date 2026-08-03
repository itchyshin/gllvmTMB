# Schur-complement equivalence check: our VA fixed-information vs gllvm's

Status: recon / empirical check only. Nothing here is promoted, nothing here
makes `confint.gllvmTMB_va`/`vcov.gllvmTMB_va` return numbers — those remain
`calibrated = FALSE` and error, unchanged. Results LOCAL (D-50).

## Question

The scout established that our `.va_r3_fixed_information_blocked()` and
gllvm's `gllvm:::se.gllvm()` compute the *same formula* — the Schur
complement `H_ff - H_fv H_vv^-1 H_vf` of the observed information of the
negative ELBO, marginalising the variational block. Whether they produce
the *same numbers* was UNVERIFIED. This checks it.

## Setup

One small dataset, fit both ways:

- `N = 60` units, `T = 6` traits, `q = 1` latent dimension.
- Binomial-probit, `Ntrials = 6` (not Bernoulli — pilot runs at `Ntrials = 1`
  produced near-zero `sigma.lv` / exploding loadings for several seeds, a
  genuine near-degeneracy of the small-data cell, not a bug; `Ntrials = 6`
  gives seeds a stable non-degenerate optimum).
- `unique = FALSE` on our side — a single dense tier, gllvm's model exactly.
- Data generated with `set.seed(2)` from a planted loading vector and
  intercepts, then fit by both packages on the identical `y` matrix.

Ours:
```r
gllvmTMB:::.va_r3_fit(y=, n_trials=rep(6,360), X=, unit_id=, trait_id=, q=1,
  family="binomial_probit", link="probit", unique=FALSE, n_starts=1L, H=15L,
  eval_method="ac", collapse_variational_cov=FALSE,
  control=list(eval.max=4000L, iter.max=2000L))
info <- gllvmTMB:::.va_r3_fixed_information(fit$objective, fit$best$par, route="auto")
# -> routes to the blocked Schur; info$se_profile
```

gllvm:
```r
gllvm::gllvm(y=Y, family=binomial(link="probit"), num.lv=1, method="VA",
             Ntrials=6, seed=1L, trace=FALSE)
se <- gllvm:::se.gllvm(fit)   # hits the (num.lv>0, TR=NULL) Schur branch,
                               # A.mat - B.mat %*% solve(D.mat, t(B.mat))
```

Both objectives landed on the same optimum: our reported objective
(negative ELBO) is `593.4345`; gllvm's `logL` is `-593.4345`. Point
estimates (intercepts, loadings) agree to ~1e-5–1e-6 absolute — consistent
with two different optimizers converging to the same point to slightly
different tolerances, not with fitting different models.

Caveat on fit health: our fit's per-start `healthy` flag came back `FALSE`
(`max_abs_gradient = 1.15e-4`, just over the `1e-4` gate) because `n_starts=1`
deliberately bypasses the 3-start agreement gate (documented behaviour, not a
bug) and the gradient sits fractionally over threshold at this tiny scale.
Tightening `control` (`eval.max=4000`, `iter.max=2000`) did not move the
optimum, so this reads as a very flat objective near the optimum for this
cell, not non-convergence. Flagging it rather than hiding it.

The dense route (`route="dense"`) errored (`va_hessian_error_no_fixed_se`) on
this same fit — not investigated, out of scope for this check. The blocked
route is the documented default and is what both this check and the shipped
code use; its own header comment claims it was cross-checked against the
dense route elsewhere to `1.5e-10` relative.

## Why raw parameters aren't directly comparable

- gllvm pins the loading matrix's diagonal to 1 (`theta[1,1] = 1`, no SE) and
  carries the free scale in `sigma.lv`; we leave loadings entirely free in
  `theta_rr`. Different parameterisations of the same rotation/sign-ambiguous
  quantity.
- gllvm's `se.gllvm()` excludes `ePower`, `lambda2`, `Ab_lv`, `sigmab_lv`
  from its `incl` set. None of those apply here (no quadratic response model,
  no random loadings) so this exclusion made no difference to this
  comparison, but it means the two `incl` sets are not identical in general.
- So instead of comparing raw information matrices, we compared two
  *derived quantities both sides can express*: (a) the intercept block
  directly (`beta` vs `beta0`, same parameterisation on both sides), and
  (b) each loading `Lambda_j`, computed on our side directly (`theta_rr` is
  already `Lambda` for `q=1`) and on gllvm's side by the delta method
  (`Lambda_j = theta_j * sigma.lv`, propagated through gllvm's own full
  `cov.mat.mod`, not just its marginal SEs).

## Results

**Intercepts** (`beta` vs `beta0`, directly comparable — same parameterisation):

| trait | ours SE    | gllvm SE   | abs diff   | rel diff   |
|-------|------------|------------|------------|------------|
| 1     | 0.13542817 | 0.13542807 | 1.03e-07   | 7.60e-07   |
| 2     | 0.07587273 | 0.07587273 | 1.41e-09   | 1.85e-08   |
| 3     | 0.16749905 | 0.16749941 | 3.60e-07   | 2.15e-06   |
| 4     | 0.15230336 | 0.15230374 | 3.90e-07   | 2.56e-06   |
| 5     | 0.06891580 | 0.06891583 | 3.01e-08   | 4.37e-07   |
| 6     | 0.06640752 | 0.06640751 | 9.57e-09   | 1.44e-07   |

Max relative difference: **2.56e-06**.

**Loadings** (`Lambda_j`; ours = `theta_rr` directly since `q=1`; gllvm =
delta method on `theta_j * sigma.lv` using gllvm's own full covariance
matrix, `Lambda_1`'s SE = `SE(sigma.lv)` exactly since `theta_1` is pinned):

| j | ours SE    | gllvm SE (delta) | abs diff   | rel diff   |
|---|------------|-------------------|------------|------------|
| 1 | 0.12300603 | 0.12300769        | 1.66e-06   | 1.35e-05   |
| 2 | 0.07654406 | 0.07654401        | 4.66e-08   | 6.09e-07   |
| 3 | 0.15741575 | 0.15741667        | 9.17e-07   | 5.83e-06   |
| 4 | 0.13993744 | 0.13993815        | 7.15e-07   | 5.11e-06   |
| 5 | 0.07258385 | 0.07258376        | 8.89e-08   | 1.22e-06   |
| 6 | 0.07038014 | 0.07038004        | 1.00e-07   | 1.43e-06   |

Max relative difference: **1.35e-05**.

Both max relative differences (2.6e-6 for intercepts, 1.4e-5 for loadings)
are of the same order as the point-estimate disagreement between the two
optima (~1e-5–1e-6 absolute on parameters an order of magnitude larger than
0), i.e. fully explained by the two packages' optimizers stopping at
very slightly different points on a shared flat objective — not by any
difference in the information-matrix formula itself.

## Verdict: SAME NUMBERS

On every quantity that could be honestly aligned across the two
parameterisations — the intercept block directly, and the loadings via
delta-method on the rotation/sign-consistent `Lambda_j` — our blocked Schur
complement (`.va_r3_fixed_information_blocked()`) and gllvm's
`se.gllvm()` Schur complement agree to 4–6 significant figures, with the
residual disagreement fully attributable to the two optimizers converging to
slightly different points rather than to any difference in the SE formula.

This settles the previously-UNVERIFIED claim: the two implementations of
"observed information of the negative ELBO, Schur-complemented against the
variational block" are numerically the same computation, not merely the same
algebra on paper. It does **not** say anything about whether that Wald SE is
*calibrated* (nominal coverage) — that is exactly the open question the
coverage campaign this work feeds into is designed to answer, and per the
unifying-hypothesis framing this is the arm that assumes the information
matrix equality holds, so agreeing with gllvm here means we and gllvm would
fail together if that assumption is wrong.

## What was not checked

- Only `q = 1`. Off-diagonal `L_off` variational terms (`q > 1`) were not
  exercised, so the block-diagonal Schur's off-diagonal correctness at higher
  rank is untested here (the header comment claims a 1.5e-10 cross-check
  against the dense route elsewhere, but the dense route errored in this
  session and was not chased down).
- Only one seed / one small `N`. No claim about behaviour as `N` grows, or
  about coverage — that is the campaign this is recon for, not this check.
- `se_conditional` (the naive, documented-anti-conservative conditional SE)
  was extracted but not compared to gllvm — gllvm does not expose that
  quantity, so there is nothing on gllvm's side to compare it to.
