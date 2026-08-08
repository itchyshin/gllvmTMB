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
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
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

test_that("extract_Sigma with unique=FALSE emits the no-Psi advisory note", {
  fit <- make_fit_B_rr_only()
  expect_message(
    extract_Sigma(fit, level = "unit", part = "total"),
    regexp = "no-Psi|unique = FALSE"
  )
  ## Capture the value separately (expect_message returns the captured
  ## message in some testthat versions, not the call's value)
  out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  expect_true(any(grepl("no-Psi|unique = FALSE", out$note, ignore.case = TRUE)))
  out_unit <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))
  note_unit <- paste(out_unit$note, collapse = "\n")
  expect_match(note_unit, "Sigma_unit", fixed = TRUE)
  expect_false(grepl("Sigma_B", note_unit, fixed = TRUE))
  shared <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared"))
  expect_equal(out$Sigma, shared$Sigma, tolerance = 1e-10)
})

test_that("extract_Sigma does not call a phylo_dep covariance latent-only", {
  skip_if_not_installed("ape")
  set.seed(20260711)
  n_species <- 24L
  n_traits <- 3L
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  dat <- expand.grid(
    species = tree$tip.label,
    trait = paste0("trait_", seq_len(n_traits)),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$species <- factor(dat$species, levels = tree$tip.label)
  dat$trait <- factor(dat$trait, levels = paste0("trait_", seq_len(n_traits)))
  dat$value <- stats::rnorm(nrow(dat))

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, tree = tree),
    data = dat,
    trait = "trait",
    unit = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_no_message(
    out <- extract_Sigma(fit, level = "phy", part = "total")
  )
  expect_false(any(grepl("latent-only", out$note, fixed = TRUE)))
  expect_equal(dim(out$Sigma), c(n_traits, n_traits))
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

## ---------------------------------------------------------------------------
## link_residual NA-propagation contract (isdm lane, 2026-08-08).
##
## `link_residual_per_trait()` returns NA_real_ (with a warning) for a trait
## whose rows span more than one family/link -- no single link-residual
## variance is defined for it. The consumer inside extract_Sigma() used to
## gate the addition with `any(link_resid_per_trait != 0, na.rm = TRUE)`,
## which discards NA via `na.rm = TRUE` and silently falls through to the
## `link_residual = "none"` result: the warning said "undefined" while the
## return value behaved as though the residual were exactly 0. The fix
## propagates NA into the affected diag(Sigma) entry (and, via
## .safe_cov2cor(), into that trait's row/column of R) instead.

make_within_trait_mixed_family_fit <- function(seed = 2026L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 80, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1.0, 0.6,
                        0.3, -0.5), nrow = 2, ncol = 2, byrow = TRUE),
    psi_B    = c(0.3, 0.3),
    seed     = seed
  )
  df <- sim$data
  ## trait_1 stays a single family (Gaussian) throughout.
  ## trait_2 is split WITHIN the trait by site parity: odd sites -> Poisson
  ## counts, even sites -> binomial-cloglog binary -- the SAME trait, two
  ## families, dispatched via a `source` column that is deliberately NOT the
  ## trait column (confirmed-working configuration for this defect).
  df$source <- ifelse(
    df$trait == "trait_1", "gauss",
    ifelse(as.integer(df$site) %% 2L == 1L, "t2_pois", "t2_bin")
  )
  df$source <- factor(df$source, levels = c("gauss", "t2_pois", "t2_bin"))

  is_pois <- df$source == "t2_pois"
  is_bin  <- df$source == "t2_bin"
  df$value[is_pois] <- pmax(0L, as.integer(round(df$value[is_pois] + 2)))
  df$value[is_bin]  <- as.integer(df$value[is_bin] > 0)

  family_list <- list(
    gauss   = gaussian(),
    t2_pois = poisson(),
    t2_bin  = binomial(link = "cloglog")
  )
  attr(family_list, "family_var") <- "source"

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data   = df,
    family = family_list
  )))
}

