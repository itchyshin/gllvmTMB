## Q7: when a `diag()` term is at the per-row level, sigma_eps and the
## diag-S random effects are jointly unidentifiable. The engine should
## auto-suppress sigma_eps (fix at a tiny value, map off) and emit a
## clear message so the user knows.

make_per_row_data <- function(seed = 42, n = 50, Tn = 4) {
  set.seed(seed)
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  S_diag <- c(0.20, 0.15, 0.10, 0.25)
  ## n_species = 1, mean_species_per_site = 1 => one row per (site, trait)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n, n_species = 1, n_traits = Tn, mean_species_per_site = 1,
    Lambda_B = Lambda, S_B = S_diag,
    beta = matrix(0, Tn, 2), seed = seed
  )
  s$data
}

make_multi_row_data <- function(seed = 43, n_sites = 30, n_species = 8, Tn = 4) {
  set.seed(seed)
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = Tn,
    mean_species_per_site = 5,
    Lambda_B = Lambda, S_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W, S_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2), seed = seed
  )
  s$data
}

test_that("Q7: per-row diag at site auto-suppresses sigma_eps with a message", {
  df <- make_per_row_data()
  expect_message(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
      data = df
    )),
    regexp = "Auto-suppressing.*sigma_eps"
  )
})

test_that("Q7: sigma_eps is mapped to NA when per-row diag triggers suppression", {
  df  <- make_per_row_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = df
  )))
  expect_true("log_sigma_eps" %in% names(fit$tmb_obj$env$map))
  expect_true(is.na(fit$tmb_obj$env$map$log_sigma_eps[1]))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("Q7: multi-row diag at site does NOT trigger suppression", {
  df <- make_multi_row_data()
  ## Multi-row diag at site (5 species per site -> ~5 obs per (site, trait))
  ## is properly identified alongside sigma_eps; no Q7 message.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) + unique(0 + trait | site),
    data = df
  )))
  ## sigma_eps should NOT be mapped to NA (still being estimated)
  expect_true(!("log_sigma_eps" %in% names(fit$tmb_obj$env$map)) ||
              !is.na(fit$tmb_obj$env$map$log_sigma_eps[1]))
})

test_that("Q7: per-row diag at site_species level also auto-suppresses sigma_eps", {
  df <- make_multi_row_data()
  ## unique(0 + trait | site_species) with one obs per (site, species, trait)
  ## IS at the per-row level by construction.
  expect_message(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | site, d = 2) +
              latent(0 + trait | site_species, d = 1) +
              unique(0 + trait | site_species),
      data = df
    )),
    regexp = "Auto-suppressing.*sigma_eps"
  )
})

test_that("Q7: binary fits never trigger the Q7 message (no continuous family)", {
  df <- make_per_row_data()
  df$value <- as.integer(df$value > 0)
  ## Binary: sigma_eps already auto-mapped via the !any_continuous branch;
  ## Q7 should NOT fire (no message about per-row absorbing the residual).
  msg_out <- testthat::capture_messages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, family = binomial(link = "logit")
  )))
  expect_false(any(grepl("Auto-suppressing.*sigma_eps", msg_out)))
})
