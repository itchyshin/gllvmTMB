# gllvm 2.0.13 reference read: closed-form VA for binomial-probit and ordinal-probit

**Source**: `gllvm` 2.0.13, installed binary-only (no `R/*.R`, no `src/` in this
environment). Extracted via
`writeLines(deparse(body(gllvm:::gllvm.VA)), "/tmp/gllvm_va_body.txt")`
(1315 lines) and `writeLines(deparse(gllvm:::calc.quad), "/tmp/gllvm_calcquad.txt")`
(43 lines). Also deparsed for cross-checking: `gllvm:::glmmVA` (149 lines),
`gllvm:::gllvm.TMB` (4086 lines).

**Provenance / scope notice**: this document quotes short expressions
(a few lines each) verbatim from the deparsed `gllvm` source, strictly for
mathematical comparison against gllvmTMB's own VA implementation. Nothing
here is, or should be, ported/copied into any gllvmTMB source file. All line
numbers below refer to `/tmp/gllvm_va_body.txt` unless stated otherwise
(`calc.quad` line numbers refer to `/tmp/gllvm_calcquad.txt`).

**Notation-mapping warning** (read this before the rest): gllvm's variable
`theta` is the p x d matrix of species/column loadings (row j = loadings of
column j). gllvm's variable `lambda` / `Lambda` (confusingly) is *not* a
loading — it is the per-observation covariance matrix of the variational
posterior on the latent variable (n x d, or n x d x d for the unstructured
case). So the task's notation "`A_i = (I_d + sum_j lambda_j lambda_j')^{-1}`"
(where `lambda_j` = species j's loading vector) corresponds in gllvm's own
naming to `A_i = new.lambda[i,,]`, computed from `theta[j,]` (loadings), i.e.
`A_i = (I_d + sum_j theta_j theta_j')^{-1}`. gllvm's `lambda` = the task's
`A_i`; gllvm's `theta` = the task's per-species loading vector `lambda_j`.
This is the single biggest source-vs-task naming collision and is flagged
explicitly to avoid mistranslation.

---

## 1. Binomial-probit objective

Location: `ll0` closure inside the main EM `while` loop, family branch at
lines 381-389. The shared linear-predictor construction that feeds it is
lines 353-367.

Shared construction (all families), lines 353-367:

```r
mu.mat <- matrix(new.beta0, n, p, byrow = TRUE) + offset
if (!is.null(X) && is.null(TR))  mu.mat <- mu.mat + X %*% t(new.env)
if (!is.null(TR))                mu.mat <- mu.mat + matrix((Xd %*% B), n, p)
if (row.eff != FALSE)            mu.mat <- mu.mat + matrix(new.row.params, n, p, byrow = FALSE)
if (num.lv > 0)                  mu.mat <- mu.mat + new.vameans %*% t(new.theta)
eta.mat <- mu.mat
if (num.lv > 0)
    eta.mat <- eta.mat + calc.quad(new.lambda, new.theta, tmp.Lambda.struc)$mat
```

`mu.mat` = fixed/trait effects + row effect + `vameans %*% t(theta)`, i.e. the
linear predictor evaluated **at the variational mean** only (no variance
correction). `eta.mat` = `mu.mat` **plus** the closed-form quadratic term
`calc.quad(...)$mat` (see item 5's sibling function, `calc.quad`, described
below): `calc.quad$mat[i,j] = 0.5 * theta_j' A_i theta_j` (diagonal case:
`0.5 * sum_l lambda[i,l] * theta[j,l]^2`, `calc.quad` line 4; unstructured
case: `0.5 * theta[j,]' %*% lambda[i,,] %*% theta[j,]`, `calc.quad` lines
21-40).

Binomial branch, lines 381-389:

```r
if (family == "binomial") {
    probs <- pnorm(mu.mat)
    out1 <- dbinom(as.matrix(y), size = trial.size, prob = probs, log = TRUE)
    out1 <- sum(out1[is.finite(out1)])
    if (num.lv > 0)
        out1 <- out1 - calc.quad(new.lambda, new.theta, tmp.Lambda.struc)$mat.sum
}
```

**What is actually formed**: `probs = Phi(mu.mat)` uses `mu.mat`, i.e. the
plug-in linear predictor at the variational mean — it does **not** use
`eta.mat` (the version with the quadratic term folded in). `dbinom(y, 1,
probs, log = TRUE)` is then the ordinary Bernoulli/binomial log-density at
that plug-in probability, summed over finite cells only (`out1[is.finite(out1)]`
silently drops any `-Inf`/`NaN` cells rather than penalizing or erroring on
them). Only *after* this per-cell sum is a single **aggregate scalar**
correction subtracted: `calc.quad(...)$mat.sum`, which is
`sum_i sum_j 0.5 * theta_j' A_i theta_j` — the same quadratic form used
verbatim for Poisson, but here applied once in total rather than folded into
each cell's nonlinearity. Contrast with Poisson (lines 368-370,
`out1 <- sum(y * mu.mat - lfactorial(y) - exp(eta.mat))`): there,
`calc.quad$mat` is embedded *inside* `exp(eta.mat)` per cell, which is the
exact Gaussian moment-generating-function identity `E[exp(Z)] =
exp(mu + 0.5*Var(Z))` for `Z ~ N(mu_ij, theta_j' A_i theta_j)` — an exact
closed form, not an approximation. Binomial has no analogous exact identity
for `E[log Phi(Z)]`, so instead of touching the `pnorm` argument at all, the
code just adds the *same functional form* of quadratic penalty as an
aggregate afterthought. **Inference** (not asserted as gllvm's stated
derivation, since no comments/vignette are present in the deparsed body): this
reads as a fixed-curvature (Bohning-style) quadratic bound applied uniformly
rather than a mean-dependent second-order correction — consistent with the
family split seen in item 5, where the lambda-update for binomial/ordinal
drops the `mu.mat[i,]` weighting that Poisson/NB retain.

