## Design: does GH warm-started from the Albert-Chib optimum recover GH accuracy
## at a fraction of GH's optimisation work?
##
## Three arms, ONE seed each, all on the SAME data and the SAME objective
## construction (H = 15, profile_variational = TRUE, one-tier binomial-probit,
## N = 100, T = 10, q = 1, n_trials = 6 -- the DGP of dev/va-speed/10-seed-cell.R):
##   AC       : nlminb on the AC objective from the package default start.
##   GH-cold  : nlminb on the GH objective from the SAME default start.
##   GH-warm  : nlminb on the GH objective from AC's optimum (global block AND
##              the variational block, transplanted as the parameters list).
##
## Every arm is a SINGLE nlminb call with identical control, so $iterations and
## $evaluations are directly comparable. No polish loop, no L-BFGS-B fallback --
## those would make the iteration accounting incomparable across arms. Seed 1
## additionally runs the shipped .va_r3_fit() GH path as a cross-check that the
## hand-built cold objective lands on the same optimum.
##
## WALL-CLOCK IS NOT REPORTED: other agents run concurrently, so timings are
## contended and worthless. ITERATIONS/EVALUATIONS are contention-free.
## Results LOCAL (D-50).
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; H0 <- 15L
CTRL <- list(eval.max = 2000L, iter.max = 1000L)
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

make_cell <- function(SEED) {
  set.seed(SEED)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                    trait = rep(seq_len(T0), each = N0))
  X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  list(d = d, X = X, Sigma_true = lam %*% t(lam))
}

score <- function(par) {
  th <- par[names(par) == "theta_rr"]
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(th, T0, q0)
  L %*% t(L)
}

## nlminb plus the SAME polish loop .va_r3_fit() runs (up to two extra nlminb
## passes while max|grad| >= 1e-4). Without it a run can return convergence = 0
## while still short of the package's gradient gate, and a warm-vs-cold gap
## would then be an under-convergence artefact rather than a real difference.
## Iterations and evaluations are TOTALLED across passes, so the arms stay
## comparable. No L-BFGS-B fallback: it reports iterations = NA and would
## destroy the accounting.
opt_with_polish <- function(obj) {
  f <- stats::nlminb(obj$par, obj$fn, obj$gr, control = CTRL)
  it <- f$iterations; ev <- unname(f$evaluations[[1L]]); passes <- 0L
  for (k in seq_len(2L)) {
    g <- tryCatch(obj$gr(f$par), error = function(e) NA_real_)
    if (all(is.finite(g)) && max(abs(g)) < 1e-4) break
    cand <- tryCatch(stats::nlminb(f$par, obj$fn, obj$gr, control = CTRL),
                     error = function(e) NULL)
    if (is.null(cand) || !is.finite(cand$objective) ||
        cand$objective > f$objective + 1e-8) break
    it <- it + cand$iterations; ev <- ev + unname(cand$evaluations[[1L]])
    f <- cand; passes <- k
  }
  f$iterations <- it
  f$evaluations <- c(`function` = ev)
  f$polish_passes <- passes
  f
}

run_seed <- function(SEED) {
  cell <- make_cell(SEED)
  d <- cell$d; X <- cell$X
  v <- gllvmTMB:::.va_r3_validate_data(
    y = d$y, n_trials = rep(NTR, nrow(d)), X = X, unit_id = d$unit,
    trait_id = d$trait, q = q0, family = "binomial_probit", link = "probit",
    unique = TRUE)
  p0 <- gllvmTMB:::.va_r3_default_parameters(v, 1L)
  mk <- function(tier, pars) gllvmTMB:::.va_r3_make_objective(
    v, H = H0, parameters = pars, eval_method = tier,
    profile_variational = TRUE, silent = TRUE)

  ## ---- (a) AC ------------------------------------------------------------
  oa <- mk("ac", p0)
  fa <- opt_with_polish(oa)
  invisible(oa$fn(fa$par))                 # refresh env$last.par at the optimum
  full_ac <- oa$env$last.par               # global + variational block

  ## ---- (b) GH cold -------------------------------------------------------
  og <- mk("gh", p0)
  ## HARD GUARD: a silent name/length mismatch between the AC and GH parameter
  ## vectors would invalidate the transplant, so refuse rather than proceed.
  stopifnot(identical(names(oa$par), names(og$par)),
            identical(length(oa$par), length(og$par)))
  fgc <- opt_with_polish(og)

  ## ---- (c) GH warm-started from AC's optimum -----------------------------
  ## Transplant BOTH blocks: rebuild the parameters list from AC's last.par so
  ## the inner Newton solve also starts where AC left off. log_phi / log_sigma
  ## are mapped off for binomial_probit and never appear in last.par; they keep
  ## their (inert) defaults.
  pw <- p0
  for (nm in c("beta", "theta_rr", "log_sd_tier", "m", "log_L_diag", "L_off")) {
    vals <- unname(full_ac[names(full_ac) == nm])
    if (length(vals)) {
      stopifnot(length(vals) == length(pw[[nm]]))
      pw[[nm]] <- vals
    }
  }
  ow <- mk("gh", pw)
  stopifnot(identical(names(ow$par), names(og$par)))
  fgw <- opt_with_polish(ow)

  mg <- function(o, f) tryCatch(max(abs(o$gr(f$par))), error = function(e) NA_real_)
  ev <- function(f) unname(f$evaluations[[1L]])
  data.frame(
    seed = SEED,
    arm = c("AC", "GH-cold", "GH-warm"),
    objective = c(fa$objective, fgc$objective, fgw$objective),
    rel_frob = c(rel_frob(score(fa$par), cell$Sigma_true),
                 rel_frob(score(fgc$par), cell$Sigma_true),
                 rel_frob(score(fgw$par), cell$Sigma_true)),
    iterations = c(fa$iterations, fgc$iterations, fgw$iterations),
    fn_evals = c(ev(fa), ev(fgc), ev(fgw)),
    polish = c(fa$polish_passes, fgc$polish_passes, fgw$polish_passes),
    convergence = c(fa$convergence, fgc$convergence, fgw$convergence),
    max_grad = c(mg(oa, fa), mg(og, fgc), mg(ow, fgw)),
    stringsAsFactors = FALSE
  )
}

SEED <- as.integer(commandArgs(trailingOnly = TRUE)[1])
STORE <- "dev/va-speed/13-warmstart-polished.rds"
r <- run_seed(SEED)
print(r, row.names = FALSE, digits = 5)
prev <- if (file.exists(STORE)) readRDS(STORE) else NULL
prev <- prev[prev$seed != SEED, , drop = FALSE]
saveRDS(rbind(prev, r), STORE)
cat("SEED_", SEED, "_DONE\n", sep = "")
