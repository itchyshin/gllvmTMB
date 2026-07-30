## The missing headline: VGH's OWN degeneracy rate, against Laplace on identical data.
##
## Why this is missing. `dev/totoro-grid/results/RESULTS.md` §4 measured
## degeneracy (rel_frob > 10) at 0/320 for `gtmb_jj`, 0/600 for `gllvm_va`, and
## 70/601 (12%) for `gtmb_laplace` -- 59 of those reporting a clean status. But
## that grid ran 2026-07-26 and `R/va-vgh.R` landed 2026-07-29, so **VGH was
## never in it**. The slow `gtmb_gh` arm there (24 s median) is the OLDER
## va-r3 GH path, not VGH.
##
## That matters because VGH is the fast one: `dev/vgh/vgh-bench.R` measured
## 11.5x / 8.4x / 14.6x against Laplace at n = 200/500/1000 -- as INTERPRETED R
## against compiled C++ with AD. If VGH is also 0% degenerate, then it is both
## faster than Laplace and free of the pathology this whole lane exists to
## detect, and the Heywood gate is a stopgap for a Laplace-only 0.6.
##
## Both arms fit the SAME simulated data. Paired, so nothing is confounded.
##
## Parameterisation note, stated because the last speed benchmark was confounded
## by exactly this: VGH takes a UNIT-level X and fits per-trait coefficients, so
## `X = matrix(1, ...)` gives per-trait intercepts -- matching `0 + trait` on the
## Laplace side. Both arms therefore carry p intercepts + p*q loadings.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
e <- asNamespace("gllvmTMB")

q <- 2L
grid <- expand.grid(
  n = c(60L, 100L, 200L),
  p = c(6L, 12L),
  seed = 1:25,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 4021L + cl$n * 19L + cl$p)
      p <- cl$p
      Lam <- matrix(stats::rnorm(p * q, 0, 0.7), p, q)
      B <- stats::rnorm(p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * q), cl$n, q)
      eta <- Z %*% t(Lam) + matrix(B, cl$n, p, byrow = TRUE)
      Y <- matrix(stats::rbinom(cl$n * p, 1, stats::plogis(as.numeric(eta))), cl$n, p)

      yv <- as.numeric(t(Y))
      tr <- rep(seq_len(p), times = cl$n)
      un <- rep(seq_len(cl$n), each = p)
      G_true <- tcrossprod(Lam)
      nG <- norm(G_true, "F")

      ## ---- Laplace ----
      t0 <- proc.time()[["elapsed"]]
      la <- try(suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
        data = data.frame(y = yv, trait = factor(tr), site = factor(un)),
        family = stats::binomial(), unit = "site"
      )), silent = TRUE)
      la_s <- proc.time()[["elapsed"]] - t0
      la_sig <- la_rf <- NA_real_
      la_clean <- NA
      if (!inherits(la, "try-error")) {
        L <- la$report$Lambda_B
        la_sig <- norm(L, "F") / norm(Lam, "F")
        la_rf <- norm(tcrossprod(L) - G_true, "F") / nG
        la_clean <- isTRUE((la$opt$convergence %||% 1L) == 0L) &&
          isTRUE(la$sd_report$pdHess)
      }

      ## ---- VGH ----
      t1 <- proc.time()[["elapsed"]]
      vg <- try(e$.vgh_fit(yv, rep(1L, length(yv)), matrix(1, length(yv), 1),
                           un, tr, q = q, family = "binomial", link = "logit"),
                silent = TRUE)
      vg_s <- proc.time()[["elapsed"]] - t1
      vg_sig <- vg_rf <- NA_real_
      vg_conv <- NA
      if (!inherits(vg, "try-error")) {
        L <- as.matrix(vg$Lambda)
        vg_sig <- norm(L, "F") / norm(Lam, "F")
        vg_rf <- norm(tcrossprod(L) - G_true, "F") / nG
        vg_conv <- isTRUE(vg$converged)
      }

      data.frame(
        n = cl$n, p = p, seed = cl$seed,
        la_sigma = la_sig, la_rel_frob = la_rf, la_clean = la_clean, la_secs = la_s,
        vg_sigma = vg_sig, vg_rel_frob = vg_rf, vg_conv = vg_conv, vg_secs = vg_s,
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

message(sprintf("paired fits = %d", nrow(grid)))
res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 6)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/vgh-vs-laplace-degeneracy.csv", row.names = FALSE)

ok <- is.finite(d$la_rel_frob) & is.finite(d$vg_rel_frob)
d <- d[ok, ]
cat(sprintf("\npaired usable fits: %d\n", nrow(d)))

cat("\n=== DEGENERACY (the grid's definition, rel_frob > 10) ===\n")
cat(sprintf("  Laplace : %d of %d (%.1f%%)   of which reported clean: %d\n",
            sum(d$la_rel_frob > 10), nrow(d), 100 * mean(d$la_rel_frob > 10),
            sum(d$la_rel_frob > 10 & d$la_clean)))
cat(sprintf("  VGH     : %d of %d (%.1f%%)   of which reported converged: %d\n",
            sum(d$vg_rel_frob > 10), nrow(d), 100 * mean(d$vg_rel_frob > 10),
            sum(d$vg_rel_frob > 10 & d$vg_conv)))

cat("\n=== at the looser bar used in this lane (rel_frob >= 5) ===\n")
print(round(rbind(
  Laplace = tapply(d$la_rel_frob >= 5, d$n, mean),
  VGH = tapply(d$vg_rel_frob >= 5, d$n, mean)
), 3))

cat("\n=== median sigma = ||Lambda_hat||/||Lambda_true||  (1.0 = perfect) ===\n")
print(round(rbind(
  Laplace = tapply(d$la_sigma, d$n, stats::median),
  VGH = tapply(d$vg_sigma, d$n, stats::median)
), 4))

cat("\n=== median |sigma - 1| (lower better) ===\n")
print(round(rbind(
  Laplace = tapply(abs(d$la_sigma - 1), d$n, stats::median),
  VGH = tapply(abs(d$vg_sigma - 1), d$n, stats::median)
), 4))

cat("\n=== median rel_frob on G (lower better) ===\n")
print(round(rbind(
  Laplace = tapply(d$la_rel_frob, d$n, stats::median),
  VGH = tapply(d$vg_rel_frob, d$n, stats::median)
), 4))

cat("\n=== SPEED, median seconds (VGH is interpreted R vs compiled C++) ===\n")
print(round(rbind(
  Laplace = tapply(d$la_secs, d$n, stats::median),
  VGH = tapply(d$vg_secs, d$n, stats::median),
  speedup = tapply(d$la_secs, d$n, stats::median) / tapply(d$vg_secs, d$n, stats::median)
), 3))

cat(sprintf("\npaired: VGH closer to truth on sigma in %d of %d fits\n",
            sum(abs(d$vg_sigma - 1) < abs(d$la_sigma - 1)), nrow(d)))
cat(sprintf("paired: VGH lower rel_frob in %d of %d fits\n",
            sum(d$vg_rel_frob < d$la_rel_frob), nrow(d)))
