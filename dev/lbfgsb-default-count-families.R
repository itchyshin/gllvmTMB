## Fisher's slice: does the VA-R3 nlminb-vs-lbfgsb same-optimum finding hold
## for the two COUNT families the earlier gaussian_anchor / binomial evidence
## never touched -- poisson (log link) and nbinom2 (log link)?
##
## Grid: family in {poisson, nbinom2} x q in {1, 2, 3} x N in {150, 400},
## T = 8 fixed. Each cell is fit TWICE from IDENTICAL data with n_starts = 1L
## (one optimiser run, not the 4-start agreement gate) -- once with
## optimizer = "nlminb", once with optimizer = "lbfgsb". n_starts = 1 makes
## .va_r3_default_parameters() deterministic (start_id = 1, the factor-
## analytic warm start; no RNG), so both calls see exactly the same start.
##
## NOTE on .va_r3_fit()'s internal polish step: even with n_starts = 1, the
## per-start loop inside .va_r3_fit() always runs an nlminb polish pass (up to
## 2 passes) if the primary optimiser's gradient is not already below 1e-4,
## and will further polish with L-BFGS-B if that still doesn't converge. This
## is baked into .va_r3_fit() itself and applies identically regardless of
## which `optimizer` argument was passed, so the comparison below is "which
## primary optimiser feeds the (identical) polish machinery", exactly how
## .va_r3_fit() is actually used -- not a hand-rolled single-call comparison
## that would diverge from production behaviour.
##
## Also note: with n_starts = 1L, .va_r3_fit()'s top-level `status` can never
## be "healthy" -- the admission gate requires >= 3 healthy starts regardless
## of n_starts. That is expected and irrelevant here; we read convergence,
## objective and par straight from `fit$starts[[1]]`.
##
## Load with: devtools::load_all("/private/tmp/gllvmtmb-va-wiring-20260726")

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-va-wiring-20260726",
                                     quiet = TRUE))

csv_path <- "/private/tmp/gllvmtmb-va-wiring-20260726/dev/lbfgsb-default-count-families.csv"
log_path <- "/private/tmp/gllvmtmb-va-wiring-20260726/dev/lbfgsb-default-count-families.log"

cat(sprintf("[%s] starting Fisher count-family sweep\n", Sys.time()),
    file = log_path, append = FALSE)

## ---------------------------------------------------------------------
## Data generator: N units x T traits, q-dimensional latent score, log link.
## Deterministic given `seed`; identical data is reused for both optimiser
## calls within a cell (the fit function's own start is deterministic too).
## ---------------------------------------------------------------------
simulate_count_data <- function(family, N, T, q, seed) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(T))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = T)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  ## Moderate log-scale intercepts (mean counts roughly 1.3-3.7 before latent
  ## perturbation) so both families see a realistic, non-degenerate range.
  beta <- seq(0.3, 1.3, length.out = T)
  Lambda <- matrix(0, T, q)
  lt <- which(row(Lambda) >= col(Lambda))
  Lambda[lt] <- 0.30 * cos(seq_along(lt)) + 0.10 * ((seq_along(lt) %% 3) - 1)
  score <- matrix(rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  if (family == "poisson") {
    y <- rpois(N * T, lambda = exp(eta))
    phi_true <- NA_real_
  } else if (family == "nbinom2") {
    phi_true <- 2
    y <- rnbinom(N * T, size = phi_true, mu = exp(eta))
  } else {
    stop("unsupported family: ", family)
  }
  list(
    y = y, X = stats::model.matrix(~ 0 + trait, long),
    unit_id = unit, trait_id = trait, N = N, T = T, q = q,
    family = family, phi_true = phi_true, eta = eta
  )
}

