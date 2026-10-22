.make_animal_coef_wide_fixture <- function(seed = 13146L) {
  set.seed(seed)
  traits <- paste0("t", 1:6)
  n_unit <- 18L
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(n_unit))),
    x = as.numeric(scale(seq_len(n_unit)))
  )
  column_data <- data.frame(
    trait = traits,
    pathway = factor(rep(c("C3", "C4"), each = 3L), levels = c("C3", "C4"))
  )
  for (j in seq_along(traits)) {
    pathway_j <- as.character(column_data$pathway[[j]])
    intercept <- if (identical(pathway_j, "C3")) 0.4 else -0.2
    slope <- if (identical(pathway_j, "C3")) 0.6 else -0.35
    wide[[traits[[j]]]] <- intercept + slope * wide$x +
      stats::rnorm(n_unit, sd = 0.25)
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(traits),
    names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)

  d <- seq(0.75, 1.25, length.out = length(traits))
  R <- 0.4^abs(outer(seq_along(traits), seq_along(traits), "-"))
  A <- outer(d, d) * R
  dimnames(A) <- list(traits, traits)
  list(long = long, wide = wide, column_data = column_data, A = A)
}

.fit_animal_coef_entry <- function(data, formula, column_data,
                                   long = FALSE) {
  args <- list(
    formula = formula,
    data = data,
    column_data = column_data,
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )
  if (isTRUE(long)) args$trait <- "trait"
  suppressMessages(do.call(gllvmTMB::gllvmTMB, args))
}

test_that("animal_coef pathway models are exactly matched in long and wide form", {
  fx <- .make_animal_coef_wide_fixture()
  formula_pairs <- list(
    list(
      long = value ~ 0 + pathway + x:pathway +
        animal_coef(1 + x | trait, A = fx$A, rho = 0.37),
      wide = traits(t1, t2, t3, t4, t5, t6) ~
        0 + pathway + x:pathway +
        animal_coef(1 + x | trait, A = fx$A, rho = 0.37)
    ),
    list(
      long = value ~ 0 + pathway + x:pathway +
        animal_coef(1 + x || trait, A = fx$A, rho = 0.37),
      wide = traits(t1, t2, t3, t4, t5, t6) ~
        0 + pathway + x:pathway +
        animal_coef(1 + x || trait, A = fx$A, rho = 0.37)
    )
  )

  for (pair in formula_pairs) {
    long_fit <- .fit_animal_coef_entry(
      fx$long, pair$long, fx$column_data, long = TRUE
    )
    wide_fit <- .fit_animal_coef_entry(
      fx$wide, pair$wide, fx$column_data, long = FALSE
    )

    expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
    expect_identical(
      .free_animal_map_signature(wide_fit),
      .free_animal_map_signature(long_fit)
    )
    expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
    expect_identical(wide_fit$opt$par, long_fit$opt$par)
    expect_identical(
      suppressMessages(stats::fitted(wide_fit)),
      suppressMessages(stats::fitted(long_fit))
    )
    expect_identical(
      gllvmTMB::extract_Sigma(wide_fit, level = "column_coef"),
      gllvmTMB::extract_Sigma(long_fit, level = "column_coef")
    )
  }
})
