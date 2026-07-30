## Arc B, corrected. Does a SCALE statistic catch the loading-face degeneracies
## that the within-fit RATIO provably cannot?
##
## Why this rerun. `g_norm` was rejected earlier at AUC 0.466 -- but that was
## measured against the PSI face, which it was never proposed for. It was
## proposed for the loading face, and specifically for the regime where the
## ratio is known to fail: an over-specified rank, where SEVERAL traits inflate
## together, the robust centre in the denominator is itself inflated, and the
## ratio goes blind. Rejecting it on the wrong face was an invalid rejection.
##
## The known failure to reproduce and then beat: at an over-specified rank the
## shipped `relative_loading >= 25` missed 3 of 8 degenerate fits, and they were
## the three WORST.
##
## Candidate scale statistics, all free from a single fit:
##   max_loading   largest |loading| on the LINK scale. For a logit link this
##                 has real absolute meaning: u ~ N(0, I) is an identification
##                 requirement, so a loading IS the trait's latent SD in logit
##                 units. |loading| > 6 already means a fitted probability
##                 indistinguishable from 0 or 1 across +/-1 SD.
##   g_fro         ||G||_F, G = Lambda Lambda', rotation-invariant.
##   g_norm_var    ||G||_F normalised by the summed observed trait variances.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

p <- 6L
q_true <- 2L

grid <- expand.grid(
  n = c(60L, 100L, 200L),
  d_fit = c(2L, 3L, 4L), # 3 and 4 are over-specified
  seed = 1:40,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 3313L + cl$n * 29L + cl$d_fit)
      Lam <- matrix(stats::rnorm(p * q_true, 0, 0.7), p, q_true)
      B <- stats::rnorm(p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * q_true), cl$n, q_true)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, p, byrow = TRUE)
      Y <- matrix(stats::rbinom(cl$n * p, 1, stats::plogis(as.numeric(eta))), cl$n, p)
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = p))
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit, unique = FALSE),
        data = dat, family = stats::binomial(), unit = "site"
      ))

      Lhat <- fit$report$Lambda_B
      G_hat <- tcrossprod(Lhat)
      G_true <- tcrossprod(Lam)
      rel_frob <- norm(G_hat - G_true, "F") / norm(G_true, "F")

      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]
      obs_var <- apply(Y, 2L, stats::var)

      ## how many traits are inflated together -- the mechanism that blinds a ratio
      ml <- lt$max_loading[is.finite(lt$max_loading)]
      n_inflated <- sum(ml > 5 * stats::median(ml))

      data.frame(
        n = cl$n, d_fit = cl$d_fit, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        rel_frob = rel_frob,
        rl_max = if (length(rl)) max(rl) else NA_real_,
        max_loading = max(ml, na.rm = TRUE),
        g_fro = norm(G_hat, "F"),
        g_norm_var = norm(G_hat, "F") / sum(obs_var),
        n_inflated = n_inflated,
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 12)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/scale-statistic-overrank.csv", row.names = FALSE)

d$degen <- d$rel_frob >= 5
d$healthy <- d$rel_frob <= 0.5
cat(sprintf("usable %d of %d;  degenerate %d;  healthy %d;  middle %d\n\n",
            nrow(d), nrow(grid), sum(d$degen), sum(d$healthy),
            sum(!d$degen & !d$healthy)))

cat("=== degeneracy rate by fitted rank (truth q = 2) ===\n")
print(round(tapply(d$degen, d$d_fit, mean), 3))

cat("\n=== REPRODUCE the ratio's failure: shipped rule on degenerate fits ===\n")
g <- d[d$degen, ]
cat(sprintf("  relative_loading >= 25 catches %d of %d (%.3f)\n",
            sum(g$rl_max >= 25), nrow(g), mean(g$rl_max >= 25)))
cat(sprintf("  of the misses, worst rel_frob = %.0f\n",
            if (any(g$rl_max < 25)) max(g$rel_frob[g$rl_max < 25]) else NA))
cat("\n  ratio's blindness vs how many traits inflated together:\n")
print(round(tapply(g$rl_max >= 25, pmin(g$n_inflated, 4), mean), 3))
cat("  (columns = traits inflated; the ratio degrades as this rises)\n")

auc <- function(s, pos) {
  k <- is.finite(s)
  s <- s[k]; pos <- pos[k]
  if (length(unique(pos)) < 2L) return(NA_real_)
  r <- rank(s)
  (sum(r[pos]) - sum(pos) * (sum(pos) + 1) / 2) / (sum(pos) * sum(!pos))
}
keep <- d$degen | d$healthy
cat("\n=== discrimination on this regime (degenerate vs healthy) ===\n")
for (s in c("rl_max", "max_loading", "g_fro", "g_norm_var")) {
  cat(sprintf("  %-12s AUC = %.4f\n", s, auc(d[[s]][keep], d$degen[keep])))
}

cat("\n=== can a scale cut catch what the ratio misses, at zero FPR? ===\n")
h <- d[d$healthy, ]
cat(sprintf("%-8s %10s %10s %14s %14s\n", "cut", "sens", "FPR", "adds-to-ratio", "combined sens"))
for (t in c(4, 5, 6, 8, 10, 15)) {
  sens <- mean(g$max_loading >= t)
  fpr <- mean(h$max_loading >= t)
  adds <- sum(g$max_loading >= t & g$rl_max < 25)
  comb <- mean(g$rl_max >= 25 | g$max_loading >= t)
  cat(sprintf("ml>=%-4g %10.3f %10.4f %14d %14.3f\n", t, sens, fpr, adds, comb))
}
cat("\nhealthy max_loading quantiles (the safety margin):\n")
print(round(stats::quantile(h$max_loading, c(.5, .9, .99, 1)), 3))
cat("degenerate max_loading quantiles:\n")
print(round(stats::quantile(g$max_loading, c(0, .05, .5, 1)), 2))
