## Design 73 ordinary Gaussian predictor-informed latent scores.
##
## Symbolic alignment:
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth value |
## | --- | --- | --- | --- | --- |
## | z_i = x_i alpha + e_i | latent(..., lv = ~ x) | e_i ~ N(0,1), x_i fixed | extract_ordination(component = "mean" / "innovation") | alpha and e_i enter only through z_i |
## | B_lv = Lambda alpha' | latent(..., lv = ~ x) | Lambda fixed, alpha fixed | extract_lv_effects(type = "trait_effect") | Lambda %*% t(alpha) |
## | Sigma_unit = Lambda Lambda' + Psi | latent(..., lv = ~ x) | q_it ~ N(0, psi_t^2) | extract_Sigma(level = "unit", part = "total") | Lambda Lambda' + diag(psi^2) |
## | y_it | gaussian() | beta_t + lambda_t z_i + q_it | fitted TMB likelihood | Gaussian response |

make_lv_gaussian_recovery_data <- function(
  n_units = 36L,
  n_traits = 3L,
  d = 1L,
  seed = 20260628L
) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  x_unit <- scale(seq(-1.5, 1.5, length.out = n_units))[, 1]

  if (identical(d, 1L)) {
    Lambda <- matrix(c(0.70, -0.45, 0.55)[seq_len(n_traits)], ncol = 1L)
    alpha <- matrix(0.65, nrow = 1L, ncol = 1L)
  } else {
    Lambda <- matrix(
      c(
        0.65,
        0.20,
        -0.45,
        0.30,
        0.50,
        -0.25,
        0.35,
        0.45
      )[seq_len(n_traits * d)],
      nrow = n_traits,
      ncol = d,
      byrow = TRUE
    )
    alpha <- matrix(c(0.55, -0.35), nrow = 1L, ncol = d)
  }
  beta <- matrix(c(0.10, -0.05, 0.08, 0.03)[seq_len(n_traits)], ncol = 1L)
  psi <- c(0.18, 0.14, 0.16, 0.20)[seq_len(n_traits)]

  innovation <- matrix(stats::rnorm(n_units * d), nrow = n_units, ncol = d)
  mean_scores <- x_unit %*% alpha
  scores <- mean_scores + innovation

  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        x = x_unit[[i]],
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  trait_i <- as.integer(df$trait)
  unit_i <- as.integer(df$unit)
  eta <- as.numeric(beta[trait_i, 1L]) +
    rowSums(Lambda[trait_i, , drop = FALSE] * scores[unit_i, , drop = FALSE])
  df$value <- eta + stats::rnorm(nrow(df), sd = psi[trait_i])

  attr(df, "truth") <- list(
    Lambda = Lambda,
    alpha = alpha,
    B_lv = Lambda %*% t(alpha),
    Sigma_shared = Lambda %*% t(Lambda),
    psi = psi,
    Sigma_total = Lambda %*% t(Lambda) + diag(psi^2, n_traits),
    d = d
  )
  df
}

fit_lv_gaussian_recovery <- function(
  data,
  d = attr(data, "truth")$d,
  se = TRUE
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  suppressMessages(gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = d, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(
      se = se,
      optimizer = "optim",
      optArgs = list(method = "BFGS")
    )
  ))
}

manual_B_lv_delta_se <- function(fit) {
  fixed <- summary(fit$sd_report, "fixed")
  theta_pos <- which(rownames(fixed) == "theta_rr_B")
  alpha_pos <- which(rownames(fixed) == "alpha_lv_B")
  expect_equal(length(theta_pos), fit$n_traits * fit$d_B)
  expect_equal(length(alpha_pos), fit$d_B)

  V <- fit$sd_report$cov.fixed
  Lambda <- fit$report$Lambda_B
  alpha <- fit$report$alpha_lv_B
  out <- numeric(fit$n_traits * nrow(alpha))
  pos <- 1L
  for (h in seq_len(nrow(alpha))) {
    for (tt in seq_len(fit$n_traits)) {
      grad <- numeric(length(theta_pos) + length(alpha_pos))
      names(grad) <- c(
        paste0("theta_", seq_along(theta_pos)),
        paste0("alpha_", seq_along(alpha_pos))
      )
      theta_col <- seq.int(
        from = tt,
        to = length(theta_pos),
        by = fit$n_traits
      )
      grad[theta_col] <- alpha[h, ]
      grad[length(theta_pos) + seq_len(fit$d_B)] <- Lambda[tt, ]
      idx <- c(theta_pos, alpha_pos)
      out[[pos]] <- sqrt(as.numeric(
        t(grad) %*% V[idx, idx, drop = FALSE] %*% grad
      ))
      pos <- pos + 1L
    }
  }
  out
}

expect_lv_gaussian_recovery <- function(
  fit,
  truth,
  b_tol = 0.18,
  sigma_tol = 0.35
) {
  expect_identical(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$use$lv_B))

  effects <- extract_lv_effects(fit)
  expect_equal(
    unique(effects$uncertainty_status),
    "wald_sdreport_no_ci_validation"
  )
  expect_equal(unique(effects$validation_row), "EXT-31; LV-01")
  b_abs_error <- max(abs(
    matrix(effects$estimate, nrow = fit$n_traits) - truth$B_lv
  ))
  expect_lt(
    b_abs_error,
    b_tol,
    label = sprintf("max absolute B_lv recovery error = %.3f", b_abs_error)
  )

  report <- summary(fit$sd_report, "report")
  b_rows <- report[rownames(report) == "B_lv_unit", , drop = FALSE]
  expect_equal(nrow(b_rows), length(effects$estimate))
  expect_true(all(is.finite(b_rows[, "Std. Error"])))
  expect_equal(
    effects$std.error,
    as.numeric(b_rows[, "Std. Error"]),
    tolerance = 1e-8
  )
  if (identical(fit$d_B, 1L)) {
    expect_equal(effects$std.error, manual_B_lv_delta_se(fit), tolerance = 1e-8)
  }

  shared <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "shared"
  ))$Sigma
  unique <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "unique"
  ))$s
  total <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "total"
  ))$Sigma
  expect_equal(
    total,
    shared + diag(unique, nrow = length(unique)),
    tolerance = 1e-8
  )
  expect_lt(
    norm(total - truth$Sigma_total, "F") / norm(truth$Sigma_total, "F"),
    sigma_tol
  )
  expect_true(all(is.finite(unique)))
  expect_true(all(unique >= 0))
}

test_that("ordinary Gaussian latent lv recovers B_lv and validates sdreport delta SEs", {
  data <- make_lv_gaussian_recovery_data(n_units = 72L, d = 1L)
  truth <- attr(data, "truth")
  fit <- fit_lv_gaussian_recovery(data, d = 1L, se = TRUE)

  expect_lv_gaussian_recovery(fit, truth)
})

test_that("ordinary Gaussian latent lv rank-2 heavy recovery targets rotation-stable quantities", {
  skip_if_not_heavy()
  data <- make_lv_gaussian_recovery_data(
    n_units = 96L,
    n_traits = 4L,
    d = 2L,
    seed = 20260629L
  )
  truth <- attr(data, "truth")
  fit <- fit_lv_gaussian_recovery(data, d = 2L, se = TRUE)

  expect_lv_gaussian_recovery(fit, truth, b_tol = 0.22, sigma_tol = 0.40)
})
