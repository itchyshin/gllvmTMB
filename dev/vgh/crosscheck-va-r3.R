## ---------------------------------------------------------------------------
## crosscheck-va-r3.R -- decisive numerical cross-check of TWO INDEPENDENT
## implementations of the SAME Gaussian variational ELBO.
##
##   (A) inst/tmb/gllvmTMB_va_r3.cpp  (TMB/C++, eval_method = 0 = Gauss-Hermite)
##   (B) dev/vgh/vgh-engine.R         (base R: vgh_gh_rule / vgh_moments / vgh_elbo)
##
## Both implement
##   q(u_i) = N(a_i, A_i),  u_i ~ N(0, I_q)
##   eta_it = x_it' beta + lambda_t' a_i,   v_it = lambda_t' A_i lambda_t
##   ELBO   = sum_it E_q[log p(y_it | eta_it)] - sum_i KL(N(a_i,A_i) || N(0,I_q))
##   KL_i   = 0.5 (tr A_i + a_i'a_i - logdet A_i - q)
##
## The C++ template returns the NEGATIVE ELBO.  Agreement is asserted on
## -my_elbo vs TMB_negative_elbo, and is bisected into the expectation term and
## the KL term separately so that a disagreement can be localised.
##
## Run:  Rscript dev/vgh/crosscheck-va-r3.R
## ---------------------------------------------------------------------------

suppressWarnings(suppressMessages(library(TMB)))

repo <- "/private/tmp/gllvmtmb-vgh"

source(file.path(repo, "dev", "vgh", "vgh-engine.R"))
source(file.path(repo, "R", "va-r3-proto.R"))
CPP <- file.path(repo, "inst", "tmb", "gllvmTMB_va_r3.cpp")
stopifnot(file.exists(CPP))


## --- 1. Build one long-format design ---------------------------------------
## Long format is ordered unit-major (unit 1 traits 1..T, unit 2 traits 1..T,
## ...), which is what the cpp's cell bookkeeping expects.  X carries T trait
## dummies plus one continuous covariate: p = T + 1, full column rank.
make_design <- function(N, T, q, seed, n_trials_mode = c("bernoulli", "by_trait",
                                                         "by_cell"),
                        family = "binomial") {
  n_trials_mode <- match.arg(n_trials_mode)
  set.seed(seed)
  unit_id  <- rep(seq_len(N), each = T)
  trait_id <- rep(seq_len(T), times = N)
  n_obs    <- N * T

  Xd <- matrix(0, n_obs, T)
  Xd[cbind(seq_len(n_obs), trait_id)] <- 1
  xcont <- rnorm(n_obs)
  X <- cbind(Xd, xcont)
  colnames(X) <- NULL

  n_trials <- switch(n_trials_mode,
    bernoulli = rep(1L, n_obs),
    by_trait  = c(3L, 5L, 2L, 8L, 4L, 6L)[trait_id],
    by_cell   = sample(1:9, n_obs, replace = TRUE))

  ## y need only be a legal integer response -- the cross-check is at a FIXED
  ## parameter point, not at an optimum, so the data-generating truth is
  ## irrelevant to whether the two implementations agree.
  if (family == "binomial") {
    y <- rbinom(n_obs, size = n_trials, prob = plogis(rnorm(n_obs, 0, 1)))
  } else {
    y <- rpois(n_obs, lambda = exp(rnorm(n_obs, 0.2, 0.6)))
    n_trials <- rep(1L, n_obs)
  }

  list(y = y, n_trials = n_trials, X = X, unit_id = unit_id,
       trait_id = trait_id, N = N, T = T, q = q, family = family)
}


