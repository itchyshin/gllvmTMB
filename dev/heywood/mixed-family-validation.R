## Arc C, the arm that validates Arc A's fix.
##
## Arc A stratified the relative_loading denominator by family, on the argument
## that a large-scale trait from another family could otherwise set a binomial
## trait's yardstick. That argument was demonstrated on a HAND-BUILT fixture.
## This measures it on real mixed-family fits.
##
## The design compares the two denominators on the SAME fits, so nothing is
## confounded: for every fit, relative_loading for the binomial traits is
## computed once pooled over all traits (the old behaviour) and once restricted
## to the binomial traits (the shipped behaviour). Detection at the shipped
## threshold of 25 is then read off both.
##
## The gaussian traits' loading scale is swept, because that is the axis the
## defect lives on -- a gaussian trait on a x100 response scale is the realistic
## case in a stacked-trait model.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

n_bin <- 3L
n_gau <- 3L
p <- n_bin + n_gau
q <- 2L

grid <- expand.grid(
  n = c(60L, 100L),
  gau_scale = c(1, 10, 100),
  seed = 1:30,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 4441L + cl$n * 17L + round(cl$gau_scale))
      ## binomial traits first, then gaussian traits scaled up
      Lam <- rbind(
        matrix(stats::rnorm(n_bin * q, 0, 0.7), n_bin, q),
        matrix(stats::rnorm(n_gau * q, 0, 0.7), n_gau, q) * cl$gau_scale
      )
      B <- c(stats::rnorm(n_bin, 0, 0.3), stats::rnorm(n_gau, 0, 0.3) * cl$gau_scale)
      Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, p, byrow = TRUE)

      Y <- matrix(NA_real_, cl$n, p)
      for (t in seq_len(n_bin)) {
        Y[, t] <- stats::rbinom(cl$n, 1, stats::plogis(eta[, t]))
      }
      for (t in (n_bin + 1L):p) {
        Y[, t] <- eta[, t] + stats::rnorm(cl$n, 0, cl$gau_scale)
      }

      fam_of_trait <- c(rep("bin", n_bin), rep("gau", n_gau))
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = p)),
        family = factor(rep(fam_of_trait, times = cl$n), levels = c("bin", "gau"))
      )
      fl <- list(stats::binomial(), stats::gaussian())
      attr(fl, "family_var") <- "family"

      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
        data = dat, family = fl, unit = "site"
      ))

      ## truth on the binomial block only -- that is what the row screens
      G_true_bin <- tcrossprod(Lam[seq_len(n_bin), , drop = FALSE])
      Lhat <- fit$report$Lambda_B
      G_hat_bin <- tcrossprod(Lhat[seq_len(n_bin), , drop = FALSE])
      rel_frob_bin <- norm(G_hat_bin - G_true_bin, "F") / norm(G_true_bin, "F")

      pooled <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      strat <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(
        fit, reference_traits = seq_len(n_bin)
      )
      bi <- seq_len(n_bin)

      data.frame(
        n = cl$n, gau_scale = cl$gau_scale, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        rel_frob_bin = rel_frob_bin,
        rl_pooled = max(pooled$relative_loading[bi], na.rm = TRUE),
        rl_strat = max(strat$relative_loading[bi], na.rm = TRUE),
        max_loading_bin = max(pooled$max_loading[bi], na.rm = TRUE),
        max_loading_gau = max(pooled$max_loading[-bi], na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 10)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/mixed-family-validation.csv", row.names = FALSE)

d$degen <- d$rel_frob_bin >= 5
d$healthy <- d$rel_frob_bin <= 0.5

cat(sprintf("usable fits %d of %d;  binomial block degenerate in %d;  healthy in %d\n\n",
            nrow(d), nrow(grid), sum(d$degen), sum(d$healthy)))

cat("=== how far apart do the two denominators put the same fit? ===\n")
cat("ratio strat/pooled, by gaussian loading scale:\n")
print(round(tapply(d$rl_strat / d$rl_pooled, d$gau_scale, stats::median), 2))
cat("(1 = identical; >1 = pooling was suppressing the binomial ratio)\n")

cat("\n=== DETECTION of a degenerate binomial block at the shipped threshold 25 ===\n")
if (sum(d$degen)) {
  g <- d[d$degen, ]
  tab <- rbind(
    pooled = tapply(g$rl_pooled >= 25, g$gau_scale, mean),
    stratified = tapply(g$rl_strat >= 25, g$gau_scale, mean)
  )
  print(round(tab, 3))
  cat("\ncounts (detected / degenerate) by scale:\n")
  for (s in sort(unique(g$gau_scale))) {
    ss <- g[g$gau_scale == s, ]
    cat(sprintf("  scale %3g : pooled %2d/%2d   stratified %2d/%2d\n", s,
                sum(ss$rl_pooled >= 25), nrow(ss),
                sum(ss$rl_strat >= 25), nrow(ss)))
  }
} else {
  cat("no degenerate binomial blocks produced at this design\n")
}

cat("\n=== FALSE POSITIVES on healthy binomial blocks ===\n")
if (sum(d$healthy)) {
  h <- d[d$healthy, ]
  tab <- rbind(
    pooled = tapply(h$rl_pooled >= 25, h$gau_scale, mean),
    stratified = tapply(h$rl_strat >= 25, h$gau_scale, mean)
  )
  print(round(tab, 4))
  cat("\nworst healthy stratified ratio by scale:\n")
  print(round(tapply(h$rl_strat, h$gau_scale, max), 2))
}

cat("\n=== the mechanism: gaussian loadings dominate the pooled denominator ===\n")
print(round(tapply(d$max_loading_gau / d$max_loading_bin, d$gau_scale, stats::median), 1))
cat("(median ratio of the largest gaussian loading to the largest binomial one)\n")