## ---------------------------------------------------------------------
## Fit one cell with a given optimizer, n_starts = 1L. Returns the raw
## start-1 record plus wall-clock (informational only -- see the .md note
## on why this is NOT a speed claim).
## ---------------------------------------------------------------------
fit_one <- function(dat, optimizer, H = 61L) {
  t0 <- Sys.time()
  fit <- .va_r3_fit(
    y = dat$y, n_trials = rep(1L, length(dat$y)), X = dat$X,
    unit_id = dat$unit_id, trait_id = dat$trait_id, q = dat$q,
    family = dat$family, link = "log",
    n_starts = 1L, optimizer = optimizer, H = H
  )
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  s1 <- fit$starts[[1L]]
  list(fit = fit, start1 = s1, elapsed = elapsed)
}

## ---------------------------------------------------------------------
## Compare a pair of fits (nlminb vs lbfgsb) from identical data.
## ---------------------------------------------------------------------
compare_pair <- function(family, q, N, T, seed, H = 61L) {
  dat <- simulate_count_data(family, N = N, T = T, q = q, seed = seed)

  ## Interleave-ish: run lbfgsb before nlminb on odd seeds, after on even
  ## seeds, so any monotone drift in background CPU load does not
  ## systematically favour one optimizer's wall-clock reading. This does NOT
  ## make single-pass timings trustworthy (no warm-vs-warm control here); it
  ## only avoids a directional bias in the informational elapsed-time column.
  first_is_lbfgsb <- (seed %% 2L == 0L)
  if (first_is_lbfgsb) {
    r_l <- fit_one(dat, "lbfgsb", H = H)
    r_n <- fit_one(dat, "nlminb", H = H)
  } else {
    r_n <- fit_one(dat, "nlminb", H = H)
    r_l <- fit_one(dat, "lbfgsb", H = H)
  }

  s_n <- r_n$start1
  s_l <- r_l$start1

  obj_n <- s_n$objective
  obj_l <- s_l$objective
  obj_delta <- obj_l - obj_n

  par_n <- s_n$par
  par_l <- s_l$par
  names_ok <- !is.null(par_n) && !is.null(par_l) &&
    identical(names(par_n), names(par_l)) && length(par_n) == length(par_l)
  max_dpar <- if (names_ok) max(abs(par_l - par_n)) else NA_real_

  log_phi_max_ddelta <- NA_real_
  if (names_ok && family == "nbinom2") {
    idx <- which(names(par_n) == "log_phi")
    if (length(idx)) {
      log_phi_max_ddelta <- max(abs(par_l[idx] - par_n[idx]))
    }
  }

  agree <- is.finite(obj_delta) && is.finite(max_dpar) &&
    abs(obj_delta) <= 1e-5 && max_dpar <= 1e-2

  list(
    family = family, q = q, N = N, T = T, seed = seed,
    conv_nlminb = s_n$convergence, conv_lbfgsb = s_l$convergence,
    healthy_nlminb = s_n$healthy, healthy_lbfgsb = s_l$healthy,
    objective_nlminb = obj_n, objective_lbfgsb = obj_l,
    objective_delta = obj_delta,
    max_dpar = max_dpar,
    log_phi_max_ddelta = log_phi_max_ddelta,
    names_ok = names_ok,
    agree = agree,
    elapsed_nlminb_s = r_n$elapsed,
    elapsed_lbfgsb_s = r_l$elapsed,
    fit_order_lbfgsb_first = first_is_lbfgsb,
    message_nlminb = s_n$message,
    message_lbfgsb = s_l$message
  )
}

append_csv <- function(row, path) {
  df <- as.data.frame(row[c(
    "family", "q", "N", "T", "seed",
    "conv_nlminb", "conv_lbfgsb", "healthy_nlminb", "healthy_lbfgsb",
    "objective_nlminb", "objective_lbfgsb", "objective_delta",
    "max_dpar", "log_phi_max_ddelta", "names_ok", "agree",
    "elapsed_nlminb_s", "elapsed_lbfgsb_s", "fit_order_lbfgsb_first"
  )], stringsAsFactors = FALSE)
  write.table(df, path, sep = ",", row.names = FALSE,
              col.names = !file.exists(path), append = file.exists(path))
}

