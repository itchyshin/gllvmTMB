## Arc C: sweep the SHIPPED loading thresholds in the regimes they were never
## calibrated on, and test whether a third statistic earns its place.
##
## Three gaps this closes, each of which could change a shipped number:
##
##  A. LARGE p. `loading_runaway_thresh = 25` was chosen over 15 because the
##     healthy tail of `relative_loading` RISES with trait count (4.11, 5.32,
##     12.07 at p = 5, 12, 25) and the log-log slope was ACCELERATING
##     (0.41 then 1.12). That argument was then never tested past p = 25. If the
##     tail keeps accelerating, 25 is too low at p = 50 or 100 and the shipped
##     default is wrong.
##  B. MULTI-TRIAL binomial with `unique = TRUE`. The only cell where a live Psi
##     and a separating link coexist. Its psi face was measured; the LOADING
##     thresholds' false-positive rate there was not.
##  C. Does a rotation-invariant SCALE statistic add anything over the shipped
##     disjunction `relative_loading >= 25 OR max_loading >= 6`? `g_norm_var`
##     had the best AUC of the four candidates (0.9932) but AUC does not tell
##     you whether it catches anything the pair already catches.
##
## Healthy is defined by RECOVERY against known truth, never by convergence.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

RUNAWAY <- 25
ABSOLUTE <- 6

loading_sd <- function(dgp, p) {
  wf <- switch(dgp, homog = 0, sparse50 = 0.5, sparse75 = 0.75)
  nw <- round(p * wf)
  if (nw == 0L) rep(0.7, p) else c(rep(0.05, nw), rep(1.0, p - nw))
}

