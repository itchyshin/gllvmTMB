## Arc0b masked-cell accuracy probe: binomial, ordinal_probit, delta_lognormal,
## multinomial. Follow-up to Arc0 (gaussian/poisson).
##
## Uses devtools::load_all() in THIS worktree, NOT the installed package --
## the multinomial NA-response admission exists only in worktree source
## (confirmed by direct smoke test: installed 0.6.0 errors
## "missing categorical responses are not supported in this release").
## See dev/missing-accuracy/RESULTS.md Arc0b provenance note.
##
## Run from the repo root:
##   cd /private/tmp/gllvmtmb-missing-all-families && Rscript dev/missing-accuracy-arc0b-recovery.R
##
## Writes dev/missing-accuracy/arc0b-cells.csv. Design/results/session info
## live in dev/missing-accuracy/RESULTS.md (Arc0b Design section was written
## BEFORE this driver ran; this script appends the results table).

repo_root <- normalizePath(".")
dgp_path <- file.path(repo_root, "dev", "missing-accuracy-dgp.R")
if (!file.exists(dgp_path)) {
  stop("Run this script with CWD = repo root (dev/missing-accuracy-dgp.R not found at ", dgp_path, ")")
}
source(dgp_path) # reuse make_mask() / apply_mask() / mask_cells()

suppressMessages(devtools::load_all(repo_root, quiet = TRUE))
stopifnot(exists("predict_missing"), exists("gllvmTMB"), exists("miss_control"))
stopifnot(exists(".cv_auc", where = asNamespace("gllvmTMB")))
stopifnot(exists("extract_cutpoints", where = asNamespace("gllvmTMB")))

out_dir <- file.path(repo_root, "dev", "missing-accuracy")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
csv_path <- file.path(out_dir, "arc0b-cells.csv")
results_md_path <- file.path(out_dir, "RESULTS.md")

family_order <- c("binomial", "ordinal_probit", "delta_lognormal", "multinomial")
mech_order <- c("mcar20", "unit_clustered")
n_reps <- 10L
budget_secs <- 40 * 60

csv_cols <- c("seed", "family", "mechanism", "rate", "n_masked", "converged",
              "metric1_name", "metric1", "metric1_baseline",
              "metric2_name", "metric2", "metric2_baseline", "elapsed_s")

## ---- family-specific DGPs ----------------------------------------------

simulate_binomial_wide <- function(n_units, p_traits, seed, q_true = 1L) {
  set.seed(seed)
  trait_names <- paste0("t", seq_len(p_traits))
  unit_names <- paste0("u", seq_len(n_units))
  Lambda <- matrix(stats::rnorm(p_traits * q_true, sd = 0.7), p_traits, q_true)
  U <- matrix(stats::rnorm(n_units * q_true), n_units, q_true)
  b0 <- stats::rnorm(p_traits, sd = 0.5)
  eta <- outer(rep(1, n_units), b0) + U %*% t(Lambda)
  p <- stats::plogis(eta)
  Y <- matrix(as.double(stats::rbinom(n_units * p_traits, 1L, as.vector(p))), n_units, p_traits)
  wide <- as.data.frame(Y); names(wide) <- trait_names
  wide$unit <- factor(unit_names, levels = unit_names)
  wide <- wide[, c("unit", trait_names)]
  list(wide = wide, trait_names = trait_names)
}

simulate_ordinal_wide <- function(n_units, p_traits, seed,
                                   taus = c(0, 0.6, 1.3), sigma_b = 0.5) {
  set.seed(seed)
  trait_names <- paste0("t", seq_len(p_traits))
  unit_names <- paste0("u", seq_len(n_units))
  b0 <- stats::rnorm(p_traits, sd = 0.3)
  u <- matrix(stats::rnorm(n_units * p_traits, sd = sigma_b), n_units, p_traits)
  ystar <- outer(rep(1, n_units), b0) + u + matrix(stats::rnorm(n_units * p_traits), n_units, p_traits)
  Y <- matrix(1, n_units, p_traits)
  for (k in seq_along(taus)) Y <- Y + (ystar > taus[k])
  Y <- matrix(as.double(Y), n_units, p_traits)
  wide <- as.data.frame(Y); names(wide) <- trait_names
  wide$unit <- factor(unit_names, levels = unit_names)
  wide <- wide[, c("unit", trait_names)]
  list(wide = wide, trait_names = trait_names, K = length(taus) + 1L)
}

