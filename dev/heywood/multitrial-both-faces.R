## Arc C: the one cell where BOTH Heywood faces can occur at once.
##
## Single-trial Bernoulli has its between-unit Psi pinned off by design
## (R/fit-multi.R:4806-4830) -- one trial per cell carries no information to
## identify it. The guard is `all(n_trials == 1)`, so MULTI-TRIAL binomial with
## `unique = TRUE` keeps a live Psi *and* a binomial link that can separate.
## Both instruments should be exercised there and neither has been.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

p <- 6L
q_true <- 2L
n_trials <- 10L

grid <- expand.grid(
  n = c(60L, 150L),
  d_fit = c(2L, 3L),
  seed = 1:30,
  stringsAsFactors = FALSE
)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 2711L + cl$n * 31L + cl$d_fit)
      Lam <- matrix(stats::rnorm(p * q_true, 0, 0.7), p, q_true)
      psi_true <- rep(0.4, p)
      B <- stats::rnorm(p, 0, 0.3)
      Z <- matrix(stats::rnorm(cl$n * q_true), cl$n, q_true)
      U <- matrix(stats::rnorm(cl$n * p), cl$n, p) %*% diag(sqrt(psi_true))
      eta <- Z %*% t(Lam) + U + matrix(B, cl$n, p, byrow = TRUE)
      S <- matrix(stats::rbinom(cl$n * p, n_trials, stats::plogis(as.numeric(eta))),
                  cl$n, p)

      dat <- data.frame(
        succ = as.numeric(t(S)),
        fail = n_trials - as.numeric(t(S)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = p))
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        cbind(succ, fail) ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit),
        data = dat, family = stats::binomial(), unit = "site"
      ))

      sd_hat <- as.numeric(fit$report$sd_B %||% NA_real_)
      psi_live <- length(sd_hat) > 0L && any(is.finite(sd_hat)) &&
        max(sd_hat, na.rm = TRUE) > 1e-5
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      rl <- lt$relative_loading[is.finite(lt$relative_loading)]

      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(Lam)
      rel_frob <- norm(G_hat - G_true, "F") / norm(G_true, "F")

      chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
      pick <- function(cmp) {
        r <- chk$status[chk$component == cmp]
        if (length(r)) r[[1L]] else NA_character_
      }

      data.frame(
        n = cl$n, d_fit = cl$d_fit, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        psi_live = psi_live,
        min_sd_B = if (length(sd_hat)) min(sd_hat, na.rm = TRUE) else NA_real_,
        true_sd_B = sqrt(psi_true[[1L]]),
        rel_frob = rel_frob,
        rl_max = if (length(rl)) max(rl) else NA_real_,
        max_loading = max(lt$max_loading, na.rm = TRUE),
        row_binom = pick("binomial_prevalence_loading"),
        row_psi = pick("near_zero_psi_unit"),
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 10)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/multitrial-both-faces.csv", row.names = FALSE)

cat(sprintf("usable %d of %d\n", nrow(d), nrow(grid)))
cat("=== is Psi actually live here (unlike single-trial Bernoulli)? ===\n")
print(table(psi_live = d$psi_live))
cat("min_sd_B range:", paste(signif(range(d$min_sd_B, na.rm = TRUE), 3), collapse = " .. "),
    " (true 0.632)\n\n")

d$psi_collapsed <- d$min_sd_B < 0.1 * d$true_sd_B
d$loading_degen <- d$rel_frob >= 5
cat("=== the two faces, in the one cell where both are possible ===\n")
cat(sprintf("psi collapsed   : %d of %d (%.1f%%)\n", sum(d$psi_collapsed), nrow(d),
            100 * mean(d$psi_collapsed)))
cat(sprintf("loading degen   : %d of %d (%.1f%%)\n", sum(d$loading_degen), nrow(d),
            100 * mean(d$loading_degen)))
cat(sprintf("BOTH at once    : %d\n\n", sum(d$psi_collapsed & d$loading_degen)))

cat("=== does the shipped diagnostic report each face? ===\n")
if (any(d$psi_collapsed)) {
  cat("near_zero_psi on psi-collapsed fits:\n")
  print(table(d$row_psi[d$psi_collapsed], useNA = "ifany"))
}
if (any(d$loading_degen)) {
  cat("\nbinomial row on loading-degenerate fits:\n")
  print(table(d$row_binom[d$loading_degen], useNA = "ifany"))
}
cat("\nfalse positives on clean fits (neither face):\n")
clean <- !d$psi_collapsed & d$rel_frob <= 0.5
print(table(psi_row = d$row_psi[clean], binom_row = d$row_binom[clean]))
cat("\nhealthy max_loading (absolute arm margin):",
    if (any(clean)) round(max(d$max_loading[clean]), 2) else NA, "vs threshold 6\n")
