setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; H0 <- 15L
set.seed(1L)
lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
a   <- matrix(rnorm(N0 * q0), N0, q0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                  trait = rep(seq_len(T0), each = N0))
X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))

v <- gllvmTMB:::.va_r3_validate_data(
  y = d$y, n_trials = rep(NTR, nrow(d)), X = X, unit_id = d$unit,
  trait_id = d$trait, q = q0, family = "binomial_probit", link = "probit",
  unique = TRUE)
p0 <- gllvmTMB:::.va_r3_default_parameters(v, 1L)
cat("default param list lengths:\n"); print(vapply(p0, length, 1L))

mk <- function(tier) gllvmTMB:::.va_r3_make_objective(
  v, H = H0, parameters = p0, eval_method = tier,
  profile_variational = TRUE, silent = TRUE)
oa <- mk("ac"); og <- mk("gh")
cat("\nAC obj$par len:", length(oa$par), " GH obj$par len:", length(og$par), "\n")
cat("AC names table:\n"); print(table(names(oa$par)))
cat("GH names table:\n"); print(table(names(og$par)))
cat("identical par names:", identical(names(oa$par), names(og$par)), "\n")
cat("identical par values:", identical(unname(oa$par), unname(og$par)), "\n")
cat("AC env$par len:", length(oa$env$par), " last.par-ish names:\n")
print(table(names(oa$env$par)))
cat("fn0 ac:", oa$fn(oa$par), " fn0 gh:", og$fn(og$par), "\n")
t0 <- proc.time()[["elapsed"]]
fa <- stats::nlminb(oa$par, oa$fn, oa$gr, control = list(eval.max = 200L, iter.max = 100L))
cat("AC nlminb: obj", fa$objective, "iters", fa$iterations, "evals", paste(fa$evaluations, collapse="/"),
    "conv", fa$convergence, "secs", round(proc.time()[["elapsed"]] - t0, 1), "\n")
lp <- oa$fn(fa$par); full <- oa$env$last.par
cat("full last.par len:", length(full), "\n"); print(table(names(full)))