simulate_delta_wide <- function(n_units, p_traits, seed, sigma_true = 0.6) {
  set.seed(seed)
  trait_names <- paste0("t", seq_len(p_traits))
  unit_names <- paste0("u", seq_len(n_units))
  mu_t <- seq(0.3, 2.0, length.out = p_traits)
  Y <- matrix(NA_real_, n_units, p_traits)
  for (j in seq_len(p_traits)) {
    p_j <- stats::plogis(mu_t[j])
    pres <- stats::rbinom(n_units, 1L, p_j)
    pos <- stats::rlnorm(n_units, meanlog = mu_t[j], sdlog = sigma_true)
    Y[, j] <- pres * pos
  }
  wide <- as.data.frame(Y); names(wide) <- trait_names
  wide$unit <- factor(unit_names, levels = unit_names)
  wide <- wide[, c("unit", trait_names)]
  list(wide = wide, trait_names = trait_names, mu_true = mu_t)
}

## Copied verbatim from tests/testthat/test-multinomial-missing-response.R's
## .make_multinomial_missing().
simulate_multinomial_long <- function(n, K, seed) {
  set.seed(seed)
  x <- stats::rnorm(n)
  b0 <- c(0.5, -0.4)[seq_len(K - 1L)]
  b1 <- c(1.0, -0.8)[seq_len(K - 1L)]
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P <- exp(eta - apply(eta, 1L, max)); P <- P / rowSums(P)
  y <- vapply(seq_len(n), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
             value = factor(y, levels = seq_len(K)), x = x)
}

## ---- metric helpers ------------------------------------------------------

## eta_k: contrasts for categories 2..K (category 1's contrast fixed at 0).
.softmax_from_contrasts <- function(eta_k) {
  eta_full <- c(0, eta_k)
  ex <- exp(eta_full - max(eta_full))
  ex / sum(ex)
}

.empty_row <- function(family, mechanism, seed, rate, n_masked, elapsed,
                        m1_name, m2_name) {
  data.frame(seed = seed, family = family, mechanism = mechanism, rate = rate,
             n_masked = n_masked, converged = FALSE,
             metric1_name = m1_name, metric1 = NA_real_, metric1_baseline = NA_real_,
             metric2_name = m2_name, metric2 = NA_real_, metric2_baseline = NA_real_,
             elapsed_s = elapsed, stringsAsFactors = FALSE)
}

## ---- per-family fit runners ----------------------------------------------

run_one_fit_binomial <- function(mechanism, seed) {
  n_units <- 60L; p_traits <- 8L
  t0 <- Sys.time()
  sim <- simulate_binomial_wide(n_units, p_traits, seed = seed)
  wide <- sim$wide; trait_names <- sim$trait_names
  mask <- make_mask(mechanism, n_units, p_traits, seed = seed)
  wide_masked <- apply_mask(wide, trait_names, mask)
  designed <- mask_cells(mask, trait_names)
  n_masked <- nrow(designed)
  rate <- n_masked / (n_units * p_traits)

  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "),
    ") ~ 1 + latent(1 | unit, d = 1, unique = FALSE)"
  ))
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      form, data = wide_masked, unit = "unit", family = binomial(),
      missing = miss_control(response = "include"),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    return(list(row = .empty_row("binomial", mechanism, seed, rate, n_masked, elapsed, "AUC", "Brier"),
                error = conditionMessage(fit)))
  }
  conv <- tryCatch(identical(fit$opt$convergence, 0L) && is.finite(as.numeric(stats::logLik(fit))), error = function(e) FALSE)
  pm <- predict_missing(fit, type = "response")
  stopifnot("predict_missing() row count != designed mask size" = nrow(pm) == n_masked)
  stopifnot("predict_missing() cell identity != designed mask cells" =
              setequal(paste(pm$original_row, pm$trait), paste(designed$original_row, designed$trait)))
  pm$truth <- mapply(function(r, tr) wide[[tr]][r], pm$original_row, as.character(pm$trait))
  prevalence <- vapply(trait_names, function(tr) mean(wide_masked[[tr]], na.rm = TRUE), numeric(1L))
  pm$baseline <- prevalence[as.character(pm$trait)]

  metric1 <- metric1_b <- metric2 <- metric2_b <- NA_real_
  if (conv) {
    metric1 <- gllvmTMB:::.cv_auc(pm$truth, pm$est)
    metric1_b <- gllvmTMB:::.cv_auc(pm$truth, pm$baseline)
    metric2 <- mean((pm$est - pm$truth)^2)
    metric2_b <- mean((pm$baseline - pm$truth)^2)
  }
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row <- data.frame(seed = seed, family = "binomial", mechanism = mechanism, rate = rate,
                     n_masked = n_masked, converged = conv,
                     metric1_name = "AUC", metric1 = metric1, metric1_baseline = metric1_b,
                     metric2_name = "Brier", metric2 = metric2, metric2_baseline = metric2_b,
                     elapsed_s = elapsed, stringsAsFactors = FALSE)
  list(row = row, error = NULL)
}

