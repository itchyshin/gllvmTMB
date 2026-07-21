## Tier-2b item 2a-ii: a multinomial() trait shares an ordinary latent factor
## with other-family traits, so cross-family (nominal <-> other) correlations are
## defined and recoverable. Covers: auto subset-expansion (raw long data, no
## hand-built .multinom columns), convergence, extract_Sigma / extract_correlations
## no longer refusing, extract_cross_correlations() 2C reporting, and recovery of
## a KNOWN latent cross-correlation on an adequately-powered demo.

.build_xfam_raw <- function(seed, N = 400L, reps = 5L, Lam = NULL) {
  if (is.null(Lam)) Lam <- matrix(c(1.3, 0.4, 1.0, 0.6, -0.6, 0.9), 3, byrow = TRUE)
  d <- ncol(Lam)
  set.seed(seed)
  Z <- matrix(stats::rnorm(N * d), N, d)
  u <- Z %*% t(Lam)                                   # N x 3 latent: g, cat2, cat3
  rows <- list()
  for (i in seq_len(N)) for (r in seq_len(reps)) {
    yg <- u[i, 1] + stats::rnorm(1, sd = 0.25)
    p  <- c(1, exp(u[i, 2]), exp(u[i, 3])); p <- p / sum(p)
    yc <- sample.int(3L, 1L, prob = p)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "cat", family = "m", value = yc)
    rows[[length(rows) + 1L]] <- data.frame(unit = i, trait = "g",   family = "g", value = yg)
  }
  dat <- do.call(rbind, rows)
  dat$unit   <- factor(dat$unit, levels = seq_len(N))
  dat$trait  <- factor(dat$trait)
  dat$family <- factor(dat$family)
  list(data = dat, Lam = Lam, R_true = cov2cor(Lam %*% t(Lam)))
}

.xfam_fam <- function() {
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  fam
}

test_that("auto-Psi guidance keeps binomial and multinomial remedies distinct", {
  combined <- gllvmTMB:::.auto_psi_skip_message(
    binomial_labs = "b",
    multinomial_labs = c("cat:2", "cat:3")
  )
  text <- paste(unname(combined), collapse = "\n")
  expect_match(text, "Multi-trial data", fixed = TRUE)
  expect_match(text, "replication can identify", fixed = TRUE)
  expect_match(text, "rejects explicit multinomial", fixed = TRUE)
  expect_match(text, "shared {.fn latent} block", fixed = TRUE)
  expect_false(grepl("or add an explicit {.fn indep} term", text, fixed = TRUE))

  binomial_only <- paste(unname(gllvmTMB:::.auto_psi_skip_message(
    binomial_labs = "b"
  )), collapse = "\n")
  expect_match(binomial_only, "Multi-trial data", fixed = TRUE)
  expect_false(grepl("multinomial contrast", binomial_only, fixed = TRUE))

  multinomial_only <- paste(unname(gllvmTMB:::.auto_psi_skip_message(
    multinomial_labs = c("cat:2", "cat:3")
  )), collapse = "\n")
  expect_match(multinomial_only, "replication can identify", fixed = TRUE)
  expect_match(multinomial_only, "rejects explicit multinomial", fixed = TRUE)
  expect_false(grepl("Multi-trial data", multinomial_only, fixed = TRUE))
  expect_false(grepl("an explicit {.fn indep} term is", multinomial_only,
                     fixed = TRUE))

  ids <- c(
    gllvmTMB:::.auto_psi_skip_frequency_id(binomial_labs = "b"),
    gllvmTMB:::.auto_psi_skip_frequency_id(multinomial_labs = "cat:2"),
    gllvmTMB:::.auto_psi_skip_frequency_id(
      binomial_labs = "b", multinomial_labs = "cat:2"
    )
  )
  expect_identical(ids, c(
    "gllvmTMB-psi-skip-binomial",
    "gllvmTMB-psi-skip-multinomial",
    "gllvmTMB-psi-skip-binomial-multinomial"
  ))
  expect_length(unique(ids), 3L)
})