## --- 2. A fixed, reproducible random parameter point ------------------------
make_point <- function(N, T, q, seed) {
  set.seed(seed)
  p <- T + 1L
  beta <- rnorm(p, 0, 0.5)

  Lambda <- matrix(0, T, q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- runif(q, 0.4, 1.2)
  for (j in seq_len(q)) {
    if (j < T) Lambda[seq.int(j + 1L, T), j] <- rnorm(T - j, 0, 0.6)
  }

  m          <- matrix(rnorm(N * q, 0, 0.8), N, q)
  log_L_diag <- matrix(rnorm(N * q, -0.35, 0.30), N, q)
  n_off      <- q * (q - 1L) / 2L
  L_off      <- matrix(rnorm(N * n_off, 0, 0.45), N, n_off)

  list(beta = beta, Lambda = Lambda, m = m,
       log_L_diag = log_L_diag, L_off = L_off)
}


## --- 3. My ELBO, built from the engine in dev/vgh/vgh-engine.R --------------
## Lambda / L_i packings are re-derived here INDEPENDENTLY from the cpp source
## (column-major strict lower triangle in both cases), then the engine's own
## vgh_gh_rule / vgh_moments / vgh_elbo do the numerical work.
my_elbo <- function(d, pt, H, family = "binomial") {
  N <- d$N; T <- d$T; q <- d$q
  rule <- vgh_gh_rule(H)
  fam  <- vgh_family(if (family == "binomial") "binomial" else "poisson")

  Lambda <- pt$Lambda
  amean  <- pt$m

  ## A_i = L_i L_i', L_i lower triangular: exp(log_L_diag) on the diagonal,
  ## L_off filled column-major down the strict lower triangle.
  Avec    <- matrix(0, N, q * q)
  logdetA <- numeric(N)
  for (i in seq_len(N)) {
    Li <- matrix(0, q, q)
    diag(Li) <- exp(pt$log_L_diag[i, ])
    off_pos <- 1L
    for (col in seq_len(q)) {
      if (col < q) {
        rows <- seq.int(col + 1L, q)
        Li[rows, col] <- pt$L_off[i, seq.int(off_pos, length.out = length(rows))]
        off_pos <- off_pos + length(rows)
      }
    }
    Avec[i, ]  <- as.vector(tcrossprod(Li))          # column-major vec(A_i)
    logdetA[i] <- 2 * sum(pt$log_L_diag[i, ])
  }

  ## n x m matrices M and S2
  XB <- as.vector(d$X %*% pt$beta)
  M  <- matrix(0, N, T)
  M[cbind(d$unit_id, d$trait_id)] <- XB
  M <- M + amean %*% t(Lambda)

  L2 <- if (q == 1L) matrix(Lambda[, 1]^2, ncol = 1L) else
    t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))     # T x q^2
  S2 <- Avec %*% t(L2)

  Ymat <- matrix(0, N, T); Ymat[cbind(d$unit_id, d$trait_id)] <- d$y
  Nmat <- matrix(0, N, T); Nmat[cbind(d$unit_id, d$trait_id)] <- d$n_trials

  mom <- vgh_moments(fam, M, S2, rule)               # B = E[b(eta)]

  ## -KL, exactly the engine's own formula (vgh_elbo's `kl` object)
  didx <- (seq_len(q) - 1L) * q + seq_len(q)
  trA  <- rowSums(Avec[, didx, drop = FALSE])
  neg_kl <- 0.5 * sum(logdetA - trA - rowSums(amean^2) + q)

  if (family == "binomial") {
    log_choose <- lchoose(Nmat, Ymat)
    ell <- sum(log_choose) + sum(Ymat * M) - sum(Nmat * mom$B)
  } else {
    ell <- sum(Ymat * M) - sum(mom$B) - sum(lgamma(Ymat + 1))
  }

  ## Secondary route: the engine's own vgh_elbo() entry point.  It has no
  ## n_trials argument, so it is exact only where the binomial reduces to the
  ## EF form with dispersion phi_t = 1/n_t (n constant within trait), or for
  ## Bernoulli (n = 1, phi = 1), or for Poisson (phi = 1).
  elbo_entrypoint <- NA_real_
  if (family == "poisson") {
    e <- vgh_elbo(Ymat, fam, M, S2, amean, Avec, rep(1, T), rule, logdetA)
    elbo_entrypoint <- e$value
  } else {
    n_by_trait <- apply(Nmat, 2L, function(z) if (length(unique(z)) == 1L) z[1] else NA_real_)
    if (!anyNA(n_by_trait)) {
      e <- vgh_elbo(Ymat / Nmat, fam, M, S2, amean, Avec,
                    1 / n_by_trait, rule, logdetA)
      elbo_entrypoint <- e$value + sum(lchoose(Nmat, Ymat))
    }
  }

  list(elbo = ell + neg_kl, ell = ell, kl = -neg_kl,
       M = M, S2 = S2, B = mom$B, Lambda = Lambda, Avec = Avec,
       elbo_entrypoint = elbo_entrypoint)
}