run_one_fit_ordinal <- function(mechanism, seed) {
  n_units <- 60L; p_traits <- 6L
  t0 <- Sys.time()
  sim <- simulate_ordinal_wide(n_units, p_traits, seed = seed)
  wide <- sim$wide; trait_names <- sim$trait_names
  mask <- make_mask(mechanism, n_units, p_traits, seed = seed)
  wide_masked <- apply_mask(wide, trait_names, mask)
  designed <- mask_cells(mask, trait_names)
  n_masked <- nrow(designed)
  rate <- n_masked / (n_units * p_traits)

  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1 + unique(1 | unit)"
  ))
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      form, data = wide_masked, unit = "unit", family = ordinal_probit(),
      missing = miss_control(response = "include"),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    return(list(row = .empty_row("ordinal_probit", mechanism, seed, rate, n_masked, elapsed, "Spearman_rho", "modal_accuracy"),
                error = conditionMessage(fit)))
  }
  conv <- tryCatch(identical(fit$opt$convergence, 0L) && is.finite(as.numeric(stats::logLik(fit))), error = function(e) FALSE)

  ## Honest metric choice (documented in RESULTS.md): type = "response" for
  ## ordinal_probit applies pnorm(eta) elementwise -- not a real category
  ## probability for K > 2. Use type = "link" (eta) + extract_cutpoints().
  pm <- predict_missing(fit, type = "link")
  stopifnot("predict_missing() row count != designed mask size" = nrow(pm) == n_masked)
  stopifnot("predict_missing() cell identity != designed mask cells" =
              setequal(paste(pm$original_row, pm$trait), paste(designed$original_row, designed$trait)))
  pm$truth <- mapply(function(r, tr) wide[[tr]][r], pm$original_row, as.character(pm$trait))

  metric1 <- metric2 <- metric2_b <- NA_real_
  if (conv) {
    cuts <- tryCatch(extract_cutpoints(fit, quiet = TRUE), error = function(e) NULL)
    modal_baseline <- vapply(trait_names, function(tr) {
      obs <- wide_masked[[tr]][!is.na(wide_masked[[tr]])]
      as.numeric(names(sort(table(obs), decreasing = TRUE))[1L])
    }, numeric(1L))

    pred_cat <- rep(NA_real_, nrow(pm))
    if (!is.null(cuts) && nrow(cuts) > 0L) {
      for (i in seq_len(nrow(pm))) {
        tr <- as.character(pm$trait[i])
        sub_cuts <- cuts[cuts$trait == tr, , drop = FALSE]
        sub_cuts <- sub_cuts[order(sub_cuts$cutpoint_index), ]
        tau_full <- c(0, sub_cuts$tau_estimate) # tau_1 fixed at 0
        bnds <- c(-Inf, tau_full, Inf)
        probs <- diff(stats::pnorm(bnds - pm$est[i]))
        pred_cat[i] <- which.max(probs)
      }
    }
    metric1 <- suppressWarnings(stats::cor(pm$truth, pm$est, method = "spearman"))
    if (!any(is.na(pred_cat))) metric2 <- mean(pred_cat == pm$truth)
    baseline_cat <- modal_baseline[as.character(pm$trait)]
    metric2_b <- mean(baseline_cat == pm$truth)
  }
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row <- data.frame(seed = seed, family = "ordinal_probit", mechanism = mechanism, rate = rate,
                     n_masked = n_masked, converged = conv,
                     metric1_name = "Spearman_rho", metric1 = metric1, metric1_baseline = NA_real_,
                     metric2_name = "modal_accuracy", metric2 = metric2, metric2_baseline = metric2_b,
                     elapsed_s = elapsed, stringsAsFactors = FALSE)
  list(row = row, error = NULL)
}

