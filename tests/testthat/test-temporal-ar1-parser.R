test_that("temporal_latent captures a rank-one AR1 formula", {
  term <- temporal_latent(
    0 + trait | series,
    time = occasion,
    d = 1,
    structure = "ar1"
  )

  expect_s3_class(term, "gllvmTMB_temporal_latent")
  expect_equal(term$d, 1L)
  expect_equal(term$structure, "ar1")
  expect_null(term$replicate)
  expect_equal(all.vars(term$formula), c("trait", "series"))
  expect_equal(as.character(term$time), "occasion")
})

test_that("temporal_latent rejects unsupported rank, structure, and time expressions", {
  expect_error(
    temporal_latent(0 + trait | series, time = occasion, d = 2),
    "rank one"
  )
  expect_error(
    temporal_latent(0 + trait | series, time = occasion, structure = "ou"),
    "structure.*ar1"
  )
  expect_error(
    temporal_latent(0 + trait | series, time = occasion + 1),
    "bare column"
  )
})

test_that("temporal long syntax refuses a non-trait intercept block before TMB", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + temporal_latent(1 | series, time = occasion),
      data = dat, unit = "series", family = gaussian()
    ), "trait-intercept block"
  )
})

test_that("temporal parser creates a collision-safe occasion index and rewrites only its term", {
  dat <- expand.grid(
    series = c("a__b", "a"),
    occasion = 1:3,
    trait = c("t1", "t2", "t3"),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  out <- gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    dat,
    trait_col = "trait"
  )

  expect_true(isTRUE(out$spec$active))
  expect_equal(out$spec$workflow, "unreplicated")
  expect_equal(length(unique(out$data[[out$spec$pair_col]])), 6L)
  expect_equal(anyDuplicated(out$spec$pair_table[c("series", "time")]), 0L)
  expect_match(paste(deparse(out$formula), collapse = " "), "latent", fixed = TRUE)
  expect_match(paste(deparse(out$formula), collapse = " "), out$spec$pair_col, fixed = TRUE)
  expect_false(grepl("temporal_latent", paste(deparse(out$formula), collapse = " "), fixed = TRUE))
})

test_that("temporal parser refuses every unsupported panel shape before TMB", {
  base <- expand.grid(
    series = c("a", "b"), occasion = 1:3, trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  base$value <- seq_len(nrow(base))
  parse <- function(data, replicated = FALSE) {
    gllvmTMB:::.parse_temporal_latent_formula(
      if (replicated) {
        value ~ 0 + trait + temporal_latent(
          0 + trait | series, time = occasion, replicate = measurement
        )
      } else {
        value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion)
      }, data, trait_col = "trait"
    )
  }
  gap <- base
  gap$occasion[gap$series == "a" & gap$occasion == 2] <- 4
  expect_error(parse(gap), "consecutive integer occasions")
  non_integer <- base
  non_integer$occasion[1L] <- 1.5
  expect_error(parse(non_integer), "integer-valued")
  incomplete <- base[-1L, ]
  expect_error(parse(incomplete), "complete trait panel")
  duplicate <- rbind(base, base[1L, ])
  expect_error(parse(duplicate), "require.*replicate")

  replicated <- merge(base, data.frame(measurement = 1:2), by = NULL)
  expect_error(parse(rbind(replicated, replicated[1L, ]), TRUE), "duplicate.*replicate.*trait")
  one_measurement <- replicated[replicated$measurement == 1L, ]
  expect_error(parse(one_measurement, TRUE), "at least two measurements")
  incomplete_replicate <- replicated[-1L, ]
  expect_error(parse(incomplete_replicate, TRUE), "complete trait panel")
})
