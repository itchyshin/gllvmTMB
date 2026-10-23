.integrity_extract <- function() {
  extractor <- extract_correlations
  env <- new.env(parent = environment(extractor))
  env$extract_Sigma <- function(...) list(R = matrix(c(1, .3, .3, 1), 2L))
  environment(extractor) <- env
  extractor
}
.integrity_fit <- function() structure(list(use = list(rr_B = TRUE),
  trait_col = "trait", data = data.frame(trait = factor(c("a", "b"))),
  tmb_data = list(family_id_vec = 0L)), class = "gllvmTMB_multi")
.integrity_rows <- function() data.frame(tier = "B", trait_i = c("a", "b"),
  trait_j = c("b", "a"), correlation = .3, lower = .1, upper = .5,
  method = "fisher-z", interval_status = "approximate", provenance = "source-a")

test_that("numeric correlation pair indices must be finite positive integers", {
  extract <- .integrity_extract()
  fit <- .integrity_fit()
  for (pair in list(c(1.9, 2.9), c(NA_real_, 2), c(Inf, 2), c(NaN, 2),
                    c(0, 2), c(-1, 2), c(1, 3), c(1, 1))) {
    expect_error(extract(fit, pair = pair, link_residual = "none"),
                 "pair.*distinct.*integer|pair.*integer.*distinct")
  }
  expect_identical(extract(fit, pair = c(1, 2), link_residual = "none"),
                   extract(fit, pair = c("a", "b"), link_residual = "none"))
})

test_that("matrix correlation plots reject conflicting mirrored payloads", {
  skip_if_not_installed("ggplot2")
  for (column in c("correlation", "lower", "upper", "method", "interval_status", "provenance")) {
    dat <- .integrity_rows()
    dat[[column]][2L] <- if (is.numeric(dat[[column]])) .9 else "different"
    for (rows in list(1:2, 2:1)) {
      expect_error(plot_correlations(dat[rows, ], style = "heatmap"),
                   "Conflicting.*correlation", class = "gllvmTMB_correlation_conflicting_duplicates")
    }
  }
})

test_that("identical mirrored rows and distinct levels remain compatible", {
  skip_if_not_installed("ggplot2")
  dat <- .integrity_rows()
  for (style in c("heatmap", "ellipse")) {
    p <- plot_correlations(dat, style = style, include_diagonal = FALSE)
    plotted <- attr(p, "gllvmTMB_data")
    expect_equal(nrow(plotted), 2L)
    expect_equal(plotted$.estimate, c(.3, .3))
    expect_true(all(plotted$provenance == "source-a"))
  }
  other <- dat
  other$tier <- "W"
  other$correlation <- .7
  expect_no_error(plot_correlations(rbind(dat, other), style = "heatmap"))
})

test_that("correlation bootstrap counts are validated before integer conversion", {
  extract <- .integrity_extract()
  env <- environment(extract)
  env$bootstrap_Sigma <- function(fit, n_boot, ...) {
    .bootstrap_validate_count(n_boot, "n_boot")
    stop("valid count reached bootstrap", call. = FALSE)
  }
  fit <- .integrity_fit()
  expect_error(extract(fit, method = "bootstrap", nsim = 3.5,
                       link_residual = "none"), "n_boot.*positive integer")
  expect_error(extract(fit, method = "bootstrap", nsim = 4L,
                       link_residual = "none"), "valid count reached bootstrap")
})

test_that("cross-correlation bootstrap counts reach strict validation unchanged", {
  extract <- extract_cross_correlations
  env <- new.env(parent = environment(extract))
  Sigma <- diag(3L)
  dimnames(Sigma) <- list(c("nom:a", "nom:b", "other"), c("nom:a", "nom:b", "other"))
  env$extract_Sigma <- function(...) list(Sigma = Sigma)
  env$bootstrap_Sigma <- function(fit, n_boot, ...) {
    .bootstrap_validate_count(n_boot, "n_boot")
    stop("valid count reached bootstrap", call. = FALSE)
  }
  environment(extract) <- env
  fit <- .integrity_fit()
  fit$tmb_data$multinom_K_per_trait <- c(3L, 3L, 0L)
  expect_error(extract(fit, method = "bootstrap", nsim = 3.5,
                       link_residual = "none"), "n_boot.*positive integer")
  expect_error(extract(fit, method = "bootstrap", nsim = 4L,
                       link_residual = "none"), "valid count reached bootstrap")
})
