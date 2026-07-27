## S12 -- the calibration gate.
##
## VA now has standard errors (.va_r3_fixed_information). Nothing may quote
## them until we know whether they cover. This measures that directly:
## simulate with known beta_true, fit, form Wald intervals, count coverage.
##
## Two SE variants are carried side by side, because the difference is the
## whole point:
##   se_conditional -- H_ff alone (the naive optimHess-over-the-fixed-block
##                     route). Ignores variational re-optimisation.
##   se_profile     -- Schur complement, variational block marginalised out.
## If the Schur correction matters, se_profile must cover better.
##
## Also records trace(Sigma_hat)/trace(Sigma_true) per n, to settle whether the
## attenuation seen in dev/three-engine-demo.md genuinely WORSENS with n (0.668
## at n=150 -> 0.536 at n=400 on 5 seeds). Bias growing with n would be a far
## more serious finding than bias per se, so it gets its own column.
##
## Usage:  Rscript dev/va-se-calibration.R [n_seeds] [out_prefix]
## Results are LOCAL (D-50) -- never committed as artifacts, never to CI.

suppressMessages(devtools::load_all(normalizePath("."), quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
N_SEEDS <- if (length(args) >= 1L) as.integer(args[[1]]) else 5L
OUT <- if (length(args) >= 2L) args[[2]] else "dev/va-se-calibration"
N_GRID <- c(150L, 400L)
P_TRAITS <- 8L
Q <- 2L
H <- 15L
Z <- stats::qnorm(0.975)

simulate_cell <- function(n_units, seed) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(P_TRAITS))
  Lambda <- matrix(rnorm(P_TRAITS * Q, sd = 0.7), P_TRAITS, Q)
  beta <- rnorm(P_TRAITS, sd = 0.3)
  Zmat <- matrix(rnorm(n_units * Q), n_units, Q)
  eta <- matrix(beta, n_units, P_TRAITS, byrow = TRUE) + Zmat %*% t(Lambda)
  Y <- matrix(rbinom(n_units * P_TRAITS, 1L, plogis(eta)), n_units, P_TRAITS)
  long <- data.frame(
    unit  = factor(rep(seq_len(n_units), times = P_TRAITS)),
    trait = factor(rep(trait_names, each = n_units), levels = trait_names)
  )
  list(
    y = as.vector(Y), n_trials = rep(1L, n_units * P_TRAITS),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit), trait_id = as.integer(long$trait),
    beta_true = beta, Sigma_true = Lambda %*% t(Lambda), q = Q
  )
}

run_one <- function(n_units, seed, eval_method) {
  sim <- simulate_cell(n_units, seed)
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    .va_r3_fit(
      y = sim$y, n_trials = sim$n_trials, X = sim$X,
      unit_id = sim$unit_id, trait_id = sim$trait_id, q = sim$q,
      family = "binomial", link = "logit", H = H, silent = TRUE,
      eval_method = eval_method
    ),
    error = function(e) structure(list(msg = conditionMessage(e)),
                                  class = "cell_error")
  )
  t_point <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "cell_error") || is.null(fit$best)) {
    return(data.frame(n = n_units, seed = seed, eval_method = eval_method,
                      status = "FIT_ERROR", stringsAsFactors = FALSE))
  }

  t1 <- proc.time()[["elapsed"]]
  info <- .va_r3_fixed_information(fit$objective, fit$best$par)
  t_se <- proc.time()[["elapsed"]] - t1

  nm <- names(fit$best$par)
  beta_hat <- unname(fit$best$par[nm == "beta"])
  pick <- function(se) if (is.null(se)) NULL else unname(se[names(se) == "beta"])
  se_c <- pick(info$se_conditional)
  se_p <- pick(info$se_profile)

  cover <- function(se) {
    if (is.null(se) || length(se) != length(sim$beta_true)) return(NA_real_)
    mean(abs(beta_hat - sim$beta_true) <= Z * se)
  }

  ## Attenuation of Sigma_B from the reported loadings.
  rep_best <- fit$report
  atten <- NA_real_
  if (is.list(rep_best) && !is.null(rep_best$Lambda)) {
    L <- matrix(rep_best$Lambda, nrow = P_TRAITS)
    atten <- sum(diag(L %*% t(L))) / sum(diag(sim$Sigma_true))
  }

  data.frame(
    n = n_units, seed = seed, eval_method = eval_method,
    status = fit$status %||% NA_character_,
    info_status = info$status, pd_hessian = info$pd_hessian,
    cover_conditional = cover(se_c),
    cover_profile = cover(se_p),
    mean_se_conditional = if (is.null(se_c)) NA_real_ else mean(se_c),
    mean_se_profile = if (is.null(se_p)) NA_real_ else mean(se_p),
    attenuation = atten,
    secs_point = t_point, secs_se = t_se,
    secs_inference = t_point + t_se,
    stringsAsFactors = FALSE
  )
}

## ---- SMOKE: one tiny cell must produce non-NA coverage before scaling ------
smoke <- run_one(80L, 1L, "auto")
if (!nrow(smoke) || identical(smoke$status[[1]], "FIT_ERROR") ||
    is.na(smoke$cover_profile[[1]])) {
  cat("SMOKE FAILED -- aborting before the grid.\n")
  print(smoke)
  quit(status = 1L)
}
cat(sprintf("smoke ok: cover_profile=%.3f  pd=%s  info=%s\n",
            smoke$cover_profile[[1]], smoke$pd_hessian[[1]],
            smoke$info_status[[1]]))

## ---- GRID -----------------------------------------------------------------
rows <- list()
for (n_units in N_GRID) {
  for (seed in seq_len(N_SEEDS)) {
    for (em in c("auto", "gh")) {           # auto == JJ for binomial
      r <- run_one(n_units, 1000L + seed, em)
      rows[[length(rows) + 1L]] <- r
      ## Write incrementally -- a long run must never lose everything.
      utils::write.csv(do.call(rbind, lapply(rows, function(x) {
        x[, intersect(names(rows[[1]]), names(x)), drop = FALSE]
      })), paste0(OUT, "-raw.csv"), row.names = FALSE)
    }
  }
  cat(sprintf("n=%d done\n", n_units))
}

raw <- do.call(rbind, lapply(rows, function(x) {
  x[, intersect(names(rows[[1]]), names(x)), drop = FALSE]
}))

ok <- raw[!is.na(raw$cover_profile), ]
if (nrow(ok)) {
  agg <- aggregate(
    cbind(cover_conditional, cover_profile, attenuation,
          secs_point, secs_se, secs_inference) ~ n + eval_method,
    data = ok, FUN = mean
  )
  agg$mcse <- sqrt(0.95 * 0.05 / (nrow(ok) / nrow(agg) * P_TRAITS))
  utils::write.csv(agg, paste0(OUT, "-summary.csv"), row.names = FALSE)
  cat("\n=== coverage of nominal 95% Wald intervals for beta ===\n")
  print(agg, row.names = FALSE)
} else {
  cat("no usable cells\n")
}
cat("\nwrote:", paste0(OUT, "-raw.csv"), "and", paste0(OUT, "-summary.csv"), "\n")