## --- 4. TMB side ------------------------------------------------------------
tmb_side <- function(d, pt, H) {
  fam_name <- if (d$family == "binomial") "binomial" else "poisson"
  link     <- if (d$family == "binomial") "logit" else "log"
  val <- .va_r3_validate_data(
    y = d$y, n_trials = d$n_trials, X = d$X,
    unit_id = d$unit_id, trait_id = d$trait_id, q = d$q,
    N = d$N, T = d$T, family = fam_name, link = link)

  params <- list(
    beta       = as.numeric(pt$beta),
    theta_rr   = .va_r3_pack_theta_rr(pt$Lambda, d$q),
    m          = pt$m,
    log_L_diag = pt$log_L_diag,
    L_off      = pt$L_off,
    log_phi    = rep(0, d$T))

  obj <- .va_r3_make_objective(val, H = H, source = CPP,
                               parameters = params, eval_method = "gh",
                               silent = TRUE)
  nll <- obj$fn(obj$par)
  rep <- obj$report(obj$par)
  list(nll = as.numeric(nll), rep = rep)
}


## --- 5. One comparison ------------------------------------------------------
compare <- function(label, d, pt, H) {
  tm <- tmb_side(d, pt, H)
  me <- my_elbo(d, pt, H, family = d$family)

  ## bisection: mu, v, expectation term, KL term
  mu_tmb <- matrix(0, d$N, d$T); mu_tmb[cbind(d$unit_id, d$trait_id)] <- tm$rep$mu_by_obs
  v_tmb  <- matrix(0, d$N, d$T); v_tmb[cbind(d$unit_id, d$trait_id)]  <- tm$rep$v_by_obs

  ## S_flat(i, row*q + col) = S_i(row, col)  -> row-major; re-vec column-major
  A_tmb <- matrix(0, d$N, d$q * d$q)
  for (i in seq_len(d$N)) {
    A_tmb[i, ] <- as.vector(matrix(tm$rep$S_flat[i, ], d$q, d$q, byrow = TRUE))
  }

  tmb_neg  <- tm$nll
  mine_neg <- -me$elbo
  abs_d <- abs(tmb_neg - mine_neg)
  rel_d <- abs_d / max(abs(tmb_neg), 1e-300)

  data.frame(
    case = label, H = H, family = d$family,
    TMB_negative_elbo = tmb_neg,
    my_negative_elbo  = mine_neg,
    abs_diff = abs_d, rel_diff = rel_d,
    max_abs_mu_diff  = max(abs(mu_tmb - me$M)),
    max_abs_v_diff   = max(abs(v_tmb  - me$S2)),
    max_abs_Lambda_diff = max(abs(matrix(tm$rep$Lambda, d$T, d$q) - me$Lambda)),
    max_abs_A_diff   = max(abs(A_tmb - me$Avec)),
    Eterm_TMB = tm$rep$expected_loglik, Eterm_mine = me$ell,
    Eterm_diff = abs(tm$rep$expected_loglik - me$ell),
    KL_TMB = tm$rep$total_kl, KL_mine = me$kl,
    KL_diff = abs(tm$rep$total_kl - me$kl),
    entrypoint_diff = if (is.na(me$elbo_entrypoint)) NA_real_ else
      abs(-me$elbo_entrypoint - tmb_neg),
    stringsAsFactors = FALSE)
}


## --- 6. Run the grid --------------------------------------------------------
N <- 40L; T <- 6L; q <- 2L
seeds <- c(101L, 202L, 303L, 404L, 505L)
res <- list()

## 6a. binomial, n_trials > 1 (constant within trait), H = 61
for (s in seeds) {
  d  <- make_design(N, T, q, seed = s, n_trials_mode = "by_trait")
  pt <- make_point(N, T, q, seed = s + 1000L)
  res[[length(res) + 1L]] <- compare(sprintf("binom n>1 (by trait) seed %d", s), d, pt, 61L)
}

