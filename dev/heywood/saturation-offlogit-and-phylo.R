## Two remaining questions, both genuinely untested.
##
## PART 1 -- does the saturation arm earn its place OFF LOGIT?
## The per-trait test that rejected it ran on logit only. Cloglog is asymmetric
## and probit has a lighter tail, so the relationship between a runaway loading
## and fitted-probability saturation need not be the same there. If saturation
## catches degenerate fits the loading pair misses on probit or cloglog, a
## second arm IS justified -- and the earlier rejection would have been another
## case of testing a candidate in too narrow a regime.
##
## PART 2 -- the phylo tier.
## Recorded as blocked on a "pedigree fixture", but a phylogenetic VCV is just a
## valid covariance matrix and can be constructed directly from a random
## ultrametric tree. No external fixture is needed. Only SPATIAL genuinely needs
## a mesh (fmesher/INLA).
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
  wf <- switch(dgp, homog = 0, sparse50 = 0.5)
  nw <- round(p * wf)
  if (nw == 0L) rep(0.7, p) else c(rep(0.05, nw), rep(1.0, p - nw))
}

## per-trait prevalence + saturation exactly as the row computes them
tier_stats <- function(fit) {
  yv <- as.numeric(fit$tmb_data$y)
  tid <- as.integer(fit$tmb_data$trait_id) + 1L
  fid <- as.integer(fit$tmb_data$family_id_vec)
  lid <- as.integer(fit$tmb_data$link_id_vec)
  pv <- gllvmTMB:::.apply_linkinv_per_row(as.numeric(fit$report$eta), fid, lid)
  prev <- as.numeric(tapply(yv, tid, mean))
  sat <- as.numeric(tapply(seq_along(pv), tid, function(k) {
    v <- pv[k][is.finite(pv[k])]
    if (!length(v)) NA_real_ else mean(v >= SAT_PROB | v <= (1 - SAT_PROB))
  }))
  extreme <- is.finite(prev) & (prev >= PREV | prev <= (1 - PREV))
  list(sat_arm = any(is.finite(sat) & sat >= SAT_SHARE & !extreme),
       max_sat = suppressWarnings(max(sat, na.rm = TRUE)))
}

## ------------------------------------------------- PART 1: off-logit ------
g1 <- expand.grid(
  link = c("probit", "cloglog"), dgp = c("homog", "sparse50"),
  p = c(12L, 25L), n = c(60L, 150L), seed = 1:12, stringsAsFactors = FALSE
)
run1 <- function(i) {
  cl <- g1[i, ]
  out <- try({
    set.seed(cl$seed * 7717L + cl$n * 13L + cl$p + match(cl$link, c("probit","cloglog")))
    sds <- loading_sd(cl$dgp, cl$p); q <- 2L
    Lam <- matrix(stats::rnorm(cl$p * q, 0, rep(sds, times = q)), cl$p, q)
    B <- stats::rnorm(cl$p, 0, 0.3)
    Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
    eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
    li <- switch(cl$link, probit = stats::pnorm,
                 cloglog = function(x) 1 - exp(-exp(pmin(x, 20))))
    Y <- matrix(stats::rbinom(cl$n * cl$p, 1, li(as.numeric(eta))), cl$n, cl$p)
    dat <- data.frame(y = as.numeric(t(Y)),
                      trait = factor(rep(seq_len(cl$p), times = cl$n)),
                      site = factor(rep(seq_len(cl$n), each = cl$p)))
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
      data = dat, family = stats::binomial(link = cl$link), unit = "site"))
    lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
    rl <- lt$relative_loading[is.finite(lt$relative_loading)]
    ts <- tier_stats(fit)
    data.frame(link = cl$link, p = cl$p, n = cl$n, seed = cl$seed,
      rel_frob = norm(tcrossprod(fit$report$Lambda_B) - tcrossprod(Lam), "F") /
        norm(tcrossprod(Lam), "F"),
      pair = (length(rl) && max(rl) >= RUNAWAY) ||
        max(lt$max_loading, na.rm = TRUE) >= ABSOLUTE,
      sat_arm = ts$sat_arm, max_sat = ts$max_sat, stringsAsFactors = FALSE)
  }, silent = TRUE)
  if (inherits(out, "try-error")) NULL else out
}

message(sprintf("part 1 fits = %d", nrow(g1)))
d1 <- do.call(rbind, Filter(is.data.frame,
  parallel::mclapply(seq_len(nrow(g1)), run1, mc.cores = 14)))
utils::write.csv(d1, "dev/heywood/saturation-offlogit.csv", row.names = FALSE)

d1$degen <- d1$rel_frob >= 5; d1$healthy <- d1$rel_frob <= 0.5
gg <- d1[d1$degen, ]; hh <- d1[d1$healthy, ]
cat(sprintf("\n=== PART 1: off-logit saturation. usable %d; degenerate %d; healthy %d ===\n",
            nrow(d1), nrow(gg), nrow(hh)))
