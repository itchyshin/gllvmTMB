## Design 118 B0 -- fence-ROC harness pure-function tests.
## docs/design/118-mspl-interval-calibration-protocol.md s1.2, s1.6, s5.3.
##
## The harness (inst/sim/b0-fence-roc/) is a simulation runner, not exported
## package API; these tests exercise only its pure functions (labelling
## logic, the analytic attractor root, and the output schema), which need no
## live MSPL fit and stay fast. No fitting happens in this file.

lib_path <- system.file("sim/b0-fence-roc/lib-b0-fence-roc.R", package = "gllvmTMB")

test_that("the B0 harness library is shipped and sources cleanly", {
  skip_if(!nzchar(lib_path), "inst/sim/b0-fence-roc/lib-b0-fence-roc.R not found")
  expect_true(file.exists(lib_path))
  expect_silent(source(lib_path, local = TRUE))
})

local({
  if (!nzchar(lib_path)) return(invisible())
  source(lib_path, local = TRUE)

  test_that("b0_manifest() reproduces the archive's 12-cell case labelling", {
    m <- b0_manifest()
    expect_equal(nrow(m), 12L)
    expect_equal(m$case_id, sprintf("C%03d", 1:12))
    ## C011 = cloglog x high_prevalence, the fenced pocket (A1b).
    c011 <- m[m$case_id == "C011", ]
    expect_equal(c011$link, "cloglog")
    expect_equal(c011$regime, "high_prevalence")
    expect_equal(c011$beta_shift, 1.5)
    ## The well-identified anchors named in Design 118 s5.3's probe gate.
    anchors <- m[m$case_id %in% c("C001", "C004", "C005", "C008"), c("case_id", "link", "regime")]
    expect_equal(anchors$link, c("logit", "logit", "probit", "probit"))
    expect_equal(anchors$regime, c("baseline", "strong_signal", "baseline", "strong_signal"))
  })

  test_that("B0's seed_base range is disjoint from the 2026-08-14 archive's", {
    m <- b0_manifest()
    ## Archive: 1,900,000,000 + case_number*10,000,000 -> range [1.91e9, 2.02e9].
    archive_range <- c(1900000000L + 1L * 10000000L, 1900000000L + 12L * 10000000L)
    expect_true(all(m$seed_base < archive_range[[1L]]))
  })

  test_that("b0_label_l1() flags k in {0, n} only", {
    expect_true(b0_label_l1(0L, 24L))
    expect_true(b0_label_l1(24L, 24L))
    expect_false(b0_label_l1(1L, 24L))
    expect_false(b0_label_l1(23L, 24L))
    expect_equal(b0_label_l1(c(0L, 12L, 24L), 24L), c(TRUE, FALSE, TRUE))
  })

  test_that("b0_label_l2() applies the Design 118 s1.6 1e-4 tolerance", {
    expect_true(b0_label_l2(1.59640004, 1.5964000447, tol = 1e-4))
    expect_false(b0_label_l2(1.5970, 1.5964000447, tol = 1e-4)) ## well outside 1e-4
    expect_false(b0_label_l2(NA_real_, 1.5964000447))
    expect_false(b0_label_l2(1.0, NA_real_))
  })

  test_that("b0_probe_class() applies the Design 118 s1.2 refusal tiers", {
    expect_equal(b0_probe_class(0.1), "data_determined")
    expect_equal(b0_probe_class(0.25), "penalty_influenced") ## boundary: >= 0.25 is influenced
    expect_equal(b0_probe_class(0.9999), "penalty_influenced")
    expect_equal(b0_probe_class(1.0), "penalty_determined") ## boundary: >= 1.0 is determined
    expect_equal(b0_probe_class(5), "penalty_determined")
    expect_true(is.na(b0_probe_class(NA_real_)))
    expect_equal(
      b0_probe_class(c(0.1, 0.5, 2, NA)),
      c("data_determined", "penalty_influenced", "penalty_determined", NA_character_)
    )
  })

  test_that("b0_s_j() reproduces A1b's raw C011 target-3 movement (0.1792)", {
    ## A1b Task 4.4 / Design 118 P5: cloglog k=24 attractor moves from
    ## 1.715161 (c_n/2) to 1.466704 (2*c_n); |S_hat_3| = 0.1792 raw.
    sj <- b0_s_j(1.715161, 1.466704, se_penalised = 1)
    expect_equal(round(abs(sj$d_per_efold), 4), 0.1792)
  })

  test_that("b0_c_n_formula() matches the C++ template's Bernoulli route", {
    ## src/gllvmTMB.cpp:3166 -- 2*sqrt(p_free/N_eff)*multiplier, and A1b's
    ## own reported constant for the archive's 24-site/3-trait design
    ## (p_free = 6, N_eff = 72): c_n = 0.577350269189626.
    expect_equal(b0_c_n_formula(6, 72), 0.577350269189626, tolerance = 1e-12)
    expect_equal(b0_c_n_formula(6, 72, mult = 0.5), 0.577350269189626 / 2, tolerance = 1e-12)
    expect_equal(b0_c_n_formula(6, 72, mult = 2), 0.577350269189626 * 2, tolerance = 1e-12)
    ## C-ID2's largest-N_eff corner (Design 118 s5.1): p_free=24, N_eff=576.
    expect_equal(b0_c_n_formula(24, 576), 0.408248290463863, tolerance = 1e-9)
  })

  test_that("b0_attractor_root() matches A1b's k=24 cloglog root 1.5964000447", {
    ## A1b Task 1.2, the 24-site/3-trait fixture's own c_n (mult = 1).
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    root <- b0_attractor_root(k = 24L, n = 24L, c_n = c_n, link = "cloglog")
    expect_equal(root, 1.5964000447, tolerance = 1e-8)
  })

  test_that("b0_attractor_root() reproduces A1b's full cloglog k-ladder", {
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    ladder <- c(
      `19` = 0.45053164111, `20` = 0.58045495529, `21` = 0.72499012112,
      `22` = 0.89564704752, `23` = 1.12301287919, `24` = 1.59640004471
    )
    for (k in names(ladder)) {
      root <- b0_attractor_root(k = as.integer(k), n = 24L, c_n = c_n, link = "cloglog")
      expect_equal(root, unname(ladder[[k]]), tolerance = 1e-7, label = paste0("cloglog k=", k))
    }
  })

  test_that("b0_attractor_root() reproduces A1b's logit and probit k=24 roots", {
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    expect_equal(
      b0_attractor_root(k = 24L, n = 24L, c_n = c_n, link = "logit"),
      4.43246352, tolerance = 1e-7
    )
    expect_equal(
      b0_attractor_root(k = 24L, n = 24L, c_n = c_n, link = "probit"),
      2.36293512, tolerance = 1e-7
    )
  })

  test_that("Design 118 P5: the k=24 cloglog root moves to the predicted c_n/2, 2c_n values", {
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    root_half <- b0_attractor_root(k = 24L, n = 24L, c_n = c_n * 0.5, link = "cloglog")
    root_double <- b0_attractor_root(k = 24L, n = 24L, c_n = c_n * 2, link = "cloglog")
    expect_equal(round(root_half, 6), 1.715161)
    expect_equal(round(root_double, 6), 1.466704)
  })

  test_that("b0_attractor_root() stays finite across the full k=0..24 ladder for every link", {
    ## Regression guard for the cloglog overflow fix (exp(a) for a = exp(b)
    ## with b up to the bracket edge; see the score-function comment).
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    for (link in c("logit", "probit", "cloglog")) {
      roots <- vapply(0:24, function(k) b0_attractor_root(k, 24L, c_n, link), numeric(1L))
      expect_true(all(is.finite(roots)), info = link)
      expect_true(all(diff(roots) > 0), info = paste(link, "monotone in k"))
    }
  })

  test_that("b0_trait_counts() reads per-trait success counts and sizes", {
    data <- data.frame(
      trait = factor(rep(c("t1", "t2", "t3"), each = 4), levels = c("t1", "t2", "t3")),
      y = c(0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1)
    )
    counts <- b0_trait_counts(data)
    expect_equal(counts$target_name, c("t1", "t2", "t3"))
    expect_equal(counts$k, c(1L, 4L, 3L))
    expect_equal(counts$n_obs, c(4L, 4L, 4L))
  })

  test_that("b0_penalised_se() fails closed (status flag, not an error) on a broken tape", {
    out <- b0_penalised_se(list(tmb_obj = NULL, opt = list(par = 1)))
    expect_equal(out$status, "hessian_error")
    expect_true(is.na(out$se))
  })

  test_that("b0_route_b_surrogate() fails closed without a covariance or unpenalized tape", {
    no_cov <- b0_route_b_surrogate(list(opt = list(par = c(1, 2))), covariance = NULL)
    expect_equal(no_cov$status, "route_b_no_covariance")
    expect_true(all(is.na(no_cov$s_surr)))

    no_obj <- b0_route_b_surrogate(
      list(opt = list(par = c(1, 2)), mspl = list(unpenalized_tmb_obj = NULL)),
      covariance = diag(2)
    )
    expect_equal(no_obj$status, "route_b_no_unpenalized_obj")
  })

  test_that("b0_output_columns is a schema of unique, present names", {
    expect_true(is.character(b0_output_columns))
    expect_true(length(b0_output_columns) > 0)
    expect_equal(anyDuplicated(b0_output_columns), 0L)
    required <- c(
      "case_id", "outer_id", "target", "target_name", "truth", "k", "n_obs",
      "estimate", "estimate_half_cn", "estimate_double_cn", "se_penalised",
      "d_per_efold", "s_j", "probe_class", "route_b_s_surr", "attractor_root",
      "label_l1", "label_l2", "screen_status", "screen_severity", "status"
    )
    expect_true(all(required %in% b0_output_columns))
  })

  test_that("b0_na_row() produces a schema-conformant all-NA data.frame", {
    row <- b0_na_row(3L)
    expect_equal(names(row), b0_output_columns)
    expect_equal(nrow(row), 3L)
    expect_true(all(vapply(row, function(col) all(is.na(col)), logical(1L))))
  })
})
