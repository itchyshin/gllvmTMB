## WHY DOES LAPLACE WIN ON SIGMA AT MODERATE n? Bug, or real phenomenon?
##
## The family axis reported |sigma - 1|, which HIDES THE SIGN. That sign is the whole
## diagnostic:
##   * AGHQ+ridge biased DOWN  => our ridge is over-shrinking. A defect in OUR default.
##   * AGHQ+ridge biased UP    => the exact MLE is finite-sample biased upward, and
##                               Laplace's downward integral error partially cancels it.
##                               A real statistical phenomenon, not a bug.
## And the second arm separates the ridge from the quadrature: run AGHQ with the ridge
## OFF. If ridge-off AGHQ is unbiased and ridge-on is low, the penalty is the culprit.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-family-axis", quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n, p, q, seed, lam_sd = 0.8) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q); b <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, Lt = Lt,
       fml = as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                                paste(colnames(Y), collapse = ", "), q)))
}
P <- 6L; Q <- 2L; N <- 200L
ARMS <- list(laplace    = function() gllvmTMBcontrol(),
             aghq_noridge = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf),
             aghq_ridge = function() gllvmTMBcontrol(aghq = 9))
jobs <- expand.grid(seed = 3001:3016, arm = names(ARMS), stringsAsFactors = FALSE)

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]; d <- mk(N, P, Q, jb$seed)
  sg_t <- sqrt(diag(d$Lt %*% t(d$Lt)))
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                          control = ARMS[[jb$arm]]())), error = function(e) NULL)
  if (is.null(f)) return(NULL)
  L <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  data.frame(seed = jb$seed, arm = jb$arm,
             sigma_rat = median(sqrt(diag(L %*% t(L))) / sg_t),
             frob_rat  = norm(L, "F") / norm(d$Lt, "F"), stringsAsFactors = FALSE)
}, mc.cores = 6L, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, "dev/aghq-evidence/20-why-laplace-wins.csv", row.names = FALSE)

cat("=== binomial, n=200, p=6, q=2, 16 seeds — SIGNED, not |.| ===\n\n")
cat(sprintf("%-13s | %5s | %9s %9s | %9s %9s\n",
            "arm","nfit","med sigma","signed err","med frob","runaway%"))
for (a in names(ARMS)) {
  s <- res[res$arm == a & is.finite(res$sigma_rat), ]
  if (!nrow(s)) next
  m <- median(s$sigma_rat)
  cat(sprintf("%-13s | %5d | %9.4f %+9.4f | %9.4f %8.0f%%\n", a, nrow(s), m, m - 1,
              median(s$frob_rat), 100 * mean(s$frob_rat > 2)))
}
cat("\nDOWN for aghq_ridge but ~1 for aghq_noridge => OUR RIDGE over-shrinks (a defect).\n")
cat("UP for both                                  => the exact MLE is biased up; Laplace\n")
cat("                                                partially cancels it (real, not a bug).\n")