test_that("auto-Psi once-per-session messages remain distinct across fit compositions", {
  skip_on_cran(); skip_if_not_installed("MASS")
  freq_env <- getFromNamespace("message_freq_env", "rlang")
  frequency_ids <- c(
    "gllvmTMB-psi-skip-binomial",
    "gllvmTMB-psi-skip-multinomial",
    "gllvmTMB-psi-skip-binomial-multinomial",
    "gllvmTMB-psi-skip-single-trial-binary"
  )
  rlang::env_unbind(freq_env, frequency_ids)
  withr::defer(rlang::env_unbind(freq_env, frequency_ids))

  sim <- .build_xfam_raw(14L, N = 60L, reps = 2L)
  dat_bin <- sim$data
  is_original_gaussian <- dat_bin$family == "g"
  dat_bin$value[is_original_gaussian] <- as.integer(
    dat_bin$value[is_original_gaussian] > stats::median(dat_bin$value[is_original_gaussian])
  )
  dat_bin$family <- factor(
    ifelse(is_original_gaussian, "b", "g"), levels = c("b", "g")
  )
  fam_bin <- list(b = binomial(), g = gaussian())
  attr(fam_bin, "family_var") <- "family"
  expect_message(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = dat_bin, family = fam_bin, trait = "trait", unit = "unit",
      silent = TRUE
    )),
    "Single-trial binomial traits g"
  )

  expect_message(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit",
      silent = TRUE
    )),
    "For multinomial contrast traits cat:2, cat:3"
  )
})

test_that("auto-Psi fit path classifies binomial and multinomial traits", {
  skip_on_cran(); skip_if_not_installed("MASS")
  sim <- .build_xfam_raw(13L, N = 120L, reps = 3L)
  dat <- sim$data
  is_g <- dat$family == "g"
  dat$value[is_g] <- as.integer(dat$value[is_g] > stats::median(dat$value[is_g]))
  dat$family <- factor(ifelse(is_g, "b", "m"), levels = c("b", "m"))
  fam <- list(b = binomial(), m = multinomial())
  attr(fam, "family_var") <- "family"
  withr::local_options(rlib_message_verbosity = "verbose")
  fit <- NULL
  expect_message(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = dat, family = fam, trait = "trait", unit = "unit", silent = TRUE
    )),
    regexp = paste0(
      "Single-trial binomial traits g.*",
      "For multinomial contrast traits cat:2, cat:3.*",
      "rejects explicit multinomial"
    )
  )
  expect_s3_class(fit, "gllvmTMB_multi")
})

test_that("mixed multinomial + gaussian sharing a latent factor fits and auto-expands (item 2a-ii)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  sim <- .build_xfam_raw(1L, N = 300L, reps = 5L)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit")))
  expect_equal(fit$opt$convergence, 0L)
  ## Auto subset-expansion produced g + the two contrast pseudo-traits.
  expect_setequal(levels(fit$data$trait), c("g", "cat:2", "cat:3"))
  expect_equal(unname(fit$tmb_data$multinom_K_per_trait[levels(fit$data$trait) != "g"]), c(2L, 2L))
})

test_that("extract_Sigma / extract_correlations report the cross-block (no refusal)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  sim <- .build_xfam_raw(2L, N = 300L, reps = 5L)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit")))
  S <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared", link_residual = "none"))
  Sig <- if (!is.null(S$Sigma)) S$Sigma else S
  expect_equal(dim(Sig), c(3L, 3L))
  expect_true(isSymmetric(unname(round(Sig, 8))))
  expect_error(suppressWarnings(suppressMessages(extract_correlations(fit, level = "unit"))), NA)  # no refusal
})

test_that("extract_cross_correlations() reports 2C summary + (K-1) vector, reference-invariant", {
  skip_on_cran(); skip_if_not_installed("MASS")
  sim <- .build_xfam_raw(3L, N = 300L, reps = 5L)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit")))
  cc <- suppressMessages(extract_cross_correlations(fit, level = "unit",
                                                    contrasts = TRUE, link_residual = "auto"))
  expect_true(is.data.frame(cc))
  expect_true(all(c("nominal", "partner", "multiple_r", "contrast_r") %in% names(cc)))
  expect_equal(cc$nominal, "cat"); expect_equal(cc$partner, "g")
  expect_gte(cc$multiple_r, 0); expect_lte(cc$multiple_r, 1)      # magnitude in [0,1]
  expect_length(cc$contrast_r[[1]], 2L)                          # (K-1) vector

  ## Reference-invariance: re-fit with a different baseline category; the
  ## multiple correlation is unchanged (up to fit noise), the raw contrast
  ## vector changes with the reference.
  fam2 <- .xfam_fam(); fam2$m <- multinomial(baseline = "3")
  fit2 <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    data = sim$data, family = fam2, trait = "trait", unit = "unit")))
  cc2 <- suppressMessages(extract_cross_correlations(fit2, level = "unit", link_residual = "auto"))
  expect_equal(cc$multiple_r, cc2$multiple_r, tolerance = 0.05)
})

