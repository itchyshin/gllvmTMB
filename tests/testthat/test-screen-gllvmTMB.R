test_that("screen_gllvmTMB() flags sparse and duplicate binary traits", {
  n <- 20
  df <- data.frame(
    unit = factor(seq_len(n)),
    rare = c(1, rep(0, n - 1)),
    all_zero = 0,
    base = rep(c(0, 1), length.out = n),
    base_dup = rep(c(0, 1), length.out = n),
    base_comp = 1 - rep(c(0, 1), length.out = n)
  )

  scr <- suppressWarnings(screen_gllvmTMB(
    traits(rare, all_zero, base, base_dup, base_comp) ~
      1 + latent(1 | unit, d = 2),
    data = df,
    unit = "unit",
    family = binomial()
  ))

  traits <- screen_table(scr, "traits")
  expect_equal(
    traits$status[match(c("rare", "all_zero", "base"), traits$trait)],
    c("WARN", "FAIL", "PASS")
  )
  expect_equal(
    traits$minority_count[match(c("rare", "base"), traits$trait)],
    c(1, 10)
  )

  pairs <- screen_table(scr, "pairs")
  duplicate <- pairs[pairs$trait_i == "base" & pairs$trait_j == "base_dup", ]
  complement <- pairs[pairs$trait_i == "base" & pairs$trait_j == "base_comp", ]
  expect_equal(duplicate$status, "FAIL")
  expect_equal(duplicate$severity, "duplicate")
  expect_equal(complement$status, "FAIL")
  expect_equal(complement$severity, "complement")
})

test_that("screen_gllvmTMB() flags malformed binomial support", {
  df_binary <- data.frame(
    unit = factor(seq_len(5)),
    trait = factor("indicator"),
    y = c(0, 1, 2, 0, 1)
  )
  scr_binary <- screen_gllvmTMB(
    y ~ 1,
    data = df_binary,
    unit = "unit",
    trait = "trait",
    family = binomial()
  )
  traits_binary <- screen_table(scr_binary, "traits")
  expect_equal(traits_binary$status, "FAIL")
  expect_equal(traits_binary$severity, "invalid")
  expect_equal(traits_binary$invalid_n, 1)

  df_cbind <- data.frame(
    unit = factor(seq_len(4)),
    trait = factor("indicator"),
    success = c(1, 2, -1, 3),
    failure = c(3, 2, 5, 0)
  )
  scr_cbind <- screen_gllvmTMB(
    cbind(success, failure) ~ 1,
    data = df_cbind,
    unit = "unit",
    trait = "trait",
    family = binomial()
  )
  traits_cbind <- screen_table(scr_cbind, "traits")
  expect_equal(traits_cbind$status, "FAIL")
  expect_equal(traits_cbind$severity, "invalid")
  expect_equal(traits_cbind$invalid_n, 1)
})

test_that("screen_gllvmTMB() uses minority counts as well as prevalence", {
  small <- data.frame(
    unit = factor(seq_len(20)),
    trait = factor("indicator"),
    y = c(1, rep(0, 19))
  )
  small_scr <- screen_gllvmTMB(
    y ~ 1,
    data = small,
    unit = "unit",
    trait = "trait",
    family = binomial()
  )
  small_traits <- screen_table(small_scr, "traits")
  expect_equal(small_traits$status, "WARN")
  expect_equal(small_traits$severity, "strong")

  n <- 100000
  large <- data.frame(
    unit = factor(seq_len(n)),
    trait = factor("indicator"),
    y = c(rep(1, 1000), rep(0, n - 1000))
  )
  large_scr <- screen_gllvmTMB(
    y ~ 1,
    data = large,
    unit = "unit",
    trait = "trait",
    family = binomial()
  )
  large_traits <- screen_table(large_scr, "traits")
  expect_equal(large_traits$status, "INFO")
  expect_equal(large_traits$severity, "extreme_imbalance")
  expect_equal(large_traits$minority_count, 1000)
  expect_equal(large_traits$prevalence, 0.01)
})

