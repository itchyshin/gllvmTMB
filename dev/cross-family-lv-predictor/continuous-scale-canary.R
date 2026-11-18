# Small deterministic route-health canary for Gaussian/lognormal scale slots.

make_continuous_scale_data <- function(families, n_units = 30L) {
  units <- sprintf("u%02d", seq_len(n_units))
  x <- as.numeric(scale(seq(-1, 1, length.out = n_units)))
  traits <- names(families)
  out <- do.call(rbind, lapply(seq_along(units), function(i) {
    do.call(rbind, lapply(seq_along(traits), function(j) {
      family <- families[[j]]
      shared_innovation <- sin(i * 0.63)
      z <- 0.7 * x[[i]] + shared_innovation
      loading <- c(0.9, -0.7)[1L + ((j - 1L) %% 2L)]
      residual_wave <- cos(i * (0.31 + 0.05 * j))
      value <- if (family == "gaussian") {
        1 + loading * z + 0.18 * residual_wave
      } else {
        exp(0.2 + loading * z + 0.45 * residual_wave)
      }
      data.frame(
        unit = units[[i]], trait = traits[[j]], family = family,
        x = x[[i]], value = value, stringsAsFactors = FALSE
      )
    }))
  }))
  out$unit <- factor(out$unit, levels = units)
  out$trait <- factor(out$trait, levels = traits)
  out$family <- factor(out$family, levels = unique(families))
  out
}

fit_continuous_scale_canary <- function(families) {
  data <- make_continuous_scale_data(families)
  family_specs <- lapply(unique(families), function(family) {
    if (family == "gaussian") stats::gaussian() else lognormal()
  })
  names(family_specs) <- unique(families)
  attr(family_specs, "family_var") <- "family"
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = data,
    family = family_specs,
    unit = "unit",
    trait = "trait",
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

run_continuous_scale_canary <- function() {
  pure_gaussian <- fit_continuous_scale_canary(
    c(g1 = "gaussian", g2 = "gaussian")
  )
  pure_lognormal <- fit_continuous_scale_canary(
    c(l1 = "lognormal", l2 = "lognormal")
  )
  joint <- fit_continuous_scale_canary(
    c(g = "gaussian", l = "lognormal")
  )

  joint_sigma <- as.numeric(joint$report$sigma_eps)
  checks <- c(
    pure_gaussian_converged = identical(pure_gaussian$opt$convergence, 0L),
    pure_lognormal_converged = identical(pure_lognormal$opt$convergence, 0L),
    joint_converged = identical(joint$opt$convergence, 0L),
    pure_gaussian_scalar = length(pure_gaussian$report$sigma_eps) == 1L,
    pure_lognormal_scalar = length(pure_lognormal$report$sigma_eps) == 1L,
    joint_two_slots = length(joint_sigma) == 2L,
    joint_scales_positive = length(joint_sigma) == 2L &&
      all(is.finite(joint_sigma)) && all(joint_sigma > 0),
    finite_B_lv = all(is.finite(joint$report$B_lv_unit)),
    cdf_gaussian_slot = isTRUE(all.equal(
      .gllvmTMB_family_cdf_args(joint, 1L)$args$sd, joint_sigma[[1L]]
    )),
    cdf_lognormal_slot = isTRUE(all.equal(
      .gllvmTMB_family_cdf_args(joint, 2L)$args$sdlog, joint_sigma[[2L]]
    ))
  )
  list(
    checks = checks,
    sigma = list(
      pure_gaussian = pure_gaussian$report$sigma_eps,
      pure_lognormal = pure_lognormal$report$sigma_eps,
      joint = joint_sigma
    ),
    joint = joint
  )
}

if (identical(commandArgs(trailingOnly = TRUE), "--run")) {
  result <- run_continuous_scale_canary()
  print(result$checks)
  print(result$sigma)
  if (!all(result$checks)) {
    stop("Continuous-scale canary failed one or more checks.")
  }
}