if (nrow(gg)) {
  cat(sprintf("  pair alone       %.4f (%d/%d)\n", mean(gg$pair), sum(gg$pair), nrow(gg)))
  cat(sprintf("  sat arm alone    %.4f (%d/%d)\n", mean(gg$sat_arm), sum(gg$sat_arm), nrow(gg)))
  cat(sprintf("  pair OR sat      %.4f (%d/%d)\n", mean(gg$pair | gg$sat_arm),
              sum(gg$pair | gg$sat_arm), nrow(gg)))
  cat(sprintf("  >>> ADDS %d  (by link: %s)\n", sum(gg$sat_arm & !gg$pair),
      paste(sprintf("%s=%d", names(tapply(gg$sat_arm & !gg$pair, gg$link, sum)),
                    tapply(gg$sat_arm & !gg$pair, gg$link, sum)), collapse = " ")))
}
if (nrow(hh)) cat(sprintf("  FPR of sat arm   %.4f (%d/%d)\n", mean(hh$sat_arm),
                          sum(hh$sat_arm), nrow(hh)))

## ---------------------------------------------------- PART 2: phylo ------
make_vcv <- function(p, seed) {
  set.seed(seed)
  h <- stats::hclust(stats::dist(matrix(stats::rnorm(p * 3), p, 3)))
  V <- stats::cophenetic(stats::as.dendrogram(h))
  V <- as.matrix(V)
  C <- max(V) - V              # ultrametric shared-path covariance
  C <- C / max(C)
  diag(C) <- 1
  dimnames(C) <- list(paste0("sp", seq_len(p)), paste0("sp", seq_len(p)))
  C + diag(1e-6, p)
}

g2 <- expand.grid(p = c(8L, 15L), n = c(40L, 80L), seed = 1:10,
                  stringsAsFactors = FALSE)
run2 <- function(i) {
  cl <- g2[i, ]
  out <- try({
    C <- make_vcv(cl$p, cl$seed * 31L)
    set.seed(cl$seed * 991L + cl$n)
    q <- 2L
    Lam <- matrix(stats::rnorm(cl$p * q, 0, 0.7), cl$p, q)
    B <- stats::rnorm(cl$p, 0, 0.3)
    Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
    eta <- Z %*% t(Lam) + matrix(B, cl$n, cl$p, byrow = TRUE)
    Y <- matrix(stats::rbinom(cl$n * cl$p, 1, stats::plogis(as.numeric(eta))), cl$n, cl$p)
    sp <- paste0("sp", rep(seq_len(cl$p), times = cl$n))
    dat <- data.frame(y = as.numeric(t(Y)),
                      trait = factor(sp, levels = paste0("sp", seq_len(cl$p))),
                      species = factor(sp, levels = paste0("sp", seq_len(cl$p))),
                      site = factor(rep(seq_len(cl$n), each = cl$p)))
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE) +
        phylo_latent(1 | species, d = 1, vcv = C),
      data = dat, family = stats::binomial(), unit = "site"))
    lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
    rl <- lt$relative_loading[is.finite(lt$relative_loading)]
    chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
    data.frame(p = cl$p, n = cl$n, seed = cl$seed,
      tiers = paste(names(fit$report)[grepl("^Lambda", names(fit$report))], collapse = "+"),
      rel_frob = norm(tcrossprod(fit$report$Lambda_B) - tcrossprod(Lam), "F") /
        norm(tcrossprod(Lam), "F"),
      rl_max = if (length(rl)) max(rl) else NA_real_,
      max_loading = max(lt$max_loading, na.rm = TRUE),
      row_status = {s <- chk$status[chk$component == "binomial_prevalence_loading"]
                    if (length(s)) s[[1L]] else NA_character_},
      stringsAsFactors = FALSE)
  }, silent = TRUE)
  if (inherits(out, "try-error")) NULL else out
}

message(sprintf("part 2 fits = %d", nrow(g2)))
d2 <- do.call(rbind, Filter(is.data.frame,
  parallel::mclapply(seq_len(nrow(g2)), run2, mc.cores = 10)))

cat("\n=== PART 2: phylo tier ===\n")
if (is.null(d2) || !nrow(d2)) {
  cat("no phylo fits completed -- tier remains uncovered\n")
} else {
  utils::write.csv(d2, "dev/heywood/phylo-tier-coverage.csv", row.names = FALSE)
  cat(sprintf("usable %d of %d;  tiers present: %s\n", nrow(d2), nrow(g2),
              paste(unique(d2$tiers), collapse = " | ")))
  h2 <- d2[d2$rel_frob <= 0.5, ]
  cat(sprintf("healthy %d;  false positives at shipped thresholds: %d\n",
              nrow(h2), sum(h2$rl_max >= RUNAWAY | h2$max_loading >= ABSOLUTE)))
  if (nrow(h2)) {
    cat(sprintf("worst healthy rl_max %.2f (thr 25);  max_loading %.2f (thr 6)\n",
                max(h2$rl_max), max(h2$max_loading)))
  }
  cat("shipped row statuses:\n"); print(table(d2$row_status, useNA = "ifany"))
}