## =======================================================================
## SMOKE: one tiny cell end to end before the grid.
## =======================================================================
cat(sprintf("[%s] SMOKE: poisson q=1 N=20 T=8\n", Sys.time()),
    file = log_path, append = TRUE)
smoke <- compare_pair("poisson", q = 1L, N = 20L, T = 8L, seed = 1001L, H = 15L)
cat(sprintf(
  "[%s] SMOKE result: obj_nlminb=%.6f obj_lbfgsb=%.6f delta=%.3g max_dpar=%.3g conv=(%s,%s) agree=%s\n",
  Sys.time(), smoke$objective_nlminb, smoke$objective_lbfgsb,
  smoke$objective_delta, smoke$max_dpar,
  smoke$conv_nlminb, smoke$conv_lbfgsb, smoke$agree
), file = log_path, append = TRUE)
stopifnot(is.finite(smoke$objective_nlminb), is.finite(smoke$objective_lbfgsb))
cat("SMOKE OK -- both optimisers returned finite objectives. Proceeding to grid.\n")
print(smoke[c("objective_nlminb", "objective_lbfgsb", "objective_delta",
              "max_dpar", "conv_nlminb", "conv_lbfgsb", "agree")])

## Smoke cell is NOT part of the graded grid (N=20 is below the requested
## {150, 400}); it is a pipeline check only and is not written to the CSV.

## =======================================================================
## GRID: poisson, nbinom2 x q in {1,2,3} x N in {150,400}, T = 8.
## =======================================================================
grid <- expand.grid(
  family = c("poisson", "nbinom2"),
  q = c(1L, 2L, 3L),
  N = c(150L, 400L),
  stringsAsFactors = FALSE
)
## Deterministic per-cell seed, distinct from the smoke seed.
grid$seed <- 3000L + seq_len(nrow(grid))

results <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  g <- grid[i, ]
  cat(sprintf("[%s] cell %d/%d: family=%s q=%d N=%d T=8 seed=%d\n",
              Sys.time(), i, nrow(grid), g$family, g$q, g$N, g$seed),
      file = log_path, append = TRUE)
  res <- tryCatch(
    compare_pair(g$family, q = g$q, N = g$N, T = 8L, seed = g$seed, H = 61L),
    error = function(e) {
      cat(sprintf("[%s] cell %d ERROR: %s\n", Sys.time(), i, conditionMessage(e)),
          file = log_path, append = TRUE)
      list(family = g$family, q = g$q, N = g$N, T = 8L, seed = g$seed,
           conv_nlminb = NA_integer_, conv_lbfgsb = NA_integer_,
           healthy_nlminb = NA, healthy_lbfgsb = NA,
           objective_nlminb = NA_real_, objective_lbfgsb = NA_real_,
           objective_delta = NA_real_, max_dpar = NA_real_,
           log_phi_max_ddelta = NA_real_, names_ok = NA, agree = NA,
           elapsed_nlminb_s = NA_real_, elapsed_lbfgsb_s = NA_real_,
           fit_order_lbfgsb_first = NA,
           message_nlminb = paste("ERROR:", conditionMessage(e)),
           message_lbfgsb = paste("ERROR:", conditionMessage(e)))
    }
  )
  results[[i]] <- res
  append_csv(res, csv_path)
  cat(sprintf(
    "[%s] cell %d/%d done: delta=%.4g max_dpar=%.4g conv=(%s,%s) agree=%s (%.1fs/%.1fs)\n",
    Sys.time(), i, nrow(grid), res$objective_delta, res$max_dpar,
    res$conv_nlminb, res$conv_lbfgsb, res$agree,
    res$elapsed_nlminb_s, res$elapsed_lbfgsb_s
  ), file = log_path, append = TRUE)
}

cat(sprintf("[%s] grid complete. CSV at %s\n", Sys.time(), csv_path),
    file = log_path, append = TRUE)

saveRDS(results,
        "/private/tmp/gllvmtmb-va-wiring-20260726/dev/lbfgsb-default-count-families.rds")

cat("DONE.\n")
