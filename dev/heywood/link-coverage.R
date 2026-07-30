## Arc C, final gap: probit and cloglog.
##
## `.gllvmTMB_binomial_prevalence_loading_row()` fires on `family_id == 1`
## regardless of LINK, but every calibration fit so far used logit. That matters
## specifically for `loading_absolute_thresh = 6`, which is justified by a
## LINK-SCALE argument: the latent scores are standard normal by identification,
## so a loading is the trait's latent SD in link units. **That argument is
## link-specific.** A probit coefficient is ~1.7x smaller than the logit
## coefficient for the same probability curve, and cloglog is asymmetric -- so a
## threshold calibrated on logit need not transport, and the direction is
## predictable: probit loadings should run SMALLER, making 6 conservative
## (fewer false positives, possibly missed detections).
##
## Healthy is defined by RECOVERY against known truth, never convergence.

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

grid <- expand.grid(
  link = c("logit", "probit", "cloglog"),
  dgp = c("homog", "sparse50", "sparse75"),
  p = c(12L, 25L), q = 2L, n = c(60L, 150L, 400L), seed = 1:12,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 8123L + cl$n * 11L + cl$p + match(cl$link, c("logit","probit","cloglog")))
      sds <- loading_sd(cl$dgp, cl$p)
      Lam <- matrix(stats::rnorm(cl$p * cl$q, 0, rep(sds, times = cl$q)), cl$p, cl$q)
      B <- stats::rnorm(cl$p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * cl$q), cl$n, cl$q)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
      linkinv <- switch(cl$link,
        logit = stats::plogis,
        probit = stats::pnorm,
        cloglog = function(x) 1 - exp(-exp(pmin(x, 20)))
      )
      pr <- linkinv(as.numeric(eta))
      Y <- matrix(stats::rbinom(cl$n * cl$p, 1, pr), cl$n, cl$p)
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(cl$p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = cl$p))
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$q, unique = FALSE),
        data = dat, family = stats::binomial(link = cl$link), unit = "site"
      ))
      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(Lam)
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]
      chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
      st <- chk$status[chk$component == "binomial_prevalence_loading"]

      data.frame(
        link = cl$link, dgp = cl$dgp, p = cl$p, n = cl$n, seed = cl$seed,
        rel_frob = norm(G_hat - G_true, "F") / norm(G_true, "F"),
        rl_max = if (length(rl)) max(rl) else NA_real_,
        max_loading = max(lt$max_loading, na.rm = TRUE),
        row_status = if (length(st)) st[[1L]] else NA_character_,
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
utils::write.csv(d, "dev/heywood/link-coverage.csv", row.names = FALSE)

d$health <- ifelse(d$rel_frob <= 0.5, "healthy",
  ifelse(d$rel_frob >= 5, "degenerate", "middle"))
cat(sprintf("\nusable %d of %d\n", nrow(d), nrow(grid)))
print(table(link = d$link, health = d$health))

h <- d[d$health == "healthy", ]
g <- d[d$health == "degenerate", ]
fires <- function(x) x$rl_max >= RUNAWAY | x$max_loading >= ABSOLUTE

cat("\n=== FALSE POSITIVES at the shipped thresholds, by link ===\n")
print(round(tapply(seq_len(nrow(h)), h$link, function(i) mean(fires(h[i, ]))), 4))
cat("counts:\n")
for (l in unique(h$link)) {
  s <- h[h$link == l, ]
  cat(sprintf("  %-8s %d/%d\n", l, sum(fires(s)), nrow(s)))
}

cat("\n=== DETECTION by link ===\n")
if (nrow(g)) {
  print(round(tapply(seq_len(nrow(g)), g$link, function(i) mean(fires(g[i, ]))), 4))
  cat("counts:\n")
  for (l in unique(g$link)) {
    s <- g[g$link == l, ]
    cat(sprintf("  %-8s %d/%d\n", l, sum(fires(s)), nrow(s)))
  }
}

cat("\n=== does the LINK-SCALE argument transport? worst healthy max_loading ===\n")
print(round(tapply(h$max_loading, h$link, max), 3))
cat("(threshold 6; logit is the calibrated reference)\n")
cat("\nworst healthy rl_max by link (threshold 25):\n")
print(round(tapply(h$rl_max, h$link, max), 2))
cat("\ndegenerate max_loading 5th percentile by link:\n")
if (nrow(g)) print(round(tapply(g$max_loading, g$link, stats::quantile, 0.05), 2))

cat("\n=== agreement between the computed rule and the SHIPPED row ===\n")
d2 <- d[!is.na(d$row_status), ]
print(table(computed = fires(d2), shipped = d2$row_status))