## 6b. binomial, n_trials > 1 varying per CELL, H = 61
for (s in seeds) {
  d  <- make_design(N, T, q, seed = s, n_trials_mode = "by_cell")
  pt <- make_point(N, T, q, seed = s + 1000L)
  res[[length(res) + 1L]] <- compare(sprintf("binom n>1 (by cell) seed %d", s), d, pt, 61L)
}

## 6c. Bernoulli (n_trials = 1), H = 61
for (s in seeds) {
  d  <- make_design(N, T, q, seed = s, n_trials_mode = "bernoulli")
  pt <- make_point(N, T, q, seed = s + 1000L)
  res[[length(res) + 1L]] <- compare(sprintf("bernoulli seed %d", s), d, pt, 61L)
}

## 6d. GH order sweep H = 15, 25, 61 on both binomial shapes
for (H in c(15L, 25L, 61L)) {
  for (s in seeds[1:3]) {
    d  <- make_design(N, T, q, seed = s, n_trials_mode = "by_trait")
    pt <- make_point(N, T, q, seed = s + 1000L)
    res[[length(res) + 1L]] <- compare(sprintf("binom n>1 H-sweep seed %d", s), d, pt, H)
    d  <- make_design(N, T, q, seed = s, n_trials_mode = "bernoulli")
    res[[length(res) + 1L]] <- compare(sprintf("bernoulli H-sweep seed %d", s), d, pt, H)
  }
}

## 6e. Poisson (both sides exact closed form E[exp] = exp(mu + v/2))
for (s in seeds) {
  d  <- make_design(N, T, q, seed = s, family = "poisson")
  pt <- make_point(N, T, q, seed = s + 1000L)
  res[[length(res) + 1L]] <- compare(sprintf("poisson seed %d", s), d, pt, 61L)
}

## 6f. Poisson with a different latent dimension, as a packing stress test
## q >= 4 matters: at q <= 3 the row-major and column-major orderings of the
## strict lower triangle of L_i coincide, so only q >= 4 can distinguish them
## (see the negative controls in section 7).
for (qq in c(1L, 3L, 4L, 5L)) {
  ok <- tryCatch({
    d  <- make_design(N, T, qq, seed = 777L, family = "poisson")
    pt <- make_point(N, T, qq, seed = 1777L)
    res[[length(res) + 1L]] <- compare(sprintf("poisson q=%d", qq), d, pt, 61L)
    d  <- make_design(N, T, qq, seed = 777L, n_trials_mode = "by_trait")
    pt <- make_point(N, T, qq, seed = 1777L)
    res[[length(res) + 1L]] <- compare(sprintf("binom n>1 q=%d", qq), d, pt, 61L)
    TRUE
  }, error = function(e) { message("SKIPPED q=", qq, ": ", conditionMessage(e)); FALSE })
}

out <- do.call(rbind, res)

cat("\n============ TMB (cpp) vs vgh-engine.R : NEGATIVE ELBO ============\n\n")
print(format(out[, c("case", "H", "TMB_negative_elbo", "my_negative_elbo",
                     "abs_diff", "rel_diff")],
             digits = 12), row.names = FALSE)

cat("\n============ Bisection: mu, v, Lambda, A, E-term, KL ============\n\n")
print(format(out[, c("case", "H", "max_abs_mu_diff", "max_abs_v_diff",
                     "max_abs_Lambda_diff", "max_abs_A_diff",
                     "Eterm_diff", "KL_diff", "entrypoint_diff")],
             digits = 4), row.names = FALSE)

cat("\n============ Summary ============\n")
cat(sprintf("comparisons                : %d\n", nrow(out)))
cat(sprintf("max |abs diff|             : %.6e\n", max(out$abs_diff)))
cat(sprintf("max  relative diff         : %.6e\n", max(out$rel_diff)))
cat(sprintf("max  relative diff (poisson): %.6e\n",
            max(out$rel_diff[out$family == "poisson"])))
cat(sprintf("max  relative diff (binom) : %.6e\n",
            max(out$rel_diff[out$family == "binomial"])))