run_one_fit_delta <- function(mechanism, seed) {
  n_units <- 100L; p_traits <- 6L
  t0 <- Sys.time()
  sim <- simulate_delta_wide(n_units, p_traits, seed = seed)
  wide <- sim$wide; trait_names <- sim$trait_names
  ## n_cluster_units widened from the 10-unit Arc0 default: delta's n_units
  ## (100) is larger than binomial's/ordinal's (60) while p_traits (6) is the
  ## same, so a fixed 10-unit block at this n_mask concentrates masked cells
  ## far more densely (60% of the block) than intended, tripping the
  ## per-unit observed-cell guard. 20 units keeps the block density
  ## comparable to the other Arc0b families (~30%) -- discovered live: the
  ## first driver run errored here with "could not satisfy guards after 200
  ## attempts" for delta_lognormal/unit_clustered, fixed before the reported
  ## run below.
  mask <- make_mask(mechanism, n_units, p_traits, seed = seed, n_cluster_units = 20L)
  wide_masked <- apply_mask(wide, trait_names, mask)
  designed <- mask_cells(mask, trait_names)
  n_masked <- nrow(designed)
  rate <- n_masked / (n_units * p_traits)

  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1"
  ))
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      form, data = wide_masked, unit = "unit", family = delta_lognormal(),
      missing = miss_control(response = "include"),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    return(list(row = .empty_row("delta_lognormal", mechanism, seed, rate, n_masked, elapsed, "RMSE", "occurrence_AUC"),
                error = conditionMessage(fit)))
  }
  conv <- tryCatch(identical(fit$opt$convergence, 0L) && is.finite(as.numeric(stats::logLik(fit))), error = function(e) FALSE)
  pm_resp <- predict_missing(fit, type = "response")
  pm_link <- predict_missing(fit, type = "link")
  stopifnot("predict_missing() row count != designed mask size" = nrow(pm_resp) == n_masked)
  stopifnot("predict_missing() cell identity != designed mask cells" =
              setequal(paste(pm_resp$original_row, pm_resp$trait), paste(designed$original_row, designed$trait)))
  pm_resp$truth <- mapply(function(r, tr) wide[[tr]][r], pm_resp$original_row, as.character(pm_resp$trait))
  pm_resp$eta <- pm_link$est[match(
    paste(pm_resp$original_row, pm_resp$trait), paste(pm_link$original_row, pm_link$trait)
  )]

  meanfill <- vapply(trait_names, function(tr) mean(wide_masked[[tr]], na.rm = TRUE), numeric(1L))
  pm_resp$baseline_mean <- meanfill[as.character(pm_resp$trait)]
  prevalence <- vapply(trait_names, function(tr) mean(wide_masked[[tr]] > 0, na.rm = TRUE), numeric(1L))
  pm_resp$baseline_prev <- prevalence[as.character(pm_resp$trait)]

  metric1 <- metric1_b <- metric2 <- metric2_b <- NA_real_
  if (conv) {
    metric1 <- sqrt(mean((pm_resp$truth - pm_resp$est)^2))
    metric1_b <- sqrt(mean((pm_resp$truth - pm_resp$baseline_mean)^2))
    occ_truth <- as.numeric(pm_resp$truth > 0)
    p_hat <- stats::plogis(pm_resp$eta)
    metric2 <- gllvmTMB:::.cv_auc(occ_truth, p_hat)
    metric2_b <- gllvmTMB:::.cv_auc(occ_truth, pm_resp$baseline_prev)
  }
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row <- data.frame(seed = seed, family = "delta_lognormal", mechanism = mechanism, rate = rate,
                     n_masked = n_masked, converged = conv,
                     metric1_name = "RMSE", metric1 = metric1, metric1_baseline = metric1_b,
                     metric2_name = "occurrence_AUC", metric2 = metric2, metric2_baseline = metric2_b,
                     elapsed_s = elapsed, stringsAsFactors = FALSE)
  list(row = row, error = NULL)
}

