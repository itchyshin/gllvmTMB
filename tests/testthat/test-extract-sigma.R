## Tests for extract_Sigma() — the unified covariance / correlation
## extractor. Verifies the Sigma = Lambda Lambda^T + S decomposition,
## the three "part" arguments, the missing-diag advisory, and the
## binomial link_residual handling.

make_fit_BW_diag <- function(seed = 1) {
  set.seed(seed)
  n_sites <- 50; Tn <- 4; n_per_site <- 5
  Lambda_B <- matrix(c(1.0, 0.5, -0.4, 0.3,
                       0.0, 0.8,  0.4, -0.2), Tn, 2)
  psi_B <- c(0.20, 0.15, 0.10, 0.25)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  psi_W <- c(0.10, 0.08, 0.05, 0.12)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 8, n_traits = Tn,
    mean_species_per_site = n_per_site,
    Lambda_B = Lambda_B, psi_B = psi_B,
    Lambda_W = Lambda_W, psi_W = psi_W,
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = s$data
  )))
}

make_fit_B_rr_only <- function(seed = 2) {
  set.seed(seed)
  n_sites <- 60; Tn <- 4
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1, n_traits = Tn,
    mean_species_per_site = 1,
    Lambda_B = Lambda, psi_B = rep(0, Tn),
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = s$data
  )))
}

test_that("extract_Sigma with rr+diag returns Sigma = LL^T + S correctly", {
  fit <- make_fit_BW_diag()
  out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  expect_named(out, c("Sigma", "R", "level", "part", "note"))
  expect_equal(dim(out$Sigma), c(4, 4))
  expect_equal(dim(out$R),     c(4, 4))
  ## Sigma should be symmetric
  expect_equal(out$Sigma, t(out$Sigma), tolerance = 1e-10)
  ## Diagonals should be > 0
  expect_true(all(diag(out$Sigma) > 0))
  ## Correlation diagonal should be 1
  expect_equal(unname(diag(out$R)), c(1, 1, 1, 1))
})

test_that("extract_Sigma part='shared' returns LL^T only", {
  fit <- make_fit_BW_diag()
  shared <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared"))
  total  <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  unique_part <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique"))
  ## total should equal shared + diag(unique)
  reconstructed <- shared$Sigma + diag(unique_part$s, nrow = 4)
  expect_equal(reconstructed, total$Sigma, tolerance = 1e-10)
})

test_that("extract_Sigma part='unique' returns named numeric vector of length T", {
  fit <- make_fit_BW_diag()
  out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique"))
  expect_type(out$s, "double")
  expect_length(out$s, 4)
  expect_named(out$s)
  expect_true(all(out$s >= 0))
})

test_that("extract_Sigma without unique emits the missing-unique advisory note", {
  fit <- make_fit_B_rr_only()
  expect_message(
    extract_Sigma(fit, level = "unit", part = "total"),
    regexp = "unique"
  )
  ## Capture the value separately (expect_message returns the captured
  ## message in some testthat versions, not the call's value)
  out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  expect_true(any(grepl("unique", out$note, ignore.case = TRUE)))
  out_unit <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  note_unit <- paste(out_unit$note, collapse = "\n")
  expect_match(note_unit, "Sigma_unit", fixed = TRUE)
  expect_false(grepl("Sigma_B", note_unit, fixed = TRUE))
  shared <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared"))
  expect_equal(out$Sigma, shared$Sigma, tolerance = 1e-10)
})

test_that("extract_Sigma_B / extract_Sigma_W backward-compat wrappers work", {
  fit <- make_fit_BW_diag()
  out_B <- suppressMessages(extract_Sigma_B(fit))
  out_W <- suppressMessages(extract_Sigma_W(fit))
  expect_named(out_B, c("Sigma_B", "R_B"))
  expect_named(out_W, c("Sigma_W", "R_W"))
  ## Wrapper output must equal the unified extract_Sigma output
  unified_B <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  expect_equal(out_B$Sigma_B, unified_B$Sigma)
  expect_equal(out_B$R_B,     unified_B$R)
})

test_that("extract_Sigma errors on unknown level argument", {
  fit <- make_fit_B_rr_only()
  expect_error(
    suppressMessages(extract_Sigma(fit, level = "custom_group", part = "total")),
    regexp = "not yet supported"
  )
})

test_that("binomial fits with all three links fit + extract_Sigma works", {
  set.seed(2025)
  n <- 200; Tn <- 3
  Lambda <- matrix(c(0.8, 0.5, -0.3, 0.0, 0.6, 0.4), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- u %*% t(Lambda)
  for (link_name in c("logit", "probit", "cloglog")) {
    p <- switch(link_name,
                logit   = plogis(eta),
                probit  = pnorm(eta),
                cloglog = 1 - exp(-exp(eta)))
    y_bin <- matrix(rbinom(n * Tn, 1, p), n, Tn)
    df <- data.frame(
      individual = factor(rep(seq_len(n), each = Tn)),
      trait      = factor(rep(c("a","b","c"), n), levels = c("a","b","c")),
      value      = as.integer(t(y_bin))
    )
    fit <- suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 2),
      data = df, site = "individual",
      family = binomial(link = link_name)
    )))
    expect_equal(fit$opt$convergence, 0L,
                 info = paste("link =", link_name))
    expect_equal(fit$tmb_data$link_id_vec[1],
                 switch(link_name, logit = 0L, probit = 1L, cloglog = 2L))
    ## extract_Sigma should work without error (binomial has no diag-S
    ## to worry about; rr-only is the natural state on the latent scale)
    out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
    expect_equal(dim(out$Sigma), c(3, 3))
  }
})

test_that("link_residual = 'auto' adds the link-specific implicit residual to diag(Sigma)", {
  set.seed(2025)
  n <- 100; Tn <- 3
  Lambda <- matrix(c(0.5, 0.3, -0.2, 0.0, 0.4, 0.2), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- u %*% t(Lambda)
  ## Probit fit
  p <- pnorm(eta)
  y_bin <- matrix(rbinom(n * Tn, 1, p), n, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n), each = Tn)),
    trait      = factor(rep(c("a","b","c"), n), levels = c("a","b","c")),
    value      = as.integer(t(y_bin))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual", family = binomial(link = "probit")
  )))
  out_none <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                              link_residual = "none"))
  out_auto <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                              link_residual = "auto"))
  ## Probit's implicit residual is exactly 1 — diagonals should differ by 1
  expect_equal(unname(diag(out_auto$Sigma) - diag(out_none$Sigma)),
               rep(1, Tn), tolerance = 1e-10)
})
