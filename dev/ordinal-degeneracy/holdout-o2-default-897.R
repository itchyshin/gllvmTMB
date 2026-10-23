## Fresh-seed hold-out for the ordinal O2 default of 30 (#897). Run on Totoro 2026-10-04
## (4 processes x 60 fits, about 100 s wall). usage: Rscript holdout-o2-default-897.R <first_seed> <last_seed>
## Same DGP as probe-mechanism.R::sim_ordinal at n = 100; seeds 3001+ were not used by any earlier campaign.
## Output (one CSV per call) is merged into results/holdout-o2-default-897.csv.
suppressMessages(library(gllvmTMB))
a <- as.integer(commandArgs(TRUE)); P <- 4L; Q <- 2L; TAUS <- c(0, 0.7, 1.4)
one <- function(n, sigma_lambda, seed) {
  set.seed(seed * 9173L + n + round(sigma_lambda * 100))
  Lam <- matrix(stats::rnorm(P * Q, 0, sigma_lambda), P, Q); Z <- matrix(stats::rnorm(n * Q), n, Q)
  Sig_true <- Lam %*% t(Lam); alpha <- stats::rnorm(P, 0, 0.3)
  lp <- Z %*% t(Lam) + matrix(alpha, n, P, byrow = TRUE)
  ystar <- as.numeric(t(lp)) + stats::rnorm(n * P)
  dat <- data.frame(trait = factor(rep(seq_len(P), times = n)), site = factor(rep(seq_len(n), each = P)))
  dat$value <- 1L + (ystar > TAUS[1]) + (ystar > TAUS[2]) + (ystar > TAUS[3])
  fit <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = Q, unique = FALSE),
    data = dat, unit = "site", family = ordinal_probit()))), error = function(e) NULL)
  if (is.null(fit)) return(data.frame(n, sigma_lambda, seed, ok = FALSE))
  Sh <- as.matrix(extract_Sigma(fit, level = "unit", part = "total")$Sigma)
  tab <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit, reference_traits = 1:P)
  data.frame(n, sigma_lambda, seed, ok = TRUE, conv = fit$opt$convergence,
             rel_frob = norm(Sh - Sig_true, "F") / norm(Sig_true, "F"),
             max_loading_unit = max(tab$max_loading_unit))
}
res <- do.call(rbind, lapply(a[1]:a[2], function(s) rbind(one(100L, 3.0, s), one(100L, 0.7, s))))
write.csv(res, sprintf("%s/gllvm_oct4/data/holdout_%d_%d.csv", Sys.getenv("HOME"), a[1], a[2]), row.names = FALSE)
cat("done", nrow(res), "fits\n")