cat(sprintf("max |E-term diff|          : %.6e\n", max(out$Eterm_diff)))
cat(sprintf("max |KL diff|              : %.6e\n", max(out$KL_diff)))
cat(sprintf("max |mu diff|              : %.6e\n", max(out$max_abs_mu_diff)))
cat(sprintf("max |v  diff|              : %.6e\n", max(out$max_abs_v_diff)))
cat(sprintf("max |Lambda diff|          : %.6e\n", max(out$max_abs_Lambda_diff)))
cat(sprintf("max |A_i diff|             : %.6e\n", max(out$max_abs_A_diff)))
cat(sprintf("max |vgh_elbo() route diff|: %.6e\n",
            max(out$entrypoint_diff, na.rm = TRUE)))

write.csv(out, file.path(repo, "dev", "vgh", "crosscheck-va-r3.csv"),
          row.names = FALSE)
cat("\nwritten: dev/vgh/crosscheck-va-r3.csv\n")


## --- 7. NEGATIVE CONTROLS ---------------------------------------------------
## Agreement is only evidence if disagreement was possible.  Each control
## injects ONE deliberate error into my side and must produce a LARGE
## disagreement.  If a control comes back ~0, the corresponding aspect of the
## cross-check has no power and the agreement above is vacuous for it.
sabotage_elbo <- function(d, pt, H, mode) {
  N <- d$N; T <- d$T; q <- d$q
  rule <- vgh_gh_rule(H)
  if (mode == "gh_missing_sqrt2") rule$z <- rule$z / sqrt(2)
  if (mode == "gh_unnormalised_w") rule$w <- rule$w * sqrt(pi)
  fam <- vgh_family("binomial")

  ## Lambda: rebuild from theta_rr, optionally with a ROW-major strict lower
  theta <- .va_r3_pack_theta_rr(pt$Lambda, q)
  Lambda <- matrix(0, T, q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- theta[seq_len(q)]
  tail_v <- theta[-seq_len(q)]
  if (mode == "lambda_rowmajor") {
    idx <- which(row(Lambda) > col(Lambda), arr.ind = TRUE)
    idx <- idx[order(idx[, "row"], idx[, "col"]), , drop = FALSE]
    Lambda[idx] <- tail_v
  } else {
    cur <- 1L
    for (j in seq_len(q)) if (j < T) {
      rows <- seq.int(j + 1L, T)
      Lambda[rows, j] <- tail_v[seq.int(cur, length.out = length(rows))]
      cur <- cur + length(rows)
    }
  }

  Avec <- matrix(0, N, q * q); logdetA <- numeric(N)
  for (i in seq_len(N)) {
    Li <- matrix(0, q, q); diag(Li) <- exp(pt$log_L_diag[i, ])
    if (q > 1L) {
      if (mode == "L_rowmajor") {
        idx <- which(row(Li) > col(Li), arr.ind = TRUE)
        idx <- idx[order(idx[, "row"], idx[, "col"]), , drop = FALSE]
        Li[idx] <- pt$L_off[i, ]
      } else {
        op <- 1L
        for (cj in seq_len(q - 1L)) {
          rows <- seq.int(cj + 1L, q)
          Li[rows, cj] <- pt$L_off[i, seq.int(op, length.out = length(rows))]
          op <- op + length(rows)
        }
      }
    }
    Ai <- if (mode == "A_is_LtL") crossprod(Li) else tcrossprod(Li)
    Avec[i, ] <- as.vector(Ai)
    logdetA[i] <- 2 * sum(pt$log_L_diag[i, ])
  }

  XB <- as.vector(d$X %*% pt$beta)
  M <- matrix(0, N, T); M[cbind(d$unit_id, d$trait_id)] <- XB
  M <- M + pt$m %*% t(Lambda)
  L2 <- if (q == 1L) matrix(Lambda[, 1]^2, ncol = 1L) else
    t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))
  S2 <- Avec %*% t(L2)
  Ymat <- matrix(0, N, T); Ymat[cbind(d$unit_id, d$trait_id)] <- d$y
  Nmat <- matrix(0, N, T); Nmat[cbind(d$unit_id, d$trait_id)] <- d$n_trials
  mom <- vgh_moments(fam, M, S2, rule)
  didx <- (seq_len(q) - 1L) * q + seq_len(q)
  neg_kl <- 0.5 * sum(logdetA - rowSums(Avec[, didx, drop = FALSE]) -
                        rowSums(pt$m^2) + q)
  if (mode == "kl_sign_flipped") neg_kl <- -neg_kl
  ell <- sum(lchoose(Nmat, Ymat)) + sum(Ymat * M) - sum(Nmat * mom$B)
  ell + neg_kl
}

