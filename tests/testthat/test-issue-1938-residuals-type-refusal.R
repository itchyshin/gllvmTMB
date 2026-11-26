## #1938: residuals(type = "pearson") on a converged gllvmTMB_multi fit surfaced a
## raw match.arg() message instead of a gllvmTMB-specific refusal naming the
## supported diagnostic residual types.

expect_residual_type_refusal <- function(expr) {
  err <- tryCatch(expr, error = function(e) e)
  expect_s3_class(err, "rlang_error")
  msg <- conditionMessage(err)
  expect_match(msg, "`type` = \"pearson\" is not supported", fixed = FALSE)
  expect_match(msg, "randomized_quantile", fixed = TRUE)
  expect_match(msg, "simulation_rank", fixed = TRUE)
  expect_no_match(msg, "should be one of", fixed = TRUE)
  invisible(err)
}

issue_1938_data <- function() {
  labs <- paste0("sp", 1:8)
  C <- diag(8) + 0.2
  dimnames(C) <- list(labs, labs)
  df <- expand.grid(
    species = labs,
    trait = c("t1", "t2"),
    site = 1:3,
    stringsAsFactors = FALSE
  )
  df$value <- stats::rbinom(nrow(df), 1, 0.5)
  df$species <- factor(df$species, levels = labs)
  df$trait <- factor(df$trait)
  df$site <- factor(df$site)
  list(data = df, C = C)
}

test_that("residuals(type = 'pearson') refuses with supported types named (#1938)", {
  skip_on_cran()
  d <- issue_1938_data()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, vcv = d$C),
    data = d$data,
    unit = "site",
    family = binomial(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_identical(fit$opt$convergence, 0L)
  expect_residual_type_refusal(residuals(fit, type = "pearson"))
})