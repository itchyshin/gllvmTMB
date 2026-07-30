## Does the LOADING face exist outside binomial? The one untested configuration.
##
## This decides whether a second, FAMILY-GENERAL statistic is justified.
##
## Everything measured so far leaves one cell empty:
##   Arc A         gaussian/poisson, unique = FALSE, TRUE rank        -> no degeneracy
##   psi probe     gaussian/poisson, unique = TRUE,  over-rank        -> PSI collapses, loadings fine
##   this script   gaussian/poisson, unique = FALSE, OVER-rank        -> ???
##
## The reasoning that makes this the decisive cell: with `unique = FALSE` there
## is no Psi for the excess variance to collapse into, so an over-specified rank
## has only the LOADINGS as an outlet. That is precisely the argument that
## explained why Arc A's binomial sweep saw loading runaways and no psi collapse.
## If gaussian behaves the same way here, the loading face is family-general and
## a scale statistic that transports beyond a logit link is needed. If it does
## not, the loading face is binomial-specific and ONE statistic is the correct
## and complete answer.
##
## `max_loading` cannot serve a family-general role: it is a LINK-scale cut and
## a gaussian identity link has an arbitrary response scale. So the candidate
## measured here is `g_norm_var` = ||G||_F normalised by the summed observed
## trait variances, which is dimensionless.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

q_true <- 2L
grid <- expand.grid(
  family = c("gaussian", "poisson"),
  p = c(12L, 25L),
  n = c(60L, 150L),
  d_fit = c(2L, 3L, 5L), # 3 and 5 over-specify
  seed = 1:15,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 6607L + cl$n * 23L + cl$p + cl$d_fit)
      p <- cl$p
      Lam <- matrix(stats::rnorm(p * q_true, 0, 0.7), p, q_true)
      B <- switch(cl$family,
        gaussian = stats::rnorm(p, 0, 0.3),
        poisson = stats::rnorm(p, 1.2, 0.3)
      )
      Z <- matrix(stats::rnorm(cl$n * q_true), cl$n, q_true)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, p, byrow = TRUE)
      Y <- switch(cl$family,
        gaussian = matrix(as.numeric(eta) + stats::rnorm(cl$n * p), cl$n, p),
        poisson = matrix(stats::rpois(cl$n * p, exp(as.numeric(eta))), cl$n, p)
      )
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = cl$n / cl$n * p))[seq_len(cl$n * p)]
      )
      dat$site <- factor(rep(seq_len(cl$n), each = p))
      fam <- switch(cl$family, gaussian = stats::gaussian(), poisson = stats::poisson())
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit, unique = FALSE),
        data = dat, family = fam, unit = "site"
      ))

      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(Lam)
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]
      obs_var <- apply(Y, 2L, stats::var)

      data.frame(
        family = cl$family, p = p, n = cl$n, d_fit = cl$d_fit, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        rel_frob = norm(G_hat - G_true, "F") / norm(G_true, "F"),
        sigma = norm(fit$report$Lambda_B, "F") / norm(Lam, "F"),
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
utils::write.csv(d, "dev/heywood/gaussian-noPsi-overrank.csv", row.names = FALSE)

d$degen <- d$rel_frob >= 5
d$healthy <- d$rel_frob <= 0.5
cat(sprintf("\nusable %d of %d\n", nrow(d), nrow(grid)))

cat("\n=== THE DECISIVE QUESTION: does a loading runaway occur off binomial? ===\n")
cat(sprintf("degenerate (rel_frob >= 5): %d of %d\n", sum(d$degen), nrow(d)))
print(table(family = d$family, degenerate = d$degen))
cat("\nrel_frob by family x fitted rank (max):\n")
print(round(tapply(d$rel_frob, list(d$d_fit, d$family), max), 3))
cat("\nsigma = ||Lambda_hat||/||Lambda_true|| by family x rank (max):\n")
print(round(tapply(d$sigma, list(d$d_fit, d$family), max), 3))

cat("\n=== if there IS degeneracy, can g_norm_var see it? ===\n")
if (sum(d$degen) > 0 && sum(d$healthy) > 0) {
  g <- d[d$degen, ]; h <- d[d$healthy, ]
  cat("degenerate g_norm_var:", paste(signif(range(g$g_norm_var), 3), collapse = " .. "), "\n")
  cat("healthy    g_norm_var:", paste(signif(range(h$g_norm_var), 3), collapse = " .. "), "\n")
  cat("separable at zero FPR?", min(g$g_norm_var) > max(h$g_norm_var), "\n")
  cat("\nwould the SHIPPED binomial rule have caught them (if it applied)?\n")
  cat(sprintf("  rl_max >= 25: %d of %d\n", sum(g$rl_max >= 25), nrow(g)))
} else {
  cat("NO degenerate fits -- the loading face does not occur here.\n")
  cat("rel_frob range:", paste(round(range(d$rel_frob), 3), collapse = " .. "), "\n")
  cat("sigma range   :", paste(round(range(d$sigma), 3), collapse = " .. "), "\n")
  cat("\n=> the loading face is BINOMIAL-SPECIFIC across every configuration\n")
  cat("   tested, so a family-general scale statistic has nothing to detect\n")
  cat("   and ONE wired statistic is the complete answer.\n")
}