run_one_fit_multinomial <- function(mechanism, seed) {
  n_units <- 250L; K <- 3L
  t0 <- Sys.time()
  df <- simulate_multinomial_long(n = n_units, K = K, seed = seed)
  mask <- make_mask(mechanism, n_units, p_traits = 1L, seed = seed,
                     min_obs_trait = 5L, min_obs_unit = 0L, n_cluster_units = 25L)
  masked_rows <- which(mask[, 1L])
  n_masked_units <- length(masked_rows)
  rate <- n_masked_units / n_units

  df_na <- df
  df_na$value[masked_rows] <- NA

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + (0 + trait):x, data = df_na,
      trait = "trait", unit = "unit", family = multinomial(),
      missing = miss_control(response = "include"), silent = TRUE
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    return(list(row = .empty_row("multinomial", mechanism, seed, rate, n_masked_units, elapsed, "modal_accuracy", "multiclass_Brier"),
                error = conditionMessage(fit)))
  }
  conv <- tryCatch(identical(fit$opt$convergence, 0L) && is.finite(as.numeric(stats::logLik(fit))), error = function(e) FALSE)
  pm <- predict_missing(fit, type = "link")

  ## FINDING (see RESULTS.md): original_row falls back to model_row for
  ## multinomial. Join by `unit` (verified reliable) + category parsed from
  ## the `trait` label suffix, not by original_row.
  stopifnot("predict_missing() row count != n_masked_units * (K-1)" =
              nrow(pm) == n_masked_units * (K - 1L))
  masked_unit_ids <- as.character(df$unit[masked_rows])
  stopifnot("predict_missing() unit set != designed masked units" =
              setequal(unique(as.character(pm$unit)), masked_unit_ids))

  pm$category <- as.integer(sub("^.*:", "", as.character(pm$trait)))

  metric1 <- metric1_b <- metric2 <- metric2_b <- NA_real_
  if (conv) {
    by_unit <- split(seq_len(nrow(pm)), as.character(pm$unit))
    obs_freq <- as.numeric(table(factor(df_na$value[!is.na(df_na$value)], levels = seq_len(K)))) /
      sum(!is.na(df_na$value))
    baseline_cat <- which.max(obs_freq)

    n_u <- length(by_unit)
    truth_cat <- integer(n_u); pred_cat <- integer(n_u)
    brier_model <- numeric(n_u); brier_base <- numeric(n_u)
    for (i in seq_len(n_u)) {
      rows <- by_unit[[i]]
      u_id <- names(by_unit)[i]
      eta_k <- rep(NA_real_, K - 1L)
      for (r in rows) eta_k[pm$category[r] - 1L] <- pm$est[r]
      p_hat <- .softmax_from_contrasts(eta_k)
      orig_row <- which(as.character(df$unit) == u_id)
      truth_cat[i] <- as.integer(as.character(df$value[orig_row]))
      pred_cat[i] <- which.max(p_hat)
      onehot <- rep(0, K); onehot[truth_cat[i]] <- 1
      brier_model[i] <- sum((p_hat - onehot)^2)
      brier_base[i] <- sum((obs_freq - onehot)^2)
    }
    metric1 <- mean(pred_cat == truth_cat)
    metric1_b <- mean(baseline_cat == truth_cat)
    metric2 <- mean(brier_model)
    metric2_b <- mean(brier_base)
  }
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row <- data.frame(seed = seed, family = "multinomial", mechanism = mechanism, rate = rate,
                     n_masked = n_masked_units, converged = conv,
                     metric1_name = "modal_accuracy", metric1 = metric1, metric1_baseline = metric1_b,
                     metric2_name = "multiclass_Brier", metric2 = metric2, metric2_baseline = metric2_b,
                     elapsed_s = elapsed, stringsAsFactors = FALSE)
  list(row = row, error = NULL)
}

run_dispatch <- function(family_name, mechanism, seed) {
  switch(family_name,
         binomial = run_one_fit_binomial(mechanism, seed),
         ordinal_probit = run_one_fit_ordinal(mechanism, seed),
         delta_lognormal = run_one_fit_delta(mechanism, seed),
         multinomial = run_one_fit_multinomial(mechanism, seed))
}

