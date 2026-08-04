## Which TIER does `latent(1 | unit, d, unique = TRUE)` put psi in?
##
## The Step-0 pilot's DGP adds psi_j as per-observation noise with per-trait
## variance, and with one row per (unit, trait) the unit-level "unique" variance
## and the observation residual are CONFOUNDED -- they are the same quantity.
## `.total_variance_spec(tier = "unit")` looks for `theta_diag_B` specifically, so
## if `unique = TRUE` routes psi to the per-row (W) tier instead, the design fix in
## 40-step0-pilot.R is aimed at the wrong tier and the arm will still refuse.
## Settle it by fitting and reading the parameter names.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

set.seed(1L); N <- 60L; T0 <- 8L; Q <- 2L
Lam <- matrix(rnorm(T0 * Q, 0, 0.8), T0, Q); Lam[upper.tri(Lam)] <- 0
psi <- runif(T0, 0.3, 0.5); b <- rnorm(T0, 0, 0.5)
z <- matrix(rnorm(N * Q), N, Q); x <- rnorm(N)
eta <- outer(x, b) + z %*% t(Lam)
y <- eta + matrix(rnorm(N * T0, 0, sqrt(rep(psi, each = N))), N, T0)
d <- data.frame(y = as.numeric(t(y)), trait = factor(rep(seq_len(T0), times = N)),
                unit = factor(rep(seq_len(N), each = T0)), x = rep(x, each = T0))

probe <- function(label, form) {
  f <- try(gllvmTMB::gllvmTMB(form, data = d, family = gaussian(),
                              unit = "unit", silent = TRUE), silent = TRUE)
  if (inherits(f, "try-error")) {
    cat(sprintf("\n== %s ==\n  FIT ERROR: %s\n", label,
                conditionMessage(attr(f, "condition"))))
    return(invisible(NULL))
  }
  pn <- names(f$opt$par)
  cat(sprintf("\n== %s ==\n", label))
  cat("  par blocks:", paste(unique(pn), collapse = ", "), "\n")
  cat("  theta_diag_B present:", any(pn == "theta_diag_B"), "\n")
  cat("  theta_diag_W present:", any(pn == "theta_diag_W"), "\n")
  for (tr in c("unit", "unit_obs")) {
    s <- try(gllvmTMB:::.total_variance_spec(f, tier = tr), silent = TRUE)
    cat(sprintf("  .total_variance_spec(tier=%-9s): %s\n", paste0('"', tr, '"'),
                if (inherits(s, "try-error"))
                  paste0("ERROR -- ", sub("\n.*", "", conditionMessage(attr(s, "condition"))))
                else "OK"))
  }
  invisible(f)
}

probe("latent(1|unit, unique = TRUE)  [the new design fix]",
      y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q, unique = TRUE))
probe("latent(1|unit, unique = FALSE) [what the pilot had]",
      y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q, unique = FALSE))
probe("latent(unique=FALSE) + indep(0+trait|unit) [explicit B-tier psi]",
      y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q, unique = FALSE) +
        indep(0 + trait | unit))

cat("\nTruth planted: psi_j ~ U(0.3,0.5) as per-observation per-trait noise.\n")
cat("V_j = Sigma_jj + psi_j is the scored estimand at the unit tier.\n")
