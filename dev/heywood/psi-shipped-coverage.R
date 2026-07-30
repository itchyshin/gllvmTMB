## Does the SHIPPED check_gllvmTMB() already catch the psi-face Heywood case?
##
## The previous probe measured statistics. This one asks the only question that
## matters for whether a new row is justified: run check_gllvmTMB() on fits with
## a genuinely collapsed unique variance and read what it actually reports.
##
## Reasoning about `near_zero_psi_*`'s thresholds is not evidence -- the row has
## an absolute arm AND a relative arm, and the relative one cannot be evaluated
## from a summary. Use the capability.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

grid <- expand.grid(
  family = c("gaussian", "poisson"),
  n = c(40L, 80L, 150L),
  d_fit = c(1L, 2L, 3L),
  seed = 1:20,
  stringsAsFactors = FALSE
)
p <- 6L
q_true <- 1L
psi_true <- rep(0.4, p)

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 7919L + cl$n * 13L + cl$d_fit)
      Lam <- matrix(stats::rnorm(p * q_true, 0, 0.9), p, q_true)
      B <- switch(cl$family,
        gaussian = stats::rnorm(p, 0, 0.3),
        poisson = stats::rnorm(p, 1.2, 0.3)
      )
      Z <- matrix(stats::rnorm(cl$n * q_true), cl$n, q_true)
      U <- matrix(stats::rnorm(cl$n * p), cl$n, p) %*% diag(sqrt(psi_true))
      eta <- Z %*% t(Lam) + U + matrix(B, cl$n, p, byrow = TRUE)
      Y <- switch(cl$family,
        gaussian = matrix(as.numeric(eta) + stats::rnorm(cl$n * p, 0, 0.5), cl$n, p),
        poisson = matrix(stats::rpois(cl$n * p, exp(as.numeric(eta))), cl$n, p)
      )
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = p))
      )
      fam <- switch(cl$family, gaussian = stats::gaussian(), poisson = stats::poisson())
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit),
        data = dat, family = fam, unit = "site"
      ))

      sd_hat <- as.numeric(fit$report$sd_B %||% NA_real_)
      chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
      pick <- function(cmp) {
        r <- chk$status[chk$component == cmp]
        if (length(r)) r[[1L]] else NA_character_
      }

      data.frame(
        family = cl$family, n = cl$n, d_fit = cl$d_fit, seed = cl$seed,
        min_sd_B = min(sd_hat, na.rm = TRUE),
        max_sd_B = max(sd_hat, na.rm = TRUE),
        true_sd_B = sqrt(psi_true[[1L]]),
        near_zero_psi = pick("near_zero_psi_unit"),
        weak_axis = pick("weak_axis_unit"),
        boundary = pick("boundary_flags"),
        max_grad = pick("max_gradient"),
        pd_hess = pick("pd_hessian"),
        n_warn = sum(chk$status != "PASS", na.rm = TRUE),
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
utils::write.csv(d, "dev/heywood/psi-shipped-coverage.csv", row.names = FALSE)

d$heywood <- d$min_sd_B < 0.1 * d$true_sd_B
d$severe <- d$min_sd_B < 1e-4

cat(sprintf("usable fits %d;  psi-collapsed %d (%.1f%%);  severe %d\n\n",
            nrow(d), sum(d$heywood), 100 * mean(d$heywood), sum(d$severe)))

cat("=== DOES THE SHIPPED near_zero_psi ROW FIRE? ===\n")
cat("on psi-collapsed fits:\n")
print(table(d$near_zero_psi[d$heywood], useNA = "ifany"))
cat("\non SEVERE (min sd < 1e-4):\n")
print(table(d$near_zero_psi[d$severe], useNA = "ifany"))
cat("\non healthy fits (false-positive check):\n")
print(table(d$near_zero_psi[!d$heywood], useNA = "ifany"))

cat("\n=== by family, share of psi-collapsed fits WARNed by near_zero_psi ===\n")
print(round(tapply(d$near_zero_psi[d$heywood] == "WARN", d$family[d$heywood], mean), 3))
cat("\n=== by fitted rank ===\n")
print(round(tapply(d$near_zero_psi[d$heywood] == "WARN", d$d_fit[d$heywood], mean), 3))

miss <- d$heywood & d$near_zero_psi != "WARN"
cat(sprintf("\n=== THE GAP: psi-collapsed but near_zero_psi says PASS: %d ===\n", sum(miss)))
if (any(miss)) {
  cat("  min_sd_B      :", paste(signif(range(d$min_sd_B[miss]), 3), collapse = " .. "), "\n")
  cat("  ratio to truth:", paste(signif(range(d$min_sd_B[miss] / d$true_sd_B[miss]), 3), collapse = " .. "), "\n")
  cat("  min/max sd    :", paste(signif(range(d$min_sd_B[miss] / d$max_sd_B[miss]), 3), collapse = " .. "), "\n")
  cat("  (the relative arm fires below 1e-3; these sit above it)\n")
  cat("\n  does ANY other row catch them?\n")
  cat("    total non-PASS rows on those fits:", paste(range(d$n_warn[miss]), collapse = " .. "), "\n")
  print(table(weak_axis = d$weak_axis[miss], boundary = d$boundary[miss]))
}