test_that("screen_gllvmTMB() sample-size grid is count-first", {
  grid <- expand.grid(
    n = c(20, 50, 200, 1000, 100000),
    prevalence = c(0, 0.001, 0.005, 0.01, 0.05, 0.5, 0.95, 0.99, 1),
    KEEP.OUT.ATTRS = FALSE
  )

  observed <- lapply(seq_len(nrow(grid)), function(i) {
    n <- grid$n[[i]]
    k <- round(n * grid$prevalence[[i]])
    df <- data.frame(
      trait = factor("indicator"),
      y = c(rep(1, k), rep(0, n - k))
    )
    scr <- screen_gllvmTMB(
      y ~ 1,
      data = df,
      trait = "trait",
      family = binomial()
    )
    out <- screen_table(scr, "traits")
    data.frame(
      n = n,
      prevalence_target = grid$prevalence[[i]],
      status = out$status,
      severity = out$severity,
      minority_count = out$minority_count,
      prevalence = out$prevalence
    )
  })
  observed <- do.call(rbind, observed)

  expected_status <- ifelse(
    observed$minority_count == 0,
    "FAIL",
    ifelse(
      observed$minority_count < 10,
      "WARN",
      ifelse(
        observed$prevalence < 0.05 | observed$prevalence > 0.95,
        "INFO",
        "PASS"
      )
    )
  )
  expect_equal(observed$status, expected_status)

  large_rare <- observed[
    observed$n == 100000 & observed$prevalence_target %in% c(0.001, 0.01),
  ]
  expect_equal(large_rare$status, c("INFO", "INFO"))
  expect_equal(large_rare$minority_count, c(100, 1000))
})

test_that("screen_gllvmTMB() uses strong pairwise association thresholds", {
  n <- 1000
  x <- rep(c(0, 1), each = n / 2)
  y <- x
  y[c(1:10, 501:510)] <- 1 - y[c(1:10, 501:510)]
  df <- data.frame(
    unit = factor(seq_len(n)),
    x = x,
    y = y
  )

  scr <- screen_gllvmTMB(
    traits(x, y) ~ 1,
    data = df,
    unit = "unit",
    family = binomial()
  )

  pair <- screen_table(scr, "pairs")
  expect_equal(pair$status, "WARN")
  expect_equal(pair$severity, "strong_association")
  expect_equal(pair$discordant_n, 20)
  expect_gt(pair$phi, 0.95)
})

test_that("screen_gllvmTMB() checks requested discordant-count boundaries", {
  discordant_counts <- c(0, 1, 5, 10, 50, 500)
  pairs <- lapply(discordant_counts, function(discordant_n) {
    n <- 1000
    x <- rep(c(0, 1), each = n / 2)
    y <- x
    if (discordant_n > 0L) {
      n_low <- floor(discordant_n / 2)
      n_high <- discordant_n - n_low
      flip <- c(
        if (n_low > 0L) seq_len(n_low) else integer(0),
        if (n_high > 0L) n / 2 + seq_len(n_high) else integer(0)
      )
      y[flip] <- 1 - y[flip]
    }
    df <- data.frame(
      unit = factor(seq_len(n)),
      x = x,
      y = y
    )
    scr <- screen_gllvmTMB(
      traits(x, y) ~ 1,
      data = df,
      unit = "unit",
      family = binomial()
    )
    cbind(
      data.frame(target_discordant_n = discordant_n),
      screen_table(scr, "pairs")
    )
  })
  pairs <- do.call(rbind, pairs)

  expect_equal(pairs$discordant_n, discordant_counts)
  expect_equal(
    pairs$status,
    c("FAIL", "WARN", "WARN", "WARN", "WARN", "PASS")
  )
  expect_equal(
    pairs$severity,
    c("duplicate", "strong", "moderate", "moderate", "association", "none")
  )
})