append_row_csv <- function(path, row_df) {
  utils::write.table(row_df[, csv_cols], path, sep = ",", row.names = FALSE,
                      col.names = !file.exists(path), append = file.exists(path))
}

## ---- Phase 0: sanity pre-run (one fit per family, mcar20 rep1) -----------

cat("=== Phase 0: sanity pre-run (one mcar20 fit per family) ===\n")
if (file.exists(csv_path)) file.remove(csv_path)
sanity_cache <- list()
sanity_ok <- TRUE
sanity_msgs <- character(0)
for (fam in family_order) {
  fam_idx <- match(fam, family_order)
  seed <- 1000L * fam_idx + 100L * 1L + 1L
  t0 <- Sys.time()
  res <- run_dispatch(fam, "mcar20", seed)
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("%-16s mcar20 seed=%d converged=%-5s n_masked=%d elapsed=%.2fs\n",
              fam, seed, res$row$converged, res$row$n_masked, dt))
  if (dt >= 120) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, sprintf("%s sanity fit took %.1fs (>=120s)", fam, dt)) }
  if (!isTRUE(res$row$converged)) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, sprintf("%s sanity fit did not converge (error: %s)", fam, res$error %||% "none")) }
  sanity_cache[[as.character(seed)]] <- res
  append_row_csv(csv_path, res$row)
}
if (!sanity_ok) {
  cat("=== STOP: sanity pre-run failed ===\n")
  cat(paste(sanity_msgs, collapse = "\n"), "\n")
  stop("Aborting: sanity pre-run failed.")
}
cat("Sanity pre-run PASSED.\n")

run_or_cached <- function(family_name, mechanism, seed) {
  key <- as.character(seed)
  if (!is.null(sanity_cache[[key]])) return(sanity_cache[[key]])
  run_dispatch(family_name, mechanism, seed)
}

## ---- Phase 1: full grid (D-139 wall-time stop rule) -----------------------

cat("\n=== Phase 1: full grid ===\n")
t_grid_start <- Sys.time()
stop_info <- list(fired = FALSE, rule = NA_character_, detail = NA_character_)
attempted <- length(sanity_cache)
converged_n <- sum(vapply(sanity_cache, function(r) isTRUE(r$row$converged), logical(1L)))

for (family_name in family_order) {
  fam_idx <- match(family_name, family_order)
  if (stop_info$fired) break
  for (mechanism in mech_order) {
    mech_idx <- match(mechanism, mech_order)
    if (stop_info$fired) break
    for (rep in seq_len(n_reps)) {
      seed <- 1000L * fam_idx + 100L * mech_idx + rep
      elapsed_total <- as.numeric(difftime(Sys.time(), t_grid_start, units = "secs"))
      if (elapsed_total > budget_secs) {
        stop_info$fired <- TRUE
        stop_info$rule <- "D-139 wall-time (>40 min)"
        stop_info$detail <- sprintf("grid elapsed %.1f min before seed %d (%s/%s rep=%d)",
                                     elapsed_total / 60, seed, family_name, mechanism, rep)
        break
      }
      already <- !is.null(sanity_cache[[as.character(seed)]])
      res <- run_or_cached(family_name, mechanism, seed)
      if (!already) {
        append_row_csv(csv_path, res$row)
        attempted <- attempted + 1L
        if (isTRUE(res$row$converged)) converged_n <- converged_n + 1L
      }
      cat(sprintf("  fit %-16s %-14s seed=%d converged=%-5s %s=%s elapsed=%.2fs\n",
                  family_name, mechanism, seed, res$row$converged, res$row$metric1_name,
                  ifelse(is.na(res$row$metric1), "NA", sprintf("%.3f", res$row$metric1)),
                  res$row$elapsed_s))
    }
  }
}

grid_elapsed_s <- as.numeric(difftime(Sys.time(), t_grid_start, units = "secs"))

