## Settle whether `saturated_fit` earns a standalone arm -- measured PER TRAIT.
##
## An earlier pass rejected it because it "adds 0". That measurement scored only
## `rl_argmax_saturation`, i.e. saturation of the trait with the LARGEST ratio.
## But the shipped rule evaluates every trait and flags if ANY qualifies, so a
## trait could be saturated without being the argmax and the earlier test could
## not have seen it. Rejecting an arm on a statistic narrower than the arm
## itself is not a valid rejection -- the same error made earlier in this arc
## when a scale statistic was rejected on the wrong face.
##
## The candidate arm: ANY trait with saturation >= 0.5 AND prevalence NOT
## extreme -- i.e. freeing `saturated_fit` from the prevalence conjunct exactly
## as `dominant_loading` was freed. Scored against the shipped pair
## (relative_loading >= 25 OR max_loading >= 6).
##
## Healthy is defined by RECOVERY against known truth.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

RUNAWAY <- 25
ABSOLUTE <- 6
SAT_PROB <- 0.99
SAT_SHARE <- 0.5
PREV <- 0.9

loading_sd <- function(dgp, p) {
  wf <- switch(dgp, homog = 0, sparse50 = 0.5, sparse75 = 0.75)
  nw <- round(p * wf)
  if (nw == 0L) rep(0.7, p) else c(rep(0.05, nw), rep(1.0, p - nw))
}

grid <- expand.grid(
  dgp = c("homog", "sparse50", "sparse75"),
  p = c(12L, 25L), q = c(2L, 3L), n = c(60L, 150L, 400L), seed = 1:12,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 3719L + cl$n * 13L + cl$p * 5L + cl$q)
      sds <- loading_sd(cl$dgp, cl$p)
      Lam <- matrix(stats::rnorm(cl$p * cl$q, 0, rep(sds, times = cl$q)), cl$p, cl$q)
      B <- stats::rnorm(cl$p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * cl$q), cl$n, cl$q)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
      Y <- matrix(stats::rbinom(cl$n * cl$p, 1, stats::plogis(as.numeric(eta))), cl$n, cl$p)
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(cl$p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = cl$p))
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$q, unique = FALSE),
        data = dat, family = stats::binomial(), unit = "site"
      ))

      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(Lam)
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)

      ## per-trait prevalence and saturation, the way the row computes them
      yv <- as.numeric(fit$tmb_data$y)
      tid <- as.integer(fit$tmb_data$trait_id) + 1L
      pv <- stats::plogis(as.numeric(fit$report$eta))
      prev <- tapply(yv, tid, mean)
      satsh <- tapply(seq_along(pv), tid, function(k) {
        v <- pv[k][is.finite(pv[k])]
        if (!length(v)) NA_real_ else mean(v >= SAT_PROB | v <= (1 - SAT_PROB))
      })
      prev <- as.numeric(prev)
      satsh <- as.numeric(satsh)
      extreme <- is.finite(prev) & (prev >= PREV | prev <= (1 - PREV))
      sat <- is.finite(satsh) & satsh >= SAT_SHARE

      ## the candidate arm: ANY trait saturated at ORDINARY prevalence
      sat_arm <- any(sat & !extreme)

      rl <- lt$relative_loading
      pair <- any(is.finite(rl) & rl >= RUNAWAY) ||
        any(is.finite(lt$max_loading) & lt$max_loading >= ABSOLUTE)

      data.frame(
        dgp = cl$dgp, p = cl$p, q = cl$q, n = cl$n, seed = cl$seed,
        rel_frob = norm(G_hat - G_true, "F") / norm(G_true, "F"),
        pair = pair, sat_arm = sat_arm,
        n_sat_ordinary = sum(sat & !extreme, na.rm = TRUE),
        max_sat = max(satsh, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

message(sprintf("fits = %d", nrow(grid)))
res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 14)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/saturation-arm-pertrait.csv", row.names = FALSE)

d$degen <- d$rel_frob >= 5
d$healthy <- d$rel_frob <= 0.5
g <- d[d$degen, ]; h <- d[d$healthy, ]
cat(sprintf("\nusable %d;  degenerate %d;  healthy %d\n", nrow(d), nrow(g), nrow(h)))

cat("\n=== the candidate arm: ANY trait saturated at ORDINARY prevalence ===\n")
cat(sprintf("  sensitivity  %.4f (%d/%d)\n", mean(g$sat_arm), sum(g$sat_arm), nrow(g)))
cat(sprintf("  FALSE POSITIVES %.4f (%d/%d)\n", mean(h$sat_arm), sum(h$sat_arm), nrow(h)))

cat("\n=== does it ADD to the shipped pair? (the whole question) ===\n")
cat(sprintf("  pair alone        %.4f (%d/%d)\n", mean(g$pair), sum(g$pair), nrow(g)))
cat(sprintf("  pair OR sat_arm   %.4f (%d/%d)\n",
            mean(g$pair | g$sat_arm), sum(g$pair | g$sat_arm), nrow(g)))
cat(sprintf("  >>> ADDS %d degenerate fits the pair misses\n", sum(g$sat_arm & !g$pair)))
cat(sprintf("  >>> costs %d false positives (pair FPR %d, triple FPR %d)\n",
            sum(h$sat_arm & !h$pair), sum(h$pair), sum(h$pair | h$sat_arm)))

cat("\n=== transport: FPR of the arm by loading structure ===\n")
print(round(tapply(h$sat_arm, h$dgp, mean), 4))
cat("\nFPR by n:\n")
print(round(tapply(h$sat_arm, h$n, mean), 4))
cat("\nhealthy max saturation share (quantiles):\n")
print(round(stats::quantile(h$max_sat, c(.5, .9, .99, 1), na.rm = TRUE), 4))