test_that("screen_gllvmTMB() handles cbind and weights binomial modes", {
  df_cbind <- data.frame(
    unit = factor(rep(seq_len(4), each = 2)),
    trait = factor(rep(c("a", "b"), times = 4)),
    success = c(1, 8, 2, 7, 3, 6, 4, 5),
    failure = c(9, 2, 8, 3, 7, 4, 6, 5)
  )
  scr_cbind <- screen_gllvmTMB(
    cbind(success, failure) ~ 1,
    data = df_cbind,
    unit = "unit",
    trait = "trait",
    family = binomial()
  )
  traits_cbind <- screen_table(scr_cbind, "traits")
  expect_equal(unique(traits_cbind$response_mode), "cbind")
  expect_equal(traits_cbind$total_trials, c(40, 40))
  expect_equal(screen_table(scr_cbind, "pairs")$status, "NOT_CHECKED")

  df_weights <- data.frame(
    unit = factor(rep(seq_len(4), each = 2)),
    trait = factor(rep(c("a", "b"), times = 4)),
    y = c(1, 8, 2, 7, 3, 6, 4, 5),
    trials = c(10, 10, 10, 10, 10, 10, 10, 10)
  )
  scr_weights <- screen_gllvmTMB(
    y ~ 1,
    data = df_weights,
    unit = "unit",
    trait = "trait",
    weights = df_weights$trials,
    family = binomial()
  )
  traits_weights <- screen_table(scr_weights, "traits")
  expect_equal(unique(traits_weights$response_mode), "weights")
  expect_equal(traits_weights$total_trials, c(40, 40))
})

test_that("screen_gllvmTMB() keeps long and wide trait summaries aligned", {
  wide <- data.frame(
    unit = factor(seq_len(12)),
    x = rep(c(0, 1), 6),
    a = rep(c(0, 1), 6),
    b = rep(c(1, 0), 6)
  )
  wide_scr <- suppressWarnings(screen_gllvmTMB(
    traits(a, b) ~ x + latent(1 | unit, d = 1),
    data = wide,
    unit = "unit",
    family = binomial()
  ))

  long <- data.frame(
    unit = rep(wide$unit, times = 2),
    x = rep(wide$x, times = 2),
    trait = factor(rep(c("a", "b"), each = nrow(wide))),
    y = c(wide$a, wide$b)
  )
  long_scr <- suppressWarnings(screen_gllvmTMB(
    y ~ x + latent(1 | unit, d = 1),
    data = long,
    unit = "unit",
    trait = "trait",
    family = binomial()
  ))

  wide_traits <- screen_table(wide_scr, "traits")
  long_traits <- screen_table(long_scr, "traits")
  expect_equal(wide_traits$trait, long_traits$trait)
  expect_equal(wide_traits$status, long_traits$status)
  expect_equal(wide_traits$n_success, long_traits$n_success)
  expect_equal(wide_traits$n_failure, long_traits$n_failure)
})

test_that("screen_gllvmTMB() reports formula design risks", {
  df <- data.frame(
    unit = factor(seq_len(12)),
    x = rep(c(0, 1), 6),
    x_dup = rep(c(0, 1), 6),
    a = rep(c(0, 1), 6),
    b = rep(c(1, 0), 6)
  )
  scr <- suppressWarnings(screen_gllvmTMB(
    traits(a, b) ~ x + x_dup + latent(1 | unit, d = 2),
    data = df,
    unit = "unit",
    family = binomial()
  ))
  design <- screen_table(scr, "design")
  expect_equal(
    design$status[match(
      c("fixed_effect_rank", "latent_rank_1"),
      design$component
    )],
    c("FAIL", "WARN")
  )
})

test_that("screen_gllvmTMB() returns NOT_CHECKED for unsupported families", {
  df <- data.frame(
    unit = factor(seq_len(6)),
    trait = factor("count"),
    y = c(0, 1, 0, 2, 3, 0)
  )
  scr <- screen_gllvmTMB(
    y ~ 1,
    data = df,
    unit = "unit",
    trait = "trait",
    family = poisson()
  )
  expect_equal(screen_table(scr, "traits")$status, "NOT_CHECKED")
  expect_equal(screen_table(scr, "recommendations")$action, "unsupported")
})
