## Arc C, the last two gaps: MISSING DATA and the SPATIAL tier.
##
## Both were recorded as blocked. Neither is:
##   * missing data -- the row already filters on `is_y_observed`
##     (R/diagnose.R:421), so the question is simply whether the thresholds hold
##     when a share of responses is absent. The exposure is real: fewer observed
##     cells per trait means noisier per-trait prevalence and saturation, and a
##     thinner denominator for the loading ratio.
##   * spatial -- `fmesher` IS installed, and `make_mesh()` ships in the package,
##     so an SPDE mesh needs no external fixture.
##
## Healthy is defined by RECOVERY against known truth, never convergence.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

RUNAWAY <- 25
ABSOLUTE <- 6
q <- 2L

loading_sd <- function(dgp, p) {
  wf <- switch(dgp, homog = 0, sparse50 = 0.5)
  nw <- round(p * wf)
  if (nw == 0L) rep(0.7, p) else c(rep(0.05, nw), rep(1.0, p - nw))
}

## ------------------------------------------------ PART 1: missing data ----
g1 <- expand.grid(
  miss = c(0, 0.15, 0.35, 0.55),
  dgp = c("homog", "sparse50"),
  p = c(12L, 25L), n = c(100L, 250L), seed = 1:10,
  stringsAsFactors = FALSE
)

run1 <- function(i) {
  cl <- g1[i, ]
  out <- try({
    set.seed(cl$seed * 4409L + cl$n * 7L + cl$p + round(cl$miss * 100))
    sds <- loading_sd(cl$dgp, cl$p)
    Lam <- matrix(stats::rnorm(cl$p * q, 0, rep(sds, times = q)), cl$p, q)
    B <- stats::rnorm(cl$p, 0, 0.3)
    Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
    eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
    yv <- stats::rbinom(cl$n * cl$p, 1, stats::plogis(as.numeric(t(eta))))
    if (cl$miss > 0) {
      drop <- sample.int(length(yv), floor(length(yv) * cl$miss))
      yv[drop] <- NA
    }
    dat <- data.frame(
      y = yv,
      trait = factor(rep(seq_len(cl$p), times = cl$n)),
      site = factor(rep(seq_len(cl$n), each = cl$p))
    )
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
      data = dat, family = stats::binomial(), unit = "site"))
    lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
    rl <- lt$relative_loading[is.finite(lt$relative_loading)]
    chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
    st <- chk$status[chk$component == "binomial_prevalence_loading"]
    data.frame(
      miss = cl$miss, dgp = cl$dgp, p = cl$p, n = cl$n, seed = cl$seed,
      rel_frob = norm(tcrossprod(fit$report$Lambda_B) - tcrossprod(Lam), "F") /
        norm(tcrossprod(Lam), "F"),
      rl_max = if (length(rl)) max(rl) else NA_real_,
      max_loading = max(lt$max_loading, na.rm = TRUE),
      row_status = if (length(st)) st[[1L]] else NA_character_,
      stringsAsFactors = FALSE)
  }, silent = TRUE)
  if (inherits(out, "try-error")) NULL else out
}

message(sprintf("part 1 (missing) fits = %d", nrow(g1)))
d1 <- do.call(rbind, Filter(is.data.frame,
  parallel::mclapply(seq_len(nrow(g1)), run1, mc.cores = 14)))
utils::write.csv(d1, "dev/heywood/missing-data-coverage.csv", row.names = FALSE)

fires <- function(x) x$rl_max >= RUNAWAY | x$max_loading >= ABSOLUTE
cat(sprintf("\n=== PART 1: MISSING DATA. usable %d of %d ===\n", nrow(d1), nrow(g1)))
d1$healthy <- d1$rel_frob <= 0.5
d1$degen <- d1$rel_frob >= 5
h <- d1[d1$healthy, ]; g <- d1[d1$degen, ]
cat(sprintf("healthy %d, degenerate %d\n", nrow(h), nrow(g)))
cat("\nFALSE POSITIVES by missing fraction:\n")
if (nrow(h)) {
  print(round(tapply(seq_len(nrow(h)), h$miss, function(i) mean(fires(h[i, ]))), 4))
  cat("counts:\n")
  for (m in sort(unique(h$miss))) {
    s <- h[h$miss == m, ]
    cat(sprintf("  %2.0f%% missing : %d/%d   worst rl_max %.2f  worst max_loading %.2f\n",
                100 * m, sum(fires(s)), nrow(s), max(s$rl_max), max(s$max_loading)))
  }
}
if (nrow(g)) {
  cat("\nDETECTION by missing fraction:\n")
  print(round(tapply(seq_len(nrow(g)), g$miss, function(i) mean(fires(g[i, ]))), 3))
}