if (stop_info$fired) {
  cat("\n=== STOP RULE FIRED:", stop_info$rule, "===\n")
  cat(stop_info$detail, "\n")
} else {
  cat("\n=== Full Arc0b grid completed, no stop rule fired ===\n")
}
cat(sprintf("Fits attempted (unique): %d, converged: %d\n", attempted, converged_n))
cat(sprintf("Grid wall time: %.1f min\n", grid_elapsed_s / 60))

## ---- Reproducibility check: binomial mcar20 rep1 (seed 1101) -------------

cat("\n=== Reproducibility check (re-run seed 1101, binomial/mcar20) ===\n")
seed_repro <- 1101L
res_a <- sanity_cache[[as.character(seed_repro)]]
res_b <- run_dispatch("binomial", "mcar20", seed_repro)
repro_cols <- c("n_masked", "converged", "metric1", "metric1_baseline", "metric2", "metric2_baseline")
repro_ok <- isTRUE(all.equal(res_a$row[, repro_cols], res_b$row[, repro_cols], tolerance = 1e-8))
cat("Reproducibility check (seed 1101):", if (repro_ok) "PASS" else "FAIL", "\n")
if (!repro_ok) {
  cat("Original:\n"); print(res_a$row[, repro_cols])
  cat("Repeat:\n"); print(res_b$row[, repro_cols])
}

## ---- Build summary table, append to RESULTS.md ---------------------------

all_df <- utils::read.csv(csv_path, stringsAsFactors = FALSE)

summarize_cell <- function(df, family_name, mechanism) {
  sub <- df[df$family == family_name & df$mechanism == mechanism, , drop = FALSE]
  conv <- sub[sub$converged, , drop = FALSE]
  mc_se <- function(x) { x <- x[is.finite(x)]; if (length(x) < 2L) return(NA_real_); stats::sd(x) / sqrt(length(x)) }
  data.frame(
    family = family_name, mechanism = mechanism,
    n_attempt = nrow(sub), n_converged = nrow(conv),
    metric1_name = sub$metric1_name[1L],
    mean_metric1 = mean(conv$metric1, na.rm = TRUE), se_metric1 = mc_se(conv$metric1),
    mean_metric1_baseline = mean(conv$metric1_baseline, na.rm = TRUE),
    metric2_name = sub$metric2_name[1L],
    mean_metric2 = mean(conv$metric2, na.rm = TRUE), se_metric2 = mc_se(conv$metric2),
    mean_metric2_baseline = mean(conv$metric2_baseline, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summary_rows <- list()
for (fam in family_order) for (mech in mech_order) {
  if (any(all_df$family == fam & all_df$mechanism == mech)) {
    summary_rows[[length(summary_rows) + 1L]] <- summarize_cell(all_df, fam, mech)
  }
}
summary_df <- do.call(rbind, summary_rows)

fmt <- function(x, d = 3) ifelse(is.na(x), "NA", sprintf(paste0("%.", d, "f"), x))

lines <- c(
  "", "## Arc0b results", "",
  sprintf("Fits attempted (unique): %d. Converged: %d.", attempted, converged_n),
  sprintf("Grid wall time: %.1f min.", grid_elapsed_s / 60),
  sprintf("Stop rule fired: %s%s", if (stop_info$fired) stop_info$rule else "none",
          if (stop_info$fired) paste0(" -- ", stop_info$detail) else ""),
  sprintf("Reproducibility check (seed %d): %s", seed_repro, if (repro_ok) "PASS" else "FAIL"),
  "",
  "### Per-cell summary (converged fits only)",
  "",
  "| family | mechanism | n_attempt | n_converged | metric1 | mean | baseline | metric2 | mean | baseline |",
  "|---|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(summary_df))) {
  r <- summary_df[i, ]
  lines <- c(lines, sprintf(
    "| %s | %s | %d | %d | %s | %s (se %s) | %s | %s | %s | %s |",
    r$family, r$mechanism, r$n_attempt, r$n_converged,
    r$metric1_name, fmt(r$mean_metric1), fmt(r$se_metric1), fmt(r$mean_metric1_baseline),
    r$metric2_name, fmt(r$mean_metric2), fmt(r$mean_metric2_baseline)
  ))
}

lines <- c(lines, "")
cat(paste(lines, collapse = "\n"), file = results_md_path, append = TRUE)
cat("\nWrote:", results_md_path, "\n")
cat("Wrote:", csv_path, "\n")
