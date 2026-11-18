# Native all-family predictor-informed LV route-health canary.
# Families 0:15 are fitted together; multinomial (16) is exercised by the
# separate five-family canary because its grouped softmax route cannot share
# the row-level trial weights needed by binomial/betabinomial in one fit.

source(file.path("dev", "mixed-lv-family-wide", "01-run.R"), local = TRUE)

make_all_family_lv_data <- function(seed = 20260827L, n_units = 20L, d = 2L) {
  stopifnot(n_units >= 20L, d %in% 1:3)
  set.seed(seed)
  fids <- 0:15
  labels <- sprintf("f%02d", fids)
  x <- as.numeric(scale(seq(-1, 1, length.out = n_units)))
  innovation <- matrix(stats::rnorm(n_units * d), n_units, d)
  alpha <- c(0.55, -0.3, 0.2)[seq_len(d)]
  scores <- outer(x, alpha) + innovation
  loadings <- vapply(seq_along(fids), function(j) {
    c(0.75 * cos(j * 0.43), 0.65 * sin(j * 0.37), 0.4 * cos(j * 0.29))[
      seq_len(d)
    ]
  }, numeric(d))
  loadings <- t(loadings)
  eta <- scores %*% t(loadings)

  response <- vector("list", length(fids))
  for (j in seq_along(fids)) {
    fid <- fids[[j]]
    intercept <- mixed_lv_intercepts(fid, 0L)[[1L]]
    response[[j]] <- mixed_lv_draw_scalar(fid, 0L, intercept + eta[, j])
  }

  data <- do.call(rbind, lapply(seq_len(n_units), function(i) {
    data.frame(
      unit = sprintf("u%03d", i),
      trait = labels,
      family = labels,
      x = x[[i]],
      value = vapply(response, `[[`, numeric(1L), i),
      weight = ifelse(fids %in% c(1L, 8L), 20L, 1L),
      stringsAsFactors = FALSE
    )
  }))
  data$unit <- factor(data$unit, levels = sprintf("u%03d", seq_len(n_units)))
  data$trait <- factor(data$trait, levels = labels)
  data$family <- factor(data$family, levels = labels)
  families <- setNames(lapply(fids, mixed_lv_family, lid = 0L), labels)
  attr(families, "family_var") <- "family"
  list(data = data, families = families, fids = fids)
}

fit_all_family_lv_canary <- function(
    seed = 20260827L, n_units = 20L, d = 2L) {
  fixture <- make_all_family_lv_data(seed = seed, n_units = n_units, d = d)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = d, unique = FALSE, lv = ~x),
    data = fixture$data,
    family = fixture$families,
    weights = fixture$data$weight,
    unit = "unit",
    trait = "trait",
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  observed_fids <- sort(unique(as.integer(fit$tmb_data$family_id_vec)))
  checks <- c(
    convergence = identical(fit$opt$convergence, 0L),
    every_family_0_15 = identical(observed_fids, 0:15),
    finite_objective = is.finite(fit$opt$objective),
    finite_gradient = all(is.finite(fit$tmb_obj$gr(fit$opt$par))),
    finite_B_lv = all(is.finite(fit$report$B_lv_unit)),
    two_continuous_scales = length(fit$report$sigma_eps) == 2L &&
      all(is.finite(fit$report$sigma_eps)) &&
      all(fit$report$sigma_eps > 0)
  )
  list(fit = fit, checks = checks, observed_fids = observed_fids)
}

if (identical(commandArgs(trailingOnly = TRUE), "--run")) {
  result <- fit_all_family_lv_canary()
  print(result$checks)
  print(result$fit$opt[c("convergence", "message", "objective")])
  print(max(abs(result$fit$tmb_obj$gr(result$fit$opt$par))))
  if (!all(result$checks)) stop("All-family LV canary failed.")
}
