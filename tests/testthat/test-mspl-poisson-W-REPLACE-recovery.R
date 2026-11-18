## Local multi-seed Poisson MSPL point recovery under working W_*
## (G0 SIGNED REPLACE #1102). Not NEWS covered. No public SE.
## Not Totoro. Experimental admit_packet only.

.pois_wstar_sim <- function(seed, n_site = 24L, n_trait = 4L) {
  set.seed(as.integer(seed))
  site <- factor(rep(seq_len(n_site), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site))
  z <- stats::rnorm(n_site)
  beta <- c(0.2, -0.15, 0.35, 0.05)
  Lambda <- c(0.45, -0.30, 0.25, 0.20)
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * Lambda[as.integer(trait)]
  data.frame(
    site = site,
    trait = trait,
    y = stats::rpois(length(eta), lambda = exp(eta)),
    truth_beta = beta[as.integer(trait)],
    stringsAsFactors = FALSE
  )
}

.pois_wstar_fit <- function(dat) {
  suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = stats::poisson(link = "log"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = FALSE,
      warn_runaway = FALSE
    )
  ))
}

test_that("A4 REPLACE: multi-seed Poisson MSPL point recovers intercepts (local)", {
  skip_on_cran()
  seeds <- c(1102L, 1103L, 1104L, 1105L)
  rows <- lapply(seeds, function(seed) {
    dat <- .pois_wstar_sim(seed)
    fit <- .pois_wstar_fit(dat)
    expect_s3_class(fit, "gllvmTMB_mspl")
    expect_identical(fit$mspl$registry_status, "admitted")
    expect_false(identical(fit$mspl$registry_evidence, "covered"))
    expect_equal(fit$opt$convergence, 0)
    b <- as.numeric(fit$tmb_obj$env$parList(fit$opt$par)$b_fix)
    truth <- c(0.2, -0.15, 0.35, 0.05)
    mae <- mean(abs(b - truth))
    data.frame(seed = seed, mae = mae, conv = fit$opt$convergence)
  })
  tab <- do.call(rbind, rows)
  expect_true(all(tab$conv == 0))
  ## Loose local band: REPLACE changes the penalty weight, not the
  ## likelihood; intercepts should stay identifiable on this DGP.
  expect_lt(median(tab$mae), 0.75)
  expect_lt(max(tab$mae), 1.25)
})

test_that("A4 REPLACE recovery never requests public SE", {
  src <- readLines(test_path("test-mspl-poisson-W-REPLACE-recovery.R"))
  code <- gsub("#.*$", "", src)
  code <- paste(code, collapse = "\n")
  expect_false(grepl("\\bse\\s*=\\s*TRUE", code))
  expect_false(grepl("vcov\\s*\\(", code))
  expect_false(grepl("confint\\s*\\(", code))
})