modes <- c("none", "lambda_rowmajor", "L_rowmajor", "A_is_LtL",
           "kl_sign_flipped", "gh_missing_sqrt2", "gh_unnormalised_w")
nc <- list()
for (qq in c(2L, 4L)) {
  d  <- make_design(N, T, qq, seed = 909L, n_trials_mode = "by_trait")
  pt <- make_point(N, T, qq, seed = 1909L)
  ref <- tmb_side(d, pt, 61L)$nll
  for (mo in modes) {
    nc[[length(nc) + 1L]] <- data.frame(
      q = qq, control = mo,
      TMB_negative_elbo = ref,
      sabotaged_negative_elbo = -sabotage_elbo(d, pt, 61L, mo),
      abs_diff = abs(ref - (-sabotage_elbo(d, pt, 61L, mo))),
      stringsAsFactors = FALSE)
  }
}
nc <- do.call(rbind, nc)
cat("\n============ Negative controls (each must be LARGE except `none`) ====\n\n")
print(format(nc, digits = 10), row.names = FALSE)

## --- 8. Regime assertions ---------------------------------------------------
d  <- make_design(N, T, 2L, seed = 101L, n_trials_mode = "by_trait")
pt <- make_point(N, T, 2L, seed = 1101L)
tm <- tmb_side(d, pt, 61L)
cat("\n============ Regime assertions ============\n")
cat(sprintf("eval_method reported by cpp : %d  (0 = Gauss-Hermite)\n",
            as.integer(tm$rep$eval_method)))
cat(sprintf("min v_it over all cells     : %.6e  (cpp GH branch needs v > 1e-6)\n",
            min(tm$rep$v_by_obs)))
cat(sprintf("cells on the GH branch      : %d / %d\n",
            sum(tm$rep$v_by_obs > 1e-6), length(tm$rep$v_by_obs)))
cat(sprintf("range of mu_it              : [%.3f, %.3f]\n",
            min(tm$rep$mu_by_obs), max(tm$rep$mu_by_obs)))


## --- 9. The cpp's small-v branch --------------------------------------------
## Below v = 1e-6 the cpp abandons quadrature for a heat-kernel expansion
## f + v f''/2 + v^2 f''''/8 + v^3 f^(6)/48.  Section 6 never reaches that
## branch (min v ~ 5e-2), so it is exercised here separately: my side still
## uses exact Gauss-Hermite, so this measures the EXPANSION'S error, not a
## packing disagreement.
cat("\n============ cpp small-v expansion branch (my side still GH) ====\n\n")
sv <- list()
for (shrink in c(0, -4, -6, -8, -10)) {
  d  <- make_design(N, T, 2L, seed = 101L, n_trials_mode = "by_trait")
  pt <- make_point(N, T, 2L, seed = 1101L)
  pt$log_L_diag <- pt$log_L_diag + shrink
  pt$L_off      <- pt$L_off * exp(shrink)
  tmv <- tmb_side(d, pt, 61L)
  mev <- my_elbo(d, pt, 61L, family = "binomial")
  sv[[length(sv) + 1L]] <- data.frame(
    log_L_shift = shrink,
    max_v = max(tmv$rep$v_by_obs),
    branch = if (max(tmv$rep$v_by_obs) > 1e-6) "GH" else "expansion",
    TMB_negative_elbo = tmv$nll, my_negative_elbo = -mev$elbo,
    abs_diff = abs(tmv$nll + mev$elbo),
    rel_diff = abs(tmv$nll + mev$elbo) / abs(tmv$nll),
    stringsAsFactors = FALSE)
}
print(format(do.call(rbind, sv), digits = 10), row.names = FALSE)

