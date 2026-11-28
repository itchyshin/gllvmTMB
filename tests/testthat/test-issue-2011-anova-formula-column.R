## Issue #2011: anova() formula column must reflect latent rank / covstruct.

.issue_2011_mock_fit <- function(npar, loglik, d_B, n_traits = 4L) {
  structure(
    list(
      opt = list(par = numeric(npar), objective = -loglik, convergence = 0L),
      tmb_data = list(family_id_vec = rep(0L, n_traits)),
      missing_data = list(counts = list(likelihood_rows = 200L)),
      REML = FALSE,
      estimator = "ML",
      aghq = list(used = FALSE),
      likelihood_weights = list(active = FALSE),
      n_traits = n_traits,
      d_B = d_B,
      use = list(rr_B = TRUE, diag_B = TRUE, rr_W = FALSE, diag_W = FALSE,
                 propto = FALSE, diag_species = FALSE, diag_cluster2 = FALSE),
      X_fix_names = paste0("trait", paste0("t", seq_len(n_traits))),
      formula = quote(value ~ 0 + trait)
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("anova() formula column distinguishes latent ranks with the same fixed formula", {
  fit_d1 <- .issue_2011_mock_fit(npar = 8, loglik = -105, d_B = 1L)
  fit_d2 <- .issue_2011_mock_fit(npar = 11, loglik = -100, d_B = 2L)
  a <- anova(fit_d1, fit_d2)
  expect_false(identical(a$formula[1], a$formula[2]))
  expect_match(a$formula[1], "latent\\(d = 1\\)")
  expect_match(a$formula[2], "latent\\(d = 2\\)")
  expect_true(all(grepl("^value ~ 0 \\+ trait", a$formula)))
})

test_that("anova() formula column on real rank-nested fits (heavy)", {
  skip_on_cran()
  set.seed(11271213L)
  dat <- do.call(rbind, lapply(paste0("s", 1:12), function(u) {
    data.frame(
      unit = u,
      trait = rep(c("t1", "t2"), each = 1L),
      value = stats::rnorm(2L)
    )
  }))
  dat$unit <- factor(dat$unit)
  dat$trait <- factor(dat$trait)
  f1 <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, unit = "unit", control = gllvmTMBcontrol(se = FALSE)
  ))
  f2 <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2),
    data = dat, unit = "unit", control = gllvmTMBcontrol(se = FALSE)
  ))
  a <- anova(f1, f2)
  expect_false(identical(a$formula[1], a$formula[2]))
  expect_equal(a$d, c(1L, 2L))
})