## --------------------------------------------------- PART 2: spatial -----
g2 <- expand.grid(p = c(8L, 12L), n = c(60L, 120L), seed = 1:8,
                  stringsAsFactors = FALSE)

run2 <- function(i) {
  cl <- g2[i, ]
  out <- try({
    set.seed(cl$seed * 733L + cl$n + cl$p)
    coords <- data.frame(X = stats::runif(cl$n, 0, 10), Y = stats::runif(cl$n, 0, 10))
    mesh <- gllvmTMB::make_mesh(coords, c("X", "Y"), type = "kmeans",
                                n_knots = max(15L, round(cl$n / 4)), seed = 1L)
    Lam <- matrix(stats::rnorm(cl$p * q, 0, 0.7), cl$p, q)
    B <- stats::rnorm(cl$p, 0, 0.3)
    Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
    eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
    yv <- stats::rbinom(cl$n * cl$p, 1, stats::plogis(as.numeric(t(eta))))
    dat <- data.frame(
      y = yv,
      trait = factor(rep(seq_len(cl$p), times = cl$n)),
      site = factor(rep(seq_len(cl$n), each = cl$p)),
      X = rep(coords$X, each = cl$p), Y = rep(coords$Y, each = cl$p))
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE) +
        spatial_latent(0 + trait | site, d = 1),
      data = dat, family = stats::binomial(), unit = "site",
      mesh = mesh, spatial_coords = c("X", "Y")))
    lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
    rl <- lt$relative_loading[is.finite(lt$relative_loading)]
    chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
    st <- chk$status[chk$component == "binomial_prevalence_loading"]
    data.frame(
      p = cl$p, n = cl$n, seed = cl$seed,
      tiers = paste(names(fit$report)[grepl("^Lambda", names(fit$report))], collapse = "+"),
      rel_frob = norm(tcrossprod(fit$report$Lambda_B) - tcrossprod(Lam), "F") /
        norm(tcrossprod(Lam), "F"),
      rl_max = if (length(rl)) max(rl) else NA_real_,
      max_loading = max(lt$max_loading, na.rm = TRUE),
      row_status = if (length(st)) st[[1L]] else NA_character_,
      stringsAsFactors = FALSE)
  }, silent = TRUE)
  if (inherits(out, "try-error")) {
    return(data.frame(p = cl$p, n = cl$n, seed = cl$seed, tiers = NA_character_,
      rel_frob = NA_real_, rl_max = NA_real_, max_loading = NA_real_,
      row_status = paste0("ERROR: ", substr(conditionMessage(attr(out, "condition")), 1, 90)),
      stringsAsFactors = FALSE))
  }
  out
}

message(sprintf("part 2 (spatial) fits = %d", nrow(g2)))
d2 <- do.call(rbind, Filter(is.data.frame,
  parallel::mclapply(seq_len(nrow(g2)), run2, mc.cores = 8)))

cat("\n=== PART 2: SPATIAL tier ===\n")
if (is.null(d2) || !nrow(d2)) {
  cat("no rows returned\n")
} else {
  utils::write.csv(d2, "dev/heywood/spatial-tier-coverage.csv", row.names = FALSE)
  okd <- d2[!is.na(d2$rel_frob), ]
  cat(sprintf("attempted %d, fitted %d;  tiers: %s\n", nrow(d2), nrow(okd),
              paste(unique(stats::na.omit(okd$tiers)), collapse = " | ")))
  if (nrow(okd)) {
    hs <- okd[okd$rel_frob <= 0.5, ]
    cat(sprintf("healthy %d;  false positives at shipped thresholds: %d\n",
                nrow(hs), if (nrow(hs)) sum(fires(hs)) else 0L))
    if (nrow(hs)) cat(sprintf("worst healthy rl_max %.2f (thr 25); max_loading %.2f (thr 6)\n",
                              max(hs$rl_max), max(hs$max_loading)))
  }
  errs <- d2$row_status[grepl("^ERROR", d2$row_status %||% "")]
  if (length(errs)) cat("first error:", errs[[1]], "\n")
}
