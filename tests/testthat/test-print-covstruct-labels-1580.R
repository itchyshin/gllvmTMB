## #1580: print()/summary() named the same user-written term twice
## ("indep_unit, indep_unit"), and split a latent(unique = TRUE) term into
## its internal "latent_unit, indep_unit" parts. extract_cross_correlations()
## also leaked extract_Sigma()'s link-residual notes on every call, while
## extract_correlations() silences them.

.covlab_data <- function(seed = 1L, n_unit = 40L, n_trait = 4L) {
  set.seed(seed)
  z <- stats::rnorm(n_unit)
  lam <- c(1, 0.8, 0.6, 0.4)[seq_len(n_trait)]
  d <- expand.grid(unit = seq_len(n_unit), trait = seq_len(n_trait))
  d$value <- lam[d$trait] * z[d$unit] + stats::rnorm(nrow(d), sd = 0.7)
  d$unit <- factor(d$unit)
  d$trait <- factor(paste0("t", d$trait))
  d
}

.covlab_line <- function(lines) {
  grep("Covstructs:", lines, value = TRUE, fixed = TRUE)
}

test_that("a single indep() term prints one Covstructs label (#1580)", {
  skip_on_cran()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit),
    data = .covlab_data(), unit = "unit"
  )))
  for (out in list(
    utils::capture.output(print(fit)),
    utils::capture.output(print(suppressWarnings(summary(fit))))
  )) {
    line <- .covlab_line(out)
    expect_length(line, 1L)
    expect_identical(trimws(sub("Covstructs:", "", line, fixed = TRUE)),
                     "indep_unit")
  }
})

test_that("latent(unique = TRUE) prints one label, not its internal split (#1580)", {
  skip_on_cran()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
    data = .covlab_data(), unit = "unit"
  )))
  for (out in list(
    utils::capture.output(print(fit)),
    utils::capture.output(print(suppressWarnings(summary(fit))))
  )) {
    line <- .covlab_line(out)
    expect_length(line, 1L)
    expect_identical(trimws(sub("Covstructs:", "", line, fixed = TRUE)),
                     "latent_unit")
  }
})

test_that("extract_cross_correlations() emits no messages, like extract_correlations() (#1580)", {
  skip_on_cran()
  skip_if_not_installed("MASS")
  n <- 150L
  set.seed(3L)
  u <- matrix(stats::rnorm(n * 2L), n, 2L) %*%
    t(matrix(c(1.3, 0.4, 1.0, 0.6, -0.6, 0.9), 3, byrow = TRUE))
  rows <- lapply(seq_len(n), function(i) {
    p <- c(1, exp(u[i, 2]), exp(u[i, 3]))
    p <- p / sum(p)
    do.call(rbind, lapply(1:4, function(r) {
      data.frame(
        unit = i,
        trait = c("cat", "g"),
        family = c("m", "g"),
        value = c(sample.int(3L, 1L, prob = p), u[i, 1] + stats::rnorm(1, sd = 0.25))
      )
    }))
  })
  dat <- do.call(rbind, rows)
  dat$unit <- factor(dat$unit)
  dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = dat, family = fam, trait = "trait", unit = "unit"
  )))
  expect_no_message(extract_cross_correlations(fit, level = "unit"))
})
