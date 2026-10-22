## PROVENANCE NOTE (added on landing, 2026-09-04). This is the D-139 pre-run that
## sized the arcF recovery campaign (PR #1258). Its timings were measured on a
## LOADED machine (load ~48) and came out roughly 5x slower than the same fits on
## an idle Totoro -- ordinal_logit n=300 read 5.7 s here versus 1.1 s there. The
## campaign's own per-seed runtimes in dev/gapclose/arcF/recovery/summary/ are the
## honest numbers; these are the (conservative) ones the launch decision was made
## on. Kept so the estimate behind that decision is reconstructable.
## D-139 pre-run: per-fit wall-clock for ordinal_logit and censored_poisson
## at the shipped test size and 2x / 4x. DGPs lifted verbatim from the
## shipped recovery tests (test-ordinal-logit.R, test-censored-poisson.R).
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

## ---- ordinal_logit DGP (verbatim from test-ordinal-logit.R) -------------
K <- 4L; taus <- c(0, 0.7, 1.4); n_traits <- 4L; n_rep <- 2L
tnames <- paste0("t", seq_len(n_traits))
alpha <- c(0.2, -0.1, 0.15, 0.0); lambda_o <- c(1.6, 1.3, -1.2, 1.1)
ordinalise <- function(ys) 1L + (ys > taus[1]) + (ys > taus[2]) + (ys > taus[3])
sim_ord <- function(seed, n_unit) {
  set.seed(seed)
  f <- rnorm(n_unit)
  n <- n_unit * n_traits * n_rep
  unit <- rep(seq_len(n_unit), each = n_traits * n_rep)
  trait <- rep(rep(tnames, each = n_rep), times = n_unit)
  ti <- rep(rep(seq_len(n_traits), each = n_rep), times = n_unit)
  ystar <- alpha[ti] + lambda_o[ti] * f[unit] + rlogis(n)
  data.frame(unit = factor(unit, levels = seq_len(n_unit)),
             trait = factor(trait, levels = tnames),
             value = ordinalise(ystar))
}
fit_ord <- function(seed, n_unit) {
  df <- sim_ord(seed, n_unit)
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1), df,
           unit = "unit", family = ordinal_logit())
}

## ---- censored_poisson DGP (verbatim from test-censored-poisson.R) -------
beta_c <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
lambda_c <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35); Cc <- 6; n_trait_c <- 6L
fit_cens <- function(seed, n_site) {
  set.seed(seed)
  u <- rnorm(n_site)
  eta <- outer(u, lambda_c) + matrix(beta_c, n_site, n_trait_c, byrow = TRUE)
  Yt <- matrix(rpois(n_site * n_trait_c, exp(eta)), n_site, n_trait_c)
  cens <- Yt >= Cc
  dat <- data.frame(site = factor(rep(seq_len(n_site), n_trait_c)),
                    trait = factor(rep(seq_len(n_trait_c), each = n_site)),
                    y = as.vector(ifelse(cens, Cc, Yt)),
                    censored = as.integer(as.vector(cens)))
  gllvmTMB(cbind(y, censored) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
           data = dat, family = censored_poisson(), unit = "site",
           control = gllvmTMBcontrol(se = FALSE))
}

time_one <- function(label, fn, seed, n) {
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(suppressMessages(suppressWarnings(fn(seed, n))), error = function(e) e)
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    cat(sprintf("ROW| %-16s n=%-5d seed=%-5d %8.1fs  ERROR: %s\n",
                label, n, seed, el, substr(conditionMessage(fit), 1, 60))); return(invisible(NULL))
  }
  pd <- tryCatch(isTRUE(fit$fit_health$pd_hessian), error = function(e) NA)
  cat(sprintf("ROW| %-16s n=%-5d seed=%-5d %8.1fs  conv=%s  pd=%s\n",
              label, n, seed, el, fit$opt$convergence, pd))
  invisible(NULL)
}

cat("=== PRE-RUN TIMING (single core) ===\n")
for (n in c(300L, 600L, 1200L)) time_one("ordinal_logit", fit_ord, 20260903L, n)
for (n in c(200L, 400L, 800L)) time_one("censored_poisson", fit_cens, 101L, n)
## seed-spread probe at the shipped size: 3 seeds each
cat("=== SEED SPREAD at shipped size ===\n")
for (s in c(20260903L, 20260904L, 20260905L)) time_one("ordinal_logit", fit_ord, s, 300L)
for (s in c(101L, 202L, 303L)) time_one("censored_poisson", fit_cens, s, 200L)
cat("=== DONE ===\n")