test_that("cross-family latent correlation recovers a known truth (multi-seed mean)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## Multi-seed discipline: single seeds are noisy (the weaker g~cat:3 pair
  ## especially), so average the recovered latent contrast correlations over a
  ## few seeds and check the MEAN tracks R_true. Loadings-only sim, N=400 x 5.
  r_g_c2 <- r_g_c3 <- numeric(0); R_true <- NULL
  for (seed in 7L:11L) {
    sim <- .build_xfam_raw(seed, N = 400L, reps = 5L); R_true <- sim$R_true
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
      data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit")))
    if (fit$opt$convergence != 0L) next
    Lb <- fit$report$Lambda_B; R_hat <- cov2cor(Lb %*% t(Lb))
    tn <- rownames(suppressMessages(
      extract_Sigma(fit, level = "unit", part = "shared", link_residual = "none"))$Sigma)
    gi <- which(tn == "g"); c2 <- which(tn == "cat:2"); c3 <- which(tn == "cat:3")
    r_g_c2 <- c(r_g_c2, R_hat[gi, c2]); r_g_c3 <- c(r_g_c3, R_hat[gi, c3])
  }
  expect_gte(length(r_g_c2), 3L)
  ## Absolute-difference checks (testthat `tolerance` is relative, which is
  ## misleading for a correlation near zero like the weaker g~cat:3 pair).
  expect_lt(abs(mean(r_g_c2) - R_true[1, 2]), 0.06)   # strong, stable
  expect_lt(abs(mean(r_g_c3) - R_true[1, 3]), 0.10)   # weaker, noisier
})

test_that("fail-closed fence: a multinomial + augmented latent slope (rr_B_slope) is refused (Rose 2026-07-18)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## The Tier-2b fence is a fail-closed allow-list: only phylo_rr / rr_B / lv_B
  ## are permitted on a fid-16 trait. An augmented reaction-norm slope
  ## latent(1 + x | unit, d) sets use_rr_B_slope, which is NOT allowed and must
  ## abort rather than reach the untested categorical random-slope path.
  sim <- .build_xfam_raw(1L, N = 120L, reps = 3L)
  sim$data$x <- stats::rnorm(nrow(sim$data))
  expect_error(
    suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(1 + x | unit, d = 2),
      data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit"))),
    regexp = "unsupported latent|deferred|Design 84"
  )
})

test_that("unique = TRUE (default) works; the multinomial contrast between-unit Psi auto-suppresses", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## The DEFAULT latent() carries unique = TRUE. A multinomial contrast is a
  ## one-hot 0/1 per row, so its between-unit Psi is unidentified (like single-
  ## trial binary) and the engine auto-suppresses it -- unique = TRUE works out
  ## of the box, pdHess holds, and identified partners keep their Psi. This is
  ## the Link Residual Contract (design 02): categorical unique variance is 0.
  sim <- .build_xfam_raw(2L, N = 300L, reps = 5L)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2),          # unique = TRUE
    data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit", silent = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  ## Between-unit Psi for the two multinomial contrasts is auto-suppressed (~0).
  psi <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique"))
  s <- if (!is.null(psi$s)) psi$s else diag(psi$Sigma)
  mn <- grepl("^cat:", names(s))
  expect_true(any(mn))
  expect_true(all(s[mn] < 1e-2))
  ## Cross-block still reported.
  cc <- suppressMessages(extract_cross_correlations(fit, level = "unit"))
  expect_true(is.data.frame(cc) && nrow(cc) >= 1L)
})

test_that("fail-closed fence: an EXPLICIT unique()/indep() on a multinomial is refused (Rose 2026-07-18)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## The default auto-Psi (unique = TRUE) is allowed and auto-suppresses the
  ## categorical contrast Psi. But an EXPLICIT unique()/indep() diagonal is NOT
  ## the auto-Psi (auto_psi_B is FALSE), so it would leave the contrast Psi free
  ## and non-identified -- it must stay fenced.
  sim <- .build_xfam_raw(1L, N = 150L, reps = 4L)
  expect_error(
    suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE) +
        unique(0 + trait | unit),
      data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit"))),
    regexp = "unsupported latent|deferred|not identified|Design 84"
  )
  expect_error(
    suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE) +
        indep(0 + trait | unit),
      data = sim$data, family = .xfam_fam(), trait = "trait", unit = "unit"))),
    regexp = "unsupported latent|deferred|not identified|over-param|Design 84"
  )
})