test_that("extract_Sigma(link_residual = 'auto') propagates NA for a trait spanning multiple families", {
  skip_on_cran()
  fit <- make_within_trait_mixed_family_fit()
  trait_names <- levels(fit$data[[fit$trait_col]])
  mixed_idx <- which(trait_names == "trait_2")
  gauss_idx <- which(trait_names == "trait_1")

  expect_warning(
    out_auto <- suppressMessages(extract_Sigma(
      fit, level = "unit", part = "total", link_residual = "auto"
    )),
    regexp = "multiple families"
  )
  out_none <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "none"
  ))

  ## The whole point of the fix: an "auto" Sigma with an undefined per-trait
  ## residual must NOT be identical() / all.equal() to the "none" Sigma.
  expect_false(isTRUE(all.equal(out_auto$Sigma, out_none$Sigma)))

  ## The affected trait's diagonal (and its row/column of R) is visibly NA.
  expect_true(is.na(out_auto$Sigma[mixed_idx, mixed_idx]))
  expect_true(all(is.na(out_auto$R[mixed_idx, ])))
  expect_true(all(is.na(out_auto$R[, mixed_idx])))

  ## The unaffected single-family trait is untouched by the NA.
  expect_false(is.na(out_auto$Sigma[gauss_idx, gauss_idx]))
  expect_false(is.na(out_auto$R[gauss_idx, gauss_idx]))
})

test_that("link_residual = 'auto' matches per-link formulas and stays NA-free on single-family traits (boundary)", {
  set.seed(2025)
  n <- 150; Tn <- 3
  Lambda <- matrix(c(0.6, 0.4, -0.3, 0.0, 0.5, 0.3), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- u %*% t(Lambda)
  ## pi^2/3 (logit), 1 (probit), pi^2/6 (cloglog) -- Nakagawa & Schielzeth
  ## 2010, Table 2.
  expected <- c(logit = pi^2 / 3, probit = 1, cloglog = pi^2 / 6)
  for (link_name in names(expected)) {
    p <- switch(link_name,
                logit   = plogis(eta),
                probit  = pnorm(eta),
                cloglog = 1 - exp(-exp(eta)))
    y_bin <- matrix(rbinom(n * Tn, 1, p), n, Tn)
    df <- data.frame(
      individual = factor(rep(seq_len(n), each = Tn)),
      trait      = factor(rep(c("a", "b", "c"), n), levels = c("a", "b", "c")),
      value      = as.integer(t(y_bin))
    )
    fit <- suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 2),
      data = df, site = "individual",
      family = binomial(link = link_name)
    )))
    out_none <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                                link_residual = "none"))
    out_auto <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                                link_residual = "auto"))
    diff <- unname(diag(out_auto$Sigma) - diag(out_none$Sigma))
    expect_equal(diff, rep(unname(expected[[link_name]]), Tn), tolerance = 1e-8,
                 label = paste("link =", link_name))
    ## Guard against over-broad NA propagation: a single-family-per-trait fit
    ## must stay entirely finite under the fix, exactly as before it.
    expect_false(anyNA(out_auto$Sigma))
    expect_false(anyNA(out_auto$R))
  }
})

test_that("link_residual = 'auto' matches the Poisson-log formula and stays NA-free (boundary)", {
  skip_on_cran()
  set.seed(2026)
  n <- 120; Tn <- 3
  Lambda <- matrix(c(0.5, 0.3, -0.2, 0.0, 0.4, 0.2), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- 1.0 + u %*% t(Lambda)
  mu  <- exp(eta)
  y   <- matrix(rpois(n * Tn, mu), n, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n), each = Tn)),
    trait      = factor(rep(c("a", "b", "c"), n), levels = c("a", "b", "c")),
    value      = as.integer(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual",
    family = poisson()
  )))
  out_none <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                              link_residual = "none"))
  out_auto <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                              link_residual = "auto"))
  ## sigma2_d = log(1 + 1 / mu_t) (lognormal-Poisson approximation,
  ## Nakagawa & Schielzeth 2010 Table 2; R/extract-sigma.R's poisson branch
  ## of link_residual_per_trait()).
  expected <- gllvmTMB:::link_residual_per_trait(fit)
  expect_false(anyNA(expected))
  expect_true(all(expected > 0))
  expect_equal(unname(diag(out_auto$Sigma) - diag(out_none$Sigma)),
               unname(expected), tolerance = 1e-8)
  expect_false(anyNA(out_auto$Sigma))
  expect_false(anyNA(out_auto$R))
})
