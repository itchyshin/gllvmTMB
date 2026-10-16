# Fixture adapted from test-isdm-multisource.R (the admitted three-source contract).
.bootstrap_isdm_fixture <- function(
  sources = c(gbif = "count", literature = "count", survey = "pa"),
  n_cell = 30L,
  seed = 7L
) {
  set.seed(seed)
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2")
  x <- as.numeric(scale(runif(n_cell)))
  alpha <- c(-0.1, 0.2)
  beta <- c(0.4, -0.3)
  out <- do.call(
    rbind,
    lapply(names(sources), function(src) {
      d <- expand.grid(
        cell_id = cells,
        trait = species,
        stringsAsFactors = FALSE
      )
      ci <- match(d$cell_id, cells)
      si <- match(d$trait, species)
      eta <- alpha[si] + x[ci] * beta[si]
      d$isdm_source <- src
      d$support <- if (sources[[src]] == "count") 1.5 else 0.9
      d$value <- if (sources[[src]] == "count") {
        rpois(nrow(d), d$support * exp(eta))
      } else {
        rbinom(nrow(d), 1, -expm1(-d$support * exp(eta)))
      }
      d
    })
  )
  out$trait <- factor(out$trait)
  out$cell_id <- factor(out$cell_id)
  out$log_support <- log(out$support)
  out$env <- x[match(as.character(out$cell_id), cells)]
  out
}

test_that("bootstrap preserves the integrated-source no-weights contract", {
  dat <- .bootstrap_isdm_fixture(n_cell = 20)
  dat$src <- factor(dat$isdm_source)
  fam <- isdm_sources(
    gbif = poisson(),
    literature = poisson(),
    survey = binomial("cloglog")
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      trait:env +
      trait:src +
      offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat,
    trait = "trait",
    unit = "cell_id",
    family = fam,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  expect_identical(fit$opt$convergence, 0L)
  response <- .bootstrap_response_setup(fit)
  expect_null(response$weights)
  y <- simulate(fit, nsim = 3, seed = 1496)
  ref <- lapply(seq_len(ncol(y)), function(b) {
    d <- fit$data
    d$value <- y[, b]
    z <- suppressMessages(suppressWarnings(gllvmTMB(
      .reconstruct_multi_formula(fit),
      data = d,
      family = fam,
      trait = "trait",
      unit = "cell_id",
      control = .bootstrap_refit_control(fit)
    )))
    expect_identical(z$opt$convergence, 0L)
    .extract_summaries(z, level = "B", what = "Sigma", link_residual = "none")
  })
  boot <- suppressMessages(suppressWarnings(bootstrap_Sigma(
    fit,
    n_boot = 3,
    conf = .5,
    seed = 1496,
    level = "unit",
    what = "Sigma",
    link_residual = "none",
    keep_draws = TRUE,
    progress = FALSE
  )))
  expect_identical(boot$n_failed, 0L)
  expect_equal(boot$draws, ref, tolerance = 1e-7)
})
