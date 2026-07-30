## Arc C, the tier gap: does the shipped gate false-positive on a MULTI-TIER fit?
##
## Every calibration fit so far carried one latent tier (`unit` / Lambda_B).
## `.gllvmTMB_max_loading_by_trait()` loops over EVERY latent spec present
## (Lambda_B, Lambda_W, Lambda_phy, Lambda_spde) and takes each trait's maximum
## ACROSS tiers, then divides by the median of those. So a second tier changes
## BOTH the numerator and the denominator, and neither has been measured.
##
## This is the same shape of defect as the mixed-family pooling that Arc A
## fixed: a tier on a different scale can set the yardstick. The difference is
## that the fix there (`reference_traits`) restricts by FAMILY, not by tier --
## so it does not help here, and the exposure is real.
##
## The mechanism is exercised directly by sweeping `w_scale`, the size of the
## within-unit tier's loadings relative to the between-unit tier's.
##
## Healthy is defined by RECOVERY of the UNIT tier against known truth.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

RUNAWAY <- 25
ABSOLUTE <- 6
q <- 2L
r <- 3L

grid <- expand.grid(
  w_scale = c(0.2, 1, 5),
  ns = c(40L, 80L),
  p = c(8L, 15L),
  seed = 1:15,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 5501L + cl$ns * 17L + cl$p + round(cl$w_scale * 10))
      p <- cl$p
      LB <- matrix(stats::rnorm(p * q, 0, 0.7), p, q)
      LW <- matrix(stats::rnorm(p * q, 0, 0.5), p, q) * cl$w_scale
      B <- stats::rnorm(p, 0, 0.3)

      site <- rep(seq_len(cl$ns), each = p * r)
      trait <- rep(rep(seq_len(p), each = r), times = cl$ns)
      ss <- paste0(site, "_", trait)
      u <- unique(ss)
      idx <- match(ss, u)
      ZB <- matrix(stats::rnorm(cl$ns * q), cl$ns, q)
      ZW <- matrix(stats::rnorm(length(u) * q), length(u), q)

      eta <- rowSums(ZB[site, , drop = FALSE] * LB[trait, , drop = FALSE]) +
        rowSums(ZW[idx, , drop = FALSE] * LW[trait, , drop = FALSE]) + B[trait]
      y <- stats::rbinom(length(eta), 1, stats::plogis(eta))
      dat <- data.frame(
        y = y, trait = factor(trait), site = factor(site),
        site_species = factor(ss)
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait +
          latent(0 + trait | site, d = q, unique = FALSE) +
          latent(0 + trait | site_species, d = q, unique = FALSE),
        data = dat, family = stats::binomial(),
        unit = "site", unit_obs = "site_species"
      ))

      GB_true <- tcrossprod(LB)
      GB_hat <- tcrossprod(fit$report$Lambda_B)
      rel_frob <- norm(GB_hat - GB_true, "F") / norm(GB_true, "F")

      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]
      chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
      st <- chk$status[chk$component == "binomial_prevalence_loading"]

      ## per-tier maxima, to show which tier drives the pooled statistic
      mlB <- max(abs(fit$report$Lambda_B), na.rm = TRUE)
      mlW <- max(abs(fit$report$Lambda_W %||% NA_real_), na.rm = TRUE)

      data.frame(
        w_scale = cl$w_scale, ns = cl$ns, p = p, seed = cl$seed,
        rel_frob = rel_frob,
        rl_max = if (length(rl)) max(rl) else NA_real_,
        max_loading = max(lt$max_loading, na.rm = TRUE),
        ml_B = mlB, ml_W = mlW,
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
utils::write.csv(d, "dev/heywood/multitier-coverage.csv", row.names = FALSE)

d$health <- ifelse(d$rel_frob <= 0.5, "healthy",
  ifelse(d$rel_frob >= 5, "degenerate", "middle"))
cat(sprintf("\nusable %d of %d\n", nrow(d), nrow(grid)))
print(table(w_scale = d$w_scale, health = d$health))

h <- d[d$health == "healthy", ]
g <- d[d$health == "degenerate", ]
fires <- function(x) x$rl_max >= RUNAWAY | x$max_loading >= ABSOLUTE

cat("\n=== FALSE POSITIVES on healthy two-tier fits, by within-tier scale ===\n")
if (nrow(h)) {
  print(round(tapply(seq_len(nrow(h)), h$w_scale, function(i) mean(fires(h[i, ]))), 4))
  for (w in sort(unique(h$w_scale))) {
    s <- h[h$w_scale == w, ]
    cat(sprintf("  w_scale %-4g : %d/%d\n", w, sum(fires(s)), nrow(s)))
  }
  cat("\nworst healthy rl_max by w_scale (threshold 25):\n")
  print(round(tapply(h$rl_max, h$w_scale, max), 2))
  cat("worst healthy max_loading by w_scale (threshold 6):\n")
  print(round(tapply(h$max_loading, h$w_scale, max), 2))
}

cat("\n=== does the WITHIN tier dominate the pooled statistic? ===\n")
cat("median ratio max|Lambda_W| / max|Lambda_B|, by w_scale:\n")
print(round(tapply(d$ml_W / d$ml_B, d$w_scale, stats::median), 2))

if (nrow(g)) {
  cat("\n=== DETECTION on degenerate unit tiers ===\n")
  cat(sprintf("  %d of %d\n", sum(fires(g)), nrow(g)))
}

cat("\n=== agreement with the SHIPPED row ===\n")
d2 <- d[!is.na(d$row_status), ]
print(table(computed = fires(d2), shipped = d2$row_status))
