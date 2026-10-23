test_that("ordinal correlations keep every item in unique pairs and full matrices", {
  set.seed(1469)
  items <- c("zeta", "beta", "omega", "alpha")
  n <- 40L
  u <- rnorm(n)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), times = length(items))),
    item = factor(rep(items, each = n), levels = items),
    value = ordered(as.integer(cut(
      rep(u, times = length(items)) + rnorm(n * length(items)),
      breaks = c(-Inf, -0.6, 0.4, Inf), labels = FALSE
    )))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + item + latent(0 + item | unit, d = 1, unique = FALSE),
    trait = "item", unit = "unit", family = ordinal_probit(), data = dat,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  pairs <- suppressMessages(extract_correlations(
    fit, tier = "unit", link_residual = "auto"
  ))
  R <- suppressMessages(extract_Sigma(
    fit, level = "unit", link_residual = "auto"
  ))$R
  expect_equal(R, t(R), tolerance = 1e-12)
  expect_equal(nrow(pairs), choose(length(items), 2))
  expect_setequal(union(pairs$trait_i, pairs$trait_j), items)
  expect_equal(setdiff(pairs$trait_i, pairs$trait_j), items[1])
  expect_equal(setdiff(pairs$trait_j, pairs$trait_i), tail(items, 1))
  expect_equal(pairs$correlation, unname(R[cbind(
    match(pairs$trait_i, rownames(R)), match(pairs$trait_j, colnames(R))
  )]))
  full <- suppressMessages(extract_Sigma_table(
    fit, level = "unit", measure = "correlation", entries = "all",
    link_residual = "auto"
  ))
  expect_equal(nrow(full), length(items)^2)
  expect_setequal(full$trait_i, items)
  expect_setequal(full$trait_j, items)
  expect_equal(full$estimate, unname(R[cbind(full$i, full$j)]))
  expect_equal(full$estimate[full$diagonal], rep(1, length(items)))
  skip_if_not_installed("ggplot2")
  p <- plot_correlations(pairs, style = "heatmap", triangle = "full")
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  tiles <- built$data[[1]]
  expect_equal(nrow(tiles), length(items)^2)
  expect_setequal(as.numeric(tiles$x), seq_along(items))
  expect_setequal(as.numeric(tiles$y), seq_along(items))
})
