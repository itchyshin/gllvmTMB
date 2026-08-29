.make_kernel_coef_fixture <- function(seed = 13241L, n_traits = 5L,
                                      n_unit = 16L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  unit <- factor(paste0("u", seq_len(n_unit)))
  x <- as.numeric(scale(seq_len(n_unit)))
  z <- stats::rnorm(n_unit)
  wide <- data.frame(unit = unit, x = x, z = z)
  for (j in seq_along(traits)) {
    wide[[traits[[j]]]] <- 0.2 + 0.3 * x + stats::rnorm(n_unit, sd = 0.4)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(traits), names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  d <- seq(0.7, 1.3, length.out = n_traits)
  R <- 0.4^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  list(long = long, wide = wide, traits = traits, K = K)
}

.fit_kernel_coef <- function(fx, formula, wide = FALSE) {
  args <- list(
    formula = formula, data = if (wide) fx$wide else fx$long,
    unit = "unit", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  )
  if (!wide) args$trait <- "trait"
  suppressMessages(do.call(gllvmTMB::gllvmTMB, args))
}

.kernel_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) if (is.null(x)) NULL else as.integer(x))
}

.expect_kernel_route_identical <- function(coef_fit, slope_fit) {
  expect_identical(coef_fit$tmb_data, slope_fit$tmb_data)
  expect_identical(coef_fit$tmb_obj$env$random, slope_fit$tmb_obj$env$random)
  expect_identical(names(coef_fit$opt$par), names(slope_fit$opt$par))
  expect_identical(.kernel_map_signature(coef_fit),
                   .kernel_map_signature(slope_fit))
  common <- slope_fit$opt$par
  expect_identical(coef_fit$tmb_obj$fn(common), slope_fit$tmb_obj$fn(common))
  expect_identical(coef_fit$tmb_obj$gr(common), slope_fit$tmb_obj$gr(common))
  expect_identical(coef_fit$opt$objective, slope_fit$opt$objective)
  expect_identical(coef_fit$opt$par, slope_fit$opt$par)
  expect_identical(coef_fit$report, slope_fit$report)
  expect_identical(suppressMessages(stats::fitted(coef_fit)),
                   suppressMessages(stats::fitted(slope_fit)))
}
