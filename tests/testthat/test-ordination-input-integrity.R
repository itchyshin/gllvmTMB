make_ordination_integrity_fit <- function(level = "unit") {
  between <- identical(level, "unit")
  units <- paste0("u", 1:3)
  traits <- paste0("t", 1:3)
  dat <- expand.grid(unit = units, trait = traits)
  dat$unit <- factor(dat$unit, levels = units)
  dat$trait <- factor(dat$trait, levels = traits)
  dat$obs <- dat$unit
  block <- if (between) "z_B" else "z_W"
  structure(list(
    data = dat, trait_col = "trait", unit_col = "unit", unit_obs_col = "obs",
    use = list(rr_B = between, rr_W = !between, lv_B = FALSE),
    d_B = if (between) 2L else 0L, d_W = if (between) 0L else 2L,
    n_sites = 3L, n_site_species = 3L,
    report = setNames(list(matrix(seq_len(6L) / 10, 3L, 2L)),
                      if (between) "Lambda_B" else "Lambda_W"),
    tmb_obj = list(env = list(last.par.best = setNames(seq_len(6L), rep(block, 6L))))
  ), class = c("gllvmTMB_multi", "gllvmTMB"))
}

test_that("ordination rejects incomplete or oversized score blocks without recycling", {
  for (level in c("unit", "unit_obs")) {
    fit <- make_ordination_integrity_fit(level)
    block <- if (level == "unit") "z_B" else "z_W"
    expected <- rbind(c(1, 2), c(3, 4), c(5, 6))
    dimnames(expected) <- list(paste0("u", 1:3), c("LV1", "LV2"))
    expect_equal(extract_ordination(fit, level)$scores, expected, tolerance = 0)
    for (n in c(0L, 1L, 5L, 7L)) {
      malformed <- fit
      malformed$tmb_obj$env$last.par.best <- setNames(seq_len(n), rep(block, n))
      expect_error(extract_ordination(malformed, level),
                   class = "gllvmTMB_ordination_score_block_mismatch")
    }
    malformed <- fit
    names(malformed$tmb_obj$env$last.par.best) <- rep("other", 6L)
    expect_error(extract_ordination(malformed, level),
                 class = "gllvmTMB_ordination_score_block_mismatch")
    malformed$tmb_obj <- NULL
    expect_error(extract_ordination(malformed, level),
                 class = "gllvmTMB_ordination_score_block_mismatch")
  }
})

test_that("temporal ordination rejects component requests it cannot represent", {
  fit <- make_ordination_integrity_fit()
  fit$use$rr_B <- FALSE
  fit$d_B <- 0L
  fit$temporal <- list(active = TRUE, mode = "latent", d = 1L,
                       pair_table = data.frame(pair_id = paste0("pair", 1:3)))
  fit$report <- list(z_temporal_state = matrix(c(.3, .7, -.2), 1L, 3L),
                     Lambda_temporal = matrix(c(.2, .4, .6), 3L, 1L))
  expected <- matrix(c(.3, .7, -.2), 3L, 1L,
                     dimnames = list(paste0("pair", 1:3), "LV1"))
  expect_identical(extract_ordination(fit)$scores, expected)
  for (component in c("mean", "innovation")) {
    expect_error(extract_ordination(fit, component = component),
                 class = "gllvmTMB_ordination_temporal_component_unsupported")
  }
})