**No quadrature anywhere in this expression** — confirmed by direct
inspection (`pnorm`, `dbinom`, `calc.quad`'s closed-form matrix algebra only)
and by the grep in item 6.

The common entropy/KL-to-N(0,I) closing term (applies to every family, not
binomial-specific), lines 412-426:

```r
if (tmp.Lambda.struc == "unstructured") {
    foo2 <- function(i) {
        0.5 * (log(det(new.lambda[i, , ])) - sum(diag(new.lambda[i, , ])) - sum(new.vameans[i, ]^2))
    }
}
if (tmp.Lambda.struc == "diagonal") {
    foo2 <- function(i) {
        0.5 * (sum(log(t(new.lambda)[, i])) - sum(t(new.lambda)[, i]) - sum(new.vameans[i, ]^2))
    }
}
out1 <- out1 + sum(sapply(1:n, foo2))
```

This is `0.5*(log|A_i| - tr(A_i) - ||vameans_i||^2)` per row, i.e. the
standard closed-form negative KL divergence `KL(N(vameans_i, A_i) ||
N(0,I_d))` up to the additive constant `+d` (omitted — it doesn't affect
optimization). So the full binomial ELBO = plug-in Bernoulli log-lik (naive,
at the mean) − aggregate quadratic penalty (`calc.quad$mat.sum`) + per-row
Gaussian entropy/KL term. Everything here is closed-form linear algebra
(`det`, `diag`, matrix products) — no numerical integration of any kind.

---

## 2. Binomial-probit gradient

Location: `grad.mod` closure, binomial branch, lines 555-594 (the task's
suggested 556-591 sits inside this). Uses `eta.mat` (line 470-481, same
plug-in construction as `mu.mat` above but named `eta.mat` in this closure —
note this closure does **not** add `calc.quad$mat` into `eta.mat` for the
binomial branch, unlike the poisson branch immediately above it at lines
482-485).

```r
if (family == "binomial") {
    probs <- pnorm(eta.mat)
    grad.beta0 <- colSums(dnorm(eta.mat) * (y - trial.size * probs) /
        (probs * (1 - probs) + 1e-05), na.rm = TRUE)
    if (num.lv > 0) {
        for (l in 1:num.lv) {
            if (tmp.Lambda.struc == "unstructured")
                sum1 <- sweep(dnorm(eta.mat) * (y - trial.size * probs) /
                    (probs * (1 - probs) + 1e-05), 1, new.vameans[, l], "*") -
                    t(Lambda.theta[, , l])
            if (tmp.Lambda.struc == "diagonal")
                sum1 <- sweep(dnorm(eta.mat) * (y - trial.size * probs) /
                    (probs * (1 - probs) + 1e-05), 1, new.vameans[, l], "*") -
                    (new.lambda[, l] %*% t(new.theta[, l]))
            grad.theta <- c(grad.theta, colSums(sum1, na.rm = TRUE))
        }
    }
    if (!is.null(X) && is.null(TR)) {
        for (l in 1:num.X) {
            sum1 <- sweep(dnorm(eta.mat) * (y - trial.size * probs) /
                (probs * (1 - probs) + 1e-05), 1, X[, l], "*")
            grad.env <- c(grad.env, colSums(sum1))
        }
    }
    if (row.eff != FALSE)
        grad.row.params <- rowSums(dnorm(eta.mat) * (y - trial.size * probs) /
            (probs * (1 - probs) + 1e-05), na.rm = TRUE)
}
```

**Score expression**: for every parameter block (species intercept
`beta0`, loadings `theta`, environmental coefficients `env`, row effect), the
common factor is

```
s_ij = phi(eta_ij) * (y_ij - m*Phi(eta_ij)) / (Phi(eta_ij)*(1-Phi(eta_ij)) + 1e-5)
```

(`phi`=`dnorm`, `Phi`=`pnorm`, `m`=`trial.size`). This is exactly the
classical probit score `d/deta [log dbinom(y; m, Phi(eta))]`
`= phi(eta) * (y - m*Phi(eta)) / (Phi(eta)*(1-Phi(eta)))`, with a `1e-5`
additive jitter in the denominator purely for numerical safety against
`Phi(eta)` landing at exactly 0 or 1. `grad.beta0` sums `s_ij` over rows per
species; `grad.theta` (per latent dimension `l`) is `colSums(s_ij *
vameans_i,l) - [quadratic-term gradient]`, where the subtracted piece is
`t(Lambda.theta[,,l])` (unstructured) or `new.lambda[,l] %*% t(new.theta[,l])`
(diagonal) — i.e. the gradient of the *same* `calc.quad$mat.sum` correction
from item 1, differentiated w.r.t. `theta`. `grad.env` is the analogous
per-covariate score. This confirms the gradient is the exact analytic
derivative of the item-1 objective (naive plug-in probit log-lik minus
aggregate quadratic penalty) — no numerical differentiation, no quadrature.

---

## 3. The truncated-normal moment terms (`deriv.trunnorm`)

This is the Albert–Chib inverse-Mills-ratio machinery, present in two places:
the model-parameter gradient (`grad.mod`, ordinal branch, lines 595-658) and
the variational-mean gradient (`grad.var`, ordinal branch, lines 1022-1050).
Both compute the same three-way piecewise expression; I reproduce the first
occurrence in full (lines 607-628), which is the fullest and clearest:

```r
deriv.trunnorm <- matrix(0, n, p)
for (j in 1:p) {
    deriv.trunnorm[y[, j] == 1, j] <-
        -dnorm(new.zeta[j, 1] - eta.mat[y[, j] == 1, j]) /
         pnorm(new.zeta[j, 1] - eta.mat[y[, j] == 1, j])

    deriv.trunnorm[y[, j] == max(y[, j]), j] <-
        dnorm(new.zeta[j, max(y[, j]) - 1] - eta.mat[y[, j] == max(y[, j]), j]) /
        (1 - pnorm(new.zeta[j, max(y[, j]) - 1] - eta.mat[y[, j] == max(y[, j]), j]))

    if (max(y[, j]) > 2) {
        j.levels <- 2:(max(y[, j]) - 1)
        for (k in j.levels) {
            deriv.trunnorm[y[, j] == k, j] <-
                (-dnorm(new.zeta[j, k] - eta.mat[y[, j] == k, j]) +
                  dnorm(new.zeta[j, k - 1] - eta.mat[y[, j] == k, j])) /
                (pnorm(new.zeta[j, k] - eta.mat[y[, j] == k, j]) -
                  pnorm(new.zeta[j, k - 1] - eta.mat[y[, j] == k, j]))
        }
    }
}
deriv.trunnorm[!is.finite(deriv.trunnorm)] <- 0
```

**This is exactly the score of the cumulative-probit log-likelihood w.r.t.
the linear predictor `eta`**, i.e. `d/deta log[Phi(zeta_k - eta) -
Phi(zeta_{k-1} - eta)]`, which is the negative of the standard truncated-
normal (inverse Mills ratio) mean-shift term. Concretely, writing
`a = zeta_{k-1}-eta`, `b = zeta_k-eta` (with `zeta_0 := -Inf` folded into the
first-category branch and `zeta_K := +Inf` folded into the last-category
branch):

- first category (`y=1`, only an upper cutoff `zeta_1`):
  `deriv = -phi(zeta_1 - eta) / Phi(zeta_1 - eta)`
- last category (`y=max`, only a lower cutoff `zeta_{K-1}`):
  `deriv = phi(zeta_{K-1} - eta) / (1 - Phi(zeta_{K-1} - eta))`
- interior category `k`:
  `deriv = [phi(zeta_{k-1}-eta) - phi(zeta_k-eta)] / [Phi(zeta_k-eta) - Phi(zeta_{k-1}-eta)]`

Each of these is precisely `-E[Z | a < Z-eta < b]`-type inverse-Mills-ratio
term for a standard normal `Z`, restricted to the interval implied by the
observed ordinal category — the same expression that underlies Albert &
Chib's (1993) latent-normal Gibbs sampler for probit/ordinal models, here
used analytically as a gradient rather than sampled. `deriv.trunnorm` is then
used exactly like a "residual" (`y - E[y|eta]`) is used in the Gaussian/
Poisson gradients elsewhere in the same function: `grad.beta0 <-
colSums(deriv.trunnorm)` (line 629), and it is swept against `vameans`/`X`
columns to build `grad.theta`/`grad.env` (lines 630-653), in the same pattern
as the binomial branch in item 2. `deriv.trunnorm[!is.finite(...)] <- 0`
(line 628) again silently zeroes non-finite cells rather than handling the
tail case specially.

Second occurrence (`grad.var`, lines 1022-1050) is the *identical* piecewise
formula (compare lines 1025-1040 to 609-624, character-for-character
identical apart from variable renaming context), used to build
`grad.vameans` instead of `grad.theta`/`grad.beta0`:

```r
for (l in 1:num.lv) {
    grad.vameans <- c(grad.vameans, rowSums(sweep(deriv.trunnorm, 2, new.theta[, l], "*")) - new.vameans[, l])
}
```
(lines 1045-1049) — i.e. `d(ELBO)/d(vameans_l) = rowSums(deriv.trunnorm *
theta_l) - vameans_l`, the truncated-normal score projected onto loading
dimension `l`, minus the `N(0,I)` prior's linear pull-back term. This is the
same score-based construction whether the free parameter is a species
intercept/loading or a variational mean — Albert–Chib's inverse Mills ratio
is the single reusable primitive for both the M-step and the (BFGS-based,
not closed-form) update of `vameans` in the ordinal/binomial case.

Binomial's gradient (item 2) does **not** call `deriv.trunnorm` — it uses
`dnorm(eta)*(y - m*Phi(eta))/(Phi(eta)(1-Phi(eta)))` directly, which is
mathematically the two-category (`K=2`) special case of the same
inverse-Mills-ratio construction (the general ordinal `deriv.trunnorm`
collapses to the binomial score when there is exactly one cutpoint at 0 and
two categories), but gllvm implements it as a separate, non-shared code path
rather than calling a common helper.

---

## 4. Cumulative-probit ordinal objective and cutpoints

**Objective**, `ll0` ordinal branch, lines 390-411:

```r
if (family == "ordinal") {
    out1 <- matrix(NA, n, p)
    for (j in 1:p) {
        out1[y[, j] == 1, j] <- pnorm(new.zeta[j, 1] - mu.mat[y[, j] == 1, j], log.p = TRUE)
        out1[y[, j] == max(y[, j]), j] <- log(1 - pnorm(new.zeta[j, max(y[, j]) - 1] -
            mu.mat[y[, j] == max(y[, j]), j]))
        if (max(y[, j]) > 2) {
            j.levels <- 2:(max(y[, j]) - 1)
            for (k in j.levels) {
                out1[y[, j] == k, j] <- log(pnorm(new.zeta[j, k] - mu.mat[y[, j] == k, j]) -
                    pnorm(new.zeta[j, k - 1] - mu.mat[y[, j] == k, j]))
            }
        }
    }
    out1 <- sum(out1[is.finite(out1)])
    if (num.lv > 0)
        out1 <- out1 - calc.quad(new.lambda, new.theta, tmp.Lambda.struc)$mat.sum
}
```

Structurally this is the binomial pattern (item 1) generalized to `K`
categories: naive plug-in log-lik at `mu.mat` (not `eta.mat`) for every
cell, summed over finite entries only, then one aggregate `calc.quad$mat.sum`
subtracted at the end. Exactly as in item 1, there is no per-cell folding of
the quadratic variance term into the `pnorm` argument for any category.

**Cutpoint parameterisation**, block at lines 875-943 (`func.zetaj`/
`grad.zetaj`/the `constrOptim` call and its per-species loop):

```r
func.zetaj <- function(cw.zeta, j) {
    zeta0 <- c(0, cw.zeta)
    out <- 0
    out <- out + sum(pnorm(zeta0[1] - eta.mat[which(y[, j] == 1), j], log.p = TRUE))
    out <- out + sum(log(1 - pnorm(zeta0[max(y[, j]) - 1] -
        eta.mat[which(y[, j] == max(y[, j])), j])))
    if (max(y[, j]) > 2) {
        j.levels <- 2:(max(y[, j]) - 1)
        for (k in j.levels) {
            out <- out + sum(log(pnorm(zeta0[k] - eta.mat[y[, j] == k, j]) -
                pnorm(zeta0[k - 1] - eta.mat[y[, j] == k, j])))
        }
    }
    out
}
```

and the per-species update (lines 918-940):

```r
for (j in 1:p) {
    if (max(y[, j]) == 2)  new.zeta[j, ] <- zeta[j, ]
    if (max(y[, j]) > 2) {
        constraint.mat <- matrix(0, max(y[, j]) - 2, max(y[, j]) - 2)
        constraint.mat[1, 1] <- 1
        if (nrow(constraint.mat) > 1) {
            for (k in 2:nrow(constraint.mat)) constraint.mat[k, (k - 1):k] <- c(-1, 1)
        }
        update.zeta <- constrOptim(theta = zeta[j, 2:(max(y[, j]) - 1)],
            f = func.zetaj, grad = grad.zetaj, ui = constraint.mat,
            ci = rep(0, max(y[, j]) - 2), j = j, outer.eps = 0.001,
            control = list(trace = 0, fnscale = -1))
        if (!inherits(update.zeta, "try-error"))
            new.zeta[j, 2:(max(y[, j]) - 1)] <- update.zeta$par
        if (inherits(update.zeta, "try-error"))
            new.zeta[j, ] <- zeta[j, ]
    }
}
```

**Parameterisation answer**: cutpoints are stored per-species as a raw
numeric vector `zeta[j, ]`; the *first* cutpoint is implicitly fixed at 0
(`zeta0 <- c(0, cw.zeta)` — `cw.zeta` only ever holds cutpoints
`zeta[j, 2:(K-1)]`) as the identifiability constraint against the free
species intercept `beta0[j]`. Free cutpoints `zeta[j, 2:(K-1)]` are kept
increasing not by a monotone reparameterisation (e.g. cumulative sum of
`exp()`-transformed increments) but by an **explicit linear inequality
constraint** passed to `constrOptim`: `constraint.mat` encodes
`zeta[j,2] >= 0` (row 1) and `zeta[j,k] - zeta[j,k-1] >= 0` for `k>=3` (rows
2..), i.e. ordering is enforced at the optimizer level via `ui`/`ci`, not
via the parameterisation itself. If `constrOptim` throws (`try-error`,
which naturally happens if the naive log-difference below underflows to
`-Inf`/`NaN` — see next paragraph), the whole species' cutpoints are simply
left unchanged for that iteration (silent fallback, line 937-938).

**Numerical stability in the tails — answer: mostly naive, not fully
stable.** Three sub-cases:
1. First category: `pnorm(x, log.p = TRUE)` — this **is** R's numerically
   stable log-CDF (accurate deep in the left tail), correctly used.
2. Last category: `log(1 - pnorm(x))` — this is the **naive** complement
   form. The numerically robust identity would be `pnorm(x, lower.tail =
   FALSE, log.p = TRUE)` (equivalently `pnorm(-x, log.p = TRUE)`), which
   gllvm does **not** use here. When `x = zeta_{K-1} - eta` is very negative
   (deep in the tail where category `K` is essentially certain), `pnorm(x)`
   underflows toward 0 gracefully, so `log(1-pnorm(x))` is fine in that
   direction; but there is no protection in the direction where
   `1 - pnorm(x)` itself underflows to exactly 0 (giving `-Inf`).
3. Interior categories: `log(pnorm(upper) - pnorm(lower))` — **fully naive**,
   no log-space subtraction trick (no `log1p`/`expm1`/log-sum-exp style
   stabilisation) at all. When both bounds are deep in the same tail (both
   `pnorm` values close to 0 or both close to 1), this subtraction loses
   relative precision by catastrophic cancellation, same failure mode as
   the binomial two-category case would have if it were computed this way
   (it isn't — binomial has only one cutpoint, handled by the exact
   `dbinom`/`pnorm` calls in item 1/2, so it doesn't hit this).

Downstream, both `ll0` (line 407, `out1 <- sum(out1[is.finite(out1)])`) and
`deriv.trunnorm` (line 628/1044, `[!is.finite(...)] <- 0`) paper over any
resulting `-Inf`/`NaN` by silently dropping/zeroing those cells rather than
using a stable log-space computation — so the *practical* answer to "does it
do anything special for numerical stability" is: partially (only the
absolute-first category gets a genuinely stable one-sided log-CDF call), and
the fallback for everything else is silent omission of non-finite terms
rather than a stable reformulation.

---

## 5. The variational covariance closed form

Location: per-row `for (i in 1:n)` loop with an inner fixed-point `while`,
lines 1125-1200 (the family-specific solve is lines 1134-1156). Also uses
the standalone helper `calc.quad` (`/tmp/gllvm_calcquad.txt`, full 43-line
body already quoted in relevant part below), which is *not* the closed-form
covariance update itself but the quadratic-form the update is built to
control.

```r
for (i in 1:n) {
    error <- 1
    lambda.iter <- 0
    if (tmp.Lambda.struc == "unstructured") new.lambda.mat <- lambda[i, , ]
    if (tmp.Lambda.struc == "diagonal")     new.lambda.mat <- diag(x = lambda[i, ], nrow = num.lv)
    while (error > 0.01 && lambda.iter < 100) {
        cw.lambda.mat <- new.lambda.mat
        if (tmp.Lambda.struc == "unstructured") {
            theta2 <- sapply(1:p, function(j, theta) theta[j, ] %*% t(theta[j, ]), theta = new.theta)
            theta2 <- t(theta2)
            if (family %in% c("poisson", "negative.binomial"))
                new.lambda.mat <- solve(diag(rep(1, num.lv)) +
                    matrix(apply(mu.mat[i, ] * theta2, 2, sum), nrow = num.lv))
            if (family %in% c("binomial", "ordinal"))
                new.lambda.mat <- solve(diag(rep(1, num.lv)) +
                    matrix(apply(theta2, 2, sum), nrow = num.lv))
        }
        if (tmp.Lambda.struc == "diagonal") {
            theta2 <- new.theta^2
            if (family %in% c("poisson", "negative.binomial"))
                new.lambda.mat <- solve(diag(rep(1, num.lv)) +
                    diag(apply(mu.mat[i, ] * theta2, 2, sum), num.lv, num.lv))
            if (family %in% c("binomial", "ordinal"))
                new.lambda.mat <- solve(diag(rep(1, num.lv)) +
                    diag(apply(theta2, 2, sum), num.lv, num.lv))
        }
        error <- sum((new.lambda.mat - cw.lambda.mat)^2)
        ... [re-derives eta.mat/mu.mat for the poisson/NB branches only; lines 1162-1181]
        lambda.iter <- lambda.iter + 1
    }
    if (tmp.Lambda.struc == "unstructured") new.lambda[i, , ] <- new.lambda.mat
    if (tmp.Lambda.struc == "diagonal")     new.lambda[i, ] <- diag(new.lambda.mat)
    if ((family %in% c("binomial", "ordinal")) & i == 1) break
}
if (family %in% c("binomial", "ordinal")) {
    if (tmp.Lambda.struc == "diagonal")     for (i2 in 2:n) new.lambda[i2, ] <- new.lambda[1, ]
    if (tmp.Lambda.struc == "unstructured") for (i2 in 2:n) new.lambda[i2, , ] <- new.lambda[1, , ]
}
```

**Yes, the closed form appears, exactly**: for binomial/ordinal,
`new.lambda.mat = solve(I_d + sum_j theta_j theta_j')` (unstructured;
`theta2` there is literally `theta[j,] %*% t(theta[j,])` summed over `j`),
or, in the diagonal case, elementwise `A_l = 1/(1 + sum_j theta_{j,l}^2)`
per latent dimension `l` (`diag(apply(theta2, 2, sum), ...)` inverted). This
is precisely `A_i = (I_d + sum_j lambda_j lambda_j')^{-1}` in the task's
notation (`lambda_j` there = gllvm's `theta[j,]`, per the notation-mapping
warning at the top of this document).

**Is it computed directly or iteratively — answer: both, but for a
structural reason, not a numerical-difficulty one.** The surrounding
scaffolding (`while (error > 0.01 && lambda.iter < 100)`, a genuine
fixed-point iteration) is written generically to serve **Poisson/negative-
binomial**, where `new.lambda.mat` depends on `mu.mat[i, ]`, which itself
depends on `new.lambda.mat` through `calc.quad` (lines 1172-1180 recompute
`mu.mat` inside the same `while` using the just-updated `lambda`) — a real
circular fixed point that needs genuine iteration to converge. For
**binomial and ordinal**, the right-hand side (`apply(theta2, 2, sum)`) does
not involve `mu.mat[i, ]` or the previous `cw.lambda.mat` at all — it is a
pure, one-shot function of `theta` alone, identical for every row `i` (no
`i`-subscript anywhere in the binomial/ordinal solve). This is exactly why
the code special-cases the outer `for (i in 1:n)` loop for these two
families: it runs the (still nominally-iterative, but converges in exactly
one pass) computation only once, for `i == 1` (`break` at line 1188-1190),
then **copies row 1's result to every other row** in the block at lines
1192-1199. So concretely: **`A_i` is the same matrix for every observation
`i`, for binomial and ordinal**; it is computed once via a single matrix
inversion and broadcast, not solved per-row and not genuinely iterated
(the `while` loop's first pass already sits at the fixed point for these two
families — `error` would already reflect no further change on a second
pass, though the loop structure doesn't special-case that away).

`calc.quad` itself (the quadratic form `A_i` is built to bound), full body:

```r
function (lambda, theta, Lambda.struc) {
    if (Lambda.struc == "diagonal")
        out <- 0.5 * (lambda) %*% t(theta^2)
    if (Lambda.struc == "unstructured") {
        ... # builds out[i,j] = 0.5 * theta[j,]' %*% lambda[i,,] %*% theta[j,]
    }
    return(list(mat = out, mat.sum = sum(out)))
}
```
(`calc.quad` lines 1-43; diagonal case at line 4; unstructured branch spans
lines 5-40, returning the same quadratic form via matrix-array bookkeeping
rather than an explicit per-(i,j) double loop). No quadrature, no sampling —
pure closed-form bilinear algebra, confirming item 6's negative claim from
this function's side as well.

---

## 6. Negative claim: no quadrature/Hermite/GHQ/Gauss anywhere

```
$ grep -niE 'quadrature|hermite|ghq|gauss' /tmp/gllvm_va_body.txt
(no output, exit code 1)
$ grep -niE 'quadrature|hermite|ghq|gauss' /tmp/gllvm_calcquad.txt
(no output, exit code 1)
$ grep -niE 'quadrature|hermite|ghq|gauss' /tmp/gllvm_glmmVA.txt
(no output, exit code 1)
```

**Confirmed: zero occurrences** of `quadrature`, `hermite`, `ghq`, or `gauss`
(case-insensitive) in the deparsed bodies of `gllvm:::gllvm.VA`,
`gllvm:::calc.quad`, and `gllvm:::glmmVA`. This matches the prior probe's
claim exactly.

As a bonus (broader) check, the same grep against the much larger
`gllvm:::gllvm.TMB` (4086 lines, the separate compiled/Laplace path, not the
function this task is about) does return 5 hits — all of them are the string
`"gaussian"` as a response-family name (`familyn[family == "gaussian"] =
3`, lines 1575-1576/2460-2461, and the family whitelist itself at line
646-648: `"tweedie", "ZIP", "ZIB", "ZINB", "ZNIB", "gaussian"`). There is
**no** `quadrature`, `hermite`, or `ghq` anywhere in `gllvm.TMB` either — the
only "gauss"-adjacent text in the entire deparsed VA+TMB surface is the
Gaussian *response distribution* name, unrelated to Gauss-Hermite
quadrature. (Caveat: `gllvm.TMB` calls into a compiled TMB C++ template for
its actual Laplace approximation, which this deparse cannot see — so this
bonus check only rules out quadrature in the R-level TMB *wrapper* code, not
inside compiled templates. It does not weaken the primary claim for
`gllvm.VA`, which is pure R with no compiled call at all.)

---

## 7. What gllvm's VA implementation does NOT do (relative to a more general design)

All of the following are grounded in explicit absence/whitelisting found in
`gllvm.VA`'s own body (not an outside claim about gllvmTMB):

- **Family whitelist is narrow in this path**: line 144-146,
  `if (!(family %in% c("poisson", "negative.binomial", "binomial",
  "ordinal"))) stop(...)`. Only four families are reachable through the
  closed-form VA route at all. (The separate `gllvm.TMB`/Laplace path
  supports far more — `tweedie, ZIP, ZIB, ZINB, ZNIB, gaussian, gamma, beta,
  betaH, orderedBeta`, per the grep above — but that is a different
  estimation method, not this closed-form VA.)
- **`Lambda.struc` whitelist has exactly two shapes**: line 147-148,
  `"unstructured"` or `"diagonal"` only — a single common shape for the
  per-row variational covariance. There is no intermediate block-structured
  or low-rank-plus-diagonal option.
- **No cross-observation correlation structure of any kind.** The prior/KL
  term (`foo2`, lines 412-426) penalizes each row `i`'s variational mean
  only via `sum(new.vameans[i, ]^2)` — an independent `N(0, I_d)` prior per
  row, with no cross-`i` covariance term anywhere. There is no argument to
  `gllvm.VA` (checked against the full formal-argument list: `y, X, TR,
  formula, family, num.lv, max.iter, eps, row.eff, Lambda.struc, trace,
  plot, sd.errors, start.lvs, offset, maxit, diag.iter, seed, get.fourth,
  get.trait, n.init, constrOpt, restrict, start.params, starting.val,
  Lambda.start, jitter.var, yXT`) that could carry a phylogenetic, spatial,
  or kernel correlation matrix over rows — i.e. nothing corresponding to
  gllvmTMB's `phylo_latent`/`animal_latent`/`spatial_latent`/`kernel_latent`
  family exists in this function at all. Ordination rows/columns are
  exchangeable by construction.
- **Loadings identifiability is a single hard-zeroing trick, not a
  reparameterisation.** The only constraint ever applied to `theta` is
  `new.theta[upper.tri(new.theta)] <- 0` (lines 220, 332, 440, 744, 1245,
  and the corresponding `grad.theta[upper.tri(grad.theta)] <- 0` at line
  661) — zero out the upper triangle after each unconstrained BFGS step.
  There is no Cholesky-based unconstrained-to-constrained mapping, no
  orthogonality projection, and no explicit sign/scale-fixing beyond the
  triangular zeroing.
- **Row effect is a single scalar per row, and the "random" option looks
  incompletely wired in this path.** `row.eff` is `FALSE`/`"fixed"`/
  `"random"` (lines 193-197), but every subsequent use only ever tests
  `row.eff != FALSE` (e.g. lines 212, 349, 457, 511, 590, 654, 763, 805,
  870, 985, 1065, 1169) — fixed and random are treated identically by the
  optimizer, which just runs BFGS on `row.params` with one coefficient
  pinned via `grad.row.params[1] = 0` (line 664, a fixed-effect-style
  reference-level trick). The `dr <- diag(n)` object built specifically for
  `row.eff == "random"` (line 194) is **never referenced again anywhere
  else in the 1315-line body** (verified by a full-file grep for `\bdr\b`) —
  no random-effect variance component for the row effect is visible in this
  function at all. This may be handled elsewhere (e.g. in
  `calc.infomat`, not read for this task) but is not in `gllvm.VA` itself.
- **Optimization is staged, generic BFGS/`constrOptim`, not joint autodiff.**
  The whole procedure is hand-written coordinate-ascent-style EM: an outer
  `while` loop alternates (a) a joint BFGS update of
  `theta, beta0, env, B, row.params` via hand-coded `ll0`/`grad.mod`
  closures, (b) a separate dispersion-parameter BFGS step for negative
  binomial, (c) a separate per-species `constrOptim` step for ordinal
  cutpoints, (d) a separate BFGS step for the variational means
  (`grad.var`), and (e) the closed-form/fixed-point update for the
  variational covariances just described in item 5 — five distinct
  optimizer calls per outer iteration, each with hand-derived gradients,
  rather than one autodiff-driven joint optimization (which is what
  `gllvm.TMB`/TMB-based approaches, including gllvmTMB, do instead).

---

## Summary of files produced by this read

- `/tmp/gllvm_va_body.txt` — 1315-line deparsed body of `gllvm:::gllvm.VA`.
- `/tmp/gllvm_calcquad.txt` — 43-line deparsed body of `gllvm:::calc.quad`.
- `/tmp/gllvm_glmmVA.txt` — 149-line deparsed body of `gllvm:::glmmVA`.
- `/tmp/gllvm_TMB.txt` — 4086-line deparsed body of `gllvm:::gllvm.TMB`
  (used only for the bonus quadrature grep and the family-whitelist
  contrast in item 7; not otherwise analyzed for this task).

These are scratch/read files outside any repository and were not committed
or copied into gllvmTMB.