## ---- arm A: large p, single-trial binomial, unique = FALSE (as calibrated) --
gridA <- expand.grid(
  arm = "largeP", dgp = c("homog", "sparse50", "sparse75"),
  p = c(25L, 50L, 100L), q = c(2L, 3L), n = c(150L, 400L), seed = 1:15,
  stringsAsFactors = FALSE
)
## ---- arm B: multi-trial binomial, unique = TRUE (Psi live) -----------------
gridB <- expand.grid(
  arm = "multitrial", dgp = c("homog", "sparse50"),
  p = c(6L, 12L, 25L), q = c(2L, 3L), n = c(150L, 400L), seed = 1:15,
  stringsAsFactors = FALSE
)
grid <- rbind(gridA, gridB)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 5237L + cl$n * 7L + cl$p * 13L + cl$q)
      sds <- loading_sd(cl$dgp, cl$p)
      Lam <- matrix(stats::rnorm(cl$p * cl$q, 0, rep(sds, times = cl$q)), cl$p, cl$q)
      B <- stats::rnorm(cl$p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * cl$q), cl$n, cl$q)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)

      if (identical(cl$arm, "multitrial")) {
        nt <- 10L
        psi_true <- rep(0.4, cl$p)
        U <- matrix(stats::rnorm(cl$n * cl$p), cl$n, cl$p) %*% diag(sqrt(psi_true))
        eta <- eta + U
        S <- matrix(stats::rbinom(cl$n * cl$p, nt, stats::plogis(as.numeric(eta))),
                    cl$n, cl$p)
        dat <- data.frame(
          succ = as.numeric(t(S)), fail = nt - as.numeric(t(S)),
          trait = factor(rep(seq_len(cl$p), times = cl$n)),
          site = factor(rep(seq_len(cl$n), each = cl$p))
        )
        fit <- suppressWarnings(gllvmTMB::gllvmTMB(
          cbind(succ, fail) ~ 0 + trait + latent(0 + trait | site, d = cl$q),
          data = dat, family = stats::binomial(), unit = "site"
        ))
        Yobs <- S / nt
      } else {
        Y <- matrix(stats::rbinom(cl$n * cl$p, 1, stats::plogis(as.numeric(eta))),
                    cl$n, cl$p)
        dat <- data.frame(
          y = as.numeric(t(Y)),
          trait = factor(rep(seq_len(cl$p), times = cl$n)),
          site = factor(rep(seq_len(cl$n), each = cl$p))
        )
        fit <- suppressWarnings(gllvmTMB::gllvmTMB(
          y ~ 0 + trait + latent(0 + trait | site, d = cl$q, unique = FALSE),
          data = dat, family = stats::binomial(), unit = "site"
        ))
        Yobs <- Y
      }

      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(Lam)
      rel_frob <- norm(G_hat - G_true, "F") / norm(G_true, "F")
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]
      obs_var <- apply(Yobs, 2L, stats::var)

      data.frame(
        arm = cl$arm, dgp = cl$dgp, p = cl$p, q = cl$q, n = cl$n, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        rel_frob = rel_frob,
        rl_max = if (length(rl)) max(rl) else NA_real_,
        max_loading = max(lt$max_loading, na.rm = TRUE),
        g_norm_var = norm(G_hat, "F") / sum(obs_var),
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
utils::write.csv(d, "dev/heywood/arcC-threshold-coverage.csv", row.names = FALSE)

d$health <- ifelse(d$rel_frob <= 0.5, "healthy",
  ifelse(d$rel_frob >= 5, "degenerate", "middle"))
cat(sprintf("\nusable %d of %d\n", nrow(d), nrow(grid)))

## ---------------------------------------------------------------- arm A ----
A <- d[d$arm == "largeP", ]
hA <- A[A$health == "healthy", ]
gA <- A[A$health == "degenerate", ]
cat(sprintf("\n=== ARM A (large p): healthy %d, degenerate %d ===\n", nrow(hA), nrow(gA)))
cat("\nDOES THE HEALTHY TAIL KEEP ACCELERATING? worst healthy rl_max by p:\n")
print(round(tapply(hA$rl_max, hA$p, max), 2))
cat("(shipped comparison at p = 5/12/25 was 4.11 / 5.32 / 12.07)\n")
cat("\n99th percentile by p:\n")
print(round(tapply(hA$rl_max, hA$p, stats::quantile, 0.99), 2))
cat("\nworst healthy rl_max by p x dgp:\n")
print(round(tapply(hA$rl_max, list(hA$p, hA$dgp), max), 2))

cat(sprintf("\nFALSE POSITIVES at the shipped thresholds (runaway %g, absolute %g):\n",
            RUNAWAY, ABSOLUTE))
fp <- function(x) mean(x$rl_max >= RUNAWAY | x$max_loading >= ABSOLUTE)
print(round(tapply(seq_len(nrow(hA)), hA$p, function(i) fp(hA[i, ])), 4))
cat("worst healthy max_loading by p:\n")
print(round(tapply(hA$max_loading, hA$p, max), 2))
if (nrow(gA)) {
  cat("\nDETECTION by p:\n")
  print(round(tapply(seq_len(nrow(gA)), gA$p, function(i) fp(gA[i, ])), 3))
}

## ---------------------------------------------------------------- arm B ----
B <- d[d$arm == "multitrial", ]
hB <- B[B$health == "healthy", ]
gB <- B[B$health == "degenerate", ]
cat(sprintf("\n=== ARM B (multi-trial, unique = TRUE): healthy %d, degenerate %d ===\n",
            nrow(hB), nrow(gB)))
if (nrow(hB)) {
  cat(sprintf("false positives at shipped thresholds: %.4f (%d/%d)\n",
              fp(hB), sum(hB$rl_max >= RUNAWAY | hB$max_loading >= ABSOLUTE), nrow(hB)))
  cat("worst healthy rl_max:", round(max(hB$rl_max), 2),
      " worst healthy max_loading:", round(max(hB$max_loading), 2), "\n")
}
if (nrow(gB)) cat(sprintf("detection: %.3f (%d/%d)\n", fp(gB),
                          sum(gB$rl_max >= RUNAWAY | gB$max_loading >= ABSOLUTE), nrow(gB)))

## ---------------------------------------------------------------- arm C ----
cat("\n=== ARM C: does g_norm_var ADD anything to the shipped pair? ===\n")
g <- d[d$health == "degenerate", ]
h <- d[d$health == "healthy", ]
caught <- g$rl_max >= RUNAWAY | g$max_loading >= ABSOLUTE
cat(sprintf("shipped pair catches %d of %d degenerate (%.3f)\n",
            sum(caught), nrow(g), mean(caught)))
if (any(!caught) && nrow(h)) {
  cat("the misses' g_norm_var:", paste(signif(range(g$g_norm_var[!caught]), 3), collapse = " .. "), "\n")
  cat("healthy g_norm_var 99th pct / max:",
      paste(signif(c(stats::quantile(h$g_norm_var, .99), max(h$g_norm_var)), 3), collapse = " / "), "\n")
  sep <- min(g$g_norm_var[!caught]) > max(h$g_norm_var)
  cat("could a g_norm_var cut catch the misses at zero FPR?", sep, "\n")
} else {
  cat("nothing left for a third statistic to catch\n")
}